package com.circleguard.notification.integration;

import com.circleguard.notification.service.ExposureNotificationListener;
import com.circleguard.notification.service.LmsService;
import com.circleguard.notification.service.NotificationDispatcher;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.test.context.ActiveProfiles;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@SpringBootTest
@ActiveProfiles("test")
class NotificationKafkaIntegrationTest {

    @MockBean
    private NotificationDispatcher dispatcher;

    @MockBean
    private LmsService lmsService;

    @SpyBean
    private ExposureNotificationListener listener;

    @Test
    void handleStatusChanged_suspectStatus_shouldInvokeDispatcher() throws Exception {
        String eventJson = """
                {"anonymousId":"user-123","status":"SUSPECT","timestamp":1234567890}
                """;

        listener.handleStatusChange(eventJson);

        verify(dispatcher).dispatch("user-123", "SUSPECT");
    }

    @Test
    void handleStatusChanged_confirmedStatus_shouldInvokeDispatcher() throws Exception {
        String eventJson = """
                {"anonymousId":"user-456","status":"CONFIRMED","timestamp":1234567890}
                """;

        listener.handleStatusChange(eventJson);

        verify(dispatcher).dispatch("user-456", "CONFIRMED");
    }

    @Test
    void handleStatusChanged_activeStatus_shouldNotDispatch() throws Exception {
        String eventJson = """
                {"anonymousId":"user-789","status":"ACTIVE","timestamp":1234567890}
                """;

        listener.handleStatusChange(eventJson);

        verify(dispatcher, never()).dispatch(anyString(), anyString());
    }

    @Test
    void handleStatusChanged_malformedJson_shouldNotThrow() {
        org.junit.jupiter.api.Assertions.assertDoesNotThrow(
                () -> listener.handleStatusChange("not-valid-json{{"));
    }

    @Test
    void handleStatusChanged_suspectStatus_shouldAlsoSyncLms() throws Exception {
        String eventJson = """
                {"anonymousId":"user-lms","status":"SUSPECT","timestamp":1234567890}
                """;

        listener.handleStatusChange(eventJson);

        verify(lmsService).syncRemoteAttendance("user-lms", "SUSPECT");
    }
}
