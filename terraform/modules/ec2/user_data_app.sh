#!/bin/bash
yum update -y
yum install -y java-11-openjdk-devel

# Create application user
useradd -m -s /bin/bash appuser

# Create a simple Java application
mkdir -p /opt/app
cat > /opt/app/SimpleApp.java << EOF
import java.net.*;
import java.io.*;

public class SimpleApp {
    public static void main(String[] args) throws IOException {
        ServerSocket serverSocket = new ServerSocket(8080);
        System.out.println("${instance_name} started on port 8080");

        while (true) {
            Socket clientSocket = serverSocket.accept();
            PrintWriter out = new PrintWriter(clientSocket.getOutputStream(), true);

            out.println("HTTP/1.1 200 OK");
            out.println("Content-Type: text/html");
            out.println("");
            out.println("<h1>${instance_name}</h1>");
            out.println("<p>Application server is running</p>");

            clientSocket.close();
        }
    }
}
EOF

# Compile and run the application
cd /opt/app
javac SimpleApp.java
chown -R appuser:appuser /opt/app

# Create systemd service
cat > /etc/systemd/system/simpleapp.service << EOF
[Unit]
Description=Simple Java Application
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/app
ExecStart=/usr/bin/java SimpleApp
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start simpleapp
systemctl enable simpleapp

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent