#!/bin/bash

sudo curl -sS https://fs.catchpoint.com/UtilFiles/scripts/domains.txt -o /var/tmp/domains.txt > /dev/null

# File containing the list of domains
file="/var/tmp/domains.txt"

# Check if file exists
if [[ ! -e $file ]]; then
    echo "File $file does not exist."
    exit 1
fi

# Read the file line by line
echo "Ping for GTLD Servers [.com, .cn, .org, .edu, .uk]"
echo ""
while IFS= read -r domain
do
    echo "$domain"
  # Ping the domain
    if ping -c 5 "$domain" > /dev/null
    then
        echo "Ping to $domain successful"
    else
        echo "$domain is not responding"

        # Run traceroute ICMP
        echo "Running traceroute ICMP for $domain"
        traceroute "$domain"

        # Run traceroute UDP
        echo "Running traceroute UDP for $domain"
        traceroute -U "$domain"
    fi
done < "$file"

sudo rm -rf /var/tmp/domains.txt
sudo rm -rf /var/tmp/ping_traceroute.sh
