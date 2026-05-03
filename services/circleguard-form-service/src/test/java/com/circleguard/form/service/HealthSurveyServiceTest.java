package com.circleguard.form.service;

import com.circleguard.form.model.HealthSurvey;
import com.circleguard.form.model.Question;
import com.circleguard.form.model.QuestionType;
import com.circleguard.form.model.Questionnaire;
import com.circleguard.form.model.ValidationStatus;
import com.circleguard.form.repository.HealthSurveyRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.kafka.core.KafkaTemplate;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HealthSurveyServiceTest {

    @Mock
    private HealthSurveyRepository repository;

    @Mock
    private QuestionnaireService questionnaireService;

    @Mock
    private SymptomMapper symptomMapper;

    @Mock
    private KafkaTemplate<String, Object> kafkaTemplate;

    private HealthSurveyService service;

    @BeforeEach
    void setUp() {
        service = new HealthSurveyService(repository, questionnaireService, symptomMapper, kafkaTemplate);
    }

    @Test
    void submitSurvey_shouldEmitKafkaEventOnSubmission() {
        UUID anonId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder().anonymousId(anonId).build();
        Questionnaire questionnaire = new Questionnaire();

        when(questionnaireService.getActiveQuestionnaire()).thenReturn(Optional.of(questionnaire));
        when(symptomMapper.hasSymptoms(survey, questionnaire)).thenReturn(false);
        when(repository.save(any())).thenReturn(survey);

        service.submitSurvey(survey);

        verify(kafkaTemplate).send(eq("survey.submitted"), eq(anonId.toString()), any());
    }

    @Test
    void submitSurvey_shouldSetValidationStatusPendingWhenAttachmentPresent() {
        UUID anonId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder()
                .anonymousId(anonId)
                .attachmentPath("/uploads/cert.pdf")
                .build();

        when(questionnaireService.getActiveQuestionnaire()).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        HealthSurvey result = service.submitSurvey(survey);

        assertThat(result.getValidationStatus()).isEqualTo(ValidationStatus.PENDING);
    }

    @Test
    void submitSurvey_shouldNotSetPendingStatusWhenNoAttachment() {
        UUID anonId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder().anonymousId(anonId).build();

        when(questionnaireService.getActiveQuestionnaire()).thenReturn(Optional.empty());
        when(repository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        HealthSurvey result = service.submitSurvey(survey);

        assertThat(result.getValidationStatus()).isNull();
    }

    @Test
    void validateSurvey_shouldEmitCertificateValidatedEventOnApproval() {
        UUID surveyId = UUID.randomUUID();
        UUID adminId = UUID.randomUUID();
        UUID anonId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder().id(surveyId).anonymousId(anonId).build();

        when(repository.findById(surveyId)).thenReturn(Optional.of(survey));
        when(repository.save(any())).thenReturn(survey);

        service.validateSurvey(surveyId, ValidationStatus.APPROVED, adminId);

        verify(kafkaTemplate).send(eq("certificate.validated"), eq(anonId.toString()), any());
    }

    @Test
    void validateSurvey_shouldNotEmitEventWhenRejected() {
        UUID surveyId = UUID.randomUUID();
        UUID adminId = UUID.randomUUID();
        HealthSurvey survey = HealthSurvey.builder().id(surveyId).anonymousId(UUID.randomUUID()).build();

        when(repository.findById(surveyId)).thenReturn(Optional.of(survey));
        when(repository.save(any())).thenReturn(survey);

        service.validateSurvey(surveyId, ValidationStatus.REJECTED, adminId);

        verify(kafkaTemplate, never()).send(eq("certificate.validated"), anyString(), any());
    }
}
