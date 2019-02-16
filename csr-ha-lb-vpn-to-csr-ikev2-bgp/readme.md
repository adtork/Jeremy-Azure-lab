# HA CSRs in Azure with ECMP load shared IKEv2 tunnels
**Objectives and Initial Setup (Draft)**</br>
This lab guide shows how to configure highly available load balanced Cisco CSRs. Each CSR in Azure utilizes BGP over IKEv2 tunnel to a CSR located in a VNET that simulates an on prem environment. The test VM subnet on the Azure side will have UDRs pointed to an Azure Standard Load Balancer with a backend pool of the inside interfaces of CSR1 and CSR2. Traffic is load balanced across the 2 CSRs with the health probe monitoring the inside interfaces. In the event of a failure on CSR1 or CSR2, the load balancer will only steer traffic to the healthy CSR. BGP is also enabled between CSR1 and CSR2 providing tunnel redundancy if one of the tunnels goes down.
The test VMs will be able to ping each other, all CSR interfaces including VTIs/loopbacks in the event of a tunnel or router failure. BGP prefix filters could be used to lock down route advertisement if required. The main goal of this lab is to quickly stand up a sandbox environment for functionality testing. The routing configration is only an example and could be solved many ways. The entire environment is built on Azure and does not require any hardware. </br>

**Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/dual%20csr%20vpn.PNG)

**Lab IPs**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/labip.PNG)

**BGP Layout**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/dual-csrbgp-layout.PNG)

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

**Step 3:** Create internal standard load balancer, probe and rule for use in the CSR VNET. We will add backend pool members in future steps. We will be using SSH as the health probe for the inside interface of CSR1 and CSR2 with default timers. Enable floating IP and use of HA ports:
<pre lang="...">
az network lb create --name csr-lb --resource-group CSR --sku Standard --private-ip-address 10.0.2.100 --subnet lbsubnet --vnet-name CSR
az network lb address-pool create -g CSR --lb-name csr-lb -n csr-backendpool
az network lb probe create --resource-group CSR --lb-name csr-lb --name myHealthProbe --protocol tcp --port 22
az network lb rule create -g CSR --lb-name csr-lb -n MyHAPortsRule  --protocol All --frontend-port 0 --backend-port 0 --backend-pool-name csr-backendpool --floating-ip true --probe-name myHealthProbe
</pre>

**Step 4:** Create NSG and rules for the CSR1 and CSR2 interfaces. It allows SSH, UDP 500/4500, 10.x address and all outbound traffic. You can fine tune the NSG to your liking:
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
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>

