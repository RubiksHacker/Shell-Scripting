#!/bin/bash

# Display help and usage information
display_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script provides various troubleshooting and configuration utilities."
    echo "You can select an option interactively or specify flags directly from the command line."
    echo ""
    echo "Options:"
    echo "  -gtld_config          Configuring GTLD Timeout value count from 3 to 5."
    echo "  -cache_removal        Remove specific caches related to Catchpoint."
    echo "  -vm_interface_update  Update VM network interfaces for all running VMs."
    echo "  -group2_config        Apply Group2 slippage configuration. Use -value=<number> to specify the frequency. [Default: 2]"
    echo "  -value=<number>       Set value for SingleObjectScheduleServerRequestJobRunFreqSec (used with -group2_config)."
    echo "  -disk_expansion       Expand root partition for LVM partitioned Disk's using available space from /home Partition"
    echo "  -disk_cleanup         Clean up disk space and manage log files."
    echo "  -h                    Display this help message and exit."
    echo "  -delete               Delete the troubleshooting file at /var/tmp/troubleshooting.sh."
    echo ""
    echo "Examples:"
    echo "  Interactive mode:"
    echo "    $0"
    echo ""
    echo "  Run specific options directly:"
    echo "    $0 -gtld_config"
    echo "    $0 -cache_removal"
    echo "    $0 -group2_config -value=5"
    echo "    $0 -disk_cleanup"
    echo ""
    exit 0
}

cache_removal() {
    catchpoint stop
    if command -v "unbound-control"; then 
        unbound-control reload
    fi
    sudo rm -f /var/CatchPoint/Agent/Services/CommEng/Cache/DynamicConfig.dta
    sudo rm -f /var/3genlabs/hawk/syntheticnode/service/synthetic_node_configuration_stats.dat.gz
    sudo rm -f /var/3genlabs/hawk/syntheticnode/service/synthetic_node_configuration_stats.dat.gz.bak
    sudo rm -f /var/3genlabs/hawk/syntheticnode/synthetic_node_configuration.dat
    sudo rm -f /var/3genlabs/hawk/syntheticnode/synthetic_node_configuration.dat.bak
    sudo rm -rf /var/3genlabs/hawk/syntheticnode/service/cache
    sudo rm -rf /var/CatchPoint/Agent/Services/TxEng/Cache
    sudo rm -rf /var/CatchPoint/Agent/Services/TestEng/Cache
    sudo rm -rf /var/CatchPoint/Agent/Services/CommEngg/Cache
    sudo rm -rf /var/cache/yum/
    catchpoint restart
}

