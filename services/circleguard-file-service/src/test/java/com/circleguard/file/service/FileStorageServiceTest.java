package com.circleguard.file.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class FileStorageServiceTest {

    @TempDir
    Path tempDir;

    private FileStorageService service;

    @BeforeEach
    void setUp() {
        service = new FileStorageService();
        ReflectionTestUtils.setField(service, "root", tempDir);
    }

    @Test
    void saveFile_shouldReturnFilenameWithUUIDPrefix() {
        MockMultipartFile file = new MockMultipartFile(
                "file", "certificate.pdf", "application/pdf", "pdf content".getBytes());

        String filename = service.saveFile(file);

        assertThat(filename).endsWith("_certificate.pdf");
        assertThat(filename).hasSize(36 + 1 + "certificate.pdf".length());
    }

    @Test
    void saveFile_shouldActuallyPersistToDisk() {
        MockMultipartFile file = new MockMultipartFile(
                "file", "doc.txt", "text/plain", "hello world".getBytes());

        String filename = service.saveFile(file);

        assertThat(tempDir.resolve(filename)).exists();
    }

    @Test
    void saveFile_shouldHandleDifferentContentTypes() {
        MockMultipartFile pdfFile = new MockMultipartFile(
                "file", "report.pdf", "application/pdf", "pdf data".getBytes());
        MockMultipartFile imgFile = new MockMultipartFile(
                "file", "photo.jpg", "image/jpeg", new byte[]{1, 2, 3});

        String pdf = service.saveFile(pdfFile);
        String img = service.saveFile(imgFile);

        assertThat(pdf).endsWith("_report.pdf");
        assertThat(img).endsWith("_photo.jpg");
        assertThat(pdf).isNotEqualTo(img);
    }

    @Test
    void saveFile_multipleUploadsOfSameNameShouldProduceDifferentFilenames() {
        MockMultipartFile file1 = new MockMultipartFile(
                "file", "same.pdf", "application/pdf", "v1".getBytes());
        MockMultipartFile file2 = new MockMultipartFile(
                "file", "same.pdf", "application/pdf", "v2".getBytes());

        String name1 = service.saveFile(file1);
        String name2 = service.saveFile(file2);

        assertThat(name1).isNotEqualTo(name2);
    }

    @Test
    void saveFile_shouldThrowRuntimeExceptionOnIOFailure() throws Exception {
        org.springframework.web.multipart.MultipartFile mockFile =
                org.mockito.Mockito.mock(org.springframework.web.multipart.MultipartFile.class);
        org.mockito.Mockito.when(mockFile.getOriginalFilename()).thenReturn("bad.pdf");
        org.mockito.Mockito.when(mockFile.getInputStream())
                .thenThrow(new java.io.IOException("Simulated IO failure"));

        assertThatThrownBy(() -> service.saveFile(mockFile))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("Could not store file");
    }
}
