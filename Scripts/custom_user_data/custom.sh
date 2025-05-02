#!/bin/bash
exec >> /home/ec2-user/custom_log.txt 2>&1
# line tells the shell to send all standard output and errors from that point onward to the specified log file

echo "Custom Script executed on $(date)" 

dnf install -y httpd
systemctl enable httpd
systemctl start httpd
echo "Hello this is the custom user-data file" > /var/www/html/index.html
