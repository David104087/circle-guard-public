package com.circleguard.dashboard.integration;

import com.circleguard.dashboard.client.PromotionClient;
import com.circleguard.dashboard.service.AnalyticsService;
import com.circleguard.dashboard.service.KAnonymityFilter;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;
import java.util.UUID;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class DashboardIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PromotionClient promotionClient;

    @Test
    void healthBoardEndpoint_shouldReturnStatsFromPromotionService() throws Exception {
        when(promotionClient.getHealthStats()).thenReturn(
                Map.of("totalGreen", 1500, "totalExposed", 45, "totalConfirmed", 3));

        mockMvc.perform(get("/api/v1/analytics/health-board")
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalGreen").value(1500))
                .andExpect(jsonPath("$.totalExposed").value(45));
    }

    @Test
    void summaryEndpoint_shouldDelegateToPromotionClient() throws Exception {
        when(promotionClient.getHealthStats()).thenReturn(
                Map.of("activeUsers", 500, "suspectCount", 12));

        mockMvc.perform(get("/api/v1/analytics/summary"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.activeUsers").value(500));
    }

    @Test
    void departmentEndpoint_shouldApplyKAnonymityBeforeReturning() throws Exception {
        when(promotionClient.getHealthStatsByDepartment("CS")).thenReturn(
                Map.of("totalUsers", 3L, "department", "CS", "suspectCount", 2L));

        mockMvc.perform(get("/api/v1/analytics/department/CS"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalUsers").value("<5"))
                .andExpect(jsonPath("$.note").exists());
    }

    @Test
    void timeSeriesEndpoint_shouldReturnDataForHourlyPeriod() throws Exception {
        mockMvc.perform(get("/api/v1/analytics/time-series")
                        .param("period", "hourly")
                        .param("limit", "5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    @Test
    void trendsEndpoint_shouldAcceptValidUUIDAndReturnArray() throws Exception {
        UUID locationId = UUID.randomUUID();

        mockMvc.perform(get("/api/v1/analytics/trends/{locationId}", locationId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }
}