**Step 5:** Create an Availability Set for CSR1 and CSR2:
<pre lang="...">
az vm availability-set create --resource-group CSR --name myAvailabilitySet --platform-fault-domain-count 2 --platform-update-domain-count 2
</pre>
**Step 6:** Create Public IP, 2 NICs (outside/inside), assign static private IPs, apply NSG, add inside subnet NIC for CSR1 to the load balancer backend pool:
<pre lang="...">
az network public-ip create --name CSR1PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR1OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR1PublicIP --private-ip-address 10.0.0.4 --ip-forwarding true --network-security-group Azure-CSR-NSG
az network nic create --name CSR1InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.4 --network-security-group Azure-CSR-NSG --lb-name csr-lb --lb-address-pools csr-backendpool
</pre>
**Step 7:** Create CSR1 VM and specify CSR image 16.10. Tie in the previously created NICs, SSH credentials, and add it to the Availability Set. You can locate the latest available image in a particular region using these steps:
<pre lang="...">
az vm create --resource-group CSR --location EastUS --name CSR1 --size Standard_DS3_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108 --admin-username azureuser --admin-password Msft123Msft123 --availability-set myAvailabilitySet --no-wait
</pre>
**Step 8:** Repeat step 6 and 7 for CSR2:
<pre lang="...">
az network public-ip create --name CSR2PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR2OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR2PublicIP --private-ip-address 10.0.0.5 --ip-forwarding true --network-security-group Azure-CSR-NSG
az network nic create --name CSR2InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.5 --network-security-group Azure-CSR-NSG --lb-name csr-lb --lb-address-pools csr-backendpool
az vm create --resource-group CSR --location EastUS --name CSR2 --size Standard_DS3_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108 --admin-username azureuser --admin-password Msft123Msft123 --availability-set myAvailabilitySet --no-wait
</pre>
**Step 9:** Create resource group, VNET + address space and subnets for onprem VNET in East US2:
<pre lang="...">
az group create --name onprem --location "East US2"
az network vnet create --name onprem --resource-group onprem --address-prefix 10.100.0.0/16
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.2.0/24 --name OutsideSubnet2 --resource-group onprem --vnet-name onprem
</pre>
**Step 10:** Create NSG and rules for the CSR2 interfaces. It allows SSH, UDP 500/4500, 10.x address and all outbound traffic. You can fine tune the NSG to your liking:
<pre lang="...">
az network nsg create --resource-group onprem --name onprem-CSR-NSG --location EastUS2
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-192 --access Allow --protocol "*" --direction Inbound --priority 135 --source-address-prefix 192.168.0.0/16 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-1s --access Allow --protocol "*" --direction Inbound --priority 136 --source-address-prefix 1.1.1.1/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-2s --access Allow --protocol "*" --direction Inbound --priority 137 --source-address-prefix 2.2.2.2/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-3s --access Allow --protocol "*" --direction Inbound --priority 138 --source-address-prefix 3.3.3.3/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>
**Step 11:** Create Public IP, 2 NICs (outside/inside), assign static private IPs, apply NSG, add inside subnet NIC for CSR3 to the load balancer backend pool. Note- there is a second NIC with a public IP. We will terminate the IKEv2 tunnel from CSR1 on CSR3PublicIP and the tunnel from CSR2 will terminate on CSR3PublicIP2. More on that later:
<pre lang="...">
az network public-ip create --name CSR3PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static --sku standard
az network public-ip create --name CSR3PublicIP2 --resource-group onprem --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR3OutsideInterface -g onprem --subnet OutsideSubnet --vnet onprem --public-ip-address CSR3PublicIP --private-ip-address 10.100.0.4 --ip-forwarding true --network-security-group onprem-CSR-NSG
az network nic create --name CSR3InsideInterface -g onprem --subnet InsideSubnet --vnet onprem --ip-forwarding true --private-ip-address 10.100.1.4 --network-security-group onprem-CSR-NSG
az network nic create --name CSR3OutsideInterface2 -g onprem --subnet OutsideSubnet2 --vnet onprem --public-ip-address CSR3PublicIP2 --private-ip-address 10.100.2.4 --ip-forwarding true --network-security-group onprem-CSR-NSG
</pre>
**Step 12:** Create CSR2 VM and specify CSR image 16.10. Tie in the previously created NICs, and SSH credentials:
<pre lang="...">
az vm create --resource-group onprem --location EastUS2 --name CSR3 --size Standard_DS3_v2 --nics CSR3OutsideInterface CSR3OutsideInterface2 CSR3InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108  --admin-username azureuser --admin-password Msft123Msft123 --no-wait
</pre>
**Step 13:** It’s highly recommended that you run the following commands to gather the public IP addresses. Copy the output into notepad or editor to reference later
<pre lang="...">
az network public-ip show -g CSR -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show -g CSR -n CSR2PublicIP --query "{address: ipAddress}"
az network public-ip show -g onprem -n CSR3PublicIP --query "{address: ipAddress}"
az network public-ip show -g onprem -n CSR3PublicIP2 --query "{address: ipAddress}"
</pre>
**Step 14:** SSH to CSR1PublicIP. Username=azureuser pw=Msft123Msft123
Paste in the following commands AFTER replacing all references to “CSR3PublicIP” and "CSR2PublicIP" with the public IP address of CSR3PublicIP and CSR2PublicIP:
<pre lang="...">
int gi1
no ip nat outside
int gi2
no ip nat inside
!
crypto isakmp policy 1
 encr aes 256
 authentication pre-share
crypto isakmp key Msft123Msft123 address 0.0.0.0  
!
!
crypto ipsec transform-set uni-perf esp-aes 256 esp-sha-hmac 
 mode tunnel
