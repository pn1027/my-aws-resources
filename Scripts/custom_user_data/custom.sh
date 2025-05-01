#!/bin/bash
echo "Custom Script executed on $(date)" > /home/ec2-user/custom_log.txt
dnf install -y httpd
systemctl enable httpd
systemctl start httpd
echo "Hello this is the custom user-data file" > /var/www/html/index.html
