#!/bin/bash

# Install and start Apache web server
dnf update -y >> /var/log/user-data.log 2>&1
dnf install -y httpd >> /var/log/user-data.log 2>&1

systemctl start httpd >> /var/log/user-data.log 2>&1
systemctl enable httpd >> /var/log/user-data.log 2>&1
echo "<html><body><h1>Hello from EC2 Instance!</h1></body></html>" > /var/www/html/index.html

#adding lines to verify if apache was installed and started properly 
# The log file is stored on the EC2 instance's disk.
# It captures both standard output (stdout) and standard error (stderr) from each command.
# You can access it by SSH-ing into the instance and running:


