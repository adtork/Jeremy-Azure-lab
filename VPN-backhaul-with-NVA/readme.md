# Optimized VNET Connectivity- Backhauling Geo Specific Sites Via Local S2S VPN With VNET Connectivity Across Azure's Backbone
This lab guide shows how to build a S2S VPN to the closest Azure region and leverage the Azure backbone to reach VNETs in a different region. The topology will build a customer managed hub/spoke in East US. There are a number of location in Europe that need S2S connectivity to reach resources in both spokes(also in East US). Instead of having each UK site build a tunnel across the traditional Internet, we will build a VPN hub in the UK West region. All locations in Europe (we only use 1 location in this lab) will VPN to a Cisco CSR in UK West, transit the Azure backbone to reach the hub in East US. All traffic from the simulated on prem to Spoke 1 or Spoke 2 will flow through by Azure firewall. Traffic initiated from Spoke1/2 will go through Azure firewall to reach on prem. By leveraging the local Azure region for connectivity, remote offices in Europe will have better performance compared to traditional Internet. This design also works if the customer has multiple customer managed hub/spokes already deployed. Since the tunnel is terminating on a 3rd party NVA, this is a great solution for other common features I see such as (assuming the vendor supports it):

- SD-WAN tunnel termination in the Europe VPN hub
- Per tunnel NAT including address overlap
- Per tunnel QOS
- Large scale tunnel termination and route tables
- Backhauling S2S connectivity for other cloud providers

Note- the entire lab uses Azure CLI. Please make sure you have the latest version and the firewall extension added. The firewall rules can be modified to be more restrictive as needed. There is a single jump VM (with a public ip) in Spoke1. The other 2 VMs (1 in each spoke) do not have a public ip. You will be able to SSH from the Jump VM to the other VMs to test connectivity. Onprem is also simulated with a VNET and has a test VM. Spoke1VM and Spoke2VM will have a default route pointed to the Azure firewall. CSR1 is in ASN 65001, CSR2 is in ASN 65002, both are using VTIs. All VMs have a username/password of azureuser/Msft123Msft123

This lab is built with Cloud Shell (https://shell.azure.com) or Windows Subsytem for Linux (WSL2)/Ubuntu/Azure CLI

<pre lang="...">
az extension list-available --output table
az extension add --name azure-firewall
</pre>

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/VPN-backhaul-with-NVA/vpnbackhaultopo2.PNG)

