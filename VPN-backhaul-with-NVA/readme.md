# Optimized VNET Connectivity- Backhauling Geo Specific Sites Via Local S2S VPN With VNET Connectivity Across Azure's Backbone
This lab guide shows how to build a S2S VPN to the closest Azure region and leverage the Azure backbone to reach VNETs. The topology will build a customer managed hub/spoke in East US. There are a number of location in Europe that need S2S connectivity to reach resources in both spokes(also in East US). Instead of having each UK site build a tunnel across the traditional Internet, we will build a VPN hub in the UK West region. All locations in Europe (we only use 1 location in this lab) will VPN to a Cisco CSR in UK West, transit the Azure backbone to reach the hub in East US. All traffic from the simulated on prem to Spoke 1 or Spoke 2 will flow through by Azure firewall. Traffic initiated from Spoke1/2 will go through Azure firewall to reach on prem. By leveraging the local Azure region for connectivity, remote offices in Europe will have better performance compared to traditional Internet. This design also works if the customer has multiple customer managed hub/spokes already deployed. Since the tunnel is terminating on a 3rd party NVA, this is a great solution for other common features I see such as (assuming the vendor supports it):

- SD-WAN tunnel termination in the Europe VPN hub
- Per tunnel NAT including address overlap
- Per tunnel QOS
- Large scale tunnel termination and route tables
- Backhauling S2S connectivity for other cloud providers

Note- the entire lab uses Azure CLI. Please make sure you have the latest version and the firewall extension added. The firewall rules can be modified to be more restrictive as needed. There is a single jump VM (with a public ip) in Spoke1. The other 2 VMs (1 in each spoke) do not have a public ip. You will be able to SSH from the Jump VM to the other VMs to test connectivity. Onprem is also simulated with a VNET and has a test VM. Spoke1VM and Spoke2VM will have a default route pointed to the Azure firewall. CSR1 is in ASN 65001, CSR2 is in ASN 65002, both are using VTIs. All VMs have a username/password of azureuser/Msft123Msft123

<pre lang="...">
az extension list-available --output table
az extension add --name azure-firewall
</pre>

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/VPN-backhaul-with-NVA/vpnbackhaultopo.PNG)

