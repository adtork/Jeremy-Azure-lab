vasi github

# Site to site VPN between a CSR in Azure to 2 remote branches with overlapping address space. 

**Objectives and Initial Setup (Draft)**</br>
This lab guide shows how to configure site to site VPN between a CSR in Azure to 2 remote branches. The remote branches have overlapping address space and there's no ability to control NAT at each branch. All configurations must be implemented on the headend CSR in Azure. Branch A and B both have an address space of 10.100/16. The challenge is how to uniquely identify each branch tunnel and apply the correct NAT+routing. The lab will demonstrate how to make Branch A appear as 10.101 and Branch B appear as 10.102 post encryption on the Azure side CSR through the use of VRF-Aware Software Infrastructure (VASI) NAT. In this particular lab, the branches must initiate the connections. The test VM subnet on the Azure side will have UDRs pointed to an Azure Standard Load Balancer with a backend pool of the inside interfaces of CSR1 (future will have HA CSRs). The main goal of this lab is to quickly stand up a sandbox environment for functionality testing. The routing configration is only an example and could be solved many ways. The entire environment is built on Azure and does not require any hardware. </br>

**Topology**
![alt text](https:https://github.com/jwrightazure/lab/blob/master/images/vasi%20topo.PNG)

**Lab IPs**
![alt text](https:)

**BGP Layout**
![alt text](https)

**Requirements:**
- A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- If you are using Windows 10, you can install Bash shell on Ubuntu on Windows (http://www.windowscentral.com/how-install-bash-shell-command-line-windows-10).
- Azure CLI 2.0, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- Basic knowledge of Azure networking.

**Notes:**
This is for functionality testing purposes only and should not be considered production configurations. There are a number of configuration options (security policies/NSG/timers/CLI etc) and designs you can use, this is just an example to use as a baseline. Azure CLI is used to show the building blocks and order of operations to make the environment work. All CLI is provided so you can fit to your environment. Azure Cloud Shell is an option if you cannot install Azure CLI on your machine. A loopback address is added to each CSR for troubleshooting and validation purposes only. The lab uses CSR IOS-XE 16.10, syntax could very based on code levels. You may need to accept the legal agreement for the CSR BYOL demo image. Below is a Powershell example that you can run in Cloud Shell (in portal) to accept the agreement:
<pre lang="...">
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Step 1:** Login via Azure CLI. EX: I have Azure CLI on Windows 10. Open a command prompt and enter “az login”. It will prompt you for Azure credentials. All commands moving forward are done through Azure CLI and Cisco CLI via SSH.

**Step 2:** Create resource group, VNET + address space and subnets for CSR VNET in East US:
<pre lang="...">
az group create --name CSR --location "EastUS"
az network vnet create --name CSR --resource-group CSR --address-prefix 10.0.0.0/16
az network vnet subnet create --address-prefix 10.0.1.0/24 --name InsideSubnet --resource-group CSR --vnet-name CSR 
az network vnet subnet create --address-prefix 10.0.0.0/24 --name OutsideSubnet --resource-group CSR --vnet-name CSR
az network vnet subnet create --address-prefix 10.0.2.0/24 --name lbSubnet --resource-group CSR --vnet-name CSR
az network vnet subnet create --address-prefix 10.0.10.0/24 --name testVMSubnet --resource-group CSR --vnet-name CSR
</pre>

**Step 3:** Create internal standard load balancer, probe and rule for use in the CSR VNET. We will add backend pool members in future steps. We will be using SSH as the health probe for the inside interface of CSR1 with default timers. Enable floating IP and use of HA ports:
<pre lang="...">
az network lb create --name csr-lb --resource-group CSR --sku Standard --private-ip-address 10.0.2.100 --subnet lbsubnet --vnet-name CSR
az network lb address-pool create -g CSR --lb-name csr-lb -n csr-backendpool
az network lb probe create --resource-group CSR --lb-name csr-lb --name myHealthProbe --protocol tcp --port 22
az network lb rule create -g CSR --lb-name csr-lb -n MyHAPortsRule  --protocol All --frontend-port 0 --backend-port 0 --backend-pool-name csr-backendpool --floating-ip true --probe-name myHealthProbe
</pre>

**Step 5:** Create NSGs and Availability Set for the CSR. This can be tweked as needed:
<pre lang="...">
az network nsg create --resource-group CSR --name Azure-CSR-NSG --location EastUS
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-192 --access Allow --protocol "*" --direction Inbound --priority 135 --source-address-prefix 192.168.0.0/16 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-1 --access Allow --protocol "*" --direction Inbound --priority 136 --source-address-prefix 1.1.1.1/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-2 --access Allow --protocol "*" --direction Inbound --priority 137 --source-address-prefix 2.2.2.2/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-3 --access Allow --protocol "*" --direction Inbound --priority 138 --source-address-prefix 3.3.3.3/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-4 --access Allow --protocol "*" --direction Inbound --priority 139 --source-address-prefix 4.4.4.4/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az vm availability-set create --resource-group CSR --name myAvailabilitySet --platform-fault-domain-count 2 --platform-update-domain-count 2
</pre>

**Step 6:** Create Public IP, 2 NICs (outside/inside), assign static private IPs, apply NSG, add inside subnet NIC for CSR1 to the load balancer backend pool, creat CSR VM:
<pre lang="...">
az network public-ip create --name CSR1PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network public-ip create --name CSR1PublicIP2 --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR1OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR1PublicIP --private-ip-address 10.0.0.4 --ip-forwarding true --network-security-group Azure-CSR-NSG
az network nic create --name CSR1InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.4 --network-security-group Azure-CSR-NSG --lb-name csr-lb --lb-address-pools csr-backendpool
az vm create --resource-group CSR --location EastUS --name CSR1 --size Standard_DS3_v2 --nics CSR1OutsideInterface CSR1InsideInterface --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108 --admin-username azureuser --admin-password Msft123Msft123 --availability-set myAvailabilitySet --no-wait
</pre>

**Step 9:** Create resource group, VNET + address space and subnets for BranchA VNET in East US2:
<pre lang="...">
az group create --name BranchA --location "East US2"
az network vnet create --name BranchA --resource-group BranchA --address-prefix 10.100.0.0/16
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group BranchA --vnet-name BranchA
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group BranchA --vnet-name BranchA
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group BranchA --vnet-name BranchA
az network vnet subnet create --address-prefix 10.100.2.0/24 --name OutsideSubnet2 --resource-group BranchA --vnet-name BranchA
</pre>

**Step 10:** Create NSG and rules for the CSR2 interfaces. It allows SSH, UDP 500/4500, 10.x address and all outbound traffic. You can fine tune the NSG to your liking:
<pre lang="...">
az network nsg create --resource-group BranchA --name BranchA-CSR-NSG --location EastUS2
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name Allow-192 --access Allow --protocol "*" --direction Inbound --priority 135 --source-address-prefix 192.168.0.0/16 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name Allow-1s --access Allow --protocol "*" --direction Inbound --priority 136 --source-address-prefix 1.1.1.1/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name Allow-2s --access Allow --protocol "*" --direction Inbound --priority 137 --source-address-prefix 2.2.2.2/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name Allow-3s --access Allow --protocol "*" --direction Inbound --priority 138 --source-address-prefix 3.3.3.3/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name Allow-4s --access Allow --protocol "*" --direction Inbound --priority 139 --source-address-prefix 4.4.4.4/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchA --nsg-name BranchA-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>

**Step 11:** Create Public IP, 2 NICs (outside/inside), assign static private IPs, apply NSG, add inside subnet NIC for CSR2, create VM.
<pre lang="...">
az network public-ip create --name CSR2PublicIP --resource-group BranchA --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR2OutsideInterface -g BranchA --subnet OutsideSubnet --vnet BranchA --public-ip-address CSR2PublicIP --private-ip-address 10.100.0.4 --ip-forwarding true --network-security-group BranchA-CSR-NSG
az network nic create --name CSR2InsideInterface -g BranchA --subnet InsideSubnet --vnet BranchA --ip-forwarding true --private-ip-address 10.100.1.4 --network-security-group BranchA-CSR-NSG
az vm create --resource-group BranchA --location EastUS2 --name CSR2-BranchA --size Standard_DS3_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108  --admin-username azureuser --admin-password Msft123Msft123 --no-wait
</pre>

**Step 12:** Document public IP addresses assigned to CSR1 (Azure) and CSR2 (BranchA) used for tunnel termination
<pre lang="...">
az network public-ip show -g CSR -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show -g BranchA -n CSR2PublicIP --query "{address: ipAddress}"
</pre>

**Step 13:** SSH to CSR1 and paste in the following commands. Make sure to replace "CSR2PublicIP" with it's public IP:
<pre lang="...">
int gi1
no ip nat outside
int gi2
no ip nat inside

vrf definition VRF-A
 rd 101:101
 !
 address-family ipv4
 exit-address-family
!
vrf definition VRF-B
 rd 102:102
 !
 address-family ipv4
 exit-address-family
!
crypto ikev2 proposal to-BranchA-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-BranchA-policy 
 match address local 10.0.0.4
 proposal to-BranchA-proposal
!
crypto ikev2 keyring to-BranchA-keyring
 peer CSR2PublicIP
  address CSR2PublicIP
  pre-shared-key Msft123Msft123
 !
!
!
crypto ikev2 profile to-BranchA-profile
 match address local 10.0.0.4
 match identity remote address 10.100.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-BranchA-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set uni-perf esp-aes 256 esp-sha-hmac 
 mode tunnel
crypto ipsec transform-set to-BranchA-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-BranchA-IPsecProfile
 set transform-set to-BranchA-TransformSet 
 set ikev2-profile to-BranchA-profile
!
crypto ipsec profile vti-1
 set security-association lifetime kilobytes disable
 set security-association lifetime seconds 86400
 set transform-set uni-perf 
 set pfs group2
!

interface Loopback1
vrf forwarding VRF-A
 ip address 1.1.1.1 255.255.255.255
!
interface Tunnel11
 vrf forwarding VRF-A
 ip address 192.168.1.1 255.255.255.255
 ip nat inside
 ip tcp adjust-mss 1350
 tunnel source 10.0.0.4
 tunnel mode ipsec ipv4
 tunnel destination CSR2PublicIP
 tunnel protection ipsec profile to-BranchA-IPsecProfile
!
interface vasileft1
 vrf forwarding VRF-A
 ip address 172.31.255.0 255.255.255.254
 ip nat outside
 no keepalive
!
interface vasiright1
 ip address 172.31.255.1 255.255.255.254
 no keepalive
!
ip nat pool POOL-A 10.101.1.0 10.101.1.255 netmask 255.255.255.0 type match-host
ip nat inside source list 100 pool POOL-A vrf VRF-A
ip route 10.0.10.0 255.255.255.0 10.0.1.1
ip route 10.101.1.0 255.255.255.0 vasiright1
ip route 168.63.129.16 255.255.255.255 10.0.1.1
ip route 1.1.1.1 255.255.255.255 vasiright1
ip route vrf VRF-A 10.0.0.0 255.255.0.0 vasileft1
ip route vrf VRF-A 10.100.0.0 255.255.0.0 Tunnel11
ip route vrf VRF-A 192.168.1.3 255.255.255.255 Tunnel11
ip route vrf VRF-A 3.3.3.3 255.255.255.255 Tunnel11
access-list 100 permit ip 10.100.0.0 0.0.255.255 any
</pre>

**Step 14:** Create a test VM with appropriate NSGs. Azure VM will be 10.0.10.10, Branch A will be 10.100.10.10.
<pre lang="...">
az network nsg create --resource-group CSR --name Azure-VM-NSG --location EastUS
az network nsg rule create --resource-group CSR --nsg-name Azure-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group CSR --nsg-name Azure-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network public-ip create --name AzureVMPubIP --resource-group CSR --location EastUS --allocation-method Dynamic
az network nic create --resource-group CSR -n AzureVMNIC --location EastUS --subnet testVMSubnet --private-ip-address 10.0.10.10 --vnet-name CSR --public-ip-address AzureVMPubIP --network-security-group Azure-VM-NSG --ip-forwarding true
az vm create -n AzureVM -g CSR --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics AzureVMNIC --no-wait


az network nsg create --resource-group BranchA --name BranchA-VM-NSG --location EastUS2
az network nsg rule create --resource-group BranchA --nsg-name BranchA-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group BranchA --nsg-name BranchA-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network public-ip create --name BranchAVMPubIP --resource-group BranchA --location EastUS2 --allocation-method Dynamic
az network nic create --resource-group BranchA -n BranchAVMNIC --location EastUS2 --subnet testVMSubnet --private-ip-address 10.100.10.10 --vnet-name BranchA --public-ip-address BranchAVMPubIP --network-security-group BranchA-VM-NSG --ip-forwarding true
az vm create -n BranchAVM -g BranchA --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics BranchAVMNIC --no-wait
</pre>

**Step 15:** Create and apply route table in Azure VNET to send all traffic sourcing from 10.0.10/24 to the LB 10.0.2.100. If needed, add a route to the route table for your SIP with next hop Internet in order to SSH to VM.
<pre lang="...">
az network route-table create --name vm-rt --resource-group CSR
az network route-table route create --name vm-rt --resource-group CSR --route-table-name vm-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.2.100
az network vnet subnet update --name testVMSubnet --vnet-name CSR --resource-group CSR --route-table vm-rt
</pre>

**Step 16:** Create and apply route table in BranchA VNET to send all traffic sourcing from 10.100.10/24 to CSR2 inside interface 10.100.1.4. If needed, add a route to the route table for your SIP with next hop Internet in order to SSH to VM.
<pre lang="...">
az network route-table create --name vm-rt --resource-group BranchA
az network route-table route create --name vm-rt --resource-group BranchA --route-table-name vm-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name testVMSubnet --vnet-name BranchA --resource-group BranchA --route-table vm-rt
</pre>

**Step 17:** SSH to the VM Azure and turn on tcpdump for ICMP
<pre lang="...">
sudo passwd root
(you will be prompted to set a new password)
sudo sysctl -w net.ipv4.ip_forward=1
sudo tcpdump -i eth0 icmp
</pre>

**Step 17:** Ping Azure side VM (10.0.10.10) sourcing from CSR1. Default VRF will display the SIP as 10.0.1.4, sourcing from VRF-A loopback will show the SIP as 1.1.1.1.
<pre lang="...">
CSR1#ping 10.0.10.10
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.0.10.10, timeout is 2 seconds:
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 1/1/1 ms

CSR1#ping vrf VRF-A 10.0.10.10 source lo1
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.0.10.10, timeout is 2 seconds:
Packet sent with a source address of 1.1.1.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 1/1/2 ms
</pre>

**Step 18:** Connect to BranchA CSR and paste in the following commands. Make sure to replace "CSR1PublicIP" with it's public IP:
<pre lang="...">
int gi1
no ip nat outside
int gi2
no ip nat inside

!
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

interface Loopback1
 ip address 3.3.3.3 255.255.255.255
!
interface Tunnel11
 ip address 192.168.1.2 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.0.4
 tunnel mode ipsec ipv4
 tunnel destination CSR1PublicIP
 tunnel protection ipsec profile to-CSR1PublicIPsecProfile
!
ip route 10.100.10.0 255.255.255.0 10.100.1.1
ip route 192.168.1.1 255.255.255.255 Tunnel11
ip route 1.1.1.1 255.255.255.255 Tunnel11
ip route 10.0.0.0 255.255.0.0 Tunnel11
</pre>

**Step 19:** From the BranchA VM, you will now be able to ping 1.1.1.1 (CSR1 VRF-A loopback) and 10.0.10.10 (Azure side VM). The Azure VM will see the SIP as 10.101.x.x from the NAT pool even though the original SIP is 10.100.10.10.
<pre lang="...">
azureuser@BranchAVM:~$ ping 1.1.1.1
PING 1.1.1.1 (1.1.1.1) 56(84) bytes of data.
64 bytes from 1.1.1.1: icmp_seq=1 ttl=254 time=7.18 ms
64 bytes from 1.1.1.1: icmp_seq=2 ttl=254 time=6.76 ms
^C
--- 1.1.1.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 6.767/6.976/7.186/0.225 ms
azureuser@BranchAVM:~$ ping 10.0.10.10
PING 10.0.10.10 (10.0.10.10) 56(84) bytes of data.
64 bytes from 10.0.10.10: icmp_seq=1 ttl=61 time=7.96 ms
64 bytes from 10.0.10.10: icmp_seq=2 ttl=61 time=7.05 ms

azureuser@AzureVM:~$ sudo tcpdump -i eth0 icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
12:39:24.620264 IP 10.101.1.10 > AzureVM: ICMP echo request, id 2943, seq 1, length 64
12:39:24.620302 IP AzureVM > 10.101.1.10: ICMP echo reply, id 2943, seq 1, length 64
12:39:25.621928 IP 10.101.1.10 > AzureVM: ICMP echo request, id 2943, seq 2, length 64
12:39:25.621961 IP AzureVM > 10.101.1.10: ICMP echo reply, id 2943, seq 2, length 64
</pre>

**Step 20:** Create Branch B VNET, NSGs for CSR1/VM, route tables etc....notice the IP scheme layout is identical to branch 1 except in a different Azure region. Document public IP for CSR3 (Branch B).
<pre lang="...">
az group create --name BranchB --location "West US2"
az network vnet create --name BranchB --resource-group BranchB --address-prefix 10.100.0.0/16
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group BranchB --vnet-name BranchB
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group BranchB --vnet-name BranchB
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group BranchB --vnet-name BranchB
az network vnet subnet create --address-prefix 10.100.2.0/24 --name OutsideSubnet2 --resource-group BranchB --vnet-name BranchB

az network nsg create --resource-group BranchB --name BranchB-CSR-NSG --location WestUS2
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name Allow-192 --access Allow --protocol "*" --direction Inbound --priority 135 --source-address-prefix 192.168.0.0/16 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name Allow-1s --access Allow --protocol "*" --direction Inbound --priority 136 --source-address-prefix 1.1.1.1/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name Allow-2s --access Allow --protocol "*" --direction Inbound --priority 137 --source-address-prefix 2.2.2.2/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name Allow-3s --access Allow --protocol "*" --direction Inbound --priority 138 --source-address-prefix 3.3.3.3/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name Allow-4s --access Allow --protocol "*" --direction Inbound --priority 139 --source-address-prefix 4.4.4.4/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group BranchB --nsg-name BranchB-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"

az network public-ip create --name CSR3PublicIP --resource-group BranchB --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR3OutsideInterface -g BranchB --subnet OutsideSubnet --vnet BranchB --public-ip-address CSR3PublicIP --private-ip-address 10.100.0.4 --ip-forwarding true --network-security-group BranchB-CSR-NSG
az network nic create --name CSR3InsideInterface -g BranchB --subnet InsideSubnet --vnet BranchB --ip-forwarding true --private-ip-address 10.100.1.4 --network-security-group BranchB-CSR-NSG
az vm create --resource-group BranchB --location WestUS2 --name CSR3-BranchB --size Standard_DS3_v2 --nics CSR3OutsideInterface CSR3InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108  --admin-username azureuser --admin-password Msft123Msft123 --no-wait

az network nsg create --resource-group BranchB --name BranchB-VM-NSG --location WestUS2
az network nsg rule create --resource-group BranchB --nsg-name BranchB-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group BranchB --nsg-name BranchB-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network public-ip create --name BranchBVMPubIP --resource-group BranchB --location WestUS2 --allocation-method Dynamic
az network nic create --resource-group BranchB -n BranchBVMNIC --location WestUS2 --subnet testVMSubnet --private-ip-address 10.100.10.10 --vnet-name BranchB --public-ip-address BranchBVMPubIP --network-security-group BranchB-VM-NSG --ip-forwarding true
az vm create -n BranchBVM -g BranchB --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics BranchBVMNIC --no-wait

az network route-table create --name vm-rt --resource-group BranchB
az network route-table route create --name vm-rt --resource-group BranchB --route-table-name vm-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name testVMSubnet --vnet-name BranchB --resource-group BranchB --route-table vm-rt

az network public-ip show -g BranchB -n CSR3PublicIP --query "{address: ipAddress}"
</pre>

**Step 21:** Update CSR1 with VRF B for Branch B VPN and address overlap. Replace "CSR3PublicIP" with it's public IP. Add a route to the VM route table for your SIP if needed for SSH access.
<pre lang="...">
vrf definition VRF-B
 rd 102:102
 !
 address-family ipv4
 exit-address-family

crypto ikev2 proposal to-BranchB-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-BranchB-policy 
 match address local 10.0.0.4
 proposal to-BranchB-proposal
!
crypto ikev2 keyring to-BranchB-keyring
 peer CSR3PublicIP
  address CSR3PublicIP
  pre-shared-key Msft123Msft123
 !
!
!
crypto ikev2 profile to-BranchB-profile
 match address local 10.0.0.4
 match identity remote address 10.100.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-BranchB-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set uni-perf esp-aes 256 esp-sha-hmac 
 mode tunnel
crypto ipsec transform-set to-BranchB-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-BranchB-IPsecProfile
 set transform-set to-BranchB-TransformSet 
 set ikev2-profile to-BranchB-profile
!
crypto ipsec profile vti-1
 set security-association lifetime kilobytes disable
 set security-association lifetime seconds 86400
 set transform-set uni-perf 
 set pfs group2
!

interface Loopback2
vrf forwarding VRF-B
 ip address 2.2.2.2 255.255.255.255
!
interface Tunnel12
 vrf forwarding VRF-B
 ip address 192.168.10.1 255.255.255.255
 ip nat inside
 ip tcp adjust-mss 1350
 tunnel source 10.0.0.4
 tunnel mode ipsec ipv4
 tunnel destination CSR3PublicIP
 tunnel protection ipsec profile to-BranchB-IPsecProfile
!

!
interface vasileft2
 vrf forwarding VRF-B
 ip address 172.31.255.2 255.255.255.254
 ip nat outside
 no keepalive
!
interface vasiright2
 ip address 172.31.255.3 255.255.255.254
 no keepalive
!

ip nat pool POOL-B 10.102.1.0 10.102.1.255 netmask 255.255.255.0 type match-host
ip nat inside source list 101 pool POOL-B vrf VRF-B

ip route 10.102.1.0 255.255.255.0 vasiright2
ip route 2.2.2.2 255.255.255.255 vasiright2
ip route vrf VRF-B 10.0.0.0 255.255.0.0 vasileft2
ip route vrf VRF-B 10.100.0.0 255.255.0.0 Tunnel12
ip route vrf VRF-B 4.4.4.4 255.255.255.255 Tunnel12

access-list 101 permit ip 10.100.0.0 0.0.255.255 any
</pre>

**Step 22:** Validate cross VASI connectivity from VRF-B on CSR1 to Azure side VM 10.0.10.10
<pre lang="...">
CSR1#ping vrf VRF-B 10.0.10.10 source lo2
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.0.10.10, timeout is 2 seconds:
Packet sent with a source address of 2.2.2.2 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 1/1/1 ms

azureuser@AzureVM:~$ sudo tcpdump -i eth0 icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
12:55:34.063379 IP 2.2.2.2 > AzureVM: ICMP echo request, id 3, seq 0, length 80
12:55:34.063416 IP AzureVM > 2.2.2.2: ICMP echo reply, id 3, seq 0, length 80
</pre>

**Step 23:** Connect to CSR3 (Branch B) and paste in the following commands. Replace "CSR1PublicIP" with its public IP.
<pre lang="...">
int gi1
no ip nat outside
int gi2
no ip nat inside

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
!
!
crypto ikev2 profile to-azure-profile
 match address local 10.100.0.4
 match identity remote address 10.0.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-azure-keyring
 lifetime 3600
 dpd 10 5 on-demand

crypto ipsec transform-set to-azure-TransformSet esp-gcm 256 
 mode tunnel
!
!
crypto ipsec profile to-CSR1PublicIPsecProfile
 set transform-set to-azure-TransformSet 
 set ikev2-profile to-azure-profile

interface Loopback1
 ip address 4.4.4.4 255.255.255.255
!
interface Tunnel12
 ip address 192.168.10.2 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.0.4
 tunnel mode ipsec ipv4
 tunnel destination CSR1PublicIP
 tunnel protection ipsec profile to-CSR1PublicIPsecProfile
!
ip route 2.2.2.2 255.255.255.255 Tunnel12
ip route 10.0.0.0 255.255.0.0 Tunnel12
ip route 10.100.10.0 255.255.255.0 10.100.1.1
ip route 192.168.10.1 255.255.255.255 Tunnel12
</pre>

**Step 24:** SSH to Branch B VM. If you ping 10.0.10.10, the SIP will appear as 10.102.x.x even though Branch B is 10.100/16.
<pre lang="...">
azureuser@AzureVM:~$ sudo tcpdump -i eth0 icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
13:05:52.198624 IP 10.102.1.10 > AzureVM: ICMP echo request, id 2840, seq 1, length 64
13:05:52.198661 IP AzureVM > 10.102.1.10: ICMP echo reply, id 2840, seq 1, length 64
13:05:53.200449 IP 10.102.1.10 > AzureVM: ICMP echo request, id 2840, seq 2, length 64
13:05:53.200484 IP AzureVM > 10.102.1.10
</pre>
