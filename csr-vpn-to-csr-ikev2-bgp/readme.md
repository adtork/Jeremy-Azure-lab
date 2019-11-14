# Azure Networking Lab- IPSEC VPN (IKEv2) between Cisco CSRs with BGP
This lab guide illustrates how to build a basic IPSEC VPN tunnel w/IKEv2 between Cisco CSRs with BGP. This is for lab testing purposes only and should not be considered production configurations. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. Note- Loopback address have been added to each CSR for troubleshooting purposes as well as the UDRs for reachability to them. The on prem VNET is to simulate on prem connectivity. Each CSR uses code version 16.10 which has introduced new default configurations. 

Assumptions:
- A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Latest Azure CLI, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/csrvpnikev2bgp.PNG)

**You may have to accept the NVA agreement if you've never deployed this image before. This is just an example:**
<pre lang="...">
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Create CSR VNET and subnets**
<pre lang="...">
az group create --name CSR --location "WestUS"
az network vnet create --name CSR --resource-group CSR --address-prefix 10.0.0.0/16
az network vnet subnet create --address-prefix 10.0.1.0/24 --name InsideSubnet --resource-group CSR --vnet-name CSR 
az network vnet subnet create --address-prefix 10.0.0.0/24 --name OutsideSubnet --resource-group CSR --vnet-name CSR
az network vnet subnet create --address-prefix 10.0.10.0/24 --name testVMSubnet --resource-group CSR --vnet-name CSR
</pre>

**Create NSG for CSR1**
<pre lang="...">
az network nsg create --resource-group CSR --name Azure-CSR-NSG --location westus
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>

**Create CSR1**
<pre lang="...">
az network public-ip create --name CSR1PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR1OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR1PublicIP --private-ip-address 10.0.0.4 --ip-forwarding true --network-security-group Azure-CSR-NSG
az network nic create --name CSR1InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.4 --network-security-group Azure-CSR-NSG
az vm create --resource-group CSR --location westus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_12-byol:16.12.120190816 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
</pre>

**Create onprem VNET and subnets**
<pre lang="...">
az group create --name onprem --location "West US 2"
az network vnet create --name onprem --resource-group onprem --address-prefix 10.100.0.0/16
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group onprem --vnet-name onprem
</pre>

**Create NSG for CSR3**
<pre lang="...">
az network nsg create --resource-group onprem --name onprem-CSR-NSG --location westus2
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>

**Create CSR3**
<pre lang="...">
az network public-ip create --name CSR3PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR3OutsideInterface -g onprem --subnet OutsideSubnet --vnet onprem --public-ip-address CSR3PublicIP --private-ip-address 10.100.0.4 --ip-forwarding true --network-security-group onprem-CSR-NSG
az network nic create --name CSR3InsideInterface -g onprem --subnet InsideSubnet --vnet onprem --ip-forwarding true --private-ip-address 10.100.1.4 --network-security-group onprem-CSR-NSG
az vm create --resource-group onprem --location westus2 --name CSR3 --size Standard_D2_v2 --nics CSR3OutsideInterface CSR3InsideInterface  --image cisco:cisco-csr-1000v:16_12-byol:16.12.120190816  --admin-username azureuser --admin-password Msft123Msft123 --no-wait
</pre>

**Create NSG for Azure side test VM**
<pre lang="...">
az network nsg create --resource-group CSR --name Azure-VM-NSG --location westus
az network nsg rule create --resource-group CSR --nsg-name Azure-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group CSR --nsg-name Azure-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>

**Create Azure side VM**
<pre lang="...">
az network public-ip create --name AzureVMPubIP --resource-group CSR --location westus --allocation-method Dynamic
az network nic create --resource-group CSR -n AzureVMNIC --location westus --subnet testVMSubnet --private-ip-address 10.0.10.10 --vnet-name CSR --public-ip-address AzureVMPubIP --network-security-group Azure-VM-NSG --ip-forwarding true
az vm create -n AzureVM -g CSR --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics AzureVMNIC --no-wait
</pre>

**Create NSG for onprem side test VM**
<pre lang="...">
az network nsg create --resource-group onprem --name onprem-VM-NSG --location westus2
az network nsg rule create --resource-group onprem --nsg-name onprem-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group onprem --nsg-name onprem-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>

**Create  onprem side VM**
<pre lang="...">
az network public-ip create --name onpremVMPubIP --resource-group onprem --location westus2 --allocation-method Dynamic
az network nic create --resource-group onprem -n onpremVMNIC --location westus2 --subnet testVMSubnet --private-ip-address 10.100.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --network-security-group onprem-VM-NSG --ip-forwarding true
az vm create -n onpremVM -g onprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait
</pre>

**Create a route table for the onprem side VM subnet. Routes include VTIs of both CSRs as well as the loopbacks for CSRs**
<pre lang="...">
az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name csr1-loopback --resource-group onprem --route-table-name vm-rt --address-prefix 1.1.1.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name csr1-vti --resource-group onprem --route-table-name vm-rt --address-prefix 192.168.1.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name csr3-loopback --resource-group onprem --route-table-name vm-rt --address-prefix 3.3.3.3/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name csr3-vti --resource-group onprem --route-table-name vm-rt --address-prefix 192.168.1.3/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name testVMSubnet --vnet-name onprem --resource-group onprem --route-table vm-rt
</pre>