# Function to configure Catchpoint settings
group2_config() {
    local status_step1="No Changes"
    local status_step2="No Changes"
    local status_step3="No Changes"
    local prev_value=""
    local changes_needed=false

    # Default value for SingleObjectScheduleServerRequestJobRunFreqSec
    local value=2

    # Check if script is run as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        echo "Error: This script must be run as root or with sudo privileges."
        return 1
    fi

    # Process any optional arguments passed to group2_config
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -value=*)
                value="${1#*=}"
                ;;
            -r)
                echo "Reverting changes..."
                for file in "$CONF_FILE" "$VALUES_FILE" "$CONFIG_FILE"; do
                    revert_changes "$file"
                done
                return 0
                ;;
            *)
                echo "Unknown option $1"
                return 1
                ;;
        esac
        shift
    done

    # Paths to config files
    local CONF_FILE="/etc/catchpoint.d/TestEng.conf"
    local VALUES_FILE="/opt/3genlabs/registry/LocalMachine/software/3genlabs/hawk/syntheticnode/service/values.xml"
    local CONFIG_FILE="/opt/catchpoint/bin/HawkSyntheticNodeService.exe.config"
    local CONF_DIR="/etc/catchpoint.d"

    # Function to create a backup of a file if it doesn't already exist
    backup_file() {
        local file="$1"
        [[ -f "$file" && ! -f "$file.bak" ]] && cp "$file" "$file.bak" && echo "Created backup: $file.bak"
    }

    # Check if stop/start is needed
    if ! grep -q "$REQUIRED_ENTRY" "$CONF_FILE" || 
       ! grep -q "dwMaxParallelJobsSingleObject" "$VALUES_FILE" || 
       [[ "$(grep -oP '(?<=<add key="SingleObjectScheduleServerRequestJobRunFreqSec" value=")[^"]*' "$CONFIG_FILE")" != "$value" ]]; then
        echo "Stopping Catchpoint Agent..."
        catchpoint stop
    fi

    # Step 1: Ensure TestEng.conf is configured
    local REQUIRED_ENTRY='SubmitTestWorkflow_MonitorSetsCapacityTable="0=4,2=64,3=20,9=64"'
    mkdir -p "$CONF_DIR"
    touch "$CONF_FILE"
    if ! grep -q "$REQUIRED_ENTRY" "$CONF_FILE"; then
        backup_file "$CONF_FILE"
        echo "$REQUIRED_ENTRY" >> "$CONF_FILE"
        status_step1="Applied Successfully"
        changes_needed=true
    else
        status_step1="No Changes"
    fi

    # Step 2: Ensure values.xml has required configuration
    if [[ -f "$VALUES_FILE" ]]; then
        if ! grep -q "dwMaxParallelJobsSingleObject" "$VALUES_FILE"; then
            backup_file "$VALUES_FILE"
            sed -i '/<values>/a\
<value name="dwMaxParallelJobsSingleObject" \
type="int">64</value>' "$VALUES_FILE"
            status_step2="Applied Successfully"
            changes_needed=true
        else
            status_step2="No Changes"
        fi
    else
        echo "Error: $VALUES_FILE does not exist, cannot configure."
        return 1
    fi

    # Step 3: Ensure HawkSyntheticNodeService.exe.config has correct value
    if [[ -f "$CONFIG_FILE" ]]; then
        backup_file "$CONFIG_FILE"
        # Check the current value of SingleObjectScheduleServerRequestJobRunFreqSec
        prev_value=$(grep -oP '(?<=<add key="SingleObjectScheduleServerRequestJobRunFreqSec" value=")[^"]*' "$CONFIG_FILE")
        if [ "$prev_value" != "$value" ]; then
            # Update the value to the new one
            sed -i "s|\(<add key=\"SingleObjectScheduleServerRequestJobRunFreqSec\" value=\"\)[^\"]*\"|\1$value\"|" "$CONFIG_FILE"
            status_step3="Changed Value from $prev_value to $value"
            changes_needed=true
        else
            status_step3="No Changes"
        fi
    else
        echo "Error: $CONFIG_FILE does not exist, cannot configure."
        return 1
    fi

    # Start Catchpoint Agent if any changes were made
    if [ "$changes_needed" = true ]; then
        echo "Starting Catchpoint Agent..."
        catchpoint start
    fi

    # Display the final status output
    echo -e "\nGroup2 Configuration Status:\n"
    echo "Step 1: $status_step1"
    echo "Step 2: $status_step2"
    echo "Step 3: $status_step3"
    echo -e "\nConfiguration steps completed.\n"
    return 0
}




gtld_config() {
# Define the path to the values.xml file
VALUES_XML_PATH="/opt/3genlabs/registry/LocalMachine/software/3genlabs/hawk/syntheticnode/service/values.xml"

# Define the new entry with each attribute on a separate line
NEW_ENTRY='<value name="dwNetworkOutageDetectorFilter_DnsTraceTldServerMinimumFailureCount"
type="int">5</value>'

# Check if the entry is already present in values.xml
if grep -q "dwNetworkOutageDetectorFilter_DnsTraceTldServerMinimumFailureCount" "$VALUES_XML_PATH"; then
    echo "The entry is already present in $VALUES_XML_PATH."
else
    echo "The entry is not present. Adding the entry..."
    echo ""

    # Insert the new entry right before the closing </values> tag
    awk -v new_entry="$NEW_ENTRY" '
        /<\/values>/ {
            print new_entry
        }
        { print }
    ' "$VALUES_XML_PATH" | sudo tee "$VALUES_XML_PATH.tmp" > /dev/null

    # Move the updated file back to the original location
    sudo mv "$VALUES_XML_PATH.tmp" "$VALUES_XML_PATH"

    cache_removal
    
    echo "Added the new entry to $VALUES_XML_PATH."
fi
}

vm_interface_update() {
    vms=$(virsh list --name --state-running)
    for vm in $vms; do
        echo "Network Interface updated for $vm"
        if virsh dominfo $vm > /dev/null 2>&1; then
            virsh dumpxml $vm > /etc/libvirt/qemu/$vm.xml
            virsh define /etc/libvirt/qemu/$vm.xml > /dev/null
            virsh destroy $vm > /dev/null
            virsh start $vm > /dev/null
        else
            echo "VM $vm is not defined"
        fi
    done
}

# Function to check if LVM is used
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

# Main script execution
disk_expansion() {
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
    check_lvm
    find_partitions
    resize_partitions
    cache_removal
}

