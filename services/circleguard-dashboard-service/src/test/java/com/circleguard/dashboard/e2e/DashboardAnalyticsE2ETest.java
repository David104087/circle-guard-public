package com.circleguard.dashboard.e2e;

import com.circleguard.dashboard.client.PromotionClient;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class DashboardAnalyticsE2ETest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    @MockBean
    private PromotionClient promotionClient;

    private String url(String path) {
        return "http://localhost:" + port + path;
    }

    @Test
    void healthBoard_fullFlow_shouldReturnAggregatedStats() {
        when(promotionClient.getHealthStats()).thenReturn(Map.of(
                "totalGreen", 1500,
                "totalExposed", 45,
                "totalConfirmed", 3,
                "timestamp", System.currentTimeMillis()
        ));

        ResponseEntity<Map> response = restTemplate.getForEntity(
                url("/api/v1/analytics/health-board"), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().get("totalGreen")).isEqualTo(1500);
    }

    @Test
    void timeSeries_fullFlow_shouldReturnNonEmptyList() {
        ResponseEntity<List> response = restTemplate.getForEntity(
                url("/api/v1/analytics/time-series?period=hourly&limit=10"), List.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotEmpty();
    }

    @Test
    void department_withSmallPopulation_shouldMaskData() {
        when(promotionClient.getHealthStatsByDepartment("TINY")).thenReturn(Map.of(
                "totalUsers", 2L,
                "department", "TINY",
                "suspectCount", 1L
        ));

        ResponseEntity<Map> response = restTemplate.getForEntity(
                url("/api/v1/analytics/department/TINY"), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().get("totalUsers")).isEqualTo("<5");
        assertThat(response.getBody()).containsKey("note");
    }

    @Test
    void trends_withValidLocationId_shouldReturn200AndArray() {
        UUID locationId = UUID.randomUUID();

        ResponseEntity<List> response = restTemplate.getForEntity(
                url("/api/v1/analytics/trends/" + locationId), List.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isNotNull();
    }

    @Test
    void summary_shouldDelegateToPromotionAndReturnData() {
        when(promotionClient.getHealthStats()).thenReturn(Map.of(
                "activeUsers", 300,
                "suspectUsers", 15
        ));

        ResponseEntity<Map> response = restTemplate.getForEntity(
                url("/api/v1/analytics/summary"), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().get("activeUsers")).isEqualTo(300);
    }
}
