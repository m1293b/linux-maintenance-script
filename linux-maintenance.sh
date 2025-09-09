#!/bin/bash
# ==============================================================================
# All-in-One System Maintenance Setup Script
#
# This script is designed to be run directly via curl:
# curl -sSL <URL> | bash
# ==============================================================================

# --- Step 1: Create Necessary Directories ---
mkdir -p /home/$USER/scripts

# --- Step 2: Interactive Configuration ---
# This entire block has its input redirected from /dev/tty (the keyboard)
# to ensure it works correctly when piped from curl.
{
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
} < /dev/tty


# --- Step 3: Write the Configuration File ---
echo "# --- Maintenance Script Configuration ---" > "$CONFIG_FILE"
echo "NTFY_SERVER=\"$NTFY_SERVER\"" >> "$CONFIG_FILE"
echo "NTFY_TOPIC=\"$NTFY_TOPIC\"" >> "$CONFIG_FILE"
echo "SEND_START_NOTIFICATION=\"$SEND_START\"" >> "$CONFIG_FILE"
echo "SEND_SUCCESS_NOTIFICATION=\"$SEND_SUCCESS\"" >> "$CONFIG_FILE"

echo ""
echo "Configuration saved successfully to $CONFIG_FILE!"


# --- Step 4: Create the Main Maintenance Script ---
cat << 'EOF' > "$SCRIPT_FILE"
#!/bin/bash
# ==============================================================================
# Weekly System Maintenance Script
# ==============================================================================
CONFIG_FILE="/home/$USER/scripts/maintenance_config.conf"
if [ -f "$CONFIG_FILE" ]; then source "$CONFIG_FILE"; else logger "CRITICAL: Maintenance script could not find its config file."; exit 1; fi
notify() { local TITLE=$1; local MESSAGE=$2; local PRIORITY=${3:-default}; local TAGS=${4:-package}; curl -s -H "Title: $TITLE" -H "Priority: $PRIORITY" -H "Tags: $TAGS" -d "$MESSAGE" "$NTFY_SERVER/$NTFY_TOPIC"; }
HOSTNAME=$(hostname)
if [ "$SEND_START_NOTIFICATION" = "yes" ]; then notify "Maintenance Started" "Starting weekly maintenance run on $HOSTNAME." "low"; fi
UPGRADE_OUTPUT=$(sudo apt update && sudo apt full-upgrade -y 2>&1)
if [ $? -ne 0 ]; then notify "Maintenance FAILED: APT Upgrade" "APT update/upgrade failed on $HOSTNAME.

Error details:
$UPGRADE_OUTPUT" "high" "warning"; exit 1; fi
PURGE_OUTPUT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e "$(uname -r | cut -f1,2 -d"-")" | grep -e "[0-9]" | xargs sudo apt-get -y purge 2>&1)
if [ $? -ne 0 ]; then notify "Maintenance FAILED: Kernel Purge" "Failed to purge old kernels on $HOSTNAME.

Error details:
$PURGE_OUTPUT" "high" "warning"; exit 1; fi
sudo apt clean > /dev/null 2>&1
sudo apt autoclean > /dev/null 2>&1
sudo apt autoremove -y > /dev/null 2>&1
sudo journalctl --vacuum-size=500M > /dev/null 2>&1
sudo find /var/log -type f -not -path "/var/log/journal/*" -mtime +60 -delete
if [ "$SEND_SUCCESS_NOTIFICATION" = "yes" ]; then notify "$HOSTNAME - Maintenance Complete" "Weekly maintenance has finished successfully." "default" "tada"; fi
exit 0
EOF


# --- Step 5: Finalize Permissions and Scheduling ---
chmod +x "$SCRIPT_FILE"

if ! crontab -l -u $USER | grep -q "$SCRIPT_FILE"; then
    echo "Adding new cron job to run every Sunday at 2 AM..."
    (crontab -l -u $USER 2>/dev/null; echo "0 2 * * 7 $SCRIPT_FILE") | crontab -u $USER -
    echo "Cron job created."
else
    echo "Cron job already exists."
fi


# --- Step 6: Optional First Run ---
echo ""
# This final read command also needs its input redirected from the keyboard
read -p "Setup is complete. Do you want to run the maintenance script now? (y/n) [default: y]: " run_now < /dev/tty
run_now=${run_now:-y}

if [[ "$run_now" == "y" ]]; then
    echo "Running maintenance script for the first time..."
    bash "$SCRIPT_FILE"
fi

echo "All done."
