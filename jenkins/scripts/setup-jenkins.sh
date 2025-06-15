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
mkdir -p jenkins/{data,scripts,k8s,docker}
mkdir -p src/{main,test}/java/com/example
mkdir -p target/surefire-reports
mkdir -p .jenkins

# Create sample Java application if not exists
if [ ! -f "src/main/java/com/example/Application.java" ]; then
    print_status "Creating sample Java application..."
    cat > src/main/java/com/example/Application.java << 'EOF'
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
        return "Hello Microservices World!";
    }

    @GetMapping("/version")
    public String version() {
        return "Version 1.0.0";
    }
}

@Component
class CustomHealthIndicator implements HealthIndicator {
    @Override
    public Health health() {
        return Health.up()
            .withDetail("service", "microservices-app")
            .withDetail("status", "running")
            .build();
    }
}
EOF
fi

# Create sample test if not exists
if [ ! -f "src/test/java/com/example/ApplicationTest.java" ]; then
    print_status "Creating sample test..."
    cat > src/test/java/com/example/ApplicationTest.java << 'EOF'
package com.example;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@SpringJUnitConfig
public class ApplicationTest {

    @Test
    public void contextLoads() {
        assertTrue(true, "Application context should load successfully");
    }

    @Test
    public void testApplication() {
        assertTrue(true, "Sample test should pass");
    }
}
EOF
fi

# Create pom.xml if not exists
if [ ! -f "pom.xml" ]; then
    print_status "Creating Maven POM file..."
    cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>microservices-app</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <name>Microservices Application</name>
    <description>Demo microservices application for CI/CD pipeline</description>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <spring.boot.version>2.7.0</spring.boot.version>
        <junit.version>5.8.2</junit.version>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>${spring.boot.version}</version>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
            <version>${spring.boot.version}</version>
        </dependency>

        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <version>${spring.boot.version}</version>
            <scope>test</scope>
        </dependency>

        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>${junit.version}</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <version>${spring.boot.version}</version>
                <executions>
                    <execution>
                        <goals>
                            <goal>repackage</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>

            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.0.0-M7</version>
                <configuration>
                    <includes>
                        <include>**/*Test.java</include>
                        <include>**/*Tests.java</include>
                    </includes>
                </configuration>
            </plugin>

            <plugin>
                <groupId>org.jacoco</groupId>
                <artifactId>jacoco-maven-plugin</artifactId>
                <version>0.8.7</version>
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

            <plugin>
                <groupId>org.sonarsource.scanner.maven</groupId>
                <artifactId>sonar-maven-plugin</artifactId>
                <version>3.9.1.2184</version>
            </plugin>

            <plugin>
                <groupId>org.owasp</groupId>
                <artifactId>dependency-check-maven</artifactId>
                <version>7.1.1</version>
                <configuration>
                    <format>ALL</format>
                    <outputDirectory>target/dependency-check</outputDirectory>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
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
if curl -f http://localhost:8080 > /dev/null 2>&1; then
    print_success "Jenkins is running at http://localhost:8080"
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
if curl -f http://localhost:8081 > /dev/null 2>&1; then
    print_success "Demo application is running at http://localhost:8081"
else
    print_warning "Demo application may still be starting."
fi

print_success "Setup completed!"
echo ""
echo "=== 🚀 Jenkins CI/CD Environment ==="
echo "Jenkins:        http://localhost:8080"
echo "SonarQube:      http://localhost:9000 (admin/admin)"
echo "Demo App:       http://localhost:8081"
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