# Azure Networking Lab- Active/Active Azure VPN Gateway VPN to On Prem ASA- IKEv2+BGP

This lab guide illustrates how to build active/active IPSEC VPN tunnels w/IKEv2 between a Cisco ASAv and the Azure VPN gateway with BGP. This is for lab testing purposes only and should not be considered production configuration. NAT, ACLs and security proposals shown can be narrowed down if need be. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. The on prem VNET is to simulate on prem connectivity and requires no hardware.

Assumptions:
- A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Latest Azure CLI, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 

# Key points with Active/Active Azure VPN Gateways
- Azure VPN gateway will have two public IP addresses. Portal will show 1x VNG.
- Customer side must have 2 public IP addresses. 

# Base Topology
The lab deploys an active/active Azure VPN gateway into a VNET. We will also deploy a Cisco ASA in a seperate VNET to simulate on prem.
![alt text](https://github.com/jwrightazure/lab/blob/master/images/active%20active%20vpn%20to%20asa%20topo.PNG)

# BGP peering 
![alt text](https://github.com/jwrightazure/lab/blob/master/images/active%20active%20vpn%20to%20asa%20bgp.PNG)

**Build Resource Groups, VNETs and Subnets**
az group create --name Hub --location eastus
az network vnet create --resource-group Hub --name Hub --location eastus --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group Hub --vnet-name Hub

**Build Resource Groups, VNETs and Subnets to simulate on prem**
az group create --name onprem --location eastus
az network vnet create --resource-group onprem --name onprem --location eastus --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.2.0/24 --name twonet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.3.0/24 --name threenet --resource-group onprem --vnet-name onprem

**Build Public IPs for Azure VPN Gateway**
az network public-ip create --name Azure-VNGpubip1 --resource-group Hub --allocation-method Dynamic
az network public-ip create --name Azure-VNGpubip2 --resource-group Hub --allocation-method Dynamic

**Build Azure active/active VPN Gateways. Deployment will take some time. Azure side BGP ASN is 65001. Portal will only display 1 VNG with multiple IPs.**
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip1 Azure-VNGpubip2 --resource-group Hub --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65001

**Before deploying ASA in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a ASA in the portal or Powershell commands. This is a sample for a Cisco CSR**
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept

**Build ASAv in the on prem VNET. It specifies a specific image that you can change**
az network public-ip create --name ASA1MgmtIP --resource-group onprem --idle-timeout 30 --allocation-method Static
az network public-ip create --name ASA1VPNPublicIP1 --resource-group onprem --idle-timeout 30 --allocation-method Static
az network public-ip create --name ASA1VPNPublicIP2 --resource-group onprem --idle-timeout 30 --allocation-method Static
az network nic create --name ASA1MgmtInterface -g onprem --subnet threenet --vnet onprem --public-ip-address ASA1MgmtIP --private-ip-address 10.1.3.4 --ip-forwarding true
az network nic create --name ASA1OutsideInterface -g onprem --subnet zeronet --vnet onprem --public-ip-address ASA1VPNPublicIP1 --private-ip-address 10.1.0.4 --ip-forwarding true
az network nic create --name ASA1InsideInterface -g onprem --subnet onenet --vnet onprem --private-ip-address 10.1.1.4 --ip-forwarding true
az network nic create --name ASA1OutsideInterface2 -g onprem --subnet twonet --vnet onprem --public-ip-address ASA1VPNPublicIP2 --private-ip-address 10.1.2.4 --ip-forwarding true
az vm create --resource-group onprem --location eastus --name ASA1 --size Standard_D3_v2 --nics ASA1MgmtInterface ASA1OutsideInterface ASA1OutsideInterface2 ASA1InsideInterface  --image cisco:cisco-asav:asav-azure-byol:910.1.11 --admin-username azureuser --admin-password Msft123Msft123

**Build Azure side Linux VM**
az network public-ip create --name HubVMPubIP --resource-group Hub --location eastus --allocation-method Dynamic
az network nic create --resource-group Hub -n HubVMNIC --location eastus --subnet HubVM --private-ip-address 10.0.10.10 --vnet-name Hub --public-ip-address HubVMPubIP
az vm create -n HubVM -g Hub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVMNIC

**Build on prem Linux VM**
az network public-ip create --name onpremVMPubIP --resource-group onprem --location eastus --allocation-method Dynamic
az network nic create --resource-group onprem -n onpremVMNIC --location eastus --subnet VM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP
az vm create -n onpremVM -g onprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC

**After the gateway and ASAv have been created, document the public IP address for both. Value will be null until it has been successfully provisioned. Please note that the ASA VPN interfaces and management interface are different**
az network public-ip show -g Hub -n Azure-VNGpubip1 --query "{address: ipAddress}"
az network public-ip show -g Hub -n Azure-VNGpubip2 --query "{address: ipAddress}"
az network public-ip show -g onprem -n ASA1VPNPublicIP1 --query "{address: ipAddress}"
az network public-ip show -g onprem -n ASA1VPNPublicIP2 --query "{address: ipAddress}"
az network public-ip show -g onprem -n ASA1MgmtIP --query "{address: ipAddress}"

**Verify BGP information on the Azure VPN GWs. The 2 IP addresses listed are in the gateway subnet. These are the 2 "loopback" addresses on the VPN gateways the ASA will BGP peer to.**
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group Hub

**Create a route table and routes for the Azure VNET with correct association. This is for the onprem simulation to route traffic to the ASAv.**
az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name onprem --resource-group onprem --route-table vm-rt

**Create Local Network Gateway. On prem BGP peer over IPSEC is in ASN 65002 with a VTI of 192.168.2.1**
az network local-gateway create --gateway-ip-address "ASA1VPNPublicIP1" --name to-onprem --resource-group Hub --local-address-prefixes 192.168.2.1/32 --asn 65002 --bgp-peering-address 192.168.2.1

**Create VPN connection 1**
az network vpn-connection create --name to-onprem --resource-group Hub --vnet-gateway1 Azure-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp

**Create Local Network Gateway2. On prem BGP peer over IPSEC is in ASN 65002 with a VTI of 192.168.3.1**
az network local-gateway create --gateway-ip-address "ASA1VPNPublicIP2" --name to-onprem2 --resource-group Hub --local-address-prefixes 192.168.3.1/32 --asn 65002 --bgp-peering-address 192.168.3.1

**Create VPN connection 2**
az network vpn-connection create --name to-onprem2 --resource-group Hub --vnet-gateway1 Azure-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-onprem2 --enable-bgp

**SSH to ASA management address and paste in the below config. Replace references to "Azure-VNGpubip1" and "Azure-VNGpubip2" with the public IP addresses for the Azure VPN gateway**

interface GigabitEthernet0/0
 nameif outside
 security-level 0
 ip address 10.1.0.4 255.255.255.0 
 no shut
!
interface GigabitEthernet0/1
 nameif outside2
 security-level 0
 ip address 10.1.2.4 255.255.255.0
 no shut
!
interface GigabitEthernet0/2
 nameif inside
 security-level 100
 ip address 10.1.1.4 255.255.255.0 
 no shut
!
crypto ipsec ikev2 ipsec-proposal Ipsec-PROP-to-Azure
 protocol esp encryption aes-256 aes-192 aes
 protocol esp integrity sha-256 sha-1
crypto ipsec ikev2 ipsec-proposal AES256
 protocol esp encryption aes-256
 protocol esp integrity sha-1 md5
crypto ipsec ikev2 ipsec-proposal AES192
 protocol esp encryption aes-192
 protocol esp integrity sha-1 md5
crypto ipsec ikev2 ipsec-proposal AES
 protocol esp encryption aes
 protocol esp integrity sha-1 md5
crypto ipsec ikev2 ipsec-proposal 3DES
 protocol esp encryption 3des
 protocol esp integrity sha-1 md5
crypto ipsec ikev2 ipsec-proposal DES
 protocol esp encryption des
 protocol esp integrity sha-1 md5
crypto ipsec profile Ipsec-PROF-to-Azure
 set ikev2 ipsec-proposal Ipsec-PROP-to-Azure
 set security-association lifetime kilobytes unlimited
 set security-association lifetime seconds 3600
!
interface Tunnel11
 nameif vti-to-azvpngw1
 ip address 192.168.2.1 255.255.255.0 
 tunnel source interface outside
 tunnel destination Azure-VNGpubip1
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile Ipsec-PROF-to-Azure
!
interface Tunnel12
 nameif vti-to-azvpngw2
 ip address 192.168.3.1 255.255.255.0 
 tunnel source interface outside2
 tunnel destination Azure-VNGpubip2
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile Ipsec-PROF-to-Azure
!
router bgp 65002
 bgp log-neighbor-changes
 bgp graceful-restart
 bgp router-id 192.168.2.1
 address-family ipv4 unicast
  neighbor 10.0.0.4 remote-as 65001
  neighbor 10.0.0.4 ebgp-multihop 255
  neighbor 10.0.0.4 activate
  neighbor 10.0.0.5 remote-as 65001
  neighbor 10.0.0.5 ebgp-multihop 255
  neighbor 10.0.0.5 activate
  network 10.1.10.0 mask 255.255.255.0
  network 192.168.2.1 mask 255.255.255.255
  network 192.168.3.1 mask 255.255.255.255
  maximum-paths 2
  no auto-summary
  no synchronization
 exit-address-family
!
route vti-to-azvpngw1 10.0.0.4 255.255.255.255 Azure-VNGpubip1 1
route vti-to-azvpngw2 10.0.0.5 255.255.255.255 Azure-VNGpubip2 1
route inside 10.1.10.0 255.255.255.0 10.1.1.1 1
route outside Azure-VNGpubip1 255.255.255.255 10.1.0.1 1
route outside2 Azure-VNGpubip2 255.255.255.255 10.1.2.1 1
!
crypto ipsec security-association lifetime seconds 3600
crypto ipsec security-association lifetime kilobytes unlimited
crypto ipsec security-association replay disable
crypto ipsec security-association pmtu-aging infinite
crypto isakmp disconnect-notify
crypto ikev2 policy 1
 encryption aes-256 aes-192 aes 3des
 integrity sha256 sha
 group 2
 prf sha256 sha
 lifetime seconds 28800
crypto ikev2 enable outside
crypto ikev2 enable outside2
crypto ikev2 notify invalid-selectors

group-policy AzureGroupPolicy internal
group-policy AzureGroupPolicy attributes
 vpn-tunnel-protocol ikev2 l2tp-ipsec 
dynamic-access-policy-record DfltAccessPolicy
tunnel-group Azure-VNGpubip1 type ipsec-l2l
tunnel-group Azure-VNGpubip1 general-attributes
 default-group-policy AzureGroupPolicy
tunnel-group Azure-VNGpubip1 ipsec-attributes
 ikev2 remote-authentication pre-shared-key Msft123Msft123
 ikev2 local-authentication pre-shared-key Msft123Msft123
tunnel-group Azure-VNGpubip2 type ipsec-l2l
tunnel-group Azure-VNGpubip2 general-attributes
 default-group-policy AzureGroupPolicy
tunnel-group Azure-VNGpubip2 ipsec-attributes
 ikev2 remote-authentication pre-shared-key Msft123Msft123
 ikev2 local-authentication pre-shared-key Msft123Msft123
no tunnel-group-map enable peer-ip
tunnel-group-map default-group Azure-VNGpubip2
!

**Generate interesting traffic to initiate tunnel**</br>
Connect to onprem VM and ping the VM in the Azure Hub VNET (10.0.10.10)

**Validate VPN connection status in Azure CLI**
<pre lang="...">
az network vpn-connection show --name to-onprem --resource-group Hub --query "{status: connectionStatus}"
az network vpn-connection show --name to-onprem2 --resource-group Hub --query "{status: connectionStatus}"
</pre>

**Validate BGP routes being advetised from the Azure VPN GW to the ASA**
<pre lang="...">
az network vnet-gateway list-advertised-routes -g Hub -n Azure-VNG --peer 192.168.2.1
az network vnet-gateway list-advertised-routes -g Hub -n Azure-VNG --peer 192.168.3.1
</pre>

**Validate BGP routes the Azure VPN GW is receiving from the ASA**
<pre lang="...">
az network vnet-gateway list-learned-routes -g Hub -n Azure-VNG
</pre>

**Manually add a new address space 1.1.1.0/24 to the Hub VNET. Create subnet 1.1.1.0/24. Make sure to name the subnet "test1".**
- Use Azure portal

**Create VM in new 1.1.1.0/24 network.**
<pre lang="...">
az network public-ip create --name test1VMPubIP --resource-group Hub --location eastus --allocation-method Dynamic
az network nic create --resource-group Hub -n test1VMNIC --location eastus --subnet test1 --private-ip-address 1.1.1.10 --vnet-name Hub --public-ip-address test1VMPubIP
az vm create -n test1VM -g Hub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics test1VMNIC
</pre>

- The new address space created on the existing VNET will automatically be advertised to the ASA via BGP. Once the VM is created, ping 1.1.1.10 sourcing from the On Prem VM 10.1.10.10. 

**You can also add static routes or network statements to the ASA to validate new prefixes are added to the Azure effective route table.**
<pre lang="...">
ASA1(config)# route null0 2.2.2.2 255.255.255.255
ASA1(config)# route null0 3.3.3.3 255.255.255.255
ASA1(config-router)# address-family ipv4 unicast 
ASA1(config)# router bgp 65002
ASA1(config-router-af)# network 2.2.2.2 mask 255.255.255.255
ASA1(config-router-af)# network 3.3.3.3 mask 255.255.255.255
</pre>

**You should be able to ping and drop one of the tunnels (ex: int tu11). If the traffic was taking the tunnel you dropped, you will see an ~30 second drop in traffic as the fabric refreshes routes**