!
!
crypto ipsec profile vti-1
 set security-association lifetime kilobytes disable
 set security-association lifetime seconds 86400
 set transform-set uni-perf 
 set pfs group2
!
!
interface Tunnel1
 ip address 192.168.101.1 255.255.255.252
 load-interval 30
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination CSR2PublicIP
 tunnel protection ipsec profile vti-1


!ikev2 proposal can be changed to match your requirements
crypto ikev2 proposal to-csr3-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-csr3-policy 
 match address local 10.0.0.4
 proposal to-csr3-proposal
!
crypto ikev2 keyring to-csr3-keyring
 peer CSR3PublicIP
  address CSR3PublicIP
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile to-csr3-profile
 match address local 10.0.0.4
 match identity remote address 10.100.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr3-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-csr3-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-csr3-IPsecProfile
 set transform-set to-csr3-TransformSet 
 set ikev2-profile to-csr3-profile
!
interface Loopback1
 ip address 1.1.1.1 255.255.255.255
!
interface Tunnel11
 ip address 192.168.1.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.0.0.4
 tunnel mode ipsec ipv4
 tunnel destination CSR3PublicIP
 tunnel protection ipsec profile to-csr3-IPsecProfile
!

router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 neighbor 192.168.1.3 remote-as 65003
 neighbor 192.168.1.3 ebgp-multihop 255
 neighbor 192.168.1.3 update-source Tunnel11
 neighbor 192.168.101.2 remote-as 65001
 !
 address-family ipv4
  neighbor 192.168.1.3 soft-reconfiguration inbound 
  neighbor 192.168.101.2 soft-reconfiguration inbound
  network 1.1.1.1 mask 255.255.255.255
  network 10.0.0.0 mask 255.255.0.0
  network 192.168.1.1 mask 255.255.255.255
  neighbor 192.168.1.3 activate
  neighbor 192.168.101.2 activate
  neighbor 192.168.101.2 next-hop-self
  network 192.168.101.0 mask 255.255.255.252
 exit-address-family

!summary route to null for BGP propagation
ip route 10.0.0.0 255.255.0.0 Null0
!route for test vm subnet back out the inside interface. .1 is the Azure Fabric
ip route 10.0.10.0 255.255.255.0 10.0.1.1
!route Azure load balancer probes back out the inside interface
ip route 168.63.129.16 255.255.255.255 10.0.1.1
!route CSR3 VTI/tunnel11 IP over the tunnel to form BGP peering
ip route 192.168.1.3 255.255.255.255 Tunnel11
</pre>
**Step 15:** SSH to CSR2PublicIP. Username=azureuser pw=Msft123Msft123 
Paste in the following commands AFTER replacing all references to “CSR3PublicIP2” and "CSR1Public" with the public IP address of CSR3PublicIP2 and CSR1PublicIp:
<pre lang="...">
int gi1
no ip nat outside
int gi2
no ip nat inside
!
crypto isakmp policy 1
 encr aes 256
 authentication pre-share
crypto isakmp key Msft123Msft123 address 0.0.0.0  
!
!
crypto ipsec transform-set uni-perf esp-aes 256 esp-sha-hmac 
 mode tunnel
!
!
crypto ipsec profile vti-1
 set security-association lifetime kilobytes disable
 set security-association lifetime seconds 86400
 set transform-set uni-perf 
 set pfs group2
!
!
interface Tunnel1
 ip address 192.168.101.2 255.255.255.252
 load-interval 30
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination CSR1PublicIP
 tunnel protection ipsec profile vti-1

crypto ikev2 proposal to-csr3-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-csr3-policy 
 match address local 10.0.0.5
 proposal to-csr3-proposal
!
crypto ikev2 keyring to-csr3-keyring
 peer CSR3PublicIP2
  address CSR3PublicIP2
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile to-csr3-profile
 match address local 10.0.0.5
 match identity remote address 10.100.2.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr3-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-csr3-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-csr3-IPsecProfile
 set transform-set to-csr3-TransformSet 
 set ikev2-profile to-csr3-profile
!
interface Loopback1
 ip address 2.2.2.2 255.255.255.255
