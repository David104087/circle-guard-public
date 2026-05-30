plugins {
    id("org.springframework.boot")
    id("io.spring.dependency-management")
    kotlin("jvm")
    kotlin("plugin.spring")
    kotlin("plugin.jpa")
}

sonarqube {
    properties {
        property("sonar.projectKey", "circleguard-promotion-service")
        property("sonar.projectName", "circleguard-promotion-service")
        property("sonar.sources", "src/main/java")
        property("sonar.tests", "src/test/java")
        property("sonar.coverage.jacoco.xmlReportPaths", "build/reports/jacoco/test/jacocoTestReport.xml")
    }
}

dependencies {
    implementation(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))
    testImplementation(enforcedPlatform("org.testcontainers:testcontainers-bom:1.20.4"))
    testImplementation(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))

    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("io.micrometer:micrometer-registry-prometheus")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-data-neo4j")
    implementation("org.springframework.boot:spring-boot-starter-data-redis")
    implementation("org.springframework.kafka:spring-kafka")
    implementation("org.springframework.boot:spring-boot-starter-cache")
    implementation("com.github.ben-manes.caffeine:caffeine")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("io.jsonwebtoken:jjwt-api:0.11.5")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.11.5")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.11.5")
    implementation("org.flywaydb:flyway-core")
    runtimeOnly("org.postgresql:postgresql")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.security:spring-security-test")
    testImplementation("org.testcontainers:junit-jupiter:1.20.4")
    testImplementation("org.testcontainers:postgresql:1.20.4")
    testImplementation("org.testcontainers:neo4j:1.20.4")
}

configurations.all {
    resolutionStrategy.eachDependency {
        if (requested.group == "org.testcontainers") {
            useVersion("1.20.4")
        }
    }
}

tasks.withType<Test> {
    val rawSocket = "/Users/davidartuduagapenagos/Library/Containers/com.docker.docker/Data/docker.raw.sock"
    if (File(rawSocket).exists()) {
        environment("DOCKER_HOST", "unix:///tmp/docker-proxy.sock")
        environment("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE", "/tmp/docker-proxy.sock")
        environment("TESTCONTAINERS_RYUK_DISABLED", "true")
    } else {
        environment("DOCKER_HOST", System.getenv("DOCKER_HOST") ?: "unix:///tmp/docker-proxy.sock")
        environment("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE",
            System.getenv("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE") ?: "/tmp/docker-proxy.sock")
        environment("TESTCONTAINERS_RYUK_DISABLED",
            System.getenv("TESTCONTAINERS_RYUK_DISABLED") ?: "true")
        // In DooD (Docker-outside-Docker) CI setup, containers started via host Docker
        // are reachable via host.docker.internal, not localhost (which is the CI container)
        environment("TESTCONTAINERS_HOST_OVERRIDE",
            System.getenv("TESTCONTAINERS_HOST_OVERRIDE") ?: "host.docker.internal")
    }
    // Override docker-java's default API version (1.32) to match Docker 29.x minimum (1.44)
    environment("DOCKER_API_VERSION", "1.44")
    systemProperty("testcontainers.ryuk.disabled", "true")
}
