# Site to site VPN between a CSR in Azure to 2 remote branches with overlapping address space. 

**Objectives and Initial Setup**</br>
This lab guide shows how to configure site to site VPN between a CSR in Azure to 2 remote branches. The remote branches have overlapping address space and there's no ability to control NAT at each branch. All configurations must be implemented on the headend CSR in Azure. Customer A and B both have an address space of 10.100/16. The challenge is how to uniquely identify each customer tunnel and apply the correct NAT+routing. The lab will demonstrate how to make Branch A appear as 10.101 and Branch B appear as 10.102 post encryption on the Azure side CSR through the use of VRF-Aware Software Infrastructure (VASI) NAT. Also, Customer A needs to connect to public IP 100.100.100.100 on port 81 and be NATd to 10.0.10.10 port 80 (in their own VRF). Customer B needs to connect to public IP 100.100.100.100 on port 81 and be NATd to 10.0.10.20 port 80 (in their own VRF). In this particular lab, the branches must initiate the connections. The main goal of this lab is to quickly stand up a sandbox environment for functionality testing. The routing configuration is only an example and could be solved many ways. The entire environment is built on Azure and does not require any hardware. </br>

**Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/s2s-overlap-v2.PNG)

**VASI Forwarding**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/s2svasiv2.PNG)

**Before deploying CSR in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands via Cloudshell**
<pre lang="...">
Sample Powershell:
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Build Hub Resource Groups, VNET and Subnets for Hub.**
<pre lang="...">
az group create --name Hub --location "EastUS"
az network vnet create --name Hub --resource-group Hub --address-prefix 10.0.0.0/16
az network vnet subnet create --address-prefix 10.0.1.0/24 --name InsideSubnet --resource-group Hub --vnet-name Hub 
az network vnet subnet create --address-prefix 10.0.0.0/24 --name OutsideSubnet --resource-group Hub --vnet-name Hub
az network vnet subnet create --address-prefix 10.0.10.0/24 --name testVMSubnet --resource-group Hub --vnet-name Hub
az network public-ip create --name HubVMPubIP --resource-group Hub --location eastus --allocation-method Dynamic
az network nic create --resource-group Hub -n HubVMNIC --location eastus --subnet testVMSubnet --private-ip-address 10.0.10.10 --vnet-name Hub --public-ip-address HubVMPubIP --ip-forwarding true
az vm create -n HubVM -g Hub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVMNIC --no-wait 
az network public-ip create --name CSR1PublicIP --resource-group Hub --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g Hub --subnet OutsideSubnet --vnet Hub --public-ip-address CSR1PublicIP --ip-forwarding true --private-ip-address 10.0.0.4
az network nic create --name CSR1InsideInterface -g Hub --subnet InsideSubnet --vnet Hub --ip-forwarding true --private-ip-address 10.0.1.4
az vm create --resource-group Hub --location eastus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network public-ip create --name HubVM2PubIP --resource-group Hub --location eastus --allocation-method Dynamic
az network nic create --resource-group Hub -n HubVM2NIC --location eastus --subnet testVMSubnet --private-ip-address 10.0.10.20 --vnet-name Hub --public-ip-address HubVM2PubIP --ip-forwarding true
az vm create -n HubVM2 -g Hub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVM2NIC --no-wait
az network route-table create --name vm-rt --resource-group Hub
az network route-table route create --name Customer-A --resource-group Hub --route-table-name vm-rt --address-prefix 10.101.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network route-table route create --name Customer-B --resource-group Hub --route-table-name vm-rt --address-prefix 10.102.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network vnet subnet update --name testVMSubnet --vnet-name Hub --resource-group Hub --route-table vm-rt
</pre>

