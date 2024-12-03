#! /bin/bash

echo "Installing Connectwise"
sudo yum -y install java-11-openjdk-devel; sudo curl http://fs.catchpoint.com/UtilFiles/linuxlts.rpm -o linuxlts.rpm; sudo dnf -y install linuxlts.rpm
echo ""
echo "ConnectWise Installed Successfully"
echo ""
echo "Installing Salt Minion"
sudo curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.repo -o /etc/yum.repos.d/salt.repo
sudo dnf --quiet install -y salt-minion
echo ""
echo "Installing SyntheticAgent"
curl -sS https://repo.catchpoint.net/repo/rhel8-techops/catchpoint_el8_techops.repo -o /etc/yum.repos.d/catchpoint_el8_techops.repo
sudo dnf --quiet install -y SyntheticAgent 
echo ""
echo "Agent Installed Successfully, Proceeding with Chrome"
sudo curl -sS https://fs.catchpoint.com/UtilFiles/scripts/allchromedeploy.sh -o /var/tmp/allchromedeploy.sh; sh /var/tmp/allchromedeploy.sh


rm -rf /var/tmp/last_mile_setup.sh
rm -rf /etc/yum.repos.d/catchpoint_el8_techops.repo
