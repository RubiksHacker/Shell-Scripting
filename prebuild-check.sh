#!/bin/bash

# Variables to store the results
total_ram=""
total_cpu=""
epel_status=""
base_status=""
appstream_status=""
virtualization_status=""
bandwidth_result=""
root_total_space=""
root_available_space=""
home_total_space=""
home_available_space=""
lvm_status="No"
ipv4_status=""
ipv6_status=""
uek_status=""

# Function to print a heading
print_heading() {
    local text="$1"
    echo -e "\033[1;34m$text\033[0m"  # Bold blue text
}

# Function to print normal text
print_text() {
    local text="$1"
    echo -e "$text"
}

# Function to check RAM and CPU
check_specs() {
    echo "Checking Server Specs..."
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    total_cpu=$(nproc)
    echo "Done"
}

# Function to check repo status
check_repo_status() {
    if curl -s -o /dev/null -w "%{http_code}" "$1" | grep -q "200"; then
        echo "Success"
    else
        echo "Failed"
    fi
}

# Function to check OS and repositories
check_repos() {
    echo "Checking Repositories..."
    declare -A repos
    if grep -q "Oracle" /etc/os-release; then
        os="Oracle"
        repos=(
            ["EPEL"]="https://yum.oracle.com/repo/OracleLinux/OL8/developer/EPEL/x86_64/repodata/repomd.xml"
            ["Base"]="https://yum.oracle.com/repo/OracleLinux/OL8/baseos/latest/x86_64/repodata/repomd.xml"
            ["AppStream"]="https://yum.oracle.com/repo/OracleLinux/OL8/appstream/x86_64/repodata/repomd.xml"
        )
    elif grep -q "Rocky" /etc/os-release; then
        os="Rocky"
        repos=(
            ["EPEL"]="https://dl.rockylinux.org/pub/rocky/8/extras/x86_64/os/repodata/repomd.xml"
            ["Base"]="https://dl.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os/repodata/repomd.xml"
            ["AppStream"]="https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/repodata/repomd.xml"
        )
    else
        echo "Unsupported OS"
        exit 1
    fi

    # Determine the appropriate URLs for Catchpoint TechOps and Third-Party repositories based on hostname
    hostname=$(hostname)
    if [[ $hostname == cn-* ]]; then
        repos+=(
            ["TechOps"]="http://47.95.6.227/repo/rhel8-techops/repodata/repomd.xml"
            ["ThirdParty"]="http://47.95.6.227/repo/Third-Party-el8/repodata/repomd.xml"
        )
    else
        repos+=(
            ["TechOps"]="https://repo.catchpoint.net/repo/rhel8-techops/repodata/repomd.xml"
            ["ThirdParty"]="https://repo.catchpoint.net/repo/Third-Party-el8/repodata/repomd.xml"
        )
    fi

    for repo in "${!repos[@]}"; do
        status=$(check_repo_status "${repos[$repo]}")
        eval "${repo,,}_status=\$status"
    done
    echo "Done"
}

# Function to check virtualization
check_virtualization() {
    echo "Checking Virtualization..."
    if grep -E -c '(vmx|svm)' /proc/cpuinfo > /dev/null; then
        virtualization_status="Enabled"
    else
        virtualization_status="Disabled"
    fi
    echo "Done"
}

# Function to check bandwidth
check_bandwidth() {
    echo "Checking Bandwidth..."
    if ! command -v speedtest &> /dev/null; then
        curl -sS https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz -o /var/tmp/ookla-speedtest-1.2.0-linux-x86_64.tgz
        tar -xvzf /var/tmp/ookla-speedtest-1.2.0-linux-x86_64.tgz -C /var/tmp/ > /dev/null 2>&1
        cp /var/tmp/speedtest /usr/sbin/
    fi
    bandwidth_result=$(speedtest --accept-license --accept-gdpr 2>/dev/null)
    download_speed=$(echo "$bandwidth_result" | grep "Download" | awk '{print $2, $3}')
    upload_speed=$(echo "$bandwidth_result" | grep "Upload" | awk '{print $2, $3}')
    isp=$(echo "$bandwidth_result" | grep "ISP" | awk -F: '{print $2}' | xargs)
    echo "Done"
}

