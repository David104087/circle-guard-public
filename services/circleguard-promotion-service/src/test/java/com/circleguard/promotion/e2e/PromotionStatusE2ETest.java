package com.circleguard.promotion.e2e;

import com.circleguard.promotion.service.HealthStatusService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class PromotionStatusE2ETest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private HealthStatusService statusService;

    @Test
    @WithMockUser(roles = "HEALTH_CENTER")
    void reportStatus_withHealthCenterRole_shouldReturn200() throws Exception {
        String body = objectMapper.writeValueAsString(Map.of(
                "anonymousId", "user-abc",
                "status", "SUSPECT"));

        mockMvc.perform(post("/api/v1/health/report")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk());

        verify(statusService).updateStatus("user-abc", "SUSPECT", false);
    }

    @Test
    @WithMockUser(roles = "HEALTH_CENTER")
    void confirmPositive_shouldSetConfirmedStatus() throws Exception {
        String body = objectMapper.writeValueAsString(Map.of("anonymousId", "user-xyz"));

        mockMvc.perform(post("/api/v1/health/confirmed")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk());

        verify(statusService).updateStatus("user-xyz", "CONFIRMED");
    }

    @Test
    @WithMockUser(roles = "HEALTH_CENTER")
    void recovery_shouldInvokePromoteToRecovered() throws Exception {
        mockMvc.perform(post("/api/v1/health/recovery/user-recover"))
                .andExpect(status().isOk());

        verify(statusService).promoteToRecovered("user-recover");
    }

    @Test
    @WithMockUser(roles = "STUDENT")
    void reportStatus_withoutHealthCenterRole_shouldReturn403() throws Exception {
        String body = objectMapper.writeValueAsString(Map.of(
                "anonymousId", "user-abc",
                "status", "SUSPECT"));

        mockMvc.perform(post("/api/v1/health/report")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "HEALTH_CENTER")
    void reportStatusWithAdminOverride_shouldPassOverrideFlag() throws Exception {
        String body = objectMapper.writeValueAsString(Map.of(
                "anonymousId", "user-admin",
                "status", "ACTIVE",
                "adminOverride", true));

        mockMvc.perform(post("/api/v1/health/report")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk());

        verify(statusService).updateStatus("user-admin", "ACTIVE", true);
    }
}