**Create a route table for the CSR side VM subnet. Routes include VTIs of both CSRs as well as the loopbacks for CSRs**
<pre lang="...">
az network route-table create --name vm-rt --resource-group CSR
az network route-table route create --name vm-rt --resource-group CSR --route-table-name vm-rt --address-prefix 10.100.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network route-table route create --name csr1-loopback --resource-group CSR --route-table-name vm-rt --address-prefix 1.1.1.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network route-table route create --name csr1-vti --resource-group CSR --route-table-name vm-rt --address-prefix 192.168.1.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network route-table route create --name csr3-loopback --resource-group CSR --route-table-name vm-rt --address-prefix 3.3.3.3/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network route-table route create --name csr3-vti --resource-group CSR --route-table-name vm-rt --address-prefix 192.168.1.3/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network vnet subnet update --name testVMSubnet --vnet-name CSR --resource-group CSR --route-table vm-rt
</pre>

**Get public IPs for CSR1 and CSR3 and save them to notepad**
<pre lang="...">
az network public-ip show -g CSR -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show -g onprem -n CSR3PublicIP --query "{address: ipAddress}"
</pre>

**SSH to CSR1 and paste in the below configs. Make sure to change the CSR public IPs referenced**
<pre lang="...">
int gi1
no ip nat outside

int gi2
no ip nat inside

!route for test subnet
ip route 10.0.10.0 255.255.255.0 10.0.1.1

crypto ikev2 proposal to-csr3-proposal
  encryption aes-cbc-256
  integrity sha1
  group 2
  exit

crypto ikev2 policy to-csr3-policy
  proposal to-csr3-proposal
  match address local 10.0.0.4
  exit
  
crypto ikev2 keyring to-csr3-keyring
  peer "Insert CSR3PublicIP"
    address "Insert CSR3PublicIP"
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-csr3-profile
  match address local 10.0.0.4
  match identity remote address 10.100.0.4
  authentication remote pre-share
  authentication local  pre-share
  lifetime 3600
  dpd 10 5 on-demand
  keyring local to-csr3-keyring
  exit

crypto ipsec transform-set to-csr3-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-csr3-IPsecProfile
  set transform-set to-csr3-TransformSet
  set ikev2-profile to-csr3-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.1 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.0.0.4
  tunnel destination "Insert CSR3PublicIP"
  tunnel protection ipsec profile to-csr3-IPsecProfile
  exit 

!loopback interface only for testing
int lo1
ip address 1.1.1.1 255.255.255.255

router bgp 65001
  bgp log-neighbor-changes
  neighbor 192.168.1.3 remote-as 65003
  neighbor 192.168.1.3 ebgp-multihop 255
  neighbor 192.168.1.3 update-source tunnel 11

  address-family ipv4
    network 10.0.0.0 mask 255.255.0.0
    network 1.1.1.1 mask 255.255.255.255
    network 192.168.1.1 mask 255.255.255.255
    neighbor 192.168.1.3 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 192.168.1.3 255.255.255.255 Tunnel 11
ip route 10.0.0.0 255.255.0.0 null0
</pre>

**SSH to CSR3 and paste in the below configs. Make sure to chage the CSR public IPs referenced**
<pre lang="...">
int gi1
no ip nat outside

int gi2
no ip nat inside

!route for test subnet
ip route 10.100.10.0 255.255.255.0 10.100.1.1

crypto ikev2 proposal to-csr1-proposal
  encryption aes-cbc-256
  integrity sha1
  group 2
  exit

crypto ikev2 policy to-csr1-policy
  proposal to-csr1-proposal
  match address local 10.100.0.4
  exit
  
crypto ikev2 keyring to-csr1-keyring
  peer "Insert CSR1PublicIP"
    address "Insert CSR1PublicIP"
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-csr1-profile
  match address local 10.100.0.4
  match identity remote address 10.0.0.4
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
  ip address 192.168.1.3 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.100.0.4
  tunnel destination "Insert CSR1PublicIP"
  tunnel protection ipsec profile to-csr1-IPsecProfile
  exit

!loopback address for testing purposes only
int lo1
ip address 3.3.3.3 255.255.255.255

router bgp 65003
  bgp log-neighbor-changes
  neighbor 192.168.1.1 remote-as 65001
  neighbor 192.168.1.1 ebgp-multihop 255
  neighbor 192.168.1.1 update-source tunnel 11

  address-family ipv4
    network 10.100.0.0 mask 255.255.0.0
    network 3.3.3.3 mask 255.255.255.255

    network 192.168.1.3 mask 255.255.255.255
    neighbor 192.168.1.1 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 192.168.1.1 255.255.255.255 Tunnel 11
ip route 10.100.0.0 255.255.0.0 null0
</pre>

**Validation on CSR1 and CSR3**
- show crypto ikev2 sa
- show ip route bgp
- Source ping from loopback to other side loopback
- Both test VMs should be able to ping all loopbacks, VTIs and VMs acorss the tunnel
