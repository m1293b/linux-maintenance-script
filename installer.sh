#!/bin/bash

# --- Universal Installer Script ---
# This script safely downloads, fixes, and executes the main script.

# Exit immediately if any command fails
set -e

echo "--- Preparing Maintenance Script ---"

# Install sudo if it hasn't been installed

apt install sudo -y

# Define the URL for the main script on GitHub
MAIN_SCRIPT_URL="https://raw.githubusercontent.com/m1293b/linux-maintenance-script/refs/heads/main/linux-maintenance.sh"

# Define where to save the script temporarily
TEMP_SCRIPT_PATH="./tmp_main_maintenance_script.sh"

# Check for required tools (curl, dos2unix) and install if missing
echo "Checking for necessary tools..."
if ! command -v curl &> /dev/null; then
    echo "curl not found. Installing..."
    sudo apt-get update && sudo apt-get install -y curl
fi
if ! command -v dos2unix &> /dev/null; then
    echo "dos2unix not found. Installing..."
    sudo apt-get update && sudo apt-get install -y dos2unix
fi

# Download the main script
echo "Downloading main script from GitHub..."
curl -sSL "$MAIN_SCRIPT_URL" -o "$TEMP_SCRIPT_PATH"

# Fix line endings (this is the crucial step)
echo "Fixing script formatting..."
dos2unix "$TEMP_SCRIPT_PATH"

# Make the main script executable
chmod +x "$TEMP_SCRIPT_PATH"

# Execute the now-clean main script
echo "Executing main setup script..."
echo ""
bash "$TEMP_SCRIPT_PATH"

# Clean up the temporary file
rm "$TEMP_SCRIPT_PATH"

echo "Installation script finished."
