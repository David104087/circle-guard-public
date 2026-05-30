plugins {
    id("org.springframework.boot") version "3.2.4" apply false
    id("io.spring.dependency-management") version "1.1.4" apply false
    id("org.sonarqube") version "4.4.1.3373"
    kotlin("jvm") version "1.9.24" apply false
    kotlin("plugin.spring") version "1.9.24" apply false
    kotlin("plugin.jpa") version "1.9.24" apply false
}

allprojects {
    group = "com.circleguard"
    version = "1.0.0-SNAPSHOT"

    repositories {
        mavenCentral()
    }
}

sonarqube {
    properties {
        property("sonar.projectKey", "circleguard")
        property("sonar.projectName", "CircleGuard")
        property("sonar.sourceEncoding", "UTF-8")
        property("sonar.qualitygate.wait", "true")
    }
}

subprojects {
    apply(plugin = "java")
    apply(plugin = "jacoco")
    apply(plugin = "org.jetbrains.kotlin.jvm")
    extensions.configure<JavaPluginExtension> {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(21))
        }
    }

    dependencies {
        "implementation"(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))
        "testImplementation"(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))
        "compileOnly"("org.projectlombok:lombok")
        "annotationProcessor"("org.projectlombok:lombok")
        "testCompileOnly"("org.projectlombok:lombok")
        "testAnnotationProcessor"("org.projectlombok:lombok")
        "implementation"("org.jetbrains.kotlin:kotlin-reflect")
        "testImplementation"("org.springframework.boot:spring-boot-starter-test")
        "testRuntimeOnly"("com.h2database:h2")
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
        kotlinOptions {
            freeCompilerArgs = listOf("-Xjsr305=strict")
            jvmTarget = "21"
        }
    }

    tasks.withType<Test> {
        useJUnitPlatform()
        finalizedBy(tasks.named("jacocoTestReport"))
    }

    tasks.named<JacocoReport>("jacocoTestReport") {
        dependsOn(tasks.named("test"))
        reports {
            xml.required.set(true)
            html.required.set(true)
        }
    }
}

// Aggregate JaCoCo report across all subprojects
tasks.register<JacocoReport>("aggregateCoverageReport") {
    group = "verification"
    description = "Generates aggregate JaCoCo coverage report for all services"

    dependsOn(subprojects.map { it.tasks.named("test") })

    val allExecFiles = subprojects.flatMap { proj ->
        proj.fileTree("${proj.buildDir}/jacoco") { include("*.exec") }.files
    }
    executionData.setFrom(allExecFiles)

    val allSourceDirs = subprojects.map { proj ->
        proj.file("src/main/java")
    }
    sourceDirectories.setFrom(allSourceDirs)

    val allClassDirs = subprojects.flatMap { proj ->
        proj.fileTree("${proj.buildDir}/classes/java/main").files
    }
    classDirectories.setFrom(allClassDirs)

    reports {
        xml.required.set(true)
        xml.outputLocation.set(file("${buildDir}/reports/jacoco-aggregate/jacocoTestReport.xml"))
        html.required.set(true)
        html.outputLocation.set(file("${buildDir}/reports/jacoco-aggregate/html"))
    }
}