**Build Hub Resource Groups, VNET and Subnets for VNET2.**
<pre lang="...">
az group create --name vnet2 --location eastus
az network vnet create --resource-group vnet2 --name vnet2 --location eastus --address-prefixes 10.100.0.0/16 --subnet-name VM --subnet-prefix 10.100.10.0/24
az network vnet subnet create --address-prefix 10.100.0.0/24 --name tenonezero --resource-group vnet2 --vnet-name vnet2
az network vnet subnet create --address-prefix 10.100.1.0/24 --name tenoneone --resource-group vnet2 --vnet-name vnet2
az network public-ip create --name vnet2VMPubIP --resource-group vnet2 --location eastus --allocation-method Dynamic
az network nic create --resource-group vnet2 -n vnet2VMNIC --location eastus --subnet VM --private-ip-address 10.100.10.10 --vnet-name vnet2 --public-ip-address vnet2VMPubIP --ip-forwarding true
az vm create -n vnet2VM -g vnet2 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics vnet2VMNIC --no-wait 
az network public-ip create --name CSR2PublicIP --resource-group vnet2 --idle-timeout 30 --allocation-method Static
az network nic create --name CSR2OutsideInterface -g vnet2 --subnet tenonezero --vnet vnet2 --public-ip-address CSR2PublicIP --ip-forwarding true --private-ip-address 10.100.0.4
az network nic create --name CSR2insideInterface -g vnet2 --subnet tenoneone --vnet vnet2 --ip-forwarding true --private-ip-address 10.100.1.4
az vm create --resource-group vnet2 --location eastus --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network route-table create --name vm-rt --resource-group vnet2
az network route-table route create --name vm-rt --resource-group vnet2 --route-table-name vm-rt --address-prefix 100.100.100.100/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name vm-rt2 --resource-group vnet2 --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name VM --vnet-name vnet2 --resource-group vnet2 --route-table vm-rt
</pre>

**Build Hub Resource Groups, VNET and Subnets for VNET3.**
<pre lang="...">
az group create --name vnet3 --location eastus
az network vnet create --resource-group vnet3 --name vnet3 --location eastus --address-prefixes 10.100.0.0/16 --subnet-name VM --subnet-prefix 10.100.10.0/24
az network vnet subnet create --address-prefix 10.100.0.0/24 --name tenonezero --resource-group vnet3 --vnet-name vnet3
az network vnet subnet create --address-prefix 10.100.1.0/24 --name tenoneone --resource-group vnet3 --vnet-name vnet3
az network public-ip create --name vnet3VMPubIP --resource-group vnet3 --location eastus --allocation-method Dynamic
az network nic create --resource-group vnet3 -n vnet3VMNIC --location eastus --subnet VM --private-ip-address 10.100.10.10 --vnet-name vnet3 --public-ip-address vnet3VMPubIP --ip-forwarding true
az vm create -n vnet3VM -g vnet3 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics vnet3VMNIC --no-wait 
az network public-ip create --name CSR3PublicIP --resource-group vnet3 --idle-timeout 30 --allocation-method Static
az network nic create --name CSR3OutsideInterface -g vnet3 --subnet tenonezero --vnet vnet3 --public-ip-address CSR3PublicIP --ip-forwarding true --private-ip-address 10.100.0.5
az network nic create --name CSR3insideInterface -g vnet3 --subnet tenoneone --vnet vnet3 --ip-forwarding true --private-ip-address 10.100.1.5
az vm create --resource-group vnet3 --location eastus --name CSR3 --size Standard_D2_v2 --nics CSR3OutsideInterface CSR3InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network route-table create --name vm-rt --resource-group vnet3
az network route-table route create --name vm-rt --resource-group vnet3 --route-table-name vm-rt --address-prefix 100.100.100.100/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.5
az network route-table route create --name vm-rt2 --resource-group vnet3 --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.5
az network vnet subnet update --name VM --vnet-name vnet3 --resource-group vnet3 --route-table vm-rt
</pre>

**Document all public IPs in Notepad**
<pre lang="...">
az network public-ip show -g Hub -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show -g Hub -n HubVMPubIP --query "{address: ipAddress}"
az network public-ip show -g Hub -n HubVM2PubIP --query "{address: ipAddress}"
az network public-ip show -g vnet2 -n CSR2PublicIP --query "{address: ipAddress}"
az network public-ip show -g vnet2 -n vnet2VMPubIP --query "{address: ipAddress}"
az network public-ip show -g vnet3 -n CSR3PublicIP --query "{address: ipAddress}"
az network public-ip show -g vnet3 -n vnet3VMPubIP --query "{address: ipAddress}"
</pre>

