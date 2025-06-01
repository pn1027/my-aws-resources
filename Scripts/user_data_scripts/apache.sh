#!/bin/bash

# Install and start Apache web server
dnf update -y >> /var/log/user-data.log 2>&1
dnf install -y httpd >> /var/log/user-data.log 2>&1

systemctl start httpd >> /var/log/user-data.log 2>&1
systemctl enable httpd >> /var/log/user-data.log 2>&1
echo "<html><body><h1>Hello from EC2 Instance! Testing Application Load balancer</h1></body></html>" > /var/www/html/index.html






