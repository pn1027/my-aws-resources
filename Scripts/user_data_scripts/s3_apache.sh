#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user data script execution at $(date)"

dnf update -y
dnf install -y httpd awscli
systemctl start httpd
systemctl enable httpd

S3_BUCKET="ec2-website-bucket-05"

echo "Downloading index.html from S3 bucket..."
aws s3 cp s3://$S3_BUCKET/index.html /var/www/html/index.html

if [ $? -eq 0 ]; then
    echo "Successfully downloaded index.html from S3"
else
    echo "ERROR: Failed to download index.html from S3. Error code: $?"
    echo "<html><body><h1>Error downloading content from S3 bucket: $S3_BUCKET</h1></body></html>" > /var/www/html/index.html
fi

echo "User data script completed at $(date)"