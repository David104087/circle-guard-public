package com.circleguard.promotion.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.neo4j.repository.config.EnableNeo4jRepositories;

@Configuration
@ConditionalOnProperty(name = "app.neo4j.enabled", havingValue = "true", matchIfMissing = true)
@EnableNeo4jRepositories(
    basePackages = "com.circleguard.promotion.repository.graph",
    transactionManagerRef = "neo4jTransactionManager"
)
public class Neo4jRepositoriesConfig {
}