**SSH to both HubVM and HubVM2 and install NGINX**
<pre lang="...">
sudo apt-get update & sudo apt-get install nginx
</pre>

**SSH to CSR1. Paste in the below configs. Change references to the public IPs for CSR2 and CSR3.**
<pre lang="...">
vrf definition Customer-A
 rd 101:101
 !
 address-family ipv4
 exit-address-family
!
vrf definition Customer-B
 rd 102:102
 !
 address-family ipv4
 exit-address-family

crypto ikev2 proposal to-Customer-A-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
crypto ikev2 proposal to-Customer-B-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-Customer-A-policy 
 match address local 10.0.0.4
 proposal to-Customer-A-proposal
crypto ikev2 policy to-Customer-B-policy 
 match address local 10.0.0.4
 proposal to-Customer-B-proposal
!
crypto ikev2 keyring to-Customer-A-keyring
 peer CSR2PublicIP
  address CSR2PublicIP
  pre-shared-key Msft123Msft123
 !
!
crypto ikev2 keyring to-Customer-B-keyring
 peer CSR3PublicIP
  address CSR3PublicIP
  pre-shared-key Msft123Msft123
 !
!
!
crypto ikev2 profile to-Customer-A-profile
 match address local 10.0.0.4
 match identity remote address 10.100.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-Customer-A-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ikev2 profile to-Customer-B-profile
 match address local 10.0.0.4
 match identity remote address 10.100.0.5 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-Customer-B-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set uni-perf esp-aes 256 esp-sha-hmac 
 mode tunnel
crypto ipsec transform-set to-Customer-A-TransformSet esp-gcm 256 
 mode tunnel
crypto ipsec transform-set to-Customer-B-TransformSet esp-gcm 256 
 mode tunnel
!         
!
crypto ipsec profile to-Customer-A-IPsecProfile
 set transform-set to-Customer-A-TransformSet 
 set ikev2-profile to-Customer-A-profile
!
crypto ipsec profile to-Customer-B-IPsecProfile
 set transform-set to-Customer-B-TransformSet 
 set ikev2-profile to-Customer-B-profile
!
crypto ipsec profile vti-1
 set security-association lifetime kilobytes disable
 set security-association lifetime seconds 86400
 set transform-set uni-perf 
 set pfs group2
!
interface Tunnel11
 vrf forwarding Customer-A
 ip address 192.168.1.1 255.255.255.255
 ip nat inside
 ip tcp adjust-mss 1350
 tunnel source 10.0.0.4
 tunnel mode ipsec ipv4
 tunnel destination CSR2PublicIP
 tunnel protection ipsec profile to-Customer-A-IPsecProfile
!
interface Tunnel12
 vrf forwarding Customer-B
 ip address 192.168.1.1 255.255.255.255
 ip nat inside
 ip tcp adjust-mss 1350
 tunnel source 10.0.0.4
 tunnel mode ipsec ipv4
 tunnel destination CSR3PublicIP
 tunnel protection ipsec profile to-Customer-B-IPsecProfile
!
interface vasileft1
 vrf forwarding Customer-A
 ip address 172.31.255.0 255.255.255.254
 ip nat outside
 no keepalive
!         
interface vasileft2
 vrf forwarding Customer-B
 ip address 172.31.255.2 255.255.255.254
 ip nat outside
 no keepalive
!
interface vasiright1
 ip address 172.31.255.1 255.255.255.254
 no keepalive
!
interface vasiright2
 ip address 172.31.255.3 255.255.255.254
 no keepalive
