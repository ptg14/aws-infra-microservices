#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

print_status "Setting up Jenkins CI/CD environment for microservices..."

# Create necessary directories
print_status "Creating directory structure..."
mkdir -p jenkins/{data,html}
mkdir -p jenkins/src/{main,test}/java/com/example
mkdir -p jenkins/src/{main,test}/resources
mkdir -p target/surefire-reports
mkdir -p .jenkins

# Create sample Java application if not exists
if [ ! -f "jenkins/src/main/java/com/example/Application.java" ]; then
    print_status "Creating sample Java application..."
    cat > jenkins/src/main/java/com/example/Application.java << 'EOF'
package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}

@RestController
class HelloController {
    @GetMapping("/")
    public String hello() {
        return "Hello Microservices World! Application is running successfully on port 8080";
    }

    @GetMapping("/version")
    public String version() {
        return "Version 1.0.0 - Build " + System.currentTimeMillis();
    }

    @GetMapping("/health")
    public String health() {
        return "Application is healthy and running!";
    }

    @GetMapping("/api/status")
    public Object status() {
        return new Object() {
            public String status = "UP";
            public String application = "microservices-demo";
            public String version = "1.0.0";
            public long timestamp = System.currentTimeMillis();
        };
    }
}

@Component
class CustomHealthIndicator implements HealthIndicator {
    @Override
    public Health health() {
        return Health.up()
            .withDetail("service", "microservices-app")
            .withDetail("status", "running")
            .withDetail("port", "8080")
            .withDetail("profiles", System.getProperty("spring.profiles.active", "default"))
            .build();
    }
}
EOF
fi

# Create sample test if not exists
if [ ! -f "jenkins/src/test/java/com/example/ApplicationTest.java" ]; then
    print_status "Creating sample test..."
    cat > jenkins/src/test/java/com/example/ApplicationTest.java << 'EOF'
package com.example;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.web.server.LocalServerPort;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import static org.junit.jupiter.api.Assertions.*;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;

@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
@SpringJUnitConfig
public class ApplicationTest {

    @LocalServerPort
    private int port;

    @Test
    public void contextLoads() {
        assertTrue(true, "Application context should load successfully");
    }

    @Test
    public void testMainEndpoint() {
        TestRestTemplate restTemplate = new TestRestTemplate();
        String response = restTemplate.getForObject("http://localhost:" + port + "/", String.class);
        assertNotNull(response);
        assertTrue(response.contains("Hello Microservices World!"));
    }

    @Test
    public void testVersionEndpoint() {
        TestRestTemplate restTemplate = new TestRestTemplate();
        String response = restTemplate.getForObject("http://localhost:" + port + "/version", String.class);
        assertNotNull(response);
        assertTrue(response.contains("Version 1.0.0"));
    }

    @Test
    public void testHealthEndpoint() {
        TestRestTemplate restTemplate = new TestRestTemplate();
        String response = restTemplate.getForObject("http://localhost:" + port + "/health", String.class);
        assertNotNull(response);
        assertTrue(response.contains("healthy"));
    }
}
EOF
fi

# Create pom.xml if not exists
if [ ! -f "jenkins/pom.xml" ]; then
    print_status "Creating Maven POM file..."
    cat > jenkins/pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>microservices-app</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <name>Microservices Demo Application</name>
    <description>Demo microservice for Jenkins CI/CD pipeline</description>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>2.7.14</version>
        <relativePath/>
    </parent>

    <properties>
        <java.version>11</java.version>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <sonar.organization>your-org</sonar.organization>
        <sonar.host.url>http://localhost:9000</sonar.host.url>
    </properties>

    <dependencies>
        <!-- Spring Boot Web Starter -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- Spring Boot Actuator for health checks -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>

        <!-- Spring Boot Test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>

        <!-- JUnit 5 -->
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <!-- Spring Boot Maven Plugin -->
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <executions>
                    <execution>
                        <goals>
                            <goal>repackage</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>

            <!-- Maven Surefire Plugin for tests -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.0.0-M9</version>
                <configuration>
                    <includes>
                        <include>**/*Test.java</include>
                        <include>**/*Tests.java</include>
                    </includes>
                </configuration>
            </plugin>

            <!-- JaCoCo Plugin for code coverage -->
            <plugin>
                <groupId>org.jacoco</groupId>
                <artifactId>jacoco-maven-plugin</artifactId>
                <version>0.8.8</version>
                <executions>
                    <execution>
                        <goals>
                            <goal>prepare-agent</goal>
                        </goals>
                    </execution>
                    <execution>
                        <id>report</id>
                        <phase>test</phase>
                        <goals>
                            <goal>report</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>

            <!-- SonarQube Scanner -->
            <plugin>
                <groupId>org.sonarsource.scanner.maven</groupId>
                <artifactId>sonar-maven-plugin</artifactId>
                <version>3.9.1.2184</version>
            </plugin>

            <!-- Maven Compiler Plugin -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>11</source>
                    <target>11</target>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
