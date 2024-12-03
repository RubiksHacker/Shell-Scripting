#!/bin/bash

# Install necessary packages
dnf install -y dnf-utils httpd policycoreutils-python-utils

# Create directories for the repository
mkdir -p /u01/repo/{OracleLinux,logs,scripts}

# Sync the repositories
for repo in ol8_baseos_latest ol8_appstream; do
    /usr/bin/reposync --newest-only --download-metadata --repoid=$repo -p /u01/repo/OracleLinux
done

# Create the repo_sync.sh script
cat << 'EOF' > /u01/repo/scripts/repo_sync.sh
#!/bin/bash

LOG_FILE=/u01/repo/logs/repo_sync_$(date +%Y.%m.%d).log

# Remove old logs
find /u01/repo/logs/repo_sync* -mtime +5 -delete >> $LOG_FILE 2>&1

# Sync repositories
for repo in baseos appstream epel-source epel; do
    /usr/bin/reposync --newest-only --download-metadata --refresh --repoid=$repo -p /u01/repo/OracleLinux >> $LOG_FILE 2>&1
done
EOF

# Make the repo_sync.sh script executable
chmod u+x /u01/repo/scripts/repo_sync.sh

# Schedule the repo_sync.sh script in cron
(crontab -l 2>/dev/null; echo "0 1 * * * /u01/repo/scripts/repo_sync.sh > /dev/null 2>&1") | crontab -

# Start and enable Apache HTTP server
systemctl enable --now httpd

# Configure firewall to allow HTTP traffic
firewall-cmd --permanent --zone=public --add-port=80/tcp
firewall-cmd --reload

# Configure SELinux for the repository files
semanage fcontext -a -t httpd_sys_content_t "/u01/repo/OracleLinux(/.*)?"
restorecon -F -R -v /u01/repo/OracleLinux

# Present the repositories using the HTTP server
for repo in baseos appstream epel epel-source; do
    mkdir -p /var/www/html/repo/OracleLinux/$repo
    ln -s /u01/repo/OracleLinux/$repo/ /var/www/html/repo/OracleLinux/$repo/x86_64
done

# Copy the GPG keys to the HTTP server
curl -sS https://yum.oracle.com/RPM-GPG-KEY-oracle-ol8 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle
cp /etc/pki/rpm-gpg/RPM-GPG-KEY-oracle /var/www/html/RPM-GPG-KEY-oracle