!
ip nat pool POOL-A 10.101.1.0 10.101.1.255 netmask 255.255.255.0 type match-host
ip nat pool POOL-B 10.102.1.0 10.102.1.255 netmask 255.255.255.0 type match-host
ip nat inside source list 100 pool POOL-A vrf Customer-A
ip nat inside source list 101 pool POOL-B vrf Customer-B
ip nat inside source list GS_NAT_ACL interface GigabitEthernet1 vrf GS overload
ip nat outside source static tcp 10.0.10.10 80 100.100.100.100 81 vrf Customer-A extendable
ip nat outside source static tcp 10.0.10.20 80 100.100.100.100 81 vrf Customer-B extendable
ip route 0.0.0.0 0.0.0.0 10.0.0.1
ip route 10.0.10.0 255.255.255.0 10.0.1.1
ip route 10.101.1.0 255.255.255.0 vasiright1
ip route 10.102.1.0 255.255.255.0 vasiright2
ip route vrf Customer-A 10.0.0.0 255.255.0.0 vasileft1
ip route vrf Customer-A 10.100.0.0 255.255.0.0 Tunnel11
ip route vrf Customer-A 100.100.100.100 255.255.255.255 vasileft1
ip route vrf Customer-B 10.0.0.0 255.255.0.0 vasileft2
ip route vrf Customer-B 10.100.0.0 255.255.0.0 Tunnel12
ip route vrf Customer-B 100.100.100.100 255.255.255.255 vasileft2
!
ip access-list extended 100
 10 permit ip 10.100.0.0 0.0.255.255 any
ip access-list extended 101
 10 permit ip 10.100.0.0 0.0.255.255 any
</pre>

**SSH to CSR2. Paste in the below configs. Change references to the public IP for CSR1.**
<pre lang="...">
crypto ikev2 proposal to-azure-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-azure-policy 
 match address local 10.100.0.4
 proposal to-azure-proposal
!         
crypto ikev2 keyring to-azure-keyring
 peer CSR1PublicIP
  address CSR1PublicIP
  pre-shared-key Msft123Msft123
 !
crypto ikev2 profile to-azure-profile
 match address local 10.100.0.4
 match identity remote address 10.0.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-azure-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-azure-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-CSR1PublicIPsecProfile
 set transform-set to-azure-TransformSet 
 set ikev2-profile to-azure-profile
!
interface Tunnel11
 ip address 192.168.1.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.0.4
 tunnel mode ipsec ipv4
 tunnel destination CSR1PublicIP
 tunnel protection ipsec profile to-CSR1PublicIPsecProfile
!
ip route 0.0.0.0 0.0.0.0 10.100.0.1
ip route 10.0.0.0 255.255.0.0 Tunnel11
ip route 10.100.10.0 255.255.255.0 10.100.1.1
ip route 100.100.100.100 255.255.255.255 Tunnel11
</pre>

**SSH to CSR3. Paste in the below configs. Change references to the public IP for CSR1.**
<pre lang="...">
crypto ikev2 proposal to-azure-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-azure-policy 
 match address local 10.100.0.5
 proposal to-azure-proposal
!         
crypto ikev2 keyring to-azure-keyring
 peer CSR1PublicIP
  address CSR1PublicIP
  pre-shared-key Msft123Msft123
 !
crypto ikev2 profile to-azure-profile
 match address local 10.100.0.5
 match identity remote address 10.0.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-azure-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-azure-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-CSR1PublicIPsecProfile
 set transform-set to-azure-TransformSet 
 set ikev2-profile to-azure-profile
!
interface Tunnel11
 ip address 192.168.1.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.0.5
 tunnel mode ipsec ipv4
 tunnel destination CSR1PublicIP
 tunnel protection ipsec profile to-CSR1PublicIPsecProfile
!
ip route 0.0.0.0 0.0.0.0 10.100.0.1
ip route 10.0.0.0 255.255.0.0 Tunnel11
ip route 10.100.10.0 255.255.255.0 10.100.1.1
ip route 100.100.100.100 255.255.255.255 Tunnel11
</pre>

**Enable tcpdump on the test VMs in the Hub VNET**
<pre lang="...">
!on VM1
sudo tcpdump net 10.101.0.0/16 
!on VM2
sudo tcpdump net 10.102.0.0/16
</pre>

At this point, the VM in VNET2 can connect to 100.100.100.100 port 81 and will be NATd to 10.0.10.10 port 80. Hub VM1 will see the source as 10.101.1.0/24. It will also be able to ping 10.0.10.10. (Ex: from vm in vnet2, curl 100.100.100.100:81)

The VM in VNET3 can connect to 100.100.100.100 port 81 and will be NATd to 10.0.10.20 port 80. Hub VM2 will see the source as 10.102.1.0/24. It will also be able to ping 10.0.10.20. You can write ACL's to restrict traffic if needed. (Ex: from vm in vnet3, curl 100.100.100.100:81)
