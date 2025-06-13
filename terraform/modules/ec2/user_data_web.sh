#!/bin/bash
yum update -y
yum install -y httpd

# Configure httpd
systemctl start httpd
systemctl enable httpd

# Create a simple index page
cat > /var/www/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>${instance_name}</title>
</head>
<body>
    <h1>Welcome to ${instance_name}</h1>
    <p>This is a web server running on Amazon Linux 2</p>
    <p>Instance: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
    <p>AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement-availability-zone)</p>
</body>
</html>
EOF

# Configure firewall
systemctl start firewalld
systemctl enable firewalld
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent