package com.circleguard.auth.service;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.security.Key;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class JwtTokenServiceTest {

    private static final String SECRET = "my-super-secret-dev-key-32-chars-long-12345678";
    private static final long EXPIRATION = 3_600_000L;

    private JwtTokenService jwtService;

    @BeforeEach
    void setUp() {
        jwtService = new JwtTokenService(SECRET, EXPIRATION);
    }

    @Test
    void generateToken_shouldContainAnonymousIdAsSubject() {
        UUID anonymousId = UUID.randomUUID();
        Authentication auth = new UsernamePasswordAuthenticationToken(
                "user", null, List.of(new SimpleGrantedAuthority("ROLE_STUDENT")));

        String token = jwtService.generateToken(anonymousId, auth);

        Claims claims = parseClaims(token);
        assertThat(claims.getSubject()).isEqualTo(anonymousId.toString());
    }

    @Test
    void generateToken_shouldContainPermissionsInClaims() {
        UUID anonymousId = UUID.randomUUID();
        Authentication auth = new UsernamePasswordAuthenticationToken(
                "user", null,
                List.of(new SimpleGrantedAuthority("ROLE_STUDENT"),
                        new SimpleGrantedAuthority("ROLE_HEALTH_CENTER")));

        String token = jwtService.generateToken(anonymousId, auth);

        Claims claims = parseClaims(token);
        @SuppressWarnings("unchecked")
        List<String> permissions = (List<String>) claims.get("permissions");
        assertThat(permissions).containsExactlyInAnyOrder("ROLE_STUDENT", "ROLE_HEALTH_CENTER");
    }

    @Test
    void generateToken_shouldNotBeExpiredImmediately() {
        UUID anonymousId = UUID.randomUUID();
        Authentication auth = new UsernamePasswordAuthenticationToken(
                "user", null, List.of());

        String token = jwtService.generateToken(anonymousId, auth);

        Claims claims = parseClaims(token);
        assertThat(claims.getExpiration()).isAfter(claims.getIssuedAt());
        assertThat(claims.getExpiration().getTime() - claims.getIssuedAt().getTime())
                .isEqualTo(EXPIRATION);
    }

    @Test
    void generateToken_shouldProduceDifferentTokensForDifferentUsers() {
        Authentication auth = new UsernamePasswordAuthenticationToken("user", null, List.of());

        String token1 = jwtService.generateToken(UUID.randomUUID(), auth);
        String token2 = jwtService.generateToken(UUID.randomUUID(), auth);

        assertThat(token1).isNotEqualTo(token2);
    }

    @Test
    void generateToken_shouldHandleEmptyAuthorities() {
        UUID anonymousId = UUID.randomUUID();
        Authentication auth = new UsernamePasswordAuthenticationToken("user", null, List.of());

        String token = jwtService.generateToken(anonymousId, auth);

        Claims claims = parseClaims(token);
        @SuppressWarnings("unchecked")
        List<String> permissions = (List<String>) claims.get("permissions");
        assertThat(permissions).isEmpty();
    }

    private Claims parseClaims(String token) {
        Key key = Keys.hmacShaKeyFor(SECRET.getBytes());
        return Jwts.parserBuilder().setSigningKey(key).build()
                .parseClaimsJws(token).getBody();
    }
}
