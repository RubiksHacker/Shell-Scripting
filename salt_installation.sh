#!/bin/bash

# Define a function to check if a variable is empty or not
is_empty() {
  [ -z "$1" ]
}

# Hostname Variable
hostname=$(echo $HOSTNAME)

echo "Installing Necessary Packages"
yum --quiet install -y jq > /dev/null
echo ""
echo "Package Installed successfully"
echo ""

#!/bin/bash

install_salt_minion() {
    echo ""
    echo "Installing Salt-Minion"
    echo ""
    curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.repo -o /etc/yum.repos.d/salt.repo
    yum --quiet install -y salt-minion > /dev/null
    sudo systemctl enable --now salt-minion
}

# Function to configure Salt Minion based on environment
configure_salt_minion() {
    local master_ip="$1"
    local master_name="$2"
    local master_finger="$3"

    # Update /etc/hosts to point to the correct master
    sudo sed -i "/$master_ip $master_name/d" /etc/hosts
    echo "$master_ip $master_name" | sudo tee -a /etc/hosts >/dev/null

    # Backup the original minion configuration
    sudo mv /etc/salt/minion /etc/salt/minion.oem

    # Set the minion configuration to connect to the specified master
    echo -e "master: $master_name\nmaster_finger: '$master_finger'" | sudo tee /etc/salt/minion >/dev/null

    # Set the minion ID to the hostname
    sudo cat /etc/hostname | sudo tee /etc/salt/minion_id >/dev/null
}

# Installation and configuration functions for each environment
install_production_salt_minion() {
    install_salt_minion
    configure_salt_minion "64.79.149.108" "saltmaster" "30:09:cf:ab:bf:3b:d3:3e:68:8e:76:2f:07:fe:ba:9e:cc:8e:20:de:30:fc:5a:09:c7:2e:aa:b9:5f:ac:6d:e2"
}

install_qa_salt_minion() {
    install_salt_minion
    configure_salt_minion "69.80.206.216" "qasalt" "41:3d:be:4c:a0:d2:85:f9:1a:80:b1:cb:82:4c:3f:5a:f1:c9:37:32:f5:9f:3a:43:b8:f5:d7:25:02:70:bb:1b"
}

install_lm_salt_minion() {
    install_salt_minion
    configure_salt_minion "64.79.149.211" "lmsaltmaster" "89:d0:8f:a5:5d:84:3f:ec:21:7b:c2:9d:85:ab:ca:96:6e:42:77:b7:52:ed:38:7b:38:16:e2:49:39:a6:bd:2a"
}

# Define a function to restart salt minion
restart_salt_minion() {
  sudo systemctl restart salt-minion
}

salt_repo_removal() {
  rm -rf /etc/yum.repos.d/salt*
  sudo yum --quiet clean all
}

# Define a function to handle kvm role
handle_kvm_role() {
  while true; do
    echo ""
    echo "Choose the VM Type:"
    echo "1. NoNAT VMs"
    echo "2. NAT VMs"
    echo "3. KVM Only"
    echo ""
    read -p "Select the number [Eg: 1 or 2]: " choice

    if [[ $choice == "1" ]]; then
        nat_value="nonat"
    elif [[ $choice == "2" ]]; then
        nat_value="nat"
    elif [[ $choice == "3" ]]; then
        nat_value="nil"
    fi
    echo ""
    echo "You have selected: $nat_value"
    echo ""
    read -p "Is this correct? (yes/no): " confirm
    if [[ $confirm == "yes" ]]; then
        break
    else
        echo "Please select the right VM Type"
    fi
    if [[ "$nat_value" == "nonat" || "$nat_value" == "nat" || "$nat_value" == "nil" ]]; then
      break
    else
      echo "Invalid nat_value: $nat_value"
    fi
  done

  install_production_salt_minion
  sudo sh -c "echo roles: \"$role\" > /etc/salt/grains"
  if [[ "$nat_value" != "nil" ]]; then
    sudo sh -c "echo nat_value: \"$nat_value\" >> /etc/salt/grains"
  fi
  restart_salt_minion
  echo -e "\nSalt Minion Installation for $role Host with $nat_value setup is completed"
}

handle_qa() {
  install_qa_salt_minion
  restart_salt_minion
  echo "Salt Minion Installation for QA Node Setup is completed"
}

handle_lm() {
  install_lm_salt_minion
  restart_salt_minion
  echo "Salt Minion Installation for Last Mile Node Setup is completed"
}

