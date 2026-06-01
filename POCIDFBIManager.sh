#!/bin/bash

# Get the directory of the script itself
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Default values
WORKER_COUNT=5
CPU_THRESHOLD=20
LOGGING_ENABLED=true
DURATION_BETWEEN_CHECKS=10 # In seconds

# Configuration file path
CONFIG_FILE="$SCRIPT_DIR/config.conf"

# Read from configuration file if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Function to validate if the provided input is a number
is_number() {
    local num="$1"
    # Use regex to check if the input is a number
    [[ $num =~ ^[0-9]+$ ]]
}

# Function to display help message
display_help() {
    echo "Usage: $0 [options]"
    echo "  -w  Set the worker count. (Default: $WORKER_COUNT)"
    echo "  -c  Set the CPU threshold. (Default: $CPU_THRESHOLD)"
    echo "  -n  Disable logging to the log file."
    echo "  -h  Display this help message."
}

# Check for --help option
if [[ " $* " == *" --help "* ]]; then
    display_help
    exit 0
fi

# Parse command-line arguments
while getopts ":w:c:d:nh" opt; do
    case $opt in
    w)
        if is_number "$OPTARG"; then
            WORKER_COUNT=$OPTARG
        else
            echo "Error: -w argument '$OPTARG' is not a valid number." >&2
            exit 1
        fi
        ;;
    c)
        if is_number "$OPTARG"; then
            CPU_THRESHOLD=$OPTARG
        else
            echo "Error: -c argument '$OPTARG' is not a valid number." >&2
            exit 1
        fi
        ;;
    d)
        if is_number "$OPTARG"; then
            DURATION_BETWEEN_CHECKS=$OPTARG
        else
            echo "Error: -d argument '$OPTARG' is not a valid number." >&2
            exit 1
        fi
        ;;
    n)
        LOGGING_ENABLED=false
        ;;
    h)
        display_help
        exit 0
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        exit 1
        ;;
    esac
done

# Function to calculate the current CPU load
get_cpu_load() {
    echo $((100 - $(vmstat 1 2 | tail -1 | awk '{print $15}')))
}

# Function to log to stdout (systemd will capture this)
log() {
    local message="$1"
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    if [ "$LOGGING_ENABLED" = true ]; then
        echo "[$timestamp] $message"
    fi
}

# Function to cleanup when the script exits
exit_handler() {
    printf "\n"
    # Kill all spawned waste workers
    log "Killing all spawned waste workers..."
    pkill -f WasteCPUWorker.sh
    pkill -f WasteMemoryWorker.sh
    pkill -f WasteNetworkWorker.sh

    # Log script exit
    log "Exiting POCIDFBIManager.sh at $(date)."
    exit 1
}

# Trap specific signals and run the exit_handler
trap exit_handler SIGINT SIGTERM

# Change directory to the script's directory
cd "$SCRIPT_DIR" || exit

# Log script startup
log "Starting POCIDFBIManager.sh at $(date). Monitoring CPU Load..."

# Log current configuration
log "Script will trigger when CPU load is below $CPU_THRESHOLD% and will spawn $WORKER_COUNT instances of cpu workers."

# Main loop
while true; do
    # Get current CPU load
    currentCpuLoad=$(get_cpu_load)
    log "Current CPU Load at $(date): $currentCpuLoad%"

    # if CPU load is below X%, spawn Y instances of WasteCPUWorker.sh
    if [ "$currentCpuLoad" -le "$CPU_THRESHOLD" ]; then # Adjusted the threshold to 20% for some buffer
        log "CPU Load below threshold at $(date). Spawning $WORKER_COUNT instances of waste workers..."

        # Spawn instances of the specified worker(s) concurrently
        for _ in $(seq 1 "$WORKER_COUNT"); do
            /bin/bash "$SCRIPT_DIR/workers/WasteCPUWorker.sh" &
        done
        
        # Spawn memory and network workers
        /bin/bash "$SCRIPT_DIR/workers/WasteMemoryWorker.sh" &
        /bin/bash "$SCRIPT_DIR/workers/WasteNetworkWorker.sh" &

        wait # Wait for all spawned scripts to complete

        log "Completed running waste workers at $(date)."
    else
        log "CPU Load is within acceptable range at $(date). No action taken."
    fi

    sleep "$DURATION_BETWEEN_CHECKS"
done
