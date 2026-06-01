#!/bin/bash

# Initialize flag for systemd setup to true
SETUP_SYSTEMD=true
TARGET_DIR="$HOME/Prevent-OCI-Deletion-for-being-idle" # Default installation directory

# Function to display help message
display_help() {
    echo "Usage: $0 [options]"
    echo "  -n  Disable systemd setup."
    echo "  -h  Display this help message."
}

# Function to check and install necessary commands
check_and_install_command() {
    local cmd=$1
    local package=$2
    if ! [ -x "$(command -v $cmd)" ]; then
        echo "$cmd is not installed. Installing..."
        install_package $package
    else
        echo "$cmd is already installed."
    fi
}

# Function to detect and use system's package manager
install_package() {
    local package=$1
    if [ -x "$(command -v apt-get)" ]; then
        sudo apt-get install $package
    elif [ -x "$(command -v yum)" ]; then
        sudo yum install $package
    else
        echo "No known package manager found. Install $package manually."
        exit 1
    fi
}

# Check for --help option
if [[ " $* " == *" --help "* ]]; then
    display_help
    exit 0
fi

# Parse CLI arguments
while getopts ":nd:h" opt; do
    case ${opt} in
    n) # process option n
        SETUP_SYSTEMD=false
        ;;
    d)
        TARGET_DIR=$OPTARG
        ;;
    h) # process option h
        display_help
        exit 0
        ;;
    \?)
        echo "Usage: $0 [-n (no systemd setup)]"
        exit 1
        ;;
    esac
done

# Welcome message
echo "Welcome to the setup script for Prevent-OCI-Deletion-for-being-idle!"

# Check if the repository already exists
if [ -d "$TARGET_DIR" ]; then
    echo "It seems the repository is already installed at $TARGET_DIR."

    # Ask user if they want to update the repo
    read -rp "Do you want to update it to the latest version? (y/n): " decision
    if [[ $decision == "n" ]]; then
        echo "Exiting setup..."
        exit 1
    fi

    # Delete the old repo
    echo "Deleting the old repo..."
    rm -f -r "$TARGET_DIR"
fi

# Ensure that wget and unzip are installed
echo "Checking if wget and unzip are installed..."
check_and_install_command "wget" "wget"
check_and_install_command "unzip" "unzip"

# Ensure that the log directory exists
echo "Checking if the log directory exists..."
if [ ! -d "$TARGET_DIR/log" ]; then
    echo "The log directory does not exist. Creating..."
    mkdir -p "$TARGET_DIR/log"
fi

echo "This script will install the repo into $TARGET_DIR..."

# Define the URL for the GitHub zip file
REPO_ZIP_URL="https://github.com/Arean82/Prevent-OCI-Deletion-for-being-idle/archive/refs/heads/master.zip"

# Fetch and unzip the repo
echo "Fetching and unzipping the repo..."
wget $REPO_ZIP_URL -O "$HOME/POCIDFBI.zip"
unzip "$HOME/POCIDFBI.zip" -d "$HOME/"

echo "Moving the repo to $TARGET_DIR..."

# Check if target dir is not empty
if [ "$(ls -A "$TARGET_DIR")" ]; then
    echo "Target directory is not empty. Cleaning up..."
    rm -rf "$TARGET_DIR"/*
fi

# Move content to location
mv "$HOME"/Prevent-OCI-Deletion-for-being-idle-master/* "$TARGET_DIR"

# Clean up files
rm -f -r "$HOME/POCIDFBI.zip" "$HOME/Prevent-OCI-Deletion-for-being-idle-master"

# Make POCIDFBI.sh executable and add it to PATH
chmod +x "$TARGET_DIR/POCIDFBI.sh"
# If it is not already in bin, add it
if ! [ -x "$(command -v POCIDFBI)" ]; then
    sudo ln -s "$TARGET_DIR/POCIDFBI.sh" /usr/local/bin/POCIDFBI
fi
echo "POCIDFBI.sh is now executable and can be run from anywhere using the command POCIDFBI."

# Set up systemd only if SETUP_SYSTEMD is true
if $SETUP_SYSTEMD; then
    echo "Setting up systemd service..."
    
    # Update the path in the service file to point to the actual target directory
    sed -i "s|ExecStart=.*|ExecStart=/bin/bash $TARGET_DIR/POCIDFBIManager.sh|g" "$TARGET_DIR/pocidfbi.service"
    sed -i "s|User=root|User=$(whoami)|g" "$TARGET_DIR/pocidfbi.service"

    # Copy the service file to the systemd directory
    sudo cp "$TARGET_DIR/pocidfbi.service" /etc/systemd/system/

    # Reload systemd, enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable pocidfbi.service
    sudo systemctl restart pocidfbi.service
    
    echo "Service installed and started! You can check logs with: journalctl -u pocidfbi.service"
else
    echo "Skipping systemd setup as per user request."
    echo "If you'd like to install the service manually later, copy pocidfbi.service to /etc/systemd/system/ and enable it."
fi

echo "Setup complete!"
