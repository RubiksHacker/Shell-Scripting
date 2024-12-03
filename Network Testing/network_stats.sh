#!/bin/bash

# List of tools
tools=("mtr" "net-tools" "traceroute")

# Function to check if a tool is installed
function check_tool() {
    if ! command -v $1 &> /dev/null; then
        echo "$1 is not installed. Installing..."
        sudo yum install -y $1
    else
        echo "$1 is installed."
    fi
}

# Ask for domains
declare -a domains
while true; do
    read -p "Enter a domain (or 'done' when finished): " domain
    if [ "$domain" == "done" ]; then
        break
    fi
    domains+=("$domain")
done

# Confirm domains
while true; do
    echo "You have entered the following domains:"
    for domain in "${domains[@]}"; do
        echo "- $domain"
    done
    read -p "Is this correct? (yes/no): " confirm
    if [ "$confirm" == "yes" ]; then
        break
    fi
    read -p "Which domain do you want to change? " old_domain
    read -p "What is the new domain? " new_domain
    for i in "${!domains[@]}"; do
        if [ "${domains[$i]}" == "$old_domain" ]; then
            domains[$i]=$new_domain
        fi
    done
done

# Ask for number of packets
read -p "Enter the number of packets to send with mtr & traceroute: " packets

# Check each tool
for tool in "${tools[@]}"; do
    check_tool $tool
done

# Check if speedtest is installed
if ! command -v speedtest &> /dev/null; then
    echo "Speedtest is not installed. Installing..."
    wget -P /var/tmp/ https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz
    tar -xzvf /var/tmp/ookla-speedtest-1.2.0-linux-x86_64.tgz -C /var/tmp/
    sudo cp /var/tmp/speedtest /usr/sbin/
else
    echo "Speedtest is installed."
fi

# Run network stats
echo "Running network stats..."

# Speedtest
echo "Running speedtest..."
speedtest_output=$(speedtest)
echo "$speedtest_output"

# MTR for each domain
declare -a mtr_outputs
echo "Running MTR for all domains..."
for domain in "${domains[@]}"; do
    echo "Running MTR for $domain..."
    mtr_output=$(mtr --report --report-cycles=$packets $domain)
    echo "$mtr_output"
    mtr_outputs+=("$mtr_output")
done

# Traceroute for each domain
declare -a traceroute_outputs
echo "Running traceroute for all domains..."
for domain in "${domains[@]}"; do
    echo "Running traceroute for $domain..."
    traceroute_output=$(traceroute $domain)
    echo "$traceroute_output"
    traceroute_outputs+=("$traceroute_output")
done

# Netstat
echo "Running netstat..."
netstat_output=$(netstat -s)
echo "$netstat_output"

# Ask to save results
read -p "Do you want to save these results? (yes/no): " save
if [ "$save" == "yes" ]; then
    echo "[Speedtest]" > results.txt
    echo "$speedtest_output" >> results.txt
    echo "[MTR]" >> results.txt
    for i in "${!domains[@]}"; do
        echo "[${domains[$i]}]" >> results.txt
        echo "${mtr_outputs[$i]}" >> results.txt
    done
    echo "[Traceroute]" >> results.txt
    for i in "${!domains[@]}"; do
        echo "[${domains[$i]}]" >> results.txt
        echo "${traceroute_outputs[$i]}" >> results.txt
    done
    echo "[Netstat]" >> results.txt
    echo "$netstat_output" >> results.txt
    echo "Results saved to results.txt."
fi
