package com.circleguard.dashboard.service;

import com.circleguard.dashboard.client.PromotionClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AnalyticsServiceTest {

    @Mock
    private JdbcTemplate jdbc;

    @Mock
    private PromotionClient promotionClient;

    private KAnonymityFilter kAnonymityFilter;
    private AnalyticsService service;

    @BeforeEach
    void setUp() {
        kAnonymityFilter = new KAnonymityFilter();
        service = new AnalyticsService(jdbc, promotionClient, kAnonymityFilter);
    }

    @Test
    void getCampusSummary_shouldDelegateToPromotionClient() {
        Map<String, Object> expected = Map.of("totalGreen", 1500, "totalExposed", 45);
        when(promotionClient.getHealthStats()).thenReturn(expected);

        Map<String, Object> result = service.getCampusSummary();

        assertThat(result).isEqualTo(expected);
    }

    @Test
    void getDepartmentStats_shouldApplyKAnonymity() {
        Map<String, Object> raw = Map.of("totalUsers", 3L, "department", "Math", "suspectCount", 2L);
        when(promotionClient.getHealthStatsByDepartment("Math")).thenReturn(raw);

        Map<String, Object> result = service.getDepartmentStats("Math");

        assertThat(result.get("totalUsers")).isEqualTo("<5");
        assertThat(result).containsKey("note");
    }

    @Test
    void getTimeSeries_shouldReturnMockDataWhenTableMissing() {
        when(jdbc.queryForList(anyString(), anyInt()))
                .thenThrow(new RuntimeException("Table not found"));

        List<Map<String, Object>> result = service.getTimeSeries("hourly", 24);

        assertThat(result).isNotEmpty();
        assertThat(result.get(0)).containsKey("status");
        assertThat(result.get(0)).containsKey("total");
    }

    @Test
    void getEntryTrends_shouldMaskCountsBelowK() {
        java.util.LinkedHashMap<String, Object> row1 = new java.util.LinkedHashMap<>();
        row1.put("hour", "2025-01-01T10:00");
        row1.put("entry_count", 2L);
        java.util.LinkedHashMap<String, Object> row2 = new java.util.LinkedHashMap<>();
        row2.put("hour", "2025-01-01T11:00");
        row2.put("entry_count", 20L);

        when(jdbc.queryForList(anyString(), any(UUID.class))).thenReturn(List.of(row1, row2));

        UUID locationId = UUID.randomUUID();
        List<Map<String, Object>> result = service.getEntryTrends(locationId);

        assertThat(result).hasSize(2);
        assertThat(result.get(0).get("entry_count")).isEqualTo("<5");
        assertThat(result.get(1).get("entry_count")).isEqualTo(20L);
    }
}
