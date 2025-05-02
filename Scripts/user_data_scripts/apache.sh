#!/bin/bash

# Install and start Apache web server
dnf update -y >> /var/log/user-data.log 2>&1
dnf install -y httpd >> /var/log/user-data.log 2>&1

systemctl start httpd >> /var/log/user-data.log 2>&1
systemctl enable httpd >> /var/log/user-data.log 2>&1
echo "<html><body><h1>Hello from EC2 Instance!</h1></body></html>" > /var/www/html/index.html

# We added lines to verify if apache was installed and started properly 
# The log file is stored on the EC2 instance's disk.
# It captures both standard output (stdout) and standard error (stderr) from each command.
# You can access it by SSH-ing into the instance and running:

# 2 captures the standard error output and 1 captures the standard output,
# > redirects the both error and standard output to the same log file i.e. /var/log/user-data.log
# /var/log/user-data.log is the standard location for logging the execution of cloud-init user-data scripts in EC2.
# AWS often used this location for system-level logs related to instance bootstrap scripts. 

# What do you mean by cloud-init user-data scripts?
# - The cloud-init service is used to handle: Reading your script, Executing, logging the output 
# Is the custom file uploaded from local computer not a cloud-init user-data script?
# - They are the same thing when we run the custom file as EC2 user-data


# In the cusotm file we are using /home/ec2-user/custom.log.txt, is this being created in my local computer?
 
# One difference between two files is > overwrites the file while >> just appends the file 
# > is not recommended, use >> hence.





