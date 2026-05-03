package com.circleguard.auth.e2e;

import com.circleguard.auth.client.IdentityClient;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthLoginE2ETest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private IdentityClient identityClient;

    @Test
    void login_withInvalidCredentials_shouldReturn401() throws Exception {
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                Map.of("username", "bad-user", "password", "bad-pass"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message").exists());
    }

    @Test
    void visitorHandoff_withValidId_shouldReturnBearerToken() throws Exception {
        UUID anonId = UUID.randomUUID();

        mockMvc.perform(post("/api/v1/auth/visitor/handoff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                Map.of("anonymousId", anonId.toString()))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").exists())
                .andExpect(jsonPath("$.handoffPayload").exists());
    }

    @Test
    void visitorHandoff_tokenShouldContainCorrectAnonymousId() throws Exception {
        UUID anonId = UUID.randomUUID();

        MvcResult result = mockMvc.perform(post("/api/v1/auth/visitor/handoff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                Map.of("anonymousId", anonId.toString()))))
                .andExpect(status().isOk())
                .andReturn();

        String body = result.getResponse().getContentAsString();
        assertThat(body).contains(anonId.toString());
    }

    @Test
    void visitorHandoff_withoutAnonymousId_shouldReturn400() throws Exception {
        mockMvc.perform(post("/api/v1/auth/visitor/handoff")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void visitorHandoff_consecutiveRequests_shouldProduceValidTokens() throws Exception {
        UUID anonId1 = UUID.randomUUID();
        UUID anonId2 = UUID.randomUUID();

        MvcResult r1 = mockMvc.perform(post("/api/v1/auth/visitor/handoff")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("anonymousId", anonId1.toString()))))
                .andExpect(status().isOk()).andReturn();

        MvcResult r2 = mockMvc.perform(post("/api/v1/auth/visitor/handoff")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("anonymousId", anonId2.toString()))))
                .andExpect(status().isOk()).andReturn();

        String token1 = objectMapper.readTree(r1.getResponse().getContentAsString()).get("token").asText();
        String token2 = objectMapper.readTree(r2.getResponse().getContentAsString()).get("token").asText();
        assertThat(token1).isNotEqualTo(token2);
    }
}
