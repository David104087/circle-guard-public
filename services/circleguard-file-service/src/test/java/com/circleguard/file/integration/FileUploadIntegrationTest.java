package com.circleguard.file.integration;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class FileUploadIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void uploadEndpoint_shouldReturn200WithFilename() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "file", "test-certificate.pdf", "application/pdf",
                "PDF content here".getBytes());

        mockMvc.perform(multipart("/api/v1/files/upload").file(file))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.filename").exists());
    }

    @Test
    void uploadEndpoint_shouldReturnUniqueFilenameForEachUpload() throws Exception {
        MockMultipartFile file1 = new MockMultipartFile(
                "file", "doc.pdf", "application/pdf", "v1".getBytes());
        MockMultipartFile file2 = new MockMultipartFile(
                "file", "doc.pdf", "application/pdf", "v2".getBytes());

        MvcResult result1 = mockMvc.perform(multipart("/api/v1/files/upload").file(file1))
                .andExpect(status().isOk()).andReturn();
        MvcResult result2 = mockMvc.perform(multipart("/api/v1/files/upload").file(file2))
                .andExpect(status().isOk()).andReturn();

        assertThat(result1.getResponse().getContentAsString())
                .isNotEqualTo(result2.getResponse().getContentAsString());
    }

    @Test
    void uploadEndpoint_shouldPreserveOriginalFilenameAsSuffix() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "file", "medical-certificate.pdf", "application/pdf",
                "data".getBytes());

        mockMvc.perform(multipart("/api/v1/files/upload").file(file))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.filename").value(org.hamcrest.Matchers.containsString("medical-certificate.pdf")));
    }

    @Test
    void uploadEndpoint_shouldHandleImageFiles() throws Exception {
        MockMultipartFile image = new MockMultipartFile(
                "file", "photo.jpg", "image/jpeg",
                new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF});

        mockMvc.perform(multipart("/api/v1/files/upload").file(image))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.filename").value(org.hamcrest.Matchers.endsWith("_photo.jpg")));
    }

    @Test
    void uploadEndpoint_shouldReturnJsonContentType() throws Exception {
        MockMultipartFile file = new MockMultipartFile(
                "file", "file.txt", "text/plain", "content".getBytes());

        mockMvc.perform(multipart("/api/v1/files/upload").file(file))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith("application/json"));
    }
}
