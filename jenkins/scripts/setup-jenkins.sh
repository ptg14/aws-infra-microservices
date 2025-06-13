#!/bin/bash

echo "=== Setting up Jenkins CI/CD Environment ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p jenkins/plugins
mkdir -p jenkins/k8s
mkdir -p scripts
mkdir -p src/main/java
mkdir -p src/test/java
mkdir -p target/surefire-reports

# Start services
print_status "Starting Jenkins and SonarQube services..."
docker-compose up -d

# Wait for Jenkins to start
print_status "Waiting for Jenkins to start..."
sleep 30

# Get Jenkins initial admin password
if docker exec jenkins test -f /var/jenkins_home/secrets/initialAdminPassword; then
    JENKINS_PASSWORD=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null)
    print_status "Jenkins Initial Admin Password: $JENKINS_PASSWORD"
else
    print_warning "Could not retrieve Jenkins password. Check manually with: docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
fi

# Create sample application files if they don't exist
if [ ! -f "src/main/java/DemoApp.java" ]; then
    print_status "Creating sample application..."
    cat > src/main/java/DemoApp.java << 'EOF'
public class DemoApp {
    public static void main(String[] args) {
        System.out.println("Demo Microservice is running!");
        // Keep the application running
        try {
            Thread.sleep(Long.MAX_VALUE);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
EOF
fi

# Create sample test file
if [ ! -f "src/test/java/DemoAppTest.java" ]; then
    print_status "Creating sample test..."
    cat > src/test/java/DemoAppTest.java << 'EOF'
import org.junit.Test;
import static org.junit.Assert.*;

public class DemoAppTest {
    @Test
    public void testDemo() {
        assertTrue("Demo test should pass", true);
    }

    @Test
    public void testAnother() {
        assertEquals("Expected value", "Expected value", "Expected value");
    }
}
EOF
fi

# Create basic pom.xml if it doesn't exist
if [ ! -f "pom.xml" ]; then
    print_status "Creating basic pom.xml..."
    cat > pom.xml << 'EOF'
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
    <description>Demo application for Jenkins CI/CD pipeline</description>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <junit.version>4.13.2</junit.version>
        <jacoco.version>0.8.7</jacoco.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>${junit.version}</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.8.1</version>
                <configuration>
                    <source>11</source>
                    <target>11</target>
                </configuration>
            </plugin>

            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.0.0-M5</version>
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
                <version>${jacoco.version}</version>
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
        </plugins>
    </build>
</project>
EOF
fi

print_status "Setup completed!"
print_status "Access Jenkins at: http://localhost:8080"
print_status "Access SonarQube at: http://localhost:9000 (admin/admin)"
print_status ""
print_status "Next steps:"
print_status "1. Configure Jenkins with the initial admin password"
print_status "2. Install required plugins in Jenkins"
print_status "3. Configure SonarQube token in Jenkins"
print_status "4. Set up Docker Hub credentials in Jenkins"
print_status "5. Create the Jenkins pipeline job"