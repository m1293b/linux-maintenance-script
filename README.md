# Automated Linux Maintenance Script with ntfy Notifications

A comprehensive, all-in-one Bash script to set up automated weekly maintenance for Debian-based Linux systems (like Debian, Ubuntu, etc.).

This tool configures, creates, schedules, and runs a weekly task that keeps your system updated, removes old files, and sends detailed status notifications to your phone or desktop via [ntfy](https://ntfy.sh/).

---

## Features

-   **Automated Updates:** Runs `apt update` and `apt full-upgrade` weekly.
-   **System Cleanup:** Safely purges old, unused Linux kernels to free up space.
-   **Package Cleaning:** Cleans the `apt` cache and removes orphaned dependencies.
-   **Smart Log Management:** Rotates and cleans system logs to prevent them from filling the disk, while keeping recent logs for troubleshooting.
-   **ntfy Notifications:** Sends detailed notifications on start, success, and—most importantly—on failure, including the specific error message.
-   **Interactive Setup:** A simple, one-time setup process to configure your notification preferences.
-   **Secure & Self-Contained:** Creates a separate configuration file for your private ntfy details and doesn't require any external dependencies besides `curl`.

---

## Quick Start & Usage

To run the setup script on a new machine, execute the following command in your terminal.

> **⚠️ Security Warning:** This command downloads and executes a script from the internet. You should only run this if you trust the source of the script. You can review the script's code by pasting the URL into your browser before running the command.

```bash
curl -sSL https://raw.githubusercontent.com/m1293b/linux-maintenance-script/refs/heads/main/linux-maintenance.sh | bash
