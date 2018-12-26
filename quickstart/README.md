# Azure Networking Lab- Routing Traffic to Linux for Packet Capture

This lab guide builds a very basic Azure environment for routing traffic to a Linux VM for Tcpdump packet captures. Turning up Linux VMs with Tcpdump can be used to quickly troubleshoot Azure routing, NSGs, security policies etc at different segments of the network. The lab is built with Azure CLI through Cloud Shell.

Assumptions:
-	A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Azure Cloud Shell Access.
- Basic Azure networking understanding

The labs builds:
-	VNET and subnet
-	2 Linux VMs in an Availability Set with necessary NICs with IP forwarding enabled in Azure
-	Route table + association sending traffic destin to 8.8.8.8/32 to the Linux VM for packet capture

**Base Topology**
- 2 Linux VMs in the same subnet. 
- HubVM1 will serve as the Linux VM we will route traffic to for capturing. 
- HubVM1=10.0.0.10, HubVM2=10.0.0.11
 

**Build Resource Group, VNET, Subnets, VMs and route table in West. Azure CLI in Cloud Shell is used.**
<pre lang="...">
az group create --name Hub --location westus
az network vnet create --resource-group Hub --name Hub --location westus --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.0.0/24

az vm availability-set create --resource-group Hub --name myAvailabilitySet --platform-fault-domain-count 2 --platform-update-domain-count 2

az network public-ip create --name VM1PubIP --resource-group Hub --location westus --allocation-method Dynamic
az network nic create --resource-group Hub -n HubVM1NIC --location westus --subnet HubVM --private-ip-address 10.0.0.10 --vnet-name Hub --public-ip-address VM1PubIP --ip-forwarding true
az vm create -n HubVM1 -g Hub --availability-set myAvailabilitySet --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVM1NIC

az network public-ip create --name VM2PubIP --resource-group Hub --location westus --allocation-method Dynamic
az network nic create --resource-group Hub -n HubVM2NIC --location westus --subnet HubVM --private-ip-address 10.0.0.11 --vnet-name Hub --public-ip-address VM2PubIP --ip-forwarding true
az vm create -n HubVM2 -g Hub --availability-set myAvailabilitySet --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVM2NIC

az network route-table create --name test --resource-group Hub 
az network route-table route create --name test --resource-group Hub --route-table-name test --address-prefix 8.8.8.8/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.0.10
az network vnet subnet update --name HubVM --vnet-name Hub --resource-group Hub --route-table test
</pre>

**Connect to HubVM1, set SUDO password, enable IP forwarding:**<br/>
#SSH to HubVM1 public IP address#<br/>
#Set SUDO password#<br/>
azureuser@HubVM1:~$ sudo passwd root<br/>
Enter new UNIX password:<br/>
Retype new UNIX password:<br/>
passwd: password updated successfully<br/>

**Enable IP forwarding in Linux OS**<br/>
azureuser@HubVM1:~$ sudo sysctl -w net.ipv4.ip_forward=1<br/>

**Start ping and Tcpdump**<br/>
Source ping from 10.0.0.11 to 8.8.8.8<br/>

**Enable Tcpdump on HubVM1**<br/>
sudo tcpdump -i eth0 src 10.0.0.11<br/>

**HubVM2 should be receiving ICMP redirects:**<br/>
azureuser@HubVM2:~$ ping 8.8.8.8<br/>
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.<br/>
From 10.0.0.10: icmp_seq=1 Redirect Host(New nexthop: 10.0.0.1)<br/>
From 10.0.0.10 icmp_seq=2 Time to live exceeded<br/>
From 10.0.0.10 icmp_seq=3 Time to live exceeded<br/>
From 10.0.0.10 icmp_seq=4 Time to live exceeded<br/>

**HubVM1 Tcpdump sample output:**
azureuser@HubVM1:~$ sudo tcpdump -i eth0 src 10.0.0.11<br/>
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode<br/>
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes<br/>
16:05:47.681407 IP 10.0.0.11 > google-public-dns-a.google.com: ICMP echo request, id 2733, seq 100, length 64<br/>
16:05:47.681410 IP 10.0.0.11 > google-public-dns-a.google.com: ICMP echo request, id 2733, seq 100, length 64<br/>
16:05:47.682569 IP 10.0.0.11 > google-public-dns-a.google.com: ICMP echo request, id 2733, seq 100, length 64<br/>
16:05:47.682582 IP 10.0.0.11 > google-public-dns-a.google.com: ICMP echo request, id 2733, seq 100, length 64<br/>
16:05:47.682734 IP 10.0.0.11 > google-public-dns-a.google.com: ICMP echo request, id 2733, seq 100, length 64<br/>