# Packet flow over Azure backbone
![alt text](https://github.com/jwrightazure/lab/blob/master/VPN-backhaul-with-NVA/vpnbackhaulflow2.PNG)


**You may have to accept the NVA agreement if you've never deployed this image before. You can use Cloudshell (Powershell) to run the commands. This is just an example:**
<pre lang="...">
Sample Powershell:
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

# Lab Build
<pre lang="...">
# Define Resource Group and location variables. Build simulated on prem and VPN hub VNET in UK West. Also build CSR1 and CSR2.

#!/bin/bash
rgname="vpnlab"
US="eastus"
UK="ukwest"

az group create --name $rgname --location $US
az network vnet create --name onprem --resource-group $rgname --address-prefix 10.100.0.0/16 --location $UK
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group $rgname --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group $rgname --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group $rgname --vnet-name onprem

az network vnet create --name vpnhub --resource-group $rgname --address-prefix 10.0.0.0/16 --location $UK
az network vnet subnet create --address-prefix 10.0.1.0/24 --name InsideSubnet --resource-group $rgname --vnet-name vpnhub 
az network vnet subnet create --address-prefix 10.0.0.0/24 --name OutsideSubnet --resource-group $rgname --vnet-name vpnhub
az network vnet subnet create --address-prefix 10.0.10.0/24 --name testVMSubnet --resource-group $rgname --vnet-name vpnhub

az network public-ip create --name CSR1PublicIP --resource-group $rgname --idle-timeout 30 --allocation-method Static --location $UK
az network nic create --name CSR1OutsideInterface --resource-group $rgname --subnet OutsideSubnet --vnet onprem --public-ip-address CSR1PublicIP --ip-forwarding true --location $UK
az network nic create --name CSR1InsideInterface --resource-group $rgname --subnet InsideSubnet --vnet onprem --ip-forwarding true --location $UK
az vm create --resource-group $rgname --location $UK --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait 

az network public-ip create --name CSR2PublicIP --resource-group $rgname --idle-timeout 30 --allocation-method Static --location $UK
az network nic create --name CSR2OutsideInterface --resource-group $rgname --subnet OutsideSubnet --vnet vpnhub --public-ip-address CSR2PublicIP --ip-forwarding true --location $UK
az network nic create --name CSR2InsideInterface --resource-group $rgname --subnet InsideSubnet --vnet vpnhub --ip-forwarding true --location $UK
az vm create --resource-group $rgname --location $UK --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait 


# Build Hub1, Spoke1, Spoke2 and Azure firewall in East US. Also build the Jump VM, Spoke1VM and Spoke2VM

az network vnet create --resource-group $rgname --name Hub1 --address-prefixes 10.1.0.0/24 --subnet-name AzureFirewallSubnet --subnet-prefix 10.1.0.0/26 --location $US
az network vnet create --resource-group $rgname --name Spoke1 --address-prefixes 10.2.0.0/16  --subnet-name Spoke1VMSubnet --subnet-prefix 10.2.10.0/24 --location $US
az network vnet subnet create --address-prefix 10.2.1.0/24 --name JumpSubnet --resource-group $rgname --vnet-name Spoke1
az network vnet create --resource-group $rgname --name Spoke2 --address-prefixes 10.3.0.0/16 --subnet-name Spoke2VMSubnet --subnet-prefix 10.3.10.0/24 --location $US

az network public-ip create --name AZFW1-pip --resource-group $rgname --location $US --allocation-method static --sku standard
az network firewall create --name AZFW1 --resource-group $rgname --location $US
az network firewall ip-config create --firewall-name AZFW1 --name FW-config --public-ip-address AZFW1-pip --resource-group $rgname --vnet-name Hub1
az network firewall update --name AZFW1 --resource-group $rgname

az network public-ip create --name JumpVM-pip --resource-group $rgname --location $US --allocation-method Dynamic
az network nic create --resource-group $rgname -n JumpVMNIC --location $US --subnet JumpSubnet --private-ip-address 10.2.1.10 --vnet-name Spoke1 --public-ip-address JumpVM-pip --ip-forwarding true
az vm create -n JumpVM --resource-group $rgname --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics JumpVMNIC --no-wait --location $US
az network nic create --resource-group $rgname -n Spoke1VMNIC --location $US --subnet Spoke1VMSubnet --private-ip-address 10.2.10.10 --vnet-name Spoke1 --ip-forwarding true
az vm create -n Spoke1VM --resource-group $rgname --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke1VMNIC --no-wait --location $US
az network nic create --resource-group $rgname -n Spoke2VMNIC --location $US --subnet Spoke2VMSubnet --private-ip-address 10.3.10.10 --vnet-name Spoke2 --ip-forwarding true
az vm create -n Spoke2VM --resource-group $rgname --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke2VMNIC --no-wait --location $US


# Find VNET ID and create VNET peering. 

Hub1Id=$(az network vnet show --resource-group $rgname --name Hub1 --query id --out tsv)
vpnhubId=$(az network vnet show --resource-group $rgname --name vpnhub --query id --out tsv)
Spoke1Id=$(az network vnet show --resource-group $rgname --name Spoke1 --query id --out tsv)
Spoke2Id=$(az network vnet show --resource-group $rgname --name Spoke2 --query id --out tsv)
az network vnet peering create --name Hub1-To-vpnhub --resource-group $rgname --vnet-name Hub1 --remote-vnet $vpnhubId --allow-vnet-access
az network vnet peering create --name vpnhub-to-Hub1 --resource-group $rgname --vnet-name vpnhub --remote-vnet $Hub1Id --allow-vnet-access
az network vnet peering create --name Hub1-To-Spoke1 --resource-group $rgname --vnet-name Hub1 --remote-vnet $Spoke1Id --allow-vnet-access
az network vnet peering create --name Spoke1-to-Hub1 --resource-group $rgname --vnet-name Spoke1 --remote-vnet $Hub1Id --allow-vnet-access
az network vnet peering create --name Hub1-To-Spoke2 --resource-group $rgname --vnet-name Hub1 --remote-vnet $Spoke2Id --allow-vnet-access
az network vnet peering create --name Spoke2-to-Hub1 --resource-group $rgname --vnet-name Spoke2 --remote-vnet $Hub1Id --allow-vnet-access


# Build route table for Azure firewall to send 10.100/16 to the CSR. Also build route table for the inside CSR2 interface to route Spoke1/2 to Azure firewall.

az network route-table create --name AZFW1-RT --resource-group $rgname --location $US
az network route-table route create --resource-group $rgname --name to-Internet --route-table-name AZFW1-RT --address-prefix 0.0.0.0/0 --next-hop-type Internet
az network route-table route create --resource-group $rgname --name to-onprem --route-table-name AZFW1-RT --address-prefix 10.100.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network vnet subnet update -n AzureFirewallSubnet --resource-group $rgname --vnet-name Hub1 --address-prefixes 10.1.0.0/26 --route-table AZFW1-RT
az network route-table create --name CSR2inside-RT --resource-group $rgname --location $UK
az network route-table route create --resource-group $rgname --name to-spoke1 --route-table-name CSR2inside-RT --address-prefix 10.2.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network route-table route create --resource-group $rgname --name to-spoke2 --route-table-name CSR2inside-RT --address-prefix 10.3.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network vnet subnet update -n InsideSubnet --resource-group $rgname --vnet-name vpnhub --address-prefixes 10.0.1.0/24 --route-table CSR2inside-RT 


# Build route table for Spoke1/2 VM subnets with a default route to Azure firewall

az network route-table create --name Spoke1-RT --resource-group $rgname --location $US --disable-bgp-route-propagation
az network route-table route create --resource-group $rgname --name Default-Route --route-table-name Spoke1-RT --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network vnet subnet update -n Spoke1VMSubnet --resource-group $rgname --vnet-name Spoke1 --address-prefixes 10.2.10.0/24 --route-table Spoke1-RT
az network route-table create --name Spoke2-RT --resource-group $rgname --location eastus --disable-bgp-route-propagation
az network route-table route create --resource-group $rgname --name Default-Route --route-table-name Spoke2-RT --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network vnet subnet update -n Spoke2VMSubnet --resource-group $rgname --vnet-name Spoke2 --address-prefixes 10.3.10.0/24 --route-table Spoke2-RT


# Create a basic Azure firewall rule to allow 10/8 to any. Adjust as needed.**

az network firewall network-rule create --resource-group $rgname --firewall-name AZFW1 --collection-name AZFW1-rules --priority 100 --action Allow --name Allow-All --protocols Any --source-addresses 10.0.0.0/8 --destination-addresses * --destination-ports *


# Create a test VM in the on prem network and routes for Spoke1/2.

az network public-ip create --name onpremVMPubIP --resource-group $rgname --location $UK --allocation-method Static
az network nic create --resource-group $rgname -n onpremVMNIC --location $UK --subnet testVMSubnet --private-ip-address 10.100.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --ip-forwarding true
az vm create -n onpremVM --resource-group $rgname --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait --location $UK
az network route-table create --name onprem-rt --resource-group $rgname --location $UK
az network route-table route create --name to-spoke1 --resource-group $rgname --route-table-name onprem-rt --address-prefix 10.2.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name to-spoke2 --resource-group $rgname --route-table-name onprem-rt --address-prefix 10.3.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name testVMSubnet --vnet-name onprem --resource-group $rgname --route-table onprem-rt


# Document all public IPs and paste them in notepad.

az network public-ip show --name JumpVM-pip --resource-group $rgname --query [ipAddress] --output tsv
az network public-ip show --name CSR2PublicIP --resource-group $rgname --query [ipAddress] --output tsv
az network public-ip show --name CSR1PublicIP --resource-group $rgname --query [ipAddress] --output tsv
az network public-ip show --name onpremVMPubIP --resource-group $rgname --query [ipAddress] --output tsv
az network public-ip show --name AZFW1-pip --resource-group $rgname --query [ipAddress] --output tsv
</pre>

**SSH to CSR2 and paste in the below configs. Make sure to change CSR1PublicIP to the public IP of CSR documented in notepad.**
<pre lang="...">
ip route 10.2.0.0 255.255.0.0 10.0.1.1 tag 12345
ip route 10.3.0.0 255.255.0.0 10.0.1.1 tag 12345

crypto ikev2 proposal to-csr1-proposal
  encryption aes-cbc-256
  integrity sha1
  group 2
  exit

crypto ikev2 policy to-csr1-policy
  proposal to-csr1-proposal
  match address local 10.0.0.4
  exit
  
crypto ikev2 keyring to-csr1-keyring
  peer CSR1PublicIP
    address CSR1PublicIP
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-csr1-profile
  match address local 10.0.0.4
  match identity remote address 10.100.0.4
  authentication remote pre-share
  authentication local  pre-share
  lifetime 3600
  dpd 10 5 on-demand
  keyring local to-csr1-keyring
  exit

crypto ipsec transform-set to-csr1-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-csr1-IPsecProfile
  set transform-set to-csr1-TransformSet
  set ikev2-profile to-csr1-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.2 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.0.0.4
  tunnel destination CSR1PublicIP
  tunnel protection ipsec profile to-csr1-IPsecProfile
  exit 

route-map redis permit 10 
 match tag 12345

router bgp 65002
  bgp log-neighbor-changes
  neighbor 192.168.1.1 remote-as 65001
  neighbor 192.168.1.1 ebgp-multihop 255
  neighbor 192.168.1.1 update-source tunnel 11

  address-family ipv4
    redistribute static route-map redis
    neighbor 192.168.1.1 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 192.168.1.1 255.255.255.255 Tunnel 11
</pre>

**SSH to CSR1 and paste in the below configs. Make sure to change CSR2PublicIP to the public IP of CSR documented in notepad.**
<pre lang="...">
crypto ikev2 proposal to-csr2-proposal
  encryption aes-cbc-256
  integrity sha1
  group 2
  exit

crypto ikev2 policy to-csr2-policy
  proposal to-csr2-proposal
  match address local 10.100.0.4
  exit
  
crypto ikev2 keyring to-csr2-keyring
  peer CSR2PublicIP
    address CSR2PublicIP
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-csr2-profile
  match address local 10.100.0.4
  match identity remote address 10.0.0.4
  authentication remote pre-share
  authentication local  pre-share
  lifetime 3600
  dpd 10 5 on-demand
  keyring local to-csr2-keyring
  exit

crypto ipsec transform-set to-csr2-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-csr2-IPsecProfile
  set transform-set to-csr2-TransformSet
  set ikev2-profile to-csr2-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.1 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.100.0.4
  tunnel destination CSR2PublicIP
  tunnel protection ipsec profile to-csr2-IPsecProfile
  exit 

ip route 10.100.10.0 255.255.255.0 10.100.1.1 tag 12345
route-map redis permit 10 
 match tag 12345

router bgp 65001
  bgp log-neighbor-changes
  neighbor 192.168.1.2 remote-as 65002
  neighbor 192.168.1.2 ebgp-multihop 255
  neighbor 192.168.1.2 update-source tunnel 11

  address-family ipv4
    redistribute static route-map redis
    neighbor 192.168.1.2 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 192.168.1.2 255.255.255.255 Tunnel 11
</pre>

At this point, there should be communication between Spoke1/Spoke2 and the on prem VM. You can also SSH to the Jump VM, from there SSH to Spoke1VM (10.2.10.10). Run curl ipconfig.io and the address should match the public IP of the Azure firewall. 
