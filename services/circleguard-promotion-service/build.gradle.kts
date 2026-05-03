plugins {
    id("org.springframework.boot")
    id("io.spring.dependency-management")
    kotlin("jvm")
    kotlin("plugin.spring")
    kotlin("plugin.jpa")
}

dependencies {
    implementation(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))
    testImplementation(enforcedPlatform("org.testcontainers:testcontainers-bom:1.20.4"))
    testImplementation(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))

    implementation("org.springframework.boot:spring-boot-starter-web")
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
    // docker-java defaults to API 1.32, but Docker 29.x requires >= 1.44.
    // Use a version-rewriting proxy socket (docker-version-proxy.py).
    // On macOS dev: detect raw socket and use the local proxy.
    // In CI (Jenkins): DOCKER_HOST env var is set externally; forward it to the forked test JVM.
    val rawSocket = "/Users/davidartuduagapenagos/Library/Containers/com.docker.docker/Data/docker.raw.sock"
    if (File(rawSocket).exists()) {
        systemProperty("DOCKER_HOST", "unix:///tmp/docker-proxy.sock")
        systemProperty("api.version", "1.44")
        environment("DOCKER_HOST", "unix:///tmp/docker-proxy.sock")
        environment("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE", "/tmp/docker-proxy.sock")
        environment("TESTCONTAINERS_RYUK_DISABLED", "true")
    } else {
        // Forward Docker env vars from the Gradle daemon (CI environment)
        System.getenv("DOCKER_HOST")?.let { environment("DOCKER_HOST", it) }
        System.getenv("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE")?.let {
            environment("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE", it)
        }
        System.getenv("TESTCONTAINERS_RYUK_DISABLED")?.let {
            environment("TESTCONTAINERS_RYUK_DISABLED", it)
        }
    }
    systemProperty("testcontainers.ryuk.disabled", "true")
}
