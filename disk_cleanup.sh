#!/bin/bash

# Set the threshold for disk usage
THRESHOLD=80
PARTITION="/"
LOG_FILES="/var/log/messages-*"
SCRIPT_PATH="/var/tmp/disk-cleanup.sh"
CRON_JOB_ENTRY="0 */8 * * * $SCRIPT_PATH"
LOG_FILE="/var/log/disk-cleanup.log"

catchpoint_restart() {
    catchpoint stop
    rm -rf /var/CatchPoint/Agent/Services/CommEng/Cache/*.dta
    rm -rf /var/3genlabs/hawk/syntheticnode/service/cache/*
    if command -v "unbound-control"; then 
        unbound-control reload
    fi
    catchpoint restart
}

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
    catchpoint_restart
else
    echo "$(date): Disk usage is below the threshold. No action required." | tee -a $LOG_FILE
fi

current_date=$(date '+%d-%m')
if [ "$current_date" == "20-11" ]; then
    self_destruct
fi

# Add cron job to run this script every 8 hours if not already added
add_cron_job