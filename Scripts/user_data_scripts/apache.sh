#!/bin/bash

# Install and start Apache web server
dnf update -y
dnf install -y httpd

systemctl start httpd
systemctl enable httpd
echo "<html><body><h1>Hello from EC2 Instance!</h1></body></html>" > /var/www/html/index.html