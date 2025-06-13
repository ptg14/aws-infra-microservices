FROM openjdk:11-jre-slim

# Set working directory
WORKDIR /app

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy application jar (adjust path based on your build tool)
COPY target/*.jar app.jar 2>/dev/null || echo "No jar file found in target/"
COPY build/libs/*.jar app.jar 2>/dev/null || echo "No jar file found in build/libs/"

# If no jar file exists, create a simple demo application
RUN if [ ! -f app.jar ]; then \
        echo 'Creating demo application...' && \
        mkdir -p /tmp/demo && \
        cd /tmp/demo && \
        echo 'public class DemoApp { public static void main(String[] args) { System.out.println("Demo Microservice Running!"); try { Thread.sleep(Long.MAX_VALUE); } catch(Exception e) {} } }' > DemoApp.java && \
        javac DemoApp.java && \
        echo "Main-Class: DemoApp" > manifest.txt && \
        jar cfm /app/app.jar manifest.txt *.class; \
    fi

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "app.jar"]