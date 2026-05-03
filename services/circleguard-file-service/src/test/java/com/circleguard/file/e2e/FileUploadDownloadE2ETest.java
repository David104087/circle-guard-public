package com.circleguard.file.e2e;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class FileUploadDownloadE2ETest {

    @LocalServerPort
    private int port;

    @Autowired
    private TestRestTemplate restTemplate;

    private String baseUrl() {
        return "http://localhost:" + port;
    }

    @Test
    void fullUploadFlow_shouldUploadAndReturnFilename() {
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        ByteArrayResource resource = new ByteArrayResource("certificate content".getBytes()) {
            @Override
            public String getFilename() {
                return "health-cert.pdf";
            }
        };
        body.add("file", resource);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        HttpEntity<MultiValueMap<String, Object>> request = new HttpEntity<>(body, headers);
        ResponseEntity<java.util.Map> response = restTemplate.postForEntity(
                baseUrl() + "/api/v1/files/upload", request, java.util.Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).containsKey("filename");
        String filename = (String) response.getBody().get("filename");
        assertThat(filename).endsWith("_health-cert.pdf");
    }

    @Test
    void uploadMultipleFiles_shouldProduceUniqueFilenames() {
        String filename1 = uploadFile("report.pdf", "content1");
        String filename2 = uploadFile("report.pdf", "content2");

        assertThat(filename1).isNotEqualTo(filename2);
    }

    @Test
    void uploadEndpoint_shouldReturn200ForValidPayload() {
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        ByteArrayResource resource = new ByteArrayResource("data".getBytes()) {
            @Override
            public String getFilename() { return "test.txt"; }
        };
        body.add("file", resource);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        ResponseEntity<java.util.Map> response = restTemplate.postForEntity(
                baseUrl() + "/api/v1/files/upload",
                new HttpEntity<>(body, headers),
                java.util.Map.class);

        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
    }

    private String uploadFile(String name, String content) {
        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        ByteArrayResource resource = new ByteArrayResource(content.getBytes()) {
            @Override
            public String getFilename() { return name; }
        };
        body.add("file", resource);

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        ResponseEntity<java.util.Map> response = restTemplate.postForEntity(
                baseUrl() + "/api/v1/files/upload",
                new HttpEntity<>(body, headers),
                java.util.Map.class);

        return (String) response.getBody().get("filename");
    }
}
