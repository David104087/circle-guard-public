package com.circleguard.dashboard.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class KAnonymityFilterTest {

    private KAnonymityFilter filter;

    @BeforeEach
    void setUp() {
        filter = new KAnonymityFilter();
    }

    @Test
    void shouldReturnEmptyMapWhenInputIsNull() {
        Map<String, Object> result = filter.apply(null);
        assertThat(result).isEmpty();
    }

    @Test
    void shouldMaskCountFieldsBelowK() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 100L);
        stats.put("suspectCount", 3L);
        stats.put("confirmedCount", 10L);

        Map<String, Object> result = filter.apply(stats);

        assertThat(result.get("suspectCount")).isEqualTo("<5");
        assertThat(result.get("confirmedCount")).isEqualTo(10L);
    }

    @Test
    void shouldMaskEntireResultWhenTotalUsersBelowK() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 3L);
        stats.put("department", "CS");
        stats.put("suspectCount", 2L);

        Map<String, Object> result = filter.apply(stats);

        assertThat(result.get("totalUsers")).isEqualTo("<5");
        assertThat(result).containsKey("note");
        assertThat(result.get("department")).isEqualTo("CS");
    }

    @Test
    void shouldNotMaskWhenAllCountsAboveOrEqualK() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 200L);
        stats.put("suspectCount", 10L);
        stats.put("confirmedCount", 7L);

        Map<String, Object> result = filter.apply(stats);

        assertThat(result.get("suspectCount")).isEqualTo(10L);
        assertThat(result.get("confirmedCount")).isEqualTo(7L);
    }

    @Test
    void shouldRespectCustomKThreshold() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 50L);
        stats.put("suspectCount", 7L);

        Map<String, Object> result = filter.apply(stats, 10);

        assertThat(result.get("suspectCount")).isEqualTo("<10");
    }

    @Test
    void shouldNotModifyZeroCountFields() {
        Map<String, Object> stats = new LinkedHashMap<>();
        stats.put("totalUsers", 100L);
        stats.put("suspectCount", 0L);

        Map<String, Object> result = filter.apply(stats);

        assertThat(result.get("suspectCount")).isEqualTo(0L);
    }
}
