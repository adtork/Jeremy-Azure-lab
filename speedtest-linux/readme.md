# Azure Networking Lab- quick speed test with and without a firewall in path (draft)

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

################
sudo apt-get install speedtest-cli
speedtest-cli --bytes 
speedtest-cli --list | less
10546) Sprint (New York, NY, United States) [419.17 km]
speedtest-cli --server 10546
##################
azureuser@speedtestVM:~$ speedtest-cli --server 10546
Retrieving speedtest.net configuration...
Testing from Microsoft Corporation (40.71.168.188)...
Retrieving speedtest.net server list...
Retrieving information for the selected server...
Hosted by Sprint (New York, NY) [419.17 km]: 18.964 ms
Testing download speed................................................................................
Download: 1261.96 Mbit/s
Testing upload speed......................................................................................................
Upload: 566.07 Mbit/s
azureuser@speedtestVM:~$
##################
Use portal to create an Azure firewall and allow everything outbound. Creating the firewall and rules are not shown.

################
