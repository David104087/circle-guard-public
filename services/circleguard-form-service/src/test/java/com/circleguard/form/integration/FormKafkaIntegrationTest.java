package com.circleguard.form.integration;

import com.circleguard.form.model.HealthSurvey;
import com.circleguard.form.repository.HealthSurveyRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FormKafkaIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private HealthSurveyRepository surveyRepository;

    @MockBean
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Test
    void submitSurvey_shouldTriggerKafkaEvent() throws Exception {
        UUID anonId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder()
                .anonymousId(anonId)
                .hasFever(false)
                .hasCough(false)
                .build();

        HealthSurvey saved = HealthSurvey.builder()
                .id(UUID.randomUUID())
                .anonymousId(anonId)
                .hasFever(false)
                .hasCough(false)
                .build();
        when(surveyRepository.save(any())).thenReturn(saved);

        mockMvc.perform(post("/api/v1/surveys")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(survey)))
                .andExpect(status().isOk());

        verify(kafkaTemplate).send(eq("survey.submitted"), eq(anonId.toString()), any());
    }

    @Test
    void submitSurveyWithAttachment_shouldSetPendingStatus() throws Exception {
        UUID anonId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder()
                .anonymousId(anonId)
                .attachmentPath("/uploads/cert.pdf")
                .build();

        when(surveyRepository.save(any())).thenAnswer(inv -> {
            HealthSurvey s = inv.getArgument(0);
            return HealthSurvey.builder()
                    .id(UUID.randomUUID())
                    .anonymousId(s.getAnonymousId())
                    .attachmentPath(s.getAttachmentPath())
                    .validationStatus(s.getValidationStatus())
                    .build();
        });

        mockMvc.perform(post("/api/v1/surveys")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(survey)))
                .andExpect(status().isOk());

        verify(kafkaTemplate).send(eq("survey.submitted"), anyString(), any());
    }
}
