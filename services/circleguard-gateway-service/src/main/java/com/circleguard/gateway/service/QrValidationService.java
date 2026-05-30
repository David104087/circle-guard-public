package com.circleguard.gateway.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;
import java.security.Key;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class QrValidationService {
    private final StringRedisTemplate redisTemplate;
    private final MeterRegistry meterRegistry;

    @Value("${qr.secret}")
    private String qrSecret;

    private static final String STATUS_KEY_PREFIX = "user:status:";

    public ValidationResult validateToken(String token) {
        try {
            Key key = Keys.hmacShaKeyFor(qrSecret.getBytes());
            Claims claims = Jwts.parserBuilder()
                    .setSigningKey(key)
                    .build()
                    .parseClaimsJws(token)
                    .getBody();

            String anonymousId = claims.getSubject();

            // Check Redis for current Health Status
            String status = redisTemplate.opsForValue().get(STATUS_KEY_PREFIX + anonymousId);

            if ("CONTAGIED".equals(status) || "POTENTIAL".equals(status)) {
                recordValidation("RED");
                return new ValidationResult(false, "RED", "Access Denied: Health Risk Detected");
            }

            recordValidation("GREEN");
            return new ValidationResult(true, "GREEN", "Welcome to Campus");

        } catch (Exception e) {
            recordValidation("INVALID");
            return new ValidationResult(false, "RED", "Invalid or Expired Token");
        }
    }

    private void recordValidation(String result) {
        Counter.builder("qr_validations_total")
            .description("Total QR access validations processed at the campus gateway")
            .tag("result", result)
            .register(meterRegistry)
            .increment();
    }

    public record ValidationResult(boolean valid, String status, String message) {}
}
