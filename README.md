# Prevent OCI Deletion for being idle

<div align="center">

[![Version](https://img.shields.io/github/v/release/Arean82/Prevent-OCI-Deletion-for-being-idle)](https://github.com/Arean82/Prevent-OCI-Deletion-for-being-idle/releases/)
[![Discord](https://img.shields.io/discord/1166016207816757248?color=7289da&label=Discord&logo=discord&logoColor=white)](https://discord.gg/HRNVF5Tf9a)
[![License](https://img.shields.io/github/license/Arean82/Prevent-OCI-Deletion-for-being-idle)](LICENSE)

</div>

The `Prevent-OCI-Deletion-for-being-idle` repository has been designed to help users maintain their Oracle Cloud Infrastructure (OCI) ForeverFree tier instances active, following Oracle's policy that could lead to the deletion of instances under certain conditions.

## Acknowledgment

This project has been improved upon and expanded from the original work found at [OCIScripts by Drag-NDrop](https://github.com/Drag-NDrop/OCIScripts). We express our gratitude to the original author for their initiative and groundwork.

While the current repository contains modifications, optimizations, and extensions to the original work, the foundational ideas and script mechanisms are attributed to the source mentioned above. We encourage users and contributors to refer to the original repository to understand the context and motivation that led to the inception of these scripts.

## Why This Script?

Oracle may delete your ForeverFree tier instance if, during a 7-day period, the following criteria are met:

* CPU utilization for the 95th percentile is less than 20%.
* Network utilization is less than 20%.
* Memory utilization is less than 20% (applies to [A1 shapes](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#Details_of_the_Always_Free_Compute_instance__a1_flex) only).

The purpose of these scripts is to ensure that the instance remains within Oracle's usage guidelines without manual intervention. While this approach is practical, it is crucial to understand the ethical and environmental implications of such a strategy. We encourage users to only deploy this solution if absolutely necessary. Please make sure to check the [Oracle Cloud Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm#compute__idleinstances) page for the latest information on the ForeverFree tier policy.

## Scripts Description

1. **workers/WasteCPUWorker.sh** - This is the CPU "waster" script, designed to produce computational work via hashing.
2. **workers/WasteMemoryWorker.sh** - This script consumes memory via Python to keep A1 instances active.
3. **workers/WasteNetworkWorker.sh** - This script downloads dummy data to `/dev/null` to generate active network traffic.
4. **POCIDFBIManager.sh** - This script acts as the "manager" running as a systemd service. It monitors the CPU usage and spawns instances of the worker scripts if usage falls below a threshold.
5. **POCIDFBI.sh** - This script is used to configure the manager script. It will prompt you for the desired worker count and CPU threshold, and then update the `config.conf` file and restart the systemd service.

## Configuration

Before you set up and run the scripts, you may want to configure the worker count and CPU threshold to fit your needs. There are two primary ways to configure these parameters:

### 1. Command Line Interface (CLI)

You can directly pass these values when running the manager script (`POCIDFBIManager.sh`) using the `-w`, `-n` and `-c` options.

```bash
./POCIDFBIManager.sh -w [WORKER_COUNT] -c [CPU_THRESHOLD] -n -d [DURATION_BETWEEN_CHECKS]
```

Replace `[WORKER_COUNT]` with the desired number of worker instances and `[CPU_THRESHOLD]` with the desired CPU usage threshold (as a percentage) below which the worker script should be invoked. `-n` is a flag used to disable logging, when applied disables logging to a file. `-d` is a flag used to set the duration between checks, the default is 10 seconds.

**Example**:

```bash
./POCIDFBIManager.sh -w 5 -c 20 -n -d 10
```

This command runs the manager script with a worker count of 5 and a CPU threshold of 20% (i.e., if CPU usage falls below 20%, the worker script will be invoked). The worker script used is `WasteCPUWorker.sh`. The `-n` flag disables logging, and the `-d` flag sets the duration between checks to 10 seconds.

### 2. Configuration File (`config.conf`)

Alternatively, you can use the provided `config.conf` file to set default values for the worker count and CPU threshold. This approach is beneficial if you don't want to provide these values every time you run the script.

Open `config.conf` in your favorite text editor:

```bash
nano config.conf
```

And then set your desired values:

```bash
WORKER_COUNT=5
CPU_THRESHOLD=20
LOGGING_ENABLED=true
DURATION_BETWEEN_CHECKS=10
```

Save the file and exit the editor. Now, when you run the manager script without CLI arguments, it will use these values from `config.conf`. An important thing to note, is that once the manager is started it will only grab the settings once. If you change the settings in `config.conf` you will need to restart the manager script.

### 3. Configuration Script (`POCIDFBI.sh`)

You can also use the provided `POCIDFBI.sh` script to set default values for the worker count and CPU threshold. This approach is beneficial if you don't want to provide these values every time you run the script.

All you need to do is run the script and follow the prompts:

```bash
./POCIDFBI.sh
```

Once you have set your desired values, the script will create/update the `config.conf` file and set the values for you. An important thing to note, this script will terminate the manager script if it is running. You will need to restart the manager script after running this script if it wasn't being spawned by `crontab`.

## Setup & Usage

1. Clone the repository:

   ```bash
   git clone https://github.com/Arean82/Prevent-OCI-Deletion-for-being-idle
   ```

2. Navigate to the repository directory:

   ```bash
   cd Prevent-OCI-Deletion-for-being-idle
   ```

3. Ensure the scripts have execute permissions:

   ```bash
   chmod +x *.sh
   ```

4. Add execute permissions to the worker scripts:

   ```bash
   chmod +x workers/*.sh
   ```

5. Install and enable the systemd service (Alternatively, run `install.sh` to automate this):

   ```bash
   sudo cp pocidfbi.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable pocidfbi.service
   sudo systemctl start pocidfbi.service
   ```

## Automated Setup

For a quick and easy setup, you can run the following one-liner which fetches the `install.sh` script from the repository and executes it:

```bash
curl -fsSL https://raw.githubusercontent.com/Arean82/Prevent-OCI-Deletion-for-being-idle/master/install.sh | bash
```

Upon running the above command, the script will be set up as a systemd service. You can verify this by checking the service status:

```bash
sudo systemctl status pocidfbi.service
```

## Why and How of the Script Strategy

**1. Why Use the Worker Scripts?**

The `WasteCPUWorker.sh` script generates computational work by calculating a SHA256 hash stream for 5 seconds. `WasteMemoryWorker.sh` allocates a 50MB string in memory. `WasteNetworkWorker.sh` downloads dummy data to `/dev/null`. This combined activity satisfies Oracle's metrics without having any lasting effect on storage.

**2. Why Monitor with `POCIDFBIManager.sh`?**

Instead of blindly running the waster scripts continuously, the `POCIDFBIManager.sh` script runs as a lightweight `systemd` background service, checking the current CPU workload and deciding whether to activate the waste worker scripts only when the server is idle.

## Modifying the Manager Script

To control the CPU usage, you might want to adjust the manager script. Here's a breakdown of its logic and where you can make modifications:

* **Threshold of Activation**:
  The line

  ```bash
  if [ "$currentCpuLoad" -le "$CPU_THRESHOLD" ]
  ```

  determines when to activate the CPU waster script. Here, it activates if CPU load is less than or equal to 20% (the default value). You can change this value to suit your needs. Via the CLI, you can use the `-c` option to set this value. If you are using the configuration file, you can set the `CPU_THRESHOLD` variable to your desired value.

* **Measuring CPU Load**:
  The line

  ```bash
  currentCpuLoad=$[100-$(vmstat 1 2|tail -1|awk '{print $15}')]
  ```

  uses `vmstat` to get system statistics. The value derived represents the CPU idle time, which is then subtracted from 100 to get the actual CPU load. If you are familiar with other system monitoring tools or commands and wish to use them, you can replace this line with an appropriate command that returns the current CPU load.

* **Logging Information**:
  Logging is automatically handled by `systemd`. You can view the logs cleanly using:
  
  ```bash
  journalctl -u pocidfbi.service -f
  ```

## Troubleshooting: Stopping Rogue Script Instances

If you wish to stop the application, you should stop the `systemd` service:

```bash
sudo systemctl stop pocidfbi.service
```

If you wish to disable it from starting on boot:

```bash
sudo systemctl disable pocidfbi.service
```

### Terminating the Scripts

In rare cases where child worker scripts get stuck, you can terminate them directly:

```bash
pkill -f WasteCPUWorker.sh
pkill -f WasteMemoryWorker.sh
pkill -f WasteNetworkWorker.sh
```

### Monitoring

Once you've ensured that the unwanted processes are terminated:

* **Monitor the system's CPU usage** with tools such as `top` or `htop` to confirm that CPU utilization is back to normal.

> **Caution**: Always exercise caution when using the `kill` command, especially with the `-9` option. It forcibly terminates processes and can inadvertently affect essential system processes if misused.

These scripts have been specifically designed and tested on **Ubuntu 22.04** and **Ubuntu 24.04** instances. Before using them, ensure you are running a supported instance.

If you are interested in adapting these scripts for other operating systems, distributions, or different Ubuntu versions, you might need to adjust command syntax, package management commands, and potentially other system-specific details.

## Tips

* If you are uncertain about the effect of changes you make, test them in a controlled environment before deploying them on your main instance.
  
* It's a good practice to keep an eye on the system's behavior after making adjustments to ensure it behaves as expected. Tools like `top` or `htop` can be valuable in real-time monitoring.

## Notes

* Adjust the frequency in the crontab entry as per your requirements.
* Monitor your instance's resource usage regularly to ensure it remains within desired parameters.
* Understand that this approach, while effective, can be resource-intensive. Ensure you are within the ethical bounds of Oracle's policy and terms of service.

## Disclaimer

The code and scripts provided in this repository are the independent work of Arean82 (originally Codycody31).

Users are responsible for understanding the implications and ensuring that their use of these scripts aligns with Oracle's terms of service, as well as other ethical and legal considerations. Always exercise caution and discretion when using third-party scripts, and seek appropriate legal counsel if unsure.
