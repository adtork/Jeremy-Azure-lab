# Azure Networking Lab- quick speed test with and without a firewall in path 

This lab guide illustrates how to build a simple environment with Linux host and a speed test tool. We will test outbound Internet connectivity to a few different geo diverse location with and without a firewall. The lab uses an Azure firewall but can be used with other devices. Obviously there are a number of performance testing tools and this is purely an example. Azure CLI is used so you can easily manipulate the configs to fit your environment. This is for testing purposes only.

Assumptions:
- A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Latest Azure CLI, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 

# Base Topology
The lab deploys a basic VNET with 1 subnet and an Ubuntu server. We will use the default Azure Internet path to establish a baseline. An Azure firewall will be added and the default route for the Linux VM will point to the new firewall. 

**Build Resource Groups, VNETs and Subnets**
<pre lang="...">
az group create --name speedtest --location eastus
az network vnet create --resource-group speedtest --name speedtest --location eastus --address-prefixes 10.0.0.0/16 --subnet-name speedtestVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name AzureFirewallSubnet --resource-group speedtest --vnet-name speedtest
</pre>

**Build Linux VM**
<pre lang="...">
az network public-ip create --name speedtestVMPubIP --resource-group speedtest --location eastus --allocation-method Dynamic
az network nic create --resource-group speedtest -n speedtestVMNIC --location eastus --subnet speedtestVM --private-ip-address 10.0.10.10 --vnet-name speedtest --public-ip-address speedtestVMPubIP
az vm create -n speedtestVM -g speedtest --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics speedtestVMNIC
</pre>

**SSH to Linux VM and install speedtest**</br>
sudo apt-get install speedtest-cli</br>

**Basic speedtest from Linux**</br>
speedtest-cli --bytes 

**Speedtest provides a number of destination servers. Get a list of servers available:**</br>
speedtest-cli --list | less

**Specify a server. EX: Sprint in NYC**</br>
(10546) Sprint (New York, NY, United States) [419.17 km]</br>
</br>
speedtest-cli --server 10546

**Sample results without firewall (results will vary based on a number of variables):**
<pre lang="...">
azureuser@speedtestVM:~$ speedtest-cli --server 10546
Retrieving speedtest.net configuration...
Testing from Microsoft Corporation (40.71.168.188)...
Retrieving speedtest.net server list...
Retrieving information for the selected server...
Hosted by Sprint (New York, NY) [419.17 km]: 6.622 ms
Testing download speed................................................................................
Download: 1178.10 Mbit/s
Testing upload speed......................................................................................................
Upload: 562.83 Mbit/s
azureuser@speedtestVM:~$
</pre>

**Sample results with firewall (results will vary based on a number of variables):**
<pre lang="...">
azureuser@speedtestVM:~$ speedtest-cli --server 10546
Retrieving speedtest.net configuration...
Testing from Microsoft Corporation (20.185.102.173)...
Retrieving speedtest.net server list...
Retrieving information for the selected server...
Hosted by Sprint (New York, NY) [419.17 km]: 8.084 ms
Testing download speed................................................................................
Download: 1080.35 Mbit/s
Testing upload speed......................................................................................................
Upload: 271.21 Mbit/s
azureuser@speedtestVM:~$
</pre>

**Use portal to create an Azure firewall and allow everything outbound. Creating the firewall and rules are not shown.
</br>

**Steer traffic through Azure firewall**

- Locate AZ FW IP
- Change default route to az firewall. Note- all traffic will go through the firewall and SSH will break if you are accessing the VM from the Internet. 
- Example: If you're working from home, locate your public IP (ip chicken) and put a /32 for your IP in the route table with next hop Internet. 

<pre lang="...">
az network route-table create --name vm-rt --resource-group speedtest
az network route-table route create --name vm-rt --resource-group speedtest --route-table-name vm-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.0.4
az network vnet subnet update --name speedtestVM --vnet-name speedtest --resource-group speedtest --route-table vm-rt
</pre>

**Speedtest has other hooks available:**
<pre lang="...">
azureuser@speedtestVM:~$ speedtest-cli -h
usage: speedtest-cli [-h] [--no-download] [--no-upload] [--bytes] [--share]
                     [--simple] [--csv] [--csv-delimiter CSV_DELIMITER]
                     [--csv-header] [--json] [--list] [--server SERVER]
                     [--exclude EXCLUDE] [--mini MINI] [--source SOURCE]
                     [--timeout TIMEOUT] [--secure] [--no-pre-allocate]
                     [--version]

Command line interface for testing internet bandwidth using speedtest.net.
--------------------------------------------------------------------------
https://github.com/sivel/speedtest-cli

optional arguments:
  -h, --help            show this help message and exit
  --no-download         Do not perform download test
  --no-upload           Do not perform upload test
  --bytes               Display values in bytes instead of bits. Does not
                        affect the image generated by --share, nor output from
                        --json or --csv
  --share               Generate and provide a URL to the speedtest.net share
                        results image, not displayed with --csv
  --simple              Suppress verbose output, only show basic information
  --csv                 Suppress verbose output, only show basic information
                        in CSV format. Speeds listed in bit/s and not affected
                        by --bytes
  --csv-delimiter CSV_DELIMITER
                        Single character delimiter to use in CSV output.
                        Default ","
  --csv-header          Print CSV headers
  --json                Suppress verbose output, only show basic information
                        in JSON format. Speeds listed in bit/s and not
                        affected by --bytes
  --list                Display a list of speedtest.net servers sorted by
                        distance
  --server SERVER       Specify a server ID to test against. Can be supplied
                        multiple times
  --exclude EXCLUDE     Exclude a server from selection. Can be supplied
                        multiple times
  --mini MINI           URL of the Speedtest Mini server
  --source SOURCE       Source IP address to bind to
  --timeout TIMEOUT     HTTP timeout in seconds. Default 10
  --secure              Use HTTPS instead of HTTP when communicating with
                        speedtest.net operated servers
  --no-pre-allocate     Do not pre allocate upload data. Pre allocation is
                        enabled by default to improve upload performance. To
                        support systems with insufficient memory, use this
                        option to avoid a MemoryError
  --version             Show the version number and exit
azureuser@speedtestVM:~$
</pre>