!
interface Tunnel11
 ip address 192.168.1.2 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.0.0.5
 tunnel mode ipsec ipv4
 tunnel destination CSR3PublicIP2
 tunnel protection ipsec profile to-csr3-IPsecProfile
!
router bgp 65001
 bgp log-neighbor-changes
 bgp router-id 2.2.2.2
 neighbor 192.168.1.33 remote-as 65003
 neighbor 192.168.1.33 ebgp-multihop 255
 neighbor 192.168.1.33 update-source Tunnel11
 neighbor 192.168.101.1 remote-as 65001
 !
 address-family ipv4
  neighbor 192.168.1.33 soft-reconfiguration inbound 
  neighbor 192.168.101.2 soft-reconfiguration inbound 
  network 2.2.2.2 mask 255.255.255.255
  network 10.0.0.0 mask 255.255.0.0
  network 192.168.1.2 mask 255.255.255.255
  neighbor 192.168.1.33 activate
  neighbor 192.168.101.1 activate
  neighbor 192.168.101.1 next-hop-self
  network 192.168.101.0 mask 255.255.255.252
 exit-address-family
!
ip route 10.0.0.0 255.255.0.0 Null0
ip route 10.0.10.0 255.255.255.0 10.0.1.1
ip route 168.63.129.16 255.255.255.255 10.0.1.1
ip route 192.168.1.33 255.255.255.255 Tunnel11
</pre>
**Step 16:** SSH to CSR3PublicIP. Username=azureuser pw=Msft123Msft123
Paste in the following commands AFTER replacing all references to “CSR1PublicIP” and “CSR2PublicIP” with the public IP address of CSR1PublicIP and CSR2PublicIP.
<pre lang="...">
int gi1
no ip nat outside
int gi2
no ip nat inside
int gi3
ip address dhcp
no shut
!
crypto ikev2 proposal to-csr1-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
crypto ikev2 proposal to-csr2-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-csr1-policy 
 match address local 10.100.0.4
 proposal to-csr1-proposal
crypto ikev2 policy to-csr2-policy 
 match address local 10.100.2.4
 proposal to-csr1-proposal
!
crypto ikev2 keyring to-csr1-keyring
 peer CSR1PublicIP
  address CSR1PublicIP
  pre-shared-key Msft123Msft123
 !
!
crypto ikev2 keyring to-csr2-keyring
 peer CSR2PublicIP
  address CSR2PublicIP
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile to-csr1-profile
 match address local 10.100.0.4
 match identity remote address 10.0.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr1-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ikev2 profile to-csr2-profile
 match address local 10.100.2.4
 match identity remote address 10.0.0.5 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr2-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-csr1-TransformSet esp-gcm 256 
 mode tunnel
crypto ipsec transform-set to-csr2-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-CSR1PublicIPsecProfile
 set transform-set to-csr1-TransformSet 
 set ikev2-profile to-csr1-profile
!
crypto ipsec profile to-CSR2PublicIPsecProfile
 set transform-set to-csr2-TransformSet 
 set ikev2-profile to-csr2-profile
!
interface Loopback1
 ip address 3.3.3.3 255.255.255.255
!
interface Tunnel11
 ip address 192.168.1.3 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.0.4
 tunnel mode ipsec ipv4
 tunnel destination CSR1PublicIP
 tunnel protection ipsec profile to-CSR1PublicIPsecProfile
!
interface Tunnel12
 ip address 192.168.1.33 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.2.4
 tunnel mode ipsec ipv4
 tunnel destination CSR2PublicIP
 tunnel protection ipsec profile to-CSR2PublicIPsecProfile