disk_cleanup() {
    # Set the threshold for disk usage
    THRESHOLD=80
    PARTITION="/"
    LOG_FILES="/var/log/messages-*"
    SCRIPT_PATH="/var/tmp/disk-cleanup.sh"
    CRON_JOB_ENTRY="0 */8 * * * $SCRIPT_PATH"
    LOG_FILE="/var/log/disk-cleanup.log"

    # Function to check disk utilization
    check_disk_usage() {
        df -h "$PARTITION" | awk 'NR==2 {print $5}' | sed 's/%//'
    }

    # Function to remove log files
    remove_log_files() {
        echo "Disk usage is ${1}% on ${PARTITION}, removing log files: $LOG_FILES" | tee -a $LOG_FILE
        rm -f $LOG_FILES
    }

    # Function to self-destruct script and remove cron job
    self_destruct() {
        echo "Today is 20th November. Self-destructing script and removing Cron job." | tee -a $LOG_FILE
        rm -f "$SCRIPT_PATH"
        crontab -l | grep -v "$SCRIPT_PATH" | crontab -
    }

    # Function to add cron job if it doesn't exist
    add_cron_job() {
        (crontab -l 2>/dev/null | grep -q "$SCRIPT_PATH") || (crontab -l 2>/dev/null; echo "$CRON_JOB_ENTRY") | crontab -
    }

    # Main script execution
    usage=$(check_disk_usage)

    if [ "$usage" -ge "$THRESHOLD" ]; then
        remove_log_files "$usage"
        cache_removal
    else
        echo "$(date): Disk usage is below the threshold. No action required." | tee -a $LOG_FILE
    fi

    current_date=$(date '+%d-%m')
    if [ "$current_date" == "20-11" ]; then
        self_destruct
    fi

    # Add cron job to run this script every 8 hours if not already added
    add_cron_job
}

# Function to delete the troubleshooting file
delete_troubleshooting_file() {
    local file_path="/var/tmp/troubleshooting.sh"
    if [[ -f "$file_path" ]]; then
        rm -f "$file_path"
        echo "Deleted $file_path."
    else
        echo "File $file_path does not exist."
    fi
}


select_work() {
    options=("gtld_config" "cache_removal" "vm_interface_update" "group2_config" "disk_expansion" "disk_cleanup")
    descriptions=("GTLD Configuration" "Cache Removal" "VM IP Update" "Group2 Slippage Configuration" "Root Partition Expansion" "Messages Logs Cleanup")
    while true; do
        echo ""
        echo "Select the Troubleshooting:"
        for i in "${!descriptions[@]}"; do 
            echo "$((i+1)). ${descriptions[$i]}"
        done

        echo ""
        read -p "Please enter the number corresponding to Troubleshoot: " input

        if ! [[ "$input" =~ ^[0-9]+$ ]] || [ "$input" -lt 1 ] || [ "$input" -gt "${#descriptions[@]}" ]; then
            echo "Invalid input. Please enter a number between 1 and ${#descriptions[@]}."
            continue
        fi

        role=${options[$((input-1))]}
        echo "You selected $input: ${descriptions[$((input-1))]}"
        echo ""
        read -p "Is this correct? (yes/no): " confirm

        if [[ "$confirm" == "yes" ]]; then
            break
        else
            echo "Let's try again."
        fi
    done
}


# Main argument parsing and execution section

roles=()
value_arg=""

# Check if any arguments are provided
if [[ $# -eq 0 ]]; then
    # No arguments, call select_work to prompt user for an option
    select_work
    
    # Based on the choice, add the selected role to the roles array
    case "$role" in
        "gtld_config" | "cache_removal" | "vm_interface_update" | "group2_config" | "disk_expansion" | "disk_cleanup")
            roles+=("$role")
            ;;
        *)
            echo "Invalid selection. Exiting."
            exit 1
            ;;
    esac
else
    # Process any provided arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -gtld_config)
                roles+=("gtld_config")
                ;;
            -cache_removal)
                roles+=("cache_removal")
                ;;
            -vm_interface_update)
                roles+=("vm_interface_update")
                ;;
            -group2_config)
                roles+=("group2_config")
                ;;
            -value=*)
                value_arg="$1" # Store -value argument to pass to group2_config
                ;;
            -disk_expansion)
                roles+=("disk_expansion")
                ;;
            -disk_cleanup)
                roles+=("disk_cleanup")
                ;;
            -delete)
                delete_troubleshooting_file
                exit 0
                ;;
            -h)
                display_help
                ;;
            *)
                echo "Invalid option: $1"
                exit 1
                ;;
        esac
        shift
    done
fi

# Execute the roles based on user selection
for role in "${roles[@]}"; do
    case "$role" in
        "gtld_config")
            gtld_config
            ;;
        "cache_removal")
            cache_removal
            ;;
        "vm_interface_update")
            vm_interface_update
            ;;
        "group2_config")
            # Pass the -value argument if provided
            if [ -n "$value_arg" ]; then
                group2_config "$value_arg"
            else
                group2_config
            fi
            ;;
        "disk_expansion")
            disk_expansion
            ;;
        "disk_cleanup")
            disk_cleanup
            ;;
        *)
            echo "Invalid option: $role"
            ;;
    esac
done