# Function to check partition space
check_partition_space() {
    echo "Checking Partition Info..."
    root_total_space=$(df -h / | awk 'NR==2 {print $2}')
    root_available_space=$(df -h / | awk 'NR==2 {print $4}')
    if df -h /home &> /dev/null; then
        home_total_space=$(df -h /home | awk 'NR==2 {print $2}')
        home_available_space=$(df -h /home | awk 'NR==2 {print $4}')
    fi
    echo "Done"
}

# Function to check if LVM is used and can be extended
check_lvm() {
    echo "Checking LVM Status..."
    if command -v lvextend &> /dev/null && command -v vgextend &> /dev/null; then
        if lsblk | grep -q "lvm"; then
            lvm_status="Yes"
        fi
    fi
    echo "Done"
}

# Function to check IPv4 and IPv6 connectivity
check_connectivity() {
    print_text "Checking IPv4 connectivity..."
    local ipv4_hosts=("google.com" "ibm.com" "catchpoint.com" "bing.com" "python.org")
    local ipv6_hosts=("google.com" "ibm.com" "catchpoint.com" "bing.com" "python.org")

    hostname=$(hostname)
    if [[ $hostname == cn-* ]]; then
        ipv4_hosts=("baidu.com" "qq.com" "taobao.com" "jd.com" "sina.com.cn")
        ipv6_hosts=("baidu.com" "qq.com" "taobao.com" "jd.com" "sina.com.cn")
    fi

    for host in "${ipv4_hosts[@]}"; do
        if ping -c 2 "$host" > /dev/null; then
            ipv4_status+="$host: Success\n"
        else
            ipv4_status+="$host: Failed\n"
        fi
    done
    print_text "Done"

    # Alternative IPv6 check
    if ! ip -6 route show default | grep -q "default"; then
        ipv6_status="IPv6 not configured"
        return
    fi

    print_text "Checking IPv6 connectivity..."
    for host in "${ipv6_hosts[@]}"; do
        if ping6 -c 2 "$host" > /dev/null; then
            ipv6_status+="$host: Success\n"
        else
            ipv6_status+="$host: Failed\n"
        fi
    done
    print_text "Done"
}


# Function to check UEK kernel status
check_uek() {
    print_text "Checking UEK kernel status..."
    if uname -r | grep -q "uek"; then
        uek_status="Active"
    else
        uek_status="Inactive"
    fi
    print_text "Done"
}

# Main script execution with progress indicators
check_specs
check_uek
check_repos
check_virtualization
check_partition_space
check_lvm
check_connectivity
# Check for required commands
if ! command -v tar &> /dev/null; then
    echo "Installing tar utility..."
    yum --quiet install -y tar > /dev/null
    echo "Done"
fi
check_bandwidth

# Final output
if [ "$ipv6_status" = "IPv6 not configured" ]; then
    print_text ""
    print_heading "IPv4 Connectivity Status"
    echo -e "$ipv4_status"
else
    print_text ""
    print_heading "IPv4 Connectivity Status"
    echo -e "$ipv4_status"
    print_text ""
    print_heading "IPv6 Connectivity Status"
    echo -e "$ipv6_status"
fi
print_heading "Repo's Connectivity Status"
print_text "EPEL Repository: ${epel_status}"
if [ "$os" == "Oracle" ]; then 
    print_text "Oracle Base Repo: ${base_status}"
    print_text "Oracle Appstream Repo: ${appstream_status}"
else 
    print_text "Rocky Base Repo: ${base_status}"
    print_text "Rocky Appstream Repo: ${appstream_status}"
fi
print_text "Catchpoint TechOps Repo: ${techops_status}"
print_text "Catchpoint Third-Party Repo: ${thirdparty_status}"
print_text ""
print_heading "Server Specs"
print_text "Total RAM Allocated: ${total_ram} GB"
print_text "Total CPU Cores Available: ${total_cpu}"
print_text "Virtualization: ${virtualization_status}"
print_text "LVM Partitioned: ${lvm_status}"
print_text "UEK Kernel Status: ${uek_status}"
print_text ""
print_heading "Root Partition Space"
print_text "  Total: ${root_total_space}"
print_text "  Available: ${root_available_space}"
if [ -n "$home_total_space" ]; then
    print_text ""
    print_heading "Home Partition Space"
    print_text "  Total: ${home_total_space}"
    print_text "  Available: ${home_available_space}"
fi
print_text ""
print_heading "Bandwidth Details"
print_text "  ISP: ${isp}"
print_text "  ${download_speed} Mbps"
print_text "  ${upload_speed} Mbps"

rm -rf /var/tmp/prebuild-check.sh 2> /dev/null