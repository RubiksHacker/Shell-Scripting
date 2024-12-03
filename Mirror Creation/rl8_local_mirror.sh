#!/bin/bash

# Install necessary packages
dnf install -y dnf-utils httpd policycoreutils-python-utils

# Create directories for the repository
mkdir -p /u01/repo/{RockyLinux,logs,scripts}

# Sync the repositories
for repo in baseos appstream epel-source epel epel-debuginfo epel-modular epel-modular-debuginfo epel-modular-source epel-testing epel-testing-source; do
    /usr/bin/reposync --newest-only --download-metadata --repoid=$repo -p /u01/repo/RockyLinux
done

# Create the repo_sync.sh script
cat << 'EOF' > /u01/repo/scripts/repo_sync.sh
#!/bin/bash

LOG_FILE=/u01/repo/logs/repo_sync_$(date +%Y.%m.%d).log

# Remove old logs
find /u01/repo/logs/repo_sync* -mtime +5 -delete >> $LOG_FILE 2>&1

# Sync repositories
for repo in baseos appstream epel-source epel; do
    /usr/bin/reposync --newest-only --download-metadata --refresh --repoid=$repo -p /u01/repo/RockyLinux >> $LOG_FILE 2>&1
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
semanage fcontext -a -t httpd_sys_content_t "/u01/repo/RockyLinux(/.*)?"
restorecon -F -R -v /u01/repo/RockyLinux

# Present the repositories using the HTTP server
for repo in baseos appstream epel epel-source; do
    mkdir -p /var/www/html/repo/RockyLinux/$repo
    ln -s /u01/repo/RockyLinux/$repo/ /var/www/html/repo/RockyLinux/$repo/x86_64
done

# Copy the GPG keys to the HTTP server
curl -sS https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-rockyofficial -o /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial
cp /etc/pki/rpm-gpg/RPM-GPG-KEY-rockyofficial /var/www/html/RPM-GPG-KEY-rockyofficial

curl -sS https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-8 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8
cp /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-8 /var/www/html/RPM-GPG-KEY-EPEL-8