# Denying Spoke to Spoke VPN Traffic with BGP when using Azure VPN Gateway
By default, 2 remote sites will be able to communicate if they are connecting via S2S VPN+BGP to the Azure VPN Gateway. Branch to branch communication will hairpin off of the VPN GW. Currently there are no route filtering capabilities on the VPN GW nor can you use NSGs. This lab will illustrate the default behavior as well as an option to use BGP deny spoke to spoke traffic. All Azure configurations are done with Azure CLI.

# Base Topology
The lab deploys an Azure VNET as well as 2 VNET that simulate 2 branch locations. The Azure ASN will be 65001, Branch1 is 65002 and Branch2 will be 65003. Branch1/2 will use Cisco CSRs for VPN, each using a VTI with BGP over IPSEC. There will be a VM in each VNET as well branch route tables which are specific to this lab since no hardware is needed. All username/passwords are azureuser/Msft123Msft123

![alt text](https://github.com/jwrightazure/lab/blob/master/AZVPNGW-deny-branch-to-branch/s2s-branch-deny-topo.PNG)

**Before deploying CSR in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands via Cloudshell**
<pre lang="...">
Sample Powershell:
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Create VNETS, VPN GW, CSRs, route tables and test VMs. The VPN GW will take approximately 20 minutes to deploy.**
<pre lang="...">
az group create --name Azure --location westus
az network vnet create --resource-group Azure --name Azure --location westus --address-prefixes 10.0.0.0/16 --subnet-name AzureVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group Azure --vnet-name Azure
az network vnet create --resource-group Azure --name Branch1 --location westus --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group Azure --vnet-name Branch1
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group Azure --vnet-name Branch1
az network public-ip create --name Azure-VNGpubip --resource-group Azure --allocation-method Dynamic
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group Azure --vnet Azure --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65001
az network public-ip create --name CSR1PublicIP --resource-group Azure --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g Azure --subnet zeronet --vnet Branch1 --public-ip-address CSR1PublicIP --ip-forwarding true
az network nic create --name CSR1InsideInterface -g Azure --subnet onenet --vnet Branch1 --ip-forwarding true
az vm create --resource-group Azure --location westus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network vnet create --resource-group Azure --name Branch2 --location westus --address-prefixes 10.2.0.0/16 --subnet-name VM --subnet-prefix 10.2.10.0/24
az network vnet subnet create --address-prefix 10.2.0.0/24 --name zeronet --resource-group Azure --vnet-name Branch2
az network vnet subnet create --address-prefix 10.2.1.0/24 --name onenet --resource-group Azure --vnet-name Branch2
az network public-ip create --name CSR2PublicIP --resource-group Azure --idle-timeout 30 --allocation-method Static
az network nic create --name CSR2OutsideInterface -g Azure --subnet zeronet --vnet Branch2 --public-ip-address CSR2PublicIP --ip-forwarding true
az network nic create --name CSR2InsideInterface -g Azure --subnet onenet --vnet Branch2 --ip-forwarding true
az vm create --resource-group Azure --location westus --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network public-ip create --name AzureVMPubIP --resource-group Azure --location westus --allocation-method Dynamic
az network nic create --resource-group Azure -n AzureVMNIC --location westus --subnet AzureVM --private-ip-address 10.0.10.10 --vnet-name Azure --public-ip-address AzureVMPubIP
az vm create -n AzureVM -g Azure --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics AzureVMNIC --no-wait
az network public-ip create --name Branch1VMPubIP --resource-group Azure --location westus --allocation-method Dynamic
az network nic create --resource-group Azure -n Branch1VMNIC --location westus --subnet VM --private-ip-address 10.1.10.10 --vnet-name Branch1 --public-ip-address Branch1VMPubIP
az vm create -n Branch1VM -g Azure --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Branch1VMNIC --no-wait
az network public-ip create --name Branch2VMPubIP --resource-group Azure --location westus --allocation-method Dynamic
az network nic create --resource-group Azure -n Branch2VMNIC --location westus --subnet VM --private-ip-address 10.2.10.10 --vnet-name Branch2 --public-ip-address Branch2VMPubIP
az vm create -n Branch2VM -g Azure --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Branch2VMNIC --no-wait
az network route-table create --name Branch1-RT --resource-group Azure
az network route-table route create --name Branch1-to-Azure --resource-group Azure --route-table-name Branch1-RT --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network route-table route create --name Branch1-to-Branch2 --resource-group Azure --route-table-name Branch1-RT --address-prefix 10.2.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name Branch1 --resource-group Azure --route-table Branch1-RT
az network route-table create --name Branch2-RT --resource-group Azure
az network route-table route create --name Branch2-to-Azure --resource-group Azure --route-table-name Branch2-RT --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.2.1.4
az network route-table route create --name Branch2-to-Branch1 --resource-group Azure --route-table-name Branch2-RT --address-prefix 10.1.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.2.1.4
az network vnet subnet update --name VM --vnet-name Branch2 --resource-group Azure --route-table Branch2-RT
</pre>

**Document public IPs and copy them to notepad. Do not continue until the VPN GW has a public IP.**
<pre lang="...">
az network public-ip show -g Azure -n Azure-VNGpubip --query "{address: ipAddress}"
az network public-ip show -g Azure -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show -g Azure -n CSR2PublicIP --query "{address: ipAddress}"
az network public-ip show -g Azure -n AzureVMPubIP --query "{address: ipAddress}"
az network public-ip show -g Azure -n Branch1VMPubIP --query "{address: ipAddress}"
az network public-ip show -g Azure -n Branch2VMPubIP --query "{address: ipAddress}"
</pre>

**Build Local Network Gateway and Connection to Branch1. Replace CSR1PublicIP. 192.168.1.1 is the VTI on Branch1 CSR and it will be in ASN 65002.**
<pre lang="...">
az network local-gateway create --gateway-ip-address "CSR1PublicIP" --name to-Branch1 --resource-group Azure --local-address-prefixes 192.168.1.1/32 --asn 65002 --bgp-peering-address 192.168.1.1
az network vpn-connection create --name to-Branch1 --resource-group Azure --vnet-gateway1 Azure-VNG -l westus --shared-key Msft123Msft123 --local-gateway2 to-Branch1 --enable-bgp
</pre>

**Build Local Network Gateway and Connection to Branch2. Replace CSR2PublicIP. 192.168.1.2 is the VTI on Branch2 CSR and it will be in ASN 65003.**
<pre lang="...">
az network local-gateway create --gateway-ip-address "CSR2PublicIP" --name to-Branch2 --resource-group Azure --local-address-prefixes 192.168.1.2/32 --asn 65003 --bgp-peering-address 192.168.1.2
az network vpn-connection create --name to-Branch2 --resource-group Azure --vnet-gateway1 Azure-VNG -l westus --shared-key Msft123Msft123 --local-gateway2 to-Branch2 --enable-bgp
</pre>

**Document BGP peering information on the VPN GW**
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group Azure
</pre>

**Paste in the below configurations for CSR in Branch1. Change Azure-VNGpubip to the appropriate public IP. Note- the config assumes 10.0.0.254 is the VPN GW peer.**
<pre lang="...">
CSR1
hostname CSR1
!route for simulate on prem vm
ip route 10.1.10.0 255.255.255.0 10.1.1.1

crypto ikev2 proposal to-azure-proposal
  encryption aes-cbc-256
  integrity  sha1
  group      2
  exit

crypto ikev2 policy to-azure-policy
  proposal to-azure-proposal
  match address local 10.1.0.4
  exit
  
crypto ikev2 keyring to-azure-keyring
  peer Azure-VNGpubip
    address Azure-VNGpubip
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-azure-profile
  match address  local 10.1.0.4
  match identity remote address Azure-VNGpubip 255.255.255.255
  authentication remote pre-share
  authentication local  pre-share
  lifetime       3600
  dpd 10 5 on-demand
  keyring local  to-azure-keyring
  exit

crypto ipsec transform-set to-azure-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-azure-IPsecProfile
  set transform-set  to-azure-TransformSet
  set ikev2-profile  to-azure-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.1 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.1.0.4
  tunnel destination Azure-VNGpubip
  tunnel protection ipsec profile to-azure-IPsecProfile
  exit

router bgp 65002
  bgp      log-neighbor-changes
  neighbor 10.0.0.254 remote-as 65001
  neighbor 10.0.0.254 ebgp-multihop 255
  neighbor 10.0.0.254 update-source tunnel 11

  address-family ipv4
    network 10.1.10.0 mask 255.255.255.0
    neighbor 10.0.0.254 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 10.0.0.254 255.255.255.255 Tunnel 11
</pre>

**Paste in the below configurations for CSR in Branch2. Change Azure-VNGpubip to the appropriate public IP. Note- the config assumes 10.0.0.254 is the VPN GW peer.**
<pre lang="...">
hostname CSR2
!route for simulate on prem vm
ip route 10.2.10.0 255.255.255.0 10.2.1.1

crypto ikev2 proposal to-azure-proposal
  encryption aes-cbc-256
  integrity  sha1
  group      2
  exit

crypto ikev2 policy to-azure-policy
  proposal to-azure-proposal
  match address local 10.2.0.4
  exit
  
crypto ikev2 keyring to-azure-keyring
  peer Azure-VNGpubip
    address Azure-VNGpubip
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-azure-profile
  match address  local 10.2.0.4
  match identity remote address Azure-VNGpubip 255.255.255.255
  authentication remote pre-share
  authentication local  pre-share
  lifetime       3600
  dpd 10 5 on-demand
  keyring local  to-azure-keyring
  exit

crypto ipsec transform-set to-azure-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-azure-IPsecProfile
  set transform-set  to-azure-TransformSet
  set ikev2-profile  to-azure-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.2 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.2.0.4
  tunnel destination Azure-VNGpubip
  tunnel protection ipsec profile to-azure-IPsecProfile
  exit

router bgp 65003
  bgp      log-neighbor-changes
  neighbor 10.0.0.254 remote-as 65001
  neighbor 10.0.0.254 ebgp-multihop 255
  neighbor 10.0.0.254 update-source tunnel 11

  address-family ipv4
    network 10.2.10.0 mask 255.255.255.0
    neighbor 10.0.0.254 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 10.0.0.254 255.255.255.255 Tunnel 11
</pre>

**All 3 VMs should have communication at this point. Change the Branch2 CSR BGP config displayed below. Note- the customer edge did not have to change the BGP ASN. By making the ASN appear as 65002 (via local-as), the Azure VPN GW will not advertise Branch1 to Branch2 or Branch2 to Branch1 since they have matching ASNs. **
<pre lang="...">
router bgp 65003
 bgp log-neighbor-changes
 neighbor 10.0.0.254 remote-as 65001
 neighbor 10.0.0.254 local-as 65002
 neighbor 10.0.0.254 ebgp-multihop 255
 neighbor 10.0.0.254 update-source Tunnel11
 !
 address-family ipv4
  network 10.2.10.0 mask 255.255.255.0
  neighbor 10.0.0.254 activate
 exit-address-family
</pre>

**Update the Local Network Gateway to Branch2 to ASN65002**
<pre lang="...">
az network local-gateway create --gateway-ip-address "CSR2PublicIP" --name to-Branch2 --resource-group Azure --local-address-prefixes 192.168.1.2/32 --asn 65002 --bgp-peering-address 192.168.1.2
</pre>
