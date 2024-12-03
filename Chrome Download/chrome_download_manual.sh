# Chrome 120

cat > /var/tmp/120.sh <<EOF
echo "Downloading Chrome 120"
yum install -y epel-release
yum install -y p7zip
wget "https://fs.catchpoint.com/UtilFiles/linux_chrome/catchpoint_chrome_linux_120.0.6099.224.0.7z" -P /tmp/
cd /tmp/ && 7za x /tmp/catchpoint_chrome_linux_120.0.6099.224.0.7z
sleep 5
mkdir /opt/3genlabs/hawk/syntheticnode/service/chrome/120.0.6099.224.0
tar -xvf /tmp/catchpoint_chrome_linux_120.0.6099.224.0.tar -C /opt/3genlabs/hawk/syntheticnode/service/chrome/120.0.6099.224.0
chown -R serveruser:cp /opt/3genlabs/hawk/syntheticnode/service/chrome/120.0.6099.224.0
cd /opt/3genlabs/hawk/syntheticnode/service/chrome/120.0.6099.224.0 && chown root:root chrome-sandbox && chmod 4755 chrome-sandbox
echo "Restarting Agent"
catchpoint restart
EOF

# Chrome 108:

cat > /var/tmp/108.sh <<EOF
echo "Downloading Chrome 108"
yum install -y epel-release
yum install -y p7zip
wget "https://fs.catchpoint.com/UtilFiles/linux_chrome/catchpoint_chrome_linux_108.0.5359.94.0.7z" -P /tmp/
cd /tmp/ && 7za x /tmp/catchpoint_chrome_linux_108.0.5359.94.0.7z
sleep 5
mkdir /opt/3genlabs/hawk/syntheticnode/service/chrome/108.0.5359.94.0
tar -xvf /tmp/catchpoint_chrome_linux_108.0.5359.94.0.tar -C /opt/3genlabs/hawk/syntheticnode/service/chrome/108.0.5359.94.0
chown -R serveruser:cp /opt/3genlabs/hawk/syntheticnode/service/chrome/108.0.5359.94.0
cd /opt/3genlabs/hawk/syntheticnode/service/chrome/108.0.5359.94.0 && chown root:root chrome-sandbox && chmod 4755 chrome-sandbox

echo "Restarting Agent"
catchpoint restart
EOF
yum clean all; sh /var/tmp/108.sh; rm -rf /var/tmp/108.sh

# Chrome 97

cat > /var/tmp/97.sh <<EOF
echo "Downloading Chrome 97"
yum install -y epel-release
yum install -y p7zip
wget "https://fs.catchpoint.com/UtilFiles/linux_chrome/catchpoint_chrome_linux_97.0.4692.99.0.7z" -P /tmp/
cd /tmp/ && 7za x /tmp/catchpoint_chrome_linux_97.0.4692.99.0.7z
sleep 5
mkdir /opt/3genlabs/hawk/syntheticnode/service/chrome/97.0.4692.99.0
tar -xvf /tmp/catchpoint_chrome_linux_97.0.4692.99.0.tar -C /opt/3genlabs/hawk/syntheticnode/service/chrome/97.0.4692.99.0
chown -R serveruser:cp /opt/3genlabs/hawk/syntheticnode/service/chrome/97.0.4692.99.0
cd /opt/3genlabs/hawk/syntheticnode/service/chrome/97.0.4692.99.0 && chown root:root chrome-sandbox && chmod 4755 chrome-sandbox

echo "Restarting Agent"
catchpoint restart
EOF
sh /var/tmp/97.sh; rm -rf /var/tmp/97.sh

# Chrome 89

cat > /var/tmp/89.sh <<EOF
echo "Downloading Chrome 89"
yum install -y epel-release
yum install -y p7zip
wget "https://fs.catchpoint.com/UtilFiles/linux_chrome/catchpoint_chrome_linux_89.0.4389.82.0.7z" -P /tmp/
cd /tmp/ && 7za x /tmp/catchpoint_chrome_linux_89.0.4389.82.0.7z
sleep 5
mkdir /opt/3genlabs/hawk/syntheticnode/service/chrome/89.0.4389.82.0
tar -xvf /tmp/catchpoint_chrome_linux_89.0.4389.82.0.tar -C /opt/3genlabs/hawk/syntheticnode/service/chrome/89.0.4389.82.0
chown -R serveruser:cp /opt/3genlabs/hawk/syntheticnode/service/chrome/89.0.4389.82.0
cd /opt/3genlabs/hawk/syntheticnode/service/chrome/89.0.4389.82.0 && chown root:root chrome-sandbox && chmod 4755 chrome-sandbox

echo "Restarting Agent"
catchpoint restart
EOF


# Chrome 87

cat > /var/tmp/87.sh <<EOF
echo "Downloading Chrome 87"
yum install -y epel-release
yum install -y p7zip
wget "https://fs.catchpoint.com/UtilFiles/linux_chrome/catchpoint_chrome_linux_87.0.4280.88.1.7z" -P /tmp/
cd /tmp/ && 7za x /tmp/catchpoint_chrome_linux_87.0.4280.88.1.7z
sleep 5
mkdir /opt/3genlabs/hawk/syntheticnode/service/chrome/87.0.4280.88.1
tar -xvf /tmp/catchpoint_chrome_linux_87.0.4280.88.1.tar -C /opt/3genlabs/hawk/syntheticnode/service/chrome/87.0.4280.88.1
chown -R serveruser:cp /opt/3genlabs/hawk/syntheticnode/service/chrome/87.0.4280.88.1
cd /opt/3genlabs/hawk/syntheticnode/service/chrome/87.0.4280.88.1 && chown root:root chrome-sandbox && chmod 4755 chrome-sandbox

echo "Restarting Agent"
catchpoint restart
EOF


