# Multi-stage build for Java application
FROM maven:3.6.3-openjdk-17 AS build

WORKDIR /app

# Copy pom.xml and download dependencies (for better caching)
COPY pom.xml* ./
RUN if [ -f pom.xml ]; then mvn dependency:go-offline; fi

# Copy source code
COPY src ./src

# Build application
RUN if [ -f pom.xml ]; then \
      mvn clean package -DskipTests; \
    else \
      # Create a simple Java application if no pom.xml
      mkdir -p target && \
      echo 'public class Application { public static void main(String[] args) { System.out.println("Hello Microservices!"); } }' > Application.java && \
      javac Application.java && \
      echo 'Main-Class: Application' > manifest.txt && \
      jar cfm target/app.jar manifest.txt Application.class; \
    fi

# Runtime stage
FROM openjdk:17-jre-slim

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy application from build stage
COPY --from=build /app/target/*.jar app.jar

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "app.jar"]