# Packet flow over Azure backbone
![alt text](https://github.com/jwrightazure/lab/blob/master/VPN-backhaul-with-NVA/vpnbackhaulflow.PNG)


**You may have to accept the NVA agreement if you've never deployed this image before. You can use Cloudshell (Powershell) to run the commands. This is just an example:**
<pre lang="...">
Sample Powershell:
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Build simulated on prem and VPN hub VNET in UK West. Also build CSR1 and CSR2.**
<pre lang="...">
az group create --name vpn --location eastus
az network vnet create --name onprem --resource-group vpn --address-prefix 10.100.0.0/16 --location "UK West"
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group vpn --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group vpn --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group vpn --vnet-name onprem

az network vnet create --name vpnhub --resource-group vpn --address-prefix 10.0.0.0/16 --location "UK West"
az network vnet subnet create --address-prefix 10.0.1.0/24 --name InsideSubnet --resource-group vpn --vnet-name vpnhub 
az network vnet subnet create --address-prefix 10.0.0.0/24 --name OutsideSubnet --resource-group vpn --vnet-name vpnhub
az network vnet subnet create --address-prefix 10.0.10.0/24 --name testVMSubnet --resource-group vpn --vnet-name vpnhub

az network public-ip create --name CSR1PublicIP --resource-group vpn --idle-timeout 30 --allocation-method Static --location "UK West"
az network nic create --name CSR1OutsideInterface -g vpn --subnet OutsideSubnet --vnet onprem --public-ip-address CSR1PublicIP --ip-forwarding true --location "UK West"
az network nic create --name CSR1InsideInterface -g vpn --subnet InsideSubnet --vnet onprem --ip-forwarding true --location "UK West"
az vm create --resource-group vpn --location eastus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait --location "UK West"

az network public-ip create --name CSR2PublicIP --resource-group vpn --idle-timeout 30 --allocation-method Static --location "UK West"
az network nic create --name CSR2OutsideInterface -g vpn --subnet OutsideSubnet --vnet vpnhub --public-ip-address CSR2PublicIP --ip-forwarding true --location "UK West"
az network nic create --name CSR2InsideInterface -g vpn --subnet InsideSubnet --vnet vpnhub --ip-forwarding true --location "UK West"
az vm create --resource-group vpn --location eastus --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait --location "UK West"
</pre>

**Build Hub1, Spoke1, Spoke2 and Azure firewall in East US. Also build the Jump VM, Spoke1VM and Spoke2VM**
<pre lang="...">
az network vnet create --resource-group vpn --name Hub1 --location eastus --address-prefixes 10.1.0.0/24 --subnet-name AzureFirewallSubnet --subnet-prefix 10.1.0.0/26 
az network vnet create --resource-group vpn --name Spoke1 --location eastus --address-prefixes 10.2.0.0/16  --subnet-name Spoke1VMSubnet --subnet-prefix 10.2.10.0/24 
az network vnet subnet create --address-prefix 10.2.1.0/24 --name JumpSubnet --resource-group vpn --vnet-name Spoke1
az network vnet create --resource-group vpn --name Spoke2 --location eastus --address-prefixes 10.3.0.0/16 --subnet-name Spoke2VMSubnet --subnet-prefix 10.3.10.0/24 

az network public-ip create --name AZFW1-pip --resource-group vpn --location eastus --allocation-method static --sku standard
az network firewall create --name AZFW1 --resource-group vpn --location eastus
az network firewall ip-config create --firewall-name AZFW1 --name FW-config --public-ip-address AZFW1-pip --resource-group vpn --vnet-name Hub1
az network firewall update --name AZFW1 --resource-group vpn

az network public-ip create --name JumpVM-pip --resource-group vpn --location eastus --allocation-method Dynamic
az network nic create --resource-group vpn -n JumpVMNIC --location eastus --subnet JumpSubnet --private-ip-address 10.2.1.10 --vnet-name Spoke1 --public-ip-address JumpVM-pip --ip-forwarding true
az vm create -n JumpVM -g vpn --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics JumpVMNIC --no-wait --location eastus
az network nic create --resource-group vpn -n Spoke1VMNIC --location eastus --subnet Spoke1VMSubnet --private-ip-address 10.2.10.10 --vnet-name Spoke1 --ip-forwarding true
az vm create -n Spoke1VM -g vpn --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke1VMNIC --no-wait --location eastus
az network nic create --resource-group vpn -n Spoke2VMNIC --location eastus --subnet Spoke2VMSubnet --private-ip-address 10.3.10.10 --vnet-name Spoke2 --ip-forwarding true
az vm create -n Spoke2VM -g vpn --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke2VMNIC --no-wait --location eastus
</pre>

**Build VNET peering. Replace XXXXX with your subscription**
<pre lang="...">
az network vnet peering create -g vpn -n Hub1-To-vpnhub --vnet-name Hub1 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXXX/resourceGroups/vpn/providers/Microsoft.Network/virtualNetworks/vpnhub
az network vnet peering create -g vpn -n vpnhub-to-Hub1 --vnet-name vpnhub --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXXX/resourceGroups/vpn/providers/Microsoft.Network/virtualNetworks/Hub1
az network vnet peering create -g vpn -n Hub1-to-Spoke1 --vnet-name Hub1 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXXX/resourceGroups/vpn/providers/Microsoft.Network/virtualNetworks/Spoke1
az network vnet peering create -g vpn -n Hub1-to-Spoke2 --vnet-name Hub1 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXXX/resourceGroups/vpn/providers/Microsoft.Network/virtualNetworks/Spoke2
az network vnet peering create -g vpn -n Spoke1-to-Hub1 --vnet-name Spoke1 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXXX/resourceGroups/vpn/providers/Microsoft.Network/virtualNetworks/Hub1
az network vnet peering create -g vpn -n Spoke2-to-Hub1 --vnet-name Spoke2 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXXX/resourceGroups/vpn/providers/Microsoft.Network/virtualNetworks/Hub1
</pre>

**Build route table for Azure firewall to send 10.100/16 to the CSR. Also build route table for the inside CSR2 interface to route Spoke1/2 to Azure firewall.**
<pre lang="...">
az network route-table create --name AZFW1-RT --resource-group vpn --location eastus
az network route-table route create --resource-group vpn --name to-Internet --route-table-name AZFW1-RT --address-prefix 0.0.0.0/0 --next-hop-type Internet
az network route-table route create --resource-group vpn --name to-onprem --route-table-name AZFW1-RT --address-prefix 10.100.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network vnet subnet update -n AzureFirewallSubnet -g vpn --vnet-name Hub1 --address-prefixes 10.1.0.0/26 --route-table AZFW1-RT

az network route-table create --name CSR2inside-RT --resource-group vpn --location "UK West"
az network route-table route create --resource-group vpn --name to-spoke1 --route-table-name CSR2inside-RT --address-prefix 10.2.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network route-table route create --resource-group vpn --name to-spoke2 --route-table-name CSR2inside-RT --address-prefix 10.3.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network vnet subnet update -n InsideSubnet -g vpn --vnet-name vpnhub --address-prefixes 10.0.1.0/24 --route-table CSR2inside-RT 
</pre>

**Build route table for Spoke1/2 VM subnets with a default route to Azure firewall**
<pre lang="...">
az network route-table create --name Spoke1-RT --resource-group vpn --location eastus --disable-bgp-route-propagation
az network route-table route create --resource-group vpn --name Default-Route --route-table-name Spoke1-RT --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network vnet subnet update -n Spoke1VMSubnet -g vpn --vnet-name Spoke1 --address-prefixes 10.2.10.0/24 --route-table Spoke1-RT

az network route-table create --name Spoke2-RT --resource-group vpn --location eastus --disable-bgp-route-propagation
az network route-table route create --resource-group vpn --name Default-Route --route-table-name Spoke2-RT --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network vnet subnet update -n Spoke2VMSubnet -g vpn --vnet-name Spoke2 --address-prefixes 10.3.10.0/24 --route-table Spoke2-RT
</pre>

**Create a basic Azure firewall rule to allow 10/8 to any. Adjust as needed.**
<pre lang="...">
az network firewall network-rule create --resource-group vpn --firewall-name AZFW1 --collection-name AZFW1-rules --priority 100 --action Allow --name Allow-All --protocols Any --source-addresses 10.0.0.0/8 --destination-addresses * --destination-ports *
</pre>

**Create a test VM in the on prem network and routes for Spoke1/2.**
<pre lang="...">
az network public-ip create --name onpremVMPubIP --resource-group vpn --location "UK West" --allocation-method Static
az network nic create --resource-group vpn -n onpremVMNIC --location "UK West" --subnet testVMSubnet --private-ip-address 10.100.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --ip-forwarding true
az vm create -n onpremVM -g vpn --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait --location "UK West"

az network route-table create --name onprem-rt --resource-group vpn --location "UK West"
az network route-table route create --name to-spoke1 --resource-group vpn --route-table-name onprem-rt --address-prefix 10.2.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name to-spoke2 --resource-group vpn --route-table-name onprem-rt --address-prefix 10.3.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name testVMSubnet --vnet-name onprem --resource-group vpn --route-table onprem-rt
</pre>

**Document all public IPs and paste them in notepad.**
<pre lang="...">
az network public-ip show --name JumpVM-pip --resource-group vpn --query [ipAddress] --output tsv
az network public-ip show --name CSR2PublicIP --resource-group vpn --query [ipAddress] --output tsv
az network public-ip show --name CSR1PublicIP --resource-group vpn --query [ipAddress] --output tsv
az network public-ip show --name onpremVMPubIP --resource-group vpn --query [ipAddress] --output tsv
az network public-ip show --name AZFW1-pip --resource-group vpn --query [ipAddress] --output tsv
</pre>

**As a quick test, you can SSH to the Jump VM, from there SSH to Spoke1VM (10.2.10.10). Run curl ipconfig.io and the address should match the public IP of the Azure firewall. There will not yet be reachability between Spoke1/2 and on prem.**

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

At this point, there should be communication between Spoke1/Spoke2 and the on prem VM. 
