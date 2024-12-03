#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
LIGHT_CYAN='\033[38;5;195m'
LIGHT_BLUE='\033[38;5;75m'

# Define the width of the banner
width=80

# Function to print centered text within the banner
print_centered() {
    color=$1
    text=$2
    end_offset=$3
    printf "# %*s${color}%s${NC}%*s%*s#\n" $(((${width}-2-${#text}-end_offset)/2)) "" "$text" $(((${width}-2-${#text}-end_offset)/2)) "" $end_offset ""
}

# Function to run traceroute for a domain with a specific protocol
run_traceroute() {
    protocol_name=$2
    if [ "$2" == "-I" ]; then
        protocol_name="ICMP"
    elif [ "$2" == "-U" ]; then
        protocol_name="UDP"
    elif [ "$2" == "-T" ]; then
        protocol_name="TCP"
    fi
    echo "$protocol_name Traceroute for $1"
    echo ""
    traceroute $2 $1
    echo ""
}

# Function to run traceroute for all domains with a specific protocol
run_all_traceroutes() {
    protocol=$1
    shift
    domains=("$@")
    for domain in "${domains[@]}"; do
        run_traceroute "$domain" "$protocol"
    done
}

# Function to get domains from user
get_domains() {
    domains=()
    while true; do
        read -p  "Enter a domain (or 'done' to finish):" domain
        if [ "$domain" == "done" ]; then
            break
        fi
        domains+=("$domain")
    done
    confirm_domains "${domains[@]}"
}

# Function to confirm domains
confirm_domains() {
    echo ""
    echo "You've choosed these domains: $@"
    read -p  "Is this correct? (yes/no) " answer
    echo ""
    if [ "$answer" == "no" ]; then
        get_domains
    fi
}

while true; do
    read -p "Are you going to add domains manually or through file? (manual or file): " input_method
    echo "You've entered: $input_method method"
    echo ""
    read -p "Is this correct? (yes/no) " confirm

    if [[ $confirm == "yes" ]]; then
        if [ "$input_method" == "file" ]; then
            while true; do
                echo ""
                read -p "Enter the file path: " file_path
                echo "You entered: $file_path"
                echo ""
                read -p "Is this correct? (yes/no) " answer
                if [ "$answer" == "yes" ]; then
                    domains=()
                    while IFS= read -r domain; do
                        domains+=("$domain")
                    done < "$file_path"
                    confirm_domains "${domains[@]}"
                    if [ "$answer" == "yes" ]; then
                        break 2
                    fi
                fi
            done
        else
            get_domains
            break
        fi
    else
        echo ""
        echo "Please Choose the correct method"
    fi
done

echo ""

# Print the banner
echo "#################################################################################"
echo "#                                                                               #"
print_centered "${YELLOW}" "ICMP Traceroute" 2
echo "#                                                                               #"
echo "#################################################################################"

echo ""
run_all_traceroutes "-I" "${domains[@]}"

echo "#################################################################################"
echo "#                                                                               #"
print_centered "${YELLOW}" "UDP Traceroute" 2
echo "#                                                                               #"
echo "#################################################################################"

echo ""
run_all_traceroutes "-U" "${domains[@]}"

echo "#################################################################################"
echo "#                                                                               #"
print_centered "${YELLOW}" "TCP Traceroute" 2
echo "#                                                                               #"
echo "#################################################################################"

echo ""
run_all_traceroutes "-T" "${domains[@]}"

rm -rf /var/tmp/traceroute.sh
