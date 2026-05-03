package com.circleguard.promotion.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.data.neo4j.core.Neo4jClient;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.Neo4jContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
@Testcontainers
public class HealthStatusReevaluationTest {

    @Container
    static Neo4jContainer<?> neo4jContainer = new Neo4jContainer<>("neo4j:5.12")
            .withAdminPassword("password");

    @Container
    @SuppressWarnings("resource")
    static GenericContainer<?> redis = new GenericContainer<>("redis:7.2.1")
            .withExposedPorts(6379);

    @DynamicPropertySource
    static void neo4jProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.neo4j.uri", neo4jContainer::getBoltUrl);
        registry.add("spring.neo4j.authentication.username", () -> "neo4j");
        registry.add("spring.neo4j.authentication.password", () -> "password");
        registry.add("spring.data.redis.host", redis::getHost);
        registry.add("spring.data.redis.port", redis::getFirstMappedPort);
        registry.add("app.neo4j.enabled", () -> "true");
    }

    @Autowired
    private HealthStatusService healthStatusService;

    @Autowired
    private Neo4jClient neo4jClient;

    @MockBean
    private KafkaTemplate<String, Object> kafkaTemplate;

    @BeforeEach
    void setup() {
        neo4jClient.query("MATCH (n) DETACH DELETE n").run();
    }

    @Test
    void testSingleRelease() {
        createNode("A", "CONFIRMED");
        createNode("B", "SUSPECT");
        createRelationship("A", "B");

        healthStatusService.resolveStatus("A");

        assertEquals("ACTIVE", getStatus("B"));
    }

    @Test
    void testBlockedRelease() {
        createNode("A", "CONFIRMED");
        createNode("B", "SUSPECT");
        createNode("C", "CONFIRMED");
        createRelationship("A", "B");
        createRelationship("C", "B");

        healthStatusService.resolveStatus("A");

        assertEquals("SUSPECT", getStatus("B"));
    }

    @Test
    void testMultiHopRelease() {
        createNode("A", "CONFIRMED");
        createNode("B", "SUSPECT");
        createNode("C", "PROBABLE");
        createRelationship("A", "B");
        createRelationship("B", "C");

        healthStatusService.resolveStatus("A");

        assertEquals("ACTIVE", getStatus("B"));
        assertEquals("ACTIVE", getStatus("C"));
    }

    @Test
    void testPartialReleaseInMesh() {
        createNode("A", "CONFIRMED");
        createNode("B", "SUSPECT");
        createNode("C", "PROBABLE");
        createNode("D", "SUSPECT");
        createRelationship("A", "B");
        createRelationship("B", "C");
        createRelationship("D", "C");

        healthStatusService.resolveStatus("A");

        assertEquals("ACTIVE", getStatus("B"));
        assertEquals("PROBABLE", getStatus("C"));
    }

    private void createNode(String id, String status) {
        neo4jClient.query("CREATE (:User {anonymousId: $id, status: $status})")
                .bind(id).to("id")
                .bind(status).to("status")
                .run();
    }

    private void createRelationship(String id1, String id2) {
        neo4jClient.query("MATCH (u1:User {anonymousId: $id1}), (u2:User {anonymousId: $id2}) " +
                "CREATE (u1)-[:ENCOUNTERED {startTime: timestamp()}]->(u2)")
                .bind(id1).to("id1")
                .bind(id2).to("id2")
                .run();
    }

    private String getStatus(String id) {
        return neo4jClient.query("MATCH (u:User {anonymousId: $id}) RETURN u.status as status")
                .bind(id).to("id")
                .fetchAs(String.class).one().orElse("NOT_FOUND");
    }
}