router bgp 65003
 bgp log-neighbor-changes
 bgp router-id 3.3.3.3
 neighbor 192.168.1.1 remote-as 65001
 neighbor 192.168.1.1 ebgp-multihop 255
 neighbor 192.168.1.1 update-source Tunnel11
 neighbor 192.168.1.2 remote-as 65001
 neighbor 192.168.1.2 ebgp-multihop 255
 neighbor 192.168.1.2 update-source Tunnel12
 !
 address-family ipv4
 maximum-paths 4
  neighbor 192.168.1.1 soft-reconfiguration inbound 
  neighbor 192.168.1.2 soft-reconfiguration inbound 
  network 3.3.3.3 mask 255.255.255.255
  network 10.100.0.0 mask 255.255.0.0
  network 192.168.1.3 mask 255.255.255.255
  network 192.168.1.33 mask 255.255.255.255
  neighbor 192.168.1.1 activate
  neighbor 192.168.1.2 activate
 exit-address-family

ip route 10.100.0.0 255.255.0.0 Null0
ip route 10.100.10.0 255.255.255.0 10.100.1.1
ip route CSR2PublicIP 255.255.255.255 10.100.2.1
ip route 192.168.1.1 255.255.255.255 Tunnel11
ip route 192.168.1.2 255.255.255.255 Tunnel12
</pre>
**Step 16:** At this point you should have an IKEv2 tunnel from CSR1 and CSR2 to CSR3. Here are a few commands and expected outputs. It’s important you have reachability across the tunnels before moving onto step 17.
<pre lang="...">
CSR3#sh ip bgp sum
BGP router identifier 3.3.3.3, local AS number 65003
BGP table version is 82, main routing table version 82
10 network entries using 2480 bytes of memory
16 path entries using 2304 bytes of memory
6 multipath network entries and 12 multipath paths
3/3 BGP path/bestpath attribute entries using 864 bytes of memory
1 BGP AS-PATH entries using 24 bytes of memory
0 BGP route-map cache entries using 0 bytes of memory
0 BGP filter-list cache entries using 0 bytes of memory
BGP using 5672 total bytes of memory
BGP activity 15/5 prefixes, 33/17 paths, scan interval 60 secs
10 networks peaked at 23:35:37 Feb 15 2019 UTC (00:40:15.497 ago).

Neighbor        V           AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd
192.168.1.1     4        65001      23      28       82    0    0 00:11:58        6
192.168.1.2     4        65001      54      59       82    0    0 00:41:26        6
CSR3#sh ip bgp
BGP table version is 82, local router ID is 3.3.3.3
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *m   1.1.1.1/32       192.168.1.2                            0 65001 i
 *>                    192.168.1.1              0             0 65001 i
 *>   2.2.2.2/32       192.168.1.1                            0 65001 i
 *m                    192.168.1.2              0             0 65001 i
 *>   3.3.3.3/32       0.0.0.0                  0         32768 i
 *>   10.0.0.0/16      192.168.1.1              0             0 65001 i
 *m                    192.168.1.2              0             0 65001 i
 *>   10.100.0.0/16    0.0.0.0                  0         32768 i
 rm   192.168.1.1/32   192.168.1.2                            0 65001 i
 r>                    192.168.1.1              0             0 65001 i
 rm   192.168.1.2/32   192.168.1.2              0             0 65001 i
 r>                    192.168.1.1                            0 65001 i
 *>   192.168.1.3/32   0.0.0.0                  0         32768 i
 *>   192.168.1.33/32  0.0.0.0                  0         32768 i
 *>   192.168.101.0/30 192.168.1.1              0             0 65001 i
 *m                    192.168.1.2              0             0 65001 i
CSR3#sh ip route bgp
Codes: L - local, C - connected, S - static, R - RIP, M - mobile, B - BGP
       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area 
       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2
       E1 - OSPF external type 1, E2 - OSPF external type 2, m - OMP
       n - NAT, Ni - NAT inside, No - NAT outside, Nd - NAT DIA
       i - IS-IS, su - IS-IS summary, L1 - IS-IS level-1, L2 - IS-IS level-2
       ia - IS-IS inter area, * - candidate default, U - per-user static route
       H - NHRP, G - NHRP registered, g - NHRP registration summary
       o - ODR, P - periodic downloaded static route, l - LISP
       a - application route
       + - replicated route, % - next hop override, p - overrides from PfR

Gateway of last resort is 10.100.0.1 to network 0.0.0.0

      1.0.0.0/32 is subnetted, 1 subnets
