package com.circleguard.auth.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.stereotype.Service;
import java.security.Key;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class JwtTokenService {

    private final Key key;
    private final long expiration;
    private final MeterRegistry meterRegistry;

    public JwtTokenService(@Value("${jwt.secret}") String secret,
                         @Value("${jwt.expiration}") long expiration,
                         MeterRegistry meterRegistry) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes());
        this.expiration = expiration;
        this.meterRegistry = meterRegistry;
    }

    public String generateToken(UUID anonymousId, Authentication auth) {
        Map<String, Object> claims = new HashMap<>();
        List<String> permissions = auth.getAuthorities().stream()
                .map(GrantedAuthority::getAuthority)
                .collect(Collectors.toList());

        claims.put("permissions", permissions);

        Counter.builder("auth_tokens_issued_total")
            .description("Total JWT access tokens issued after successful authentication")
            .register(meterRegistry)
            .increment();

        return Jwts.builder()
                .setClaims(claims)
                .setSubject(anonymousId.toString())
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + expiration))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();
    }
}