EOF
fi

# Create application.properties
if [ ! -f "jenkins/src/main/resources/application.properties" ]; then
    print_status "Creating application properties file..."
    cat > jenkins/src/main/resources/application.properties << 'EOF'
# Server configuration
server.port=8080

# Application configuration
spring.application.name=microservices-demo-app

# Actuator configuration
management.endpoints.web.exposure.include=health,info,metrics
management.endpoint.health.show-details=always

# Logging configuration
logging.level.com.example=INFO
logging.level.org.springframework=WARN
logging.pattern.console=%d{yyyy-MM-dd HH:mm:ss} - %msg%n
EOF
fi

# Create application-docker.properties
if [ ! -f "jenkins/src/main/resources/application-docker.properties" ]; then
    print_status "Creating application-docker properties file..."
    cat > jenkins/src/main/resources/application-docker.properties << 'EOF'
# Docker specific configuration
server.port=8080
logging.level.com.example=DEBUG
logging.level.org.springframework=INFO
EOF
fi

# Create UI
if [ ! -f "jenkins/html/index.html" ]; then
    print_status "Creating index file..."
    cat > jenkins/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Microservices Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .status { color: green; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Microservices Demo Application</h1>
        <p class="status">✅ Application is running successfully!</p>
        <p><strong>Version:</strong> 1.0.0</p>
        <p><strong>Port:</strong> 3000</p>
        <p><strong>Status:</strong> Healthy</p>
        <p><strong>Timestamp:</strong> <span id="timestamp"></span></p>

        <h2>Available Endpoints:</h2>
        <ul>
            <li><a href="/">/ - Main page</a></li>
            <li><a href="/health.html">Health check</a></li>
        </ul>
    </div>

    <script>
        document.getElementById('timestamp').textContent = new Date().toISOString();
    </script>
</body>
</html>
EOF
fi

if [ ! -f "jenkins/html/health.html" ]; then
    print_status "Creating health file..."
    cat > jenkins/html/health.html << 'EOF'
{
  "status": "UP",
  "application": "microservices-demo",
  "version": "1.0.0",
  "timestamp": "2025-06-17T10:00:00Z"
}
EOF
fi

# Pull required Docker images
print_status "Pulling Docker images..."
docker-compose -f jenkins/docker-compose.yml pull

# Start services
print_status "Starting Jenkins and related services..."
docker-compose -f jenkins/docker-compose.yml up -d

# Wait for services to start
print_status "Waiting for services to start..."
sleep 60

# Check Jenkins status
print_status "Checking Jenkins status..."
if curl -f http://localhost:8000 > /dev/null 2>&1; then
    print_success "Jenkins is running at http://localhost:8000"
else
    print_warning "Jenkins may still be starting. Please wait a few more minutes."
fi

# Get Jenkins initial admin password
if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
    JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
    print_success "Jenkins Initial Admin Password: ${JENKINS_PASSWORD}"
else
    print_warning "Could not retrieve Jenkins password. Check manually with:"
    echo "docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
fi

# Check SonarQube status
print_status "Checking SonarQube status..."
sleep 30
if curl -f http://localhost:9000 > /dev/null 2>&1; then
    print_success "SonarQube is running at http://localhost:9000"
    print_status "Default SonarQube credentials: admin/admin"
else
    print_warning "SonarQube may still be starting. Please wait a few more minutes."
fi

# Check demo application
print_status "Checking demo application..."
if curl -f http://localhost:3000 > /dev/null 2>&1; then
    print_success "Demo application is running at http://localhost:3000"
else
    print_warning "Demo application may still be starting."
fi

print_success "Setup completed!"
echo ""
echo "=== 🚀 Jenkins CI/CD Environment ==="
echo "Jenkins:        http://localhost:8000"
echo "SonarQube:      http://localhost:9000 (admin/admin)"
echo "Demo App:       http://localhost:3000"
echo "Registry:       http://localhost:5000"
echo ""
echo "=== 📋 Next Steps ==="
echo "1. Access Jenkins and complete the setup wizard"
echo "2. Install recommended plugins + SonarQube Scanner"
echo "3. Configure SonarQube server in Jenkins"
echo "4. Create a new Pipeline job pointing to your Jenkinsfile"
echo "5. Configure webhooks for automatic builds"
echo ""
echo "=== 🔧 Useful Commands ==="
echo "View logs:           docker-compose -f jenkins/docker-compose.yml logs -f"
echo "Stop services:       docker-compose -f jenkins/docker-compose.yml down"
echo "Restart services:    docker-compose -f jenkins/docker-compose.yml restart"
echo "Build locally:       mvn clean package"
echo "Run tests:           mvn test"
echo ""
print_success "Happy coding! 🎉"