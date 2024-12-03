#!/bin/bash

cache_removal() {
    sudo catchpoint stop
    rm -rf /var/CatchPoint/Agent/Services/CommEng/Cache/*.dta
    rm -rf /var/3genlabs/hawk/syntheticnode/service/cache/*
    if command -v "unbound-control"; then
        unbound-control reload
    fi
    sudo catchpoint restart
}

# Function to check if LVM is used in the server
check_lvm() {
    if ! command -v lvs &> /dev/null; then
        echo "LVM tools are not installed."
        exit 1
    fi
}

# Function to find the home and root partitions
find_partitions() {
    ROOT_PART=$(findmnt -n -o SOURCE /)
    HOME_PART=$(findmnt -n -o SOURCE /home)

    if [ -z "$ROOT_PART" ] || [ -z "$HOME_PART" ]; then
        sudo rm -rf /var/tmp/disk_expansion.sh
        echo "Root or home partition not found."
        exit 1
    fi
}

# Function to remove the home partition volume
remove_home_partition() {
    lvremove -y $HOME_PART
    if [ $? -ne 0 ]; then
        echo "Error removing home partition. Attempting to kill processes using the partition."
        
        # Kill processes using the home partition
        fuser -kuc $HOME_PART

        # Retry removing the home partition volume
        lvremove -y $HOME_PART
        if [ $? -ne 0 ]; then
            echo "Failed to remove home partition after killing processes. Retrying unmount and remove."

            # Retry unmounting the home partition
            umount -fl /home

            # Kill processes using the home partition again for safety
            fuser -kuc $HOME_PART

            # Retry removing the home partition volume
            lvremove -y $HOME_PART
            if [ $? -ne 0 ]; then
                echo "Failed to remove home partition after multiple attempts."
                sudo rm -rf /var/tmp/disk_expansion.sh
                exit 1
            fi
        fi
    fi
}

# Function to resize partitions
resize_partitions() {
    # Create a temporary directory
    mkdir -p /temp/home

    # Copy all files from the home directory to the temporary directory
    rsync -a /home/ /temp/home/

    # Unmount the home partition
    umount -fl /home

    # Remove the home partition volume
    remove_home_partition

    # Extend the root volume using the available space
    lvextend -l +100%FREE $ROOT_PART

    # Resize the XFS file system to recognize the new size and utilize the space
    xfs_growfs $ROOT_PART

    echo ""
    df -h

    # Remove the home partition entry from the fstab configuration file
    sed -i '/\/home/d' /etc/fstab

    # Create Home Directoru
    mkdir -p /home

    # Copy all the files to respective locations
    cp -r /temp/home/* /home/

    # Set the necessary permission
    chown cpadmin:cpadmin /home/cpadmin
    chown serveruser:cp /home/serveruser
    chown cpservice:cpservice /home/cpservice
    sudo chown -R serveruser:cp /home/serveruser/
    sudo chown -R cpadmin:cpadmin /home/cpadmin/
    sudo chown -R cpservice:cpservice /home/cpservice/

    # Regenerate all initramfs images for the new size to get reflected in the filesystem
    # dracut --force --regenerate-all

    echo "Root partition expanded successfully"
}

### Package Installation

# Clear repo cache
yum clean all

# Check and install epel-release if not installed
if ! rpm -q epel-release; then
    echo "Installing EPEL Package"
    yum install -y epel-release
fi

# Install fuser utility if not already installed
if ! command -v fuser; then
    yum install -y psmisc
fi

# Install rsync if not already installed
if ! command -v rsync; then
    yum --quiet install -y rsync
fi

# Main script execution
check_lvm
find_partitions
resize_partitions
cache_removal

sudo rm -rf /var/tmp/disk_expansion.sh &> /dev/null