B        1.1.1.1 [20/0] via 192.168.1.2, 00:06:14
                 [20/0] via 192.168.1.1, 00:06:14
      2.0.0.0/32 is subnetted, 1 subnets
B        2.2.2.2 [20/0] via 192.168.1.2, 00:06:14
                 [20/0] via 192.168.1.1, 00:06:14
      10.0.0.0/8 is variably subnetted, 9 subnets, 3 masks
B        10.0.0.0/16 [20/0] via 192.168.1.2, 00:06:14
                     [20/0] via 192.168.1.1, 00:06:14
      192.168.101.0/30 is subnetted, 1 subnets
B        192.168.101.0 [20/0] via 192.168.1.2, 00:06:14
                       [20/0] via 192.168.1.1, 00:06:14
CSR3#sh ip bgp neighbors 192.168.1.1    
BGP neighbor is 192.168.1.1,  remote AS 65001, external link
  BGP version 4, remote router ID 1.1.1.1
  BGP state = Established, up for 00:12:29
####truncated

CSR3#sh ip bgp neighbors 192.168.1.1 advertised-routes 
BGP table version is 82, local router ID is 3.3.3.3
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       192.168.1.1              0             0 65001 i
 *>   2.2.2.2/32       192.168.1.1                            0 65001 i
 *>   3.3.3.3/32       0.0.0.0                  0         32768 i
 *>   10.0.0.0/16      192.168.1.1              0             0 65001 i
 *>   10.100.0.0/16    0.0.0.0                  0         32768 i
 r>   192.168.1.1/32   192.168.1.1              0             0 65001 i
 r>   192.168.1.2/32   192.168.1.1                            0 65001 i
 *>   192.168.1.3/32   0.0.0.0                  0         32768 i
 *>   192.168.1.33/32  0.0.0.0                  0         32768 i
 *>   192.168.101.0/30 192.168.1.1              0             0 65001 i

CSR3#sh ip bgp neighbors 192.168.1.2 advertised-routes 
BGP table version is 82, local router ID is 3.3.3.3
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       192.168.1.1              0             0 65001 i
 *>   2.2.2.2/32       192.168.1.1                            0 65001 i
 *>   3.3.3.3/32       0.0.0.0                  0         32768 i
 *>   10.0.0.0/16      192.168.1.1              0             0 65001 i
 *>   10.100.0.0/16    0.0.0.0                  0         32768 i
 r>   192.168.1.1/32   192.168.1.1              0             0 65001 i
 r>   192.168.1.2/32   192.168.1.1                            0 65001 i
 *>   192.168.1.3/32   0.0.0.0                  0         32768 i
 *>   192.168.1.33/32  0.0.0.0                  0         32768 i
 *>   192.168.101.0/30 192.168.1.1              0             0 65001 i

Total number of prefixes 10 
CSR3#sh tcp brief
TCB       Local Address               Foreign Address             (state)
7FE78EE10030  192.168.1.33.19751         192.168.1.2.179             ESTAB
7FE78B5C3FC0  192.168.1.3.179            192.168.1.1.27247           ESTAB
7FE7928069F8  10.100.0.4.22              47.196.196.91.60396         ESTAB

CSR3#sh run | s router bgp
router bgp 65003
 bgp router-id 3.3.3.3
 bgp log-neighbor-changes
 neighbor 192.168.1.1 remote-as 65001
 neighbor 192.168.1.1 ebgp-multihop 255
 neighbor 192.168.1.1 update-source Tunnel11
 neighbor 192.168.1.2 remote-as 65001
 neighbor 192.168.1.2 ebgp-multihop 255
 neighbor 192.168.1.2 update-source Tunnel12
 !
 address-family ipv4
  network 3.3.3.3 mask 255.255.255.255
  network 10.100.0.0 mask 255.255.0.0
  network 192.168.1.3 mask 255.255.255.255
  network 192.168.1.33 mask 255.255.255.255
  neighbor 192.168.1.1 activate
  neighbor 192.168.1.2 activate
  maximum-paths 4
 exit-address-family

