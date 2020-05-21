# S2S between VNETs with overlapping address space using CSRs
This lab guide illustrates how to build a basic IPSEC/IKEv2 VPN tunnel between 2 VNETs with Cisco CSRs. The VNETs have overlapping address space and will be NATd before traversing the tunnel. The configuration is using VTIs with static routes. The NAT configuration is a basic example and can be changed as needed.

# Base Topology
The lab deploys 2x CSRs in 2 different VNETs with overlapping address space. VNET1 source network will appear as 10.100/16 to VNET2. VNET2 source network will appear as 10.200/16 to VNET1. There is a one to one static NAT for VM testing over the tunnel- 10.100.1.10->10.1.1.10 in VNET1, 10.200.1.10->10.1.1.10 in VNET2. EX: The VM in VNET1 will be able to ping 10.200.1.10 over the tunnel.

![alt text](https://github.com/jwrightazure/lab/blob/master/images/s2s-overlap.PNG)

**Before deploying CSR in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands via Cloudshell**
<pre lang="...">
Sample Powershell:
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Build Hub Resource Groups, VNET and Subnets for VNET1.**
<pre lang="...">
az group create --name vnet1 --location eastus
az network vnet create --resource-group vnet1 --name vnet1 --location eastus --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name tenonezero --resource-group vnet1 --vnet-name vnet1
az network vnet subnet create --address-prefix 10.1.1.0/24 --name tenoneone --resource-group vnet1 --vnet-name vnet1
az network public-ip create --name vnet1VMPubIP --resource-group vnet1 --location eastus --allocation-method Dynamic
az network nic create --resource-group vnet1 -n vnet1VMNIC --location eastus --subnet VM --private-ip-address 10.1.10.10 --vnet-name vnet1 --public-ip-address vnet1VMPubIP --ip-forwarding true
az vm create -n vnet1VM -g vnet1 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics vnet1VMNIC --no-wait 
az network public-ip create --name CSR1PublicIP --resource-group vnet1 --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g vnet1 --subnet tenonezero --vnet vnet1 --public-ip-address CSR1PublicIP --ip-forwarding true --private-ip-address 10.1.0.4
az network nic create --name CSR1InsideInterface -g vnet1 --subnet tenoneone --vnet vnet1 --ip-forwarding true --private-ip-address 10.1.1.4
az vm create --resource-group vnet1 --location eastus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network route-table create --name vm-rt --resource-group vnet1
az network route-table route create --name vm-rt --resource-group vnet1 --route-table-name vm-rt --address-prefix 10.200.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name vnet1 --resource-group vnet1 --route-table vm-rt
</pre>

**Build Hub Resource Groups, VNET and Subnets for VNET2.**
<pre lang="...">
az group create --name vnet2 --location eastus
az network vnet create --resource-group vnet2 --name vnet2 --location eastus --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name tenonezero --resource-group vnet2 --vnet-name vnet2
az network vnet subnet create --address-prefix 10.1.1.0/24 --name tenoneone --resource-group vnet2 --vnet-name vnet2
az network public-ip create --name vnet2VMPubIP --resource-group vnet2 --location eastus --allocation-method Dynamic
az network nic create --resource-group vnet2 -n vnet2VMNIC --location eastus --subnet VM --private-ip-address 10.1.10.10 --vnet-name vnet2 --public-ip-address vnet2VMPubIP --ip-forwarding true
az vm create -n vnet2VM -g vnet2 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics vnet2VMNIC --no-wait 
az network public-ip create --name CSR2PublicIP --resource-group vnet2 --idle-timeout 30 --allocation-method Static
az network nic create --name CSR2OutsideInterface -g vnet2 --subnet tenonezero --vnet vnet2 --public-ip-address CSR2PublicIP --ip-forwarding true --private-ip-address 10.1.0.4
az network nic create --name CSR2insideInterface -g vnet2 --subnet tenoneone --vnet vnet2 --ip-forwarding true --private-ip-address 10.1.1.4
az vm create --resource-group vnet2 --location eastus --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network route-table create --name vm-rt --resource-group vnet2
az network route-table route create --name vm-rt --resource-group vnet2 --route-table-name vm-rt --address-prefix 10.100.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name vnet2 --resource-group vnet2 --route-table vm-rt
</pre>

**Document public IPs for CSR1 and CSR2. SSH to both CSRs**
<pre lang="...">
az network public-ip show -g vnet1 -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show -g vnet2 -n CSR2PublicIP --query "{address: ipAddress}"
</pre>

**Paste in CSR1 config and change "CSR2PublicIP" to the PIP of CSR2**
<pre lang="...">
int gi1
no ip nat outside

ip access-list extended 100
 10 permit ip 10.1.0.0 0.0.255.255 any

ip nat pool vnet1 10.100.0.0 10.100.0.255 netmask 255.255.0.0 type match-host
ip nat inside source static 10.1.10.10 10.100.10.10
ip nat inside source list 100 pool vnet1

crypto ikev2 proposal to-csr2-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-csr2-policy 
 match address local 10.1.0.4
 proposal to-csr2-proposal
!
crypto ikev2 keyring to-csr2-keyring
 peer "CSR2PublicIP"
  address "CSR2PublicIP"
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile to-csr2-profile
 match address local 10.1.0.4
 match identity remote address 10.1.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr2-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-csr2-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-csr2-IPsecProfile
 set transform-set to-csr2-TransformSet 
 set ikev2-profile to-csr2-profile
!
interface Tunnel11
 ip address 192.168.1.1 255.255.255.255
 ip nat outside
 ip tcp adjust-mss 1350
 tunnel source 10.1.0.4
 tunnel mode ipsec ipv4
 tunnel destination "CSR2PublicIP"
 tunnel protection ipsec profile to-csr2-IPsecProfile
!
ip route 10.1.10.0 255.255.255.0 10.1.1.1
ip route 10.200.0.0 255.255.0.0 Tunnel11
!
interface GigabitEthernet2
 ip nat inside
</pre>

**Paste in CSR2 config and change "CSR1PublicIP" to the PIP of CSR2**
<pre lang="...">
int gi1
no ip nat outside

ip access-list extended 100
 10 permit ip 10.1.0.0 0.0.255.255 any
ip nat pool vnet2 10.200.0.0 10.200.0.255 netmask 255.255.0.0 type match-host
ip nat inside source list 100 pool vnet2
ip nat inside source static 10.1.10.10 10.200.10.10

crypto ikev2 proposal to-csr1-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-csr1-policy 
 match address local 10.1.0.4
 proposal to-csr1-proposal
!
crypto ikev2 keyring to-csr1-keyring
 peer "CSR1PublicIP"
  address "CSR1PublicIP"
  pre-shared-key Msft123Msft123
 !
crypto ikev2 profile to-csr1-profile
 match address local 10.1.0.4
 match identity remote address 10.1.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr1-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-csr1-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-csr1-IPsecProfile
 set transform-set to-csr1-TransformSet 
 set ikev2-profile to-csr1-profile

interface Tunnel11
 ip address 192.168.1.1 255.255.255.255
 ip nat outside
 ip tcp adjust-mss 1350
 tunnel source 10.1.0.4
 tunnel mode ipsec ipv4
 tunnel destination "CSR1PublicIP"
 tunnel protection ipsec profile to-csr1-IPsecProfile
!
ip route 10.1.10.0 255.255.255.0 10.1.1.1
ip route 10.100.0.0 255.255.0.0 Tunnel11
!
int gi2
ip nat inside
</pre>

