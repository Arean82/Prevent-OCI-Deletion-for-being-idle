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

# Function to calculate memory load
get_mem_load() {
    free | awk '/Mem:/ {if ($2 > 0) print int($3/$2 * 100.0); else print 0}'
}

# Function to check if network is idle
get_network_load() {
    local iface=$(ip route 2>/dev/null | awk '/^default/ {print $5}' | head -n1)
    if [ -z "$iface" ] || [ ! -e "/sys/class/net/$iface/statistics/rx_bytes" ]; then
        echo 0 # Default to 0 (idle) if we can't determine it
        return
    fi
    local rx1=$(cat /sys/class/net/$iface/statistics/rx_bytes)
    local tx1=$(cat /sys/class/net/$iface/statistics/tx_bytes)
    sleep 1
    local rx2=$(cat /sys/class/net/$iface/statistics/rx_bytes)
    local tx2=$(cat /sys/class/net/$iface/statistics/tx_bytes)
    
    local total_bps=$(( (rx2 - rx1) + (tx2 - tx1) ))
    # If bandwidth is less than ~10KB/s, consider it idle
    if [ "$total_bps" -lt 10240 ]; then
        echo 0
    else
        echo 100
    fi
}

# Function to log to stdout (systemd will capture this)
log() {
    local message="$1"
    local timestamp="$(date +"%Y-%m-%d %H:%M:%S")"
    if [ "$LOGGING_ENABLED" = true ]; then
        echo "[$timestamp] $message"
    fi
}

# Global array to track PIDs
WORKER_PIDS=()

# Function to cleanup when the script exits
exit_handler() {
    printf "\n"
    log "Killing tracked waste workers gracefully..."
    for pid in "${WORKER_PIDS[@]}"; do
        kill -9 "$pid" 2>/dev/null || true
    done

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
    WORKER_PIDS=()
    
    # Get current metrics
    currentCpuLoad=$(get_cpu_load)
    currentMemLoad=$(get_mem_load)
    currentNetLoad=$(get_network_load)

    log "Load metrics - CPU: $currentCpuLoad%, Mem: $currentMemLoad%, NetIdle: $([ "$currentNetLoad" -eq 0 ] && echo 'Yes' || echo 'No')"

    # if CPU load is below X%, spawn Y instances of WasteCPUWorker.sh
    if [ "$currentCpuLoad" -le "$CPU_THRESHOLD" ]; then 
        log "CPU Load below threshold. Spawning $WORKER_COUNT CPU workers..."
        for _ in $(seq 1 "$WORKER_COUNT"); do
            /bin/bash "$SCRIPT_DIR/workers/WasteCPUWorker.sh" &
            WORKER_PIDS+=($!)
        done
    fi

    # Trigger Memory worker if memory load is <= 20%
    if [ "$currentMemLoad" -le 20 ]; then
        log "Memory Load below threshold. Spawning Memory worker..."
        /bin/bash "$SCRIPT_DIR/workers/WasteMemoryWorker.sh" &
        WORKER_PIDS+=($!)
    fi

    # Trigger Network worker if network is idle
    if [ "$currentNetLoad" -eq 0 ]; then
        log "Network is idle. Spawning Network worker..."
        /bin/bash "$SCRIPT_DIR/workers/WasteNetworkWorker.sh" &
        WORKER_PIDS+=($!)
    fi

    # Wait for tracked workers
    if [ ${#WORKER_PIDS[@]} -gt 0 ]; then
        wait "${WORKER_PIDS[@]}" 2>/dev/null
        log "Completed running waste workers."
    fi

    sleep "$DURATION_BETWEEN_CHECKS"
done