CSR3#sh run | s route 
router bgp 65003
 bgp router-id 3.3.3.3
 bgp log-neighbor-changes
 neighbor 192.168.1.1 remote-as 65001
 neighbor 192.168.1.1 ebgp-multihop 255
 neighbor 192.168.1.1 update-source Tunnel11
 neighbor 192.168.1.2 remote-as 65001
 neighbor 192.168.1.2 ebgp-multihop 255
 neighbor 192.168.1.2 update-source Tunnel12
 !
 address-family ipv4
  network 3.3.3.3 mask 255.255.255.255
  network 10.100.0.0 mask 255.255.0.0
  network 192.168.1.3 mask 255.255.255.255
  network 192.168.1.33 mask 255.255.255.255
  neighbor 192.168.1.1 activate
  neighbor 192.168.1.2 activate
  maximum-paths 4
 exit-address-family
ip route 10.100.0.0 255.255.0.0 Null0
ip route 10.100.10.0 255.255.255.0 10.100.1.1
ip route 20.185.209.94 255.255.255.255 10.100.2.1
ip route 192.168.1.1 255.255.255.255 Tunnel11
ip route 192.168.1.2 255.255.255.255 Tunnel12
ip route vrf GS 0.0.0.0 0.0.0.0 GigabitEthernet1 10.100.0.1 global
CSR3#
</pre>

**Step 17:** Create NSG for the test VM in the CSR VNET
<pre lang="...">
az network nsg create --resource-group CSR --name Azure-VM-NSG --location EastUS
az network nsg rule create --resource-group CSR --nsg-name Azure-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group CSR --nsg-name Azure-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>
**Step 18:** Create the Public IP/NIC/private IP/NSG/VM in the CSR VNET:
<pre lang="...">
az network public-ip create --name AzureVMPubIP --resource-group CSR --location EastUS --allocation-method Dynamic
az network nic create --resource-group CSR -n AzureVMNIC --location EastUS --subnet testVMSubnet --private-ip-address 10.0.10.10 --vnet-name CSR --public-ip-address AzureVMPubIP --network-security-group Azure-VM-NSG --ip-forwarding true
az vm create -n AzureVM -g CSR --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics AzureVMNIC --no-wait
</pre>
**Step 19:** Repeat steps 17 and 18 for the VM in the onprem VNET:
<pre lang="...">
az network nsg create --resource-group onprem --name onprem-VM-NSG --location EastUS2
az network nsg rule create --resource-group onprem --nsg-name onprem-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group onprem --nsg-name onprem-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network public-ip create --name onpremVMPubIP --resource-group onprem --location EastUS2 --allocation-method Dynamic
az network nic create --resource-group onprem -n onpremVMNIC --location EastUS2 --subnet testVMSubnet --private-ip-address 10.100.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --network-security-group onprem-VM-NSG --ip-forwarding true
az vm create -n onpremVM -g onprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait
</pre>
**Step 20:** Create route table for the onprem VNET and steer all necessary traffic to 10.100.1.4 (CSR# inside). You will need to add a static route to each route table pointing your machine IP to next hop Internet if you want to SSH to the VMs from the Internet.
<pre lang="...">
az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name testVMSubnet --vnet-name onprem --resource-group onprem --route-table vm-rt
</pre>
**Step 21:** Create route table for the onprem VNET and steer all necessary traffic to 10.0.2.100 (LB VIP):
<pre lang="...">
az network route-table create --name vm-rt --resource-group CSR
az network route-table route create --name vm-rt --resource-group CSR --route-table-name vm-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.2.100
az network vnet subnet update --name testVMSubnet --vnet-name CSR --resource-group CSR --route-table vm-rt
</pre>
**Step 22:** Test scenario ideas:<br>
-Run multiple traceroutes sourcing from the Azure side VM to the on prem VM. You will see that the first hop hashes between 10.0.1.4 and 10.0.1.5. Initiate ping from VM to VM and:
-reload CSR1, packet drop should be minimal if flow was hashed to CSR1
- once CSR1 is back up with BGP peering to CSR3, drop int tu11 on CSR1. This will show that the traffic continues to flow regardless of which CSR the LB chooses since there is a BGP relationship between CSR1 and CSR2. 
- initiate the previous 2 tests, this time using CSR2
