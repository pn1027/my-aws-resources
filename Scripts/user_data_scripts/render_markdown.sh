#!/bin/bash

# Install Apache
dnf install -y httpd curl tar gzip
systemctl enable httpd
systemctl start httpd

# Install Pandoc from GitHub
cd /tmp
curl -LO https://github.com/jgm/pandoc/releases/download/3.1.11/pandoc-3.1.11-linux-amd64.tar.gz
tar -xvzf pandoc-3.1.11-linux-amd64.tar.gz
cp pandoc-3.1.11/bin/pandoc /usr/local/bin/

# Create web root if it doesn't exist
mkdir -p /var/www/html

# Download the markdown file from GitHub
curl -o /var/www/html/index.md https://raw.githubusercontent.com/pn1027/bash/main/Bash-shell.md

# Convert it to HTML
/usr/local/bin/pandoc /var/www/html/index.md -o /var/www/html/index.html

