package com.circleguard.form.e2e;

import com.circleguard.form.model.HealthSurvey;
import com.circleguard.form.model.ValidationStatus;
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

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class HealthSurveyE2ETest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private HealthSurveyRepository surveyRepository;

    @MockBean
    private KafkaTemplate<String, Object> kafkaTemplate;

    @Test
    void submitSurvey_noSymptoms_shouldReturn200AndEmitEvent() throws Exception {
        UUID anonId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder()
                .anonymousId(anonId)
                .hasFever(false)
                .hasCough(false)
                .build();

        HealthSurvey saved = HealthSurvey.builder()
                .id(UUID.randomUUID()).anonymousId(anonId)
                .hasFever(false).hasCough(false)
                .build();
        when(surveyRepository.save(any())).thenReturn(saved);

        mockMvc.perform(post("/api/v1/surveys")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(survey)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.anonymousId").value(anonId.toString()));

        verify(kafkaTemplate).send(eq("survey.submitted"), eq(anonId.toString()), any());
    }

    @Test
    void submitSurvey_withAttachment_shouldSetPendingStatus() throws Exception {
        UUID anonId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder()
                .anonymousId(anonId)
                .attachmentPath("/uploads/test.pdf")
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
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.validationStatus").value("PENDING"));
    }

    @Test
    void getPendingCertificates_shouldReturnListEndpoint() throws Exception {
        when(surveyRepository.findByAttachmentPathIsNotNullAndValidationStatus(any()))
                .thenReturn(List.of());

        mockMvc.perform(get("/api/v1/certificates/pending"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray());
    }

    @Test
    void submitSurvey_withInvalidBody_shouldReturn4xx() throws Exception {
        mockMvc.perform(post("/api/v1/surveys")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("not-json"))
                .andExpect(status().is4xxClientError());
    }

    @Test
    void validateCertificate_approved_shouldEmitCertificateEvent() throws Exception {
        UUID surveyId = UUID.randomUUID();
        UUID adminId = UUID.randomUUID();
        UUID anonId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder()
                .id(surveyId).anonymousId(anonId).build();

        when(surveyRepository.findById(surveyId)).thenReturn(Optional.of(survey));
        when(surveyRepository.save(any())).thenReturn(survey);

        mockMvc.perform(post("/api/v1/certificates/{id}/validate", surveyId)
                        .param("status", "APPROVED")
                        .param("adminId", adminId.toString()))
                .andExpect(status().isOk());

        verify(kafkaTemplate).send(eq("certificate.validated"), eq(anonId.toString()), any());
    }
}
