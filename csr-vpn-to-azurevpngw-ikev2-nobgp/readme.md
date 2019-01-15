# Azure Networking Lab- IPSEC VPN (IKEv2) between Cisco CSR and Azure VPN Gateway (draft)

This lab guide illustrates how to build a basic IPSEC VPN tunnel w/IKEv2 and the Azure VPN gateway without BGP. This is for lab testing purposes only. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. 

Assumptions:
-	A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Latest Azure CLI, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 


# Base Topology
The lab deploys an Azure VPN gateway into a VNET. We will also deploy a Cisco CSR in a seperate VNET to simulate on prem.
 

**Build Resource Groups, VNETs and Subnets**
<pre lang="...">
az group create --name Hub --location eastus
az network vnet create --resource-group Hub --name Hub --location eastus --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group Hub --vnet-name Hub
</pre>

**Build Resource Groups, VNETs and Subnets to simulate on prem**
<pre lang="...">
az group create --name onprem --location eastus
az network vnet create --resource-group onprem --name onprem --location eastus --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group onprem --vnet-name onprem
</pre>

**Build Public IPs for Azure VPN Gateway**
<pre lang="...">
az network public-ip create --name Azure-VNGpubip --resource-group Hub --allocation-method Dynamic
</pre>

**Build Azure VPN Gateway. Deployment will take some time**
<pre lang="...">
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group Hub --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait 
</pre>

**Build onprem CSR. CSR image is specified from the Marketplace in this example.**
<pre lang="...">
az network public-ip create --name CSR1PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g onprem --subnet zeronet --vnet onprem --public-ip-address CSR1PublicIP --ip-forwarding true
az network nic create --name CSR1InsideInterface -g onprem --subnet onenet --vnet onprem --ip-forwarding true
az vm create --resource-group onprem --location eastus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_6:16.6.220171219 --admin-username jewrigh --admin-password Msft123Msft123
</pre>


**After the gateway and CSR have been created, document the public IP address for both. Value will be null until it has been successfully provisioned.**
<pre lang="...">
az network public-ip show -g Hub -n Azure-VNGpubip --query "{address: ipAddress}"
az network public-ip show -g onprem -n CSR1PublicIP --query "{address: ipAddress}"
</pre>

**Create Local Network Gateway. This specifies the prefixes that are allowed to source from Azure over the tunnel to onprem.**
<pre lang="...">
az network local-gateway create --gateway-ip-address "insert CSR IP" --name to-onprem --resource-group onprem --local-address-prefixes 10.1.0.0/16
</pre>

**Create VPN connections**
<pre lang="...">
az network vpn-connection create --name to-onprem --resource-group hub --vnet-gateway1 Azure-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-onprem
</pre>

**Create a route table and routes for the Azure VNET with correct association. This is for the onprem simulation to route traffic to the CSR**
<pre lang="...">
az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name onprem --resource-group onprem --route-table vm-rt
</pre>

**Build CSR configuration in Cisco CLI**
<pre lang="...">
!route for simulated onprem vm subnet
ip route 10.1.10.0 255.255.255.0 10.1.1.1

crypto ikev2 proposal to-csr-proposal
  encryption aes-cbc-256
  integrity sha1
  group 2
  exit

##the local IP is the private IP of the outside interface. Azure will automatically NAT this outbound. Replace this with your public IP if needed##
crypto ikev2 policy to-csr-policy
  proposal to-csr-proposal
  match address local 10.1.0.4
  exit
 
#Peer IP/address is the Azure VPN gateway
crypto ikev2 keyring to-csr-keyring
  peer 13.92.121.57 
    address 13.92.121.57
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-csr-profile
  match address  local 10.1.0.4
  match identity remote address 13.92.121.57 255.255.255.255
  authentication remote pre-share
  authentication local  pre-share
  lifetime 3600
  dpd 10 5 on-demand
  keyring local  to-csr-keyring
  exit

crypto ipsec transform-set to-csr-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-csr-IPsecProfile
  set transform-set  to-csr-TransformSet
  set ikev2-profile  to-csr-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 169.254.0.1 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.1.0.4
  tunnel destination 13.92.121.57
  tunnel protection ipsec profile to-csr-IPsecProfile
  exit

ip route 10.0.0.0 255.255.0.0 Tunnel 11
</pre>

**Validate VPN connection status in Azure CLI**
<pre lang="...">
az network vpn-connection show --name to-onprem --resource-group Hub --query "{status: connectionStatus}"
</pre>

**Key Cisco commands**
show interface tunnel 11
show crypto session
show ip route  (make sure Azure prefix is pointing to tu11)
show crypto ipsec transform-set
show crypto ikev2 proposal











