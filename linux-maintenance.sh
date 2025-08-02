#!/bin/bash

# ==============================================================================
# All-in-One System Maintenance Setup Script (Corrected Version)
#
# This script configures, creates, schedules, and runs a weekly maintenance task.
# ==============================================================================

# --- Step 1: Initial System Update ---
echo "Performing initial system update and cleanup..."
# Corrected 'autoremove' typo
sudo apt update && sudo apt full-upgrade -y && sudo apt autoclean && sudo apt autoremove -y
echo "Initial update complete."
echo ""


# --- Step 2: Create Necessary Directories ---
mkdir -p /home/$USER/scripts


# --- Step 3: Interactive Configuration ---
CONFIG_FILE="/home/$USER/scripts/maintenance_config.conf"
SCRIPT_FILE="/home/$USER/scripts/update_and_upgrade.sh"

echo "--- Configuring ntfy Maintenance Notifications ---"

read -p "Enter your ntfy server URL [default: https://ntfy.sh]: " NTFY_SERVER
NTFY_SERVER=${NTFY_SERVER:-https://ntfy.sh}

while [ -z "$NTFY_TOPIC" ]; do
    read -p "Enter your secret ntfy topic name: " NTFY_TOPIC
done

while true; do
    read -p "Send a notification when the script starts? (y/n) [default: y]: " yn
    yn=${yn:-y}
    case $yn in
        [Yy]* ) SEND_START="yes"; break;;
        [Nn]* ) SEND_START="no"; break;;
        * ) echo "Please answer yes or no.";;
    esac
done

while true; do
    read -p "Send a notification when the script finishes successfully? (y/n) [default: y]: " yn
    yn=${yn:-y}
    case $yn in
        [Yy]* ) SEND_SUCCESS="yes"; break;;
        [Nn]* ) SEND_SUCCESS="no"; break;;
        * ) echo "Please answer yes or no.";;
    esac
done


# --- Step 4: Write the Configuration File ---
echo "# --- Maintenance Script Configuration ---" > "$CONFIG_FILE"
echo "NTFY_SERVER=\"$NTFY_SERVER\"" >> "$CONFIG_FILE"
echo "NTFY_TOPIC=\"$NTFY_TOPIC\"" >> "$CONFIG_FILE"
echo "SEND_START_NOTIFICATION=\"$SEND_START\"" >> "$CONFIG_FILE"
echo "SEND_SUCCESS_NOTIFICATION=\"$SEND_SUCCESS\"" >> "$CONFIG_FILE"

echo ""
echo "Configuration saved successfully to $CONFIG_FILE!"


# --- Step 5: Create the Main Maintenance Script ---
cat << 'EOF' > "$SCRIPT_FILE"
#!/bin/bash
# ==============================================================================
# Weekly System Maintenance Script
# ==============================================================================

# --- Configuration ---
CONFIG_FILE="/home/$USER/scripts/maintenance_config.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    logger "CRITICAL: Maintenance script could not find its config file."
    exit 1
fi

# --- Helper Function for Notifications ---
notify() {
    local TITLE=$1
    local MESSAGE=$2
    local PRIORITY=${3:-default}
    local TAGS=${4:-package}

    curl -s \
      -H "Title: $TITLE" \
      -H "Priority: $PRIORITY" \
      -H "Tags: $TAGS" \
      -d "$MESSAGE" \
      "$NTFY_SERVER/$NTFY_TOPIC"
}

# --- Main Logic ---
HOSTNAME=$(hostname)

if [ "$SEND_START_NOTIFICATION" = "yes" ]; then
    notify "Maintenance Started" "Starting weekly maintenance run on $HOSTNAME." "low"
fi

# 1. Update and Upgrade System
UPGRADE_OUTPUT=$(sudo apt update && sudo apt full-upgrade -y 2>&1)
if [ $? -ne 0 ]; then
    notify "Maintenance FAILED: APT Upgrade" "APT update/upgrade failed on $HOSTNAME.

Error details:
$UPGRADE_OUTPUT" "high" "warning"
    exit 1
fi

# 2. Clean Up Old Kernels
PURGE_OUTPUT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e "$(uname -r | cut -f1,2 -d"-")" | grep -e "[0-9]" | xargs sudo apt-get -y purge 2>&1)
if [ $? -ne 0 ]; then
    notify "Maintenance FAILED: Kernel Purge" "Failed to purge old kernels on $HOSTNAME.

Error details:
$PURGE_OUTPUT" "high" "warning"
    exit 1
fi

# 3. Clean Up Apt Packages
sudo apt clean > /dev/null 2>&1
sudo apt autoclean > /dev/null 2>&1
sudo apt autoremove -y > /dev/null 2>&1

# 4. Manage System Logs
sudo journalctl --vacuum-size=500M > /dev/null 2>&1
# Corrected and safer find command to avoid warnings
sudo find /var/log -type f -not -path "/var/log/journal/*" -mtime +60 -delete

# 5. Send Success Notification
if [ "$SEND_SUCCESS_NOTIFICATION" = "yes" ]; then
    notify "Maintenance Complete" "Weekly maintenance for $HOSTNAME finished successfully." "default" "tada"
fi

exit 0
EOF


# --- Step 6: Finalize Permissions and Scheduling ---
chmod +x "$SCRIPT_FILE"

if ! crontab -l -u $USER | grep -q "$SCRIPT_FILE"; then
    echo "Adding new cron job to run every Sunday at 2 AM..."
    (crontab -l -u $USER 2>/dev/null; echo "0 2 * * 7 $SCRIPT_FILE") | crontab -u $USER -
    echo "Cron job created."
else
    echo "Cron job already exists."
fi


# --- Step 7: Optional First Run ---
echo ""
read -p "Setup is complete. Do you want to run the maintenance script now? (y/n) [default: y]: " run_now
run_now=${run_now:-y}
if [[ "$run_now" == "y" ]]; then
    echo "Running maintenance script for the first time..."
    # Corrected to run the script with bash
    bash "$SCRIPT_FILE"
fi

echo "All done."