handle_syn_node_role() {
  salt_repo_removal
  install_production_salt_minion
  sudo sh -c "echo roles: node > /etc/salt/grains"
  sudo sh -c "echo network: $node_syn_network >> /etc/salt/grains"
  sudo sh -c "echo provider: synoptek >> /etc/salt/grains"
  sudo sh -c "echo nodetype: backbone >> /etc/salt/grains"
  sudo sh -c "echo isp: $isp >> /etc/salt/grains"
  sudo sh -c "echo country: $country >> /etc/salt/grains"
  sudo sh -c "echo city: $city >> /etc/salt/grains"
  restart_salt_minion
  echo "Salt Minion Installation for VM setup is completed"
}

handle_node_role() {
  salt_repo_removal
  install_production_salt_minion
  sudo sh -c "echo roles: node > /etc/salt/grains"
  sudo sh -c "echo network: $node_network >> /etc/salt/grains"
  sudo sh -c "echo provider: na >> /etc/salt/grains"
  sudo sh -c "echo nodetype: backbone >> /etc/salt/grains"
  sudo sh -c "echo isp: $isp >> /etc/salt/grains"
  sudo sh -c "echo country: $country >> /etc/salt/grains"
  sudo sh -c "echo city: $city >> /etc/salt/grains"
  restart_salt_minion
  echo "Salt Minion Installation for VM setup is completed"
}

handle_wavelength() {
  install_production_salt_minion
  sudo sh -c "echo roles: sn_node > /etc/salt/grains"
  sudo sh -c "echo instancetype: cloud >> /etc/salt/grains"
  sudo sh -c "echo network: v4 >> /etc/salt/grains"
  sudo sh -c "echo network_type: no_nat >> /etc/salt/grains"
  sudo sh -c "echo provider: aws >> /etc/salt/grains"
  sudo sh -c "echo environment: production >> /etc/salt/grains"
  sudo sh -c "echo isp: $isp >> /etc/salt/grains"
  sudo sh -c "echo city: $city >> /etc/salt/grains"
  sudo sh -c "echo country: $country >> /etc/salt/grains"
  restart_salt_minion
  echo "Salt Minion Installation for VM setup is completed"
}

# Define a function to handle bmnode role
handle_bmnode_role() {
  install_production_salt_minion
  sudo sh -c "echo roles: $role > /etc/salt/grains"
  sudo sh -c "echo network: $node_network >> /etc/salt/grains"
  sudo sh -c "echo provider: na >> /etc/salt/grains"
  sudo sh -c "echo nodetype: backbone >> /etc/salt/grains"
  sudo sh -c "echo isp: $isp >> /etc/salt/grains"
  sudo sh -c "echo country: $country >> /etc/salt/grains"
  sudo sh -c "echo city: $city >> /etc/salt/grains"
  restart_salt_minion
  echo "Salt Minion Installation for Baremetal Setup is completed"
}

handle_ibm_bmnode_role() {
  install_production_salt_minion
  sudo sh -c "echo roles: bmnode > /etc/salt/grains"
  sudo sh -c "echo network: $node_network >> /etc/salt/grains"
  sudo sh -c "echo provider: ibm >> /etc/salt/grains"
  sudo sh -c "echo instancetype: cloud >> /etc/salt/grains"
  sudo sh -c "echo country: $country >> /etc/salt/grains"
  restart_salt_minion
  echo "Salt Minion Installation for IBM Cloud node Setup is completed"
}

handle_bgp() {
  while true; do
    echo ""
    echo "Type of VMs inside this RAI?:"
    echo "1. NoNAT VMs"
    echo "2. NAT VMs"
    echo "3. BGP Only"
    echo ""
    read -p "Select the number [Eg: 1 or 2]: " choice

    if [[ $choice == "1" ]]; then
      nat_value="nonat"
    elif [[ $choice == "2" ]]; then
      nat_value="nat"
    elif [[ $choice == "3" ]]; then
      nat_value="nil"
    fi
    echo ""
    echo "You have selected: $nat_value"
    echo ""
    read -p "Is this correct? (yes/no): " confirm
    if [[ $confirm == "yes" ]]; then
      break
    else
      echo "Please select the right VM Type"
    fi
    if [[ "$nat_value" == "nonat" || "$nat_value" == "nat" || "$nat_value" == "nil" ]]; then
      break
    else
      echo "Invalid nat_value: $nat_value"
    fi
  done

  while true; do
    echo ""
    echo "Choose the BGP Type:"
    echo "1. External BGP"
    echo "2. Internal BGP"
    echo ""
    read -p "Select the number [Eg: 1 or 2]: " choice

    if [[ $choice == "1" ]]; then
      type="external"
    elif [[ $choice == "2" ]]; then
      type="internal"
    fi
    echo ""
    echo "You have selected: $type"
    echo ""
    read -p "Is this correct? (yes/no): " confirm
    if [[ $confirm == "yes" ]]; then
      break
    else
      echo "Please select the right BGP mode"
    fi
  done

  if [[ "$type" == "external" ]]; then
    install_production_salt_minion
    sudo sh -c "echo roles: bgp_node_external > /etc/salt/grains"
    if [[ "$nat_value" != "nil" ]]; then
      sudo sh -c "echo nat_value: "$nat_value" >> /etc/salt/grains"
    fi
    restart_salt_minion
    echo "Salt Minion Installation for BGP Setup is completed"
    break
  elif [[ "$type" == "internal" ]]; then
    install_production_salt_minion
    sudo sh -c "echo roles: bgp_node_internal > /etc/salt/grains"
    if [[ "$nat_value" != "nil" ]]; then
      sudo sh -c "echo nat_value: "$nat_value" >> /etc/salt/grains"
    fi
    restart_salt_minion
    echo "Salt Minion Installation for BGP Setup is completed"
    break
  else
    echo "Invalid type: $type"
    echo "Salt Instalaltion Failed, Please enter the correct BGP type"
  fi
}

# Function to handle role selection
select_role() {
  while true; do
    echo "Enter the value for roles:"
    for i in "${!options[@]}"; do 
      echo "$((i+1)). ${options[$i]}"
    done

    echo ""  # Print a newline
    read -p "Please enter the number corresponding to your role: " input

    # Validate input
    if ! [[ "$input" =~ ^[0-9]+$ ]] || [ "$input" -lt 1 ] || [ "$input" -gt "${#options[@]}" ]; then
      echo "Invalid input. Please enter a number between 1 and ${#options[@]}."
      continue
    fi

    role=${options[$((input-1))]}
    echo "You selected $input: $role"
    echo ""
    read -p "Is this correct? (yes/no): " confirm

    if [[ "$confirm" == "yes" ]]; then
      break
    else
      echo "Let's try again."
    fi
  done
}

# Function to get network type for synoptek role
get_synoptek_network() {
  ipv6init=$(grep -iE "IPV6INIT" /etc/sysconfig/network-scripts/ifcfg-ens160 | cut -d "=" -f 2 | tr -d '"')
  if [[ $ipv6init == "yes" ]]; then
    node_syn_network="v6"
  else
    node_syn_network="v4"
  fi
}



# Main script
options=("qa" "bgp" "node" "bmnode" "kvm" "ibmcloud" "lastmile" "wavelength" "synoptek")

# Main script
select_role

hostname=$(hostname)
if [[ $role == "synoptek" ]]; then 
  city=$(hostnamectl | grep -iE "Static hostname" | tr -d " " | cut -d ":" -f 2 | cut -d "-" -f 3)
  country=$(hostnamectl | grep -iE "Static hostname" | tr -d " " | cut -d ":" -f 2 | cut -d "-" -f 1)
  isp=$(hostnamectl | grep -iE "Static hostname" | tr -d " " | cut -d ":" -f 2 | cut -d "-" -f 4)
  get_synoptek_network
else
  city=$(hostnamectl | grep -iE "Static hostname" | tr -d " " | cut -d ":" -f 2 | cut -d "-" -f 2)
  country=$(hostnamectl | grep -iE "Static hostname" | tr -d " " | cut -d ":" -f 2 | cut -d "-" -f 1)
  isp=$(hostnamectl | grep -iE "Static hostname" | tr -d " " | cut -d ":" -f 2 | cut -d "-" -f 3)
fi

# Check if the hostname has "ipv6"
if [[ $hostname == *"ipv6"* ]]; then
  node_network="v6"
else
  node_network="v4"
fi

# Handle roles
case "$role" in
  "qa")
    handle_qa
    ;;
  "bgp")
    handle_bgp
    ;;
  "node")
    handle_node_role
    ;;
  "bmnode")
    handle_bmnode_role
    ;;
  "kvm")
    handle_kvm_role
    ;;
  "ibmcloud")
    handle_ibm_bmnode_role
    ;;
  "lastmile")
    handle_lm
    ;;
  "wavelength")
    handle_wavelength
    ;;
  "synoptek")
    handle_syn_node_role
    ;;
  *)
    echo "Invalid option: $role"
    ;;
esac

# Remove the script once the execution is completed
sudo rm -rf /var/tmp/salt_installation.sh