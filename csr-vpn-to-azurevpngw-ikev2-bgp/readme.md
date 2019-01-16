# Azure Networking Lab- IPSEC VPN (IKEv2) between Cisco CSR and Azure VPN Gateway- with BGP

This lab guide illustrates how to build a basic IPSEC VPN tunnel w/IKEv2 between a Cisco CSR and the Azure VPN gateway with BGP. This is for lab testing purposes only. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. Note- the on prem CSR has a private IP on the outside interface since it's hosted in Azure. You can apply a public IP if needed.

Assumptions:
-	A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Latest Azure CLI, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 


# Base Topology
The lab deploys an Azure VPN gateway into a VNET. We will also deploy a Cisco CSR in a seperate VNET to simulate on prem.
![alt text](https://github.com/jwrightazure/lab/blob/master/images/csrvpnikev2.png)

**Build Resource Groups, VNETs and Subnets**
<pre lang="...">
az group create --name Hub --location westus
az network vnet create --resource-group Hub --name Hub --location westus --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group Hub --vnet-name Hub
</pre>

**Build Resource Groups, VNETs and Subnets to simulate on prem**
<pre lang="...">
az group create --name onprem --location westus
az network vnet create --resource-group onprem --name onprem --location westus --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group onprem --vnet-name onprem
</pre>

**Build Azure side Linux VM**
<pre lang="...">
az network public-ip create --name HubVMPubIP --resource-group Hub --location westus --allocation-method Dynamic
az network nic create --resource-group Hub -n HubVMNIC --location westus --subnet HubVM --private-ip-address 10.0.10.10 --vnet-name Hub --public-ip-address HubVMPubIP
az vm create -n HubVM -g Hub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVMNIC
</pre>

**Build onprem side Linux VM**
<pre lang="...">
az network public-ip create --name onpremVMPubIP --resource-group onprem --location westus --allocation-method Dynamic
az network nic create --resource-group onprem -n onpremVMNIC --location westus --subnet VM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP
az vm create -n onpremVM -g onprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC
</pre>

**Build Public IPs for Azure VPN Gateway**
<pre lang="...">
az network public-ip create --name Azure-VNGpubip --resource-group Hub --allocation-method Dynamic
</pre>

**Build Azure VPN Gateway. Enable BGP with ASN 65001. Deployment will take some time.**
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group Hub --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65001

**Build onprem CSR. CSR image is specified from the Marketplace in this example.**
<pre lang="...">
az network public-ip create --name CSR1PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g onprem --subnet zeronet --vnet onprem --public-ip-address CSR1PublicIP --ip-forwarding true
az network nic create --name CSR1InsideInterface -g onprem --subnet onenet --vnet onprem --ip-forwarding true
az vm create --resource-group onprem --location westus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_6:16.6.220171219 --admin-username azureuser --admin-password Msft123Msft123
</pre>

**After the gateway and CSR have been created, document the public IP address for both. Value will be null until it has been successfully provisioned.**
<pre lang="...">
az network public-ip show -g Hub -n Azure-VNGpubip --query "{address: ipAddress}"
az network public-ip show -g onprem -n CSR1PublicIP --query "{address: ipAddress}"
</pre>

**Document BGP peer IP and ASN**
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group Hub
</pre>

**Create a route table and routes for the Azure VNET with correct association. This is for the onprem simulation to route traffic to the CSR**
<pre lang="...">
az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name onprem --resource-group onprem --route-table vm-rt
</pre>

**Create Local Network Gateway. This specifies the prefixes that are allowed to source from Azure over the tunnel to onprem. The 192.168.1.1 addrees is the IP of the tunnel interface on the CSR.**
<pre lang="...">
az network local-gateway create --gateway-ip-address "insert CSR Public IP" --name to-onprem --resource-group onprem --local-address-prefixes 10.1.0.0/16 --asn 65002 --bgp-peering-address 192.168.1.1
</pre>

**Create VPN connections**
<pre lang="...">
az network vpn-connection create --name to-onprem --resource-group hub --vnet-gateway1 Azure-VNG -l westus --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp
</pre>

**SSH to CSR public IP. Public IPs in the below config are an example.**
<pre lang="...">
!route for simulate on prem vm
ip route 10.1.10.0 255.255.255.0 10.1.1.1

crypto ikev2 proposal to-onprem-proposal
  encryption aes-cbc-256
  integrity  sha1
  group      2
  exit

crypto ikev2 policy to-onprem-policy
  proposal to-onprem-proposal
  match address local 10.1.0.4
  exit
  
crypto ikev2 keyring to-onprem-keyring
  peer 40.118.238.212
    address 40.118.238.212
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-onprem-profile
  match address  local 10.1.0.4
  match identity remote address 40.118.238.212 255.255.255.255
  authentication remote pre-share
  authentication local  pre-share
  lifetime       3600
  dpd 10 5 on-demand
  keyring local  to-onprem-keyring
  exit

crypto ipsec transform-set to-onprem-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-onprem-IPsecProfile
  set transform-set  to-onprem-TransformSet
  set ikev2-profile  to-onprem-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.1 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.1.0.4
  tunnel destination 40.118.238.212
  tunnel protection ipsec profile to-onprem-IPsecProfile
  exit

router bgp 65002
  bgp      log-neighbor-changes
  neighbor 10.0.0.254 remote-as 65001
  neighbor 10.0.0.254 ebgp-multihop 255
  neighbor 10.0.0.254 update-source tunnel 11

  address-family ipv4
    network 10.1.0.0 mask 255.255.0.0
    neighbor 10.0.0.254 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 10.0.0.254 255.255.255.255 Tunnel 11

</pre>

**Validate VPN connection status in Azure CLI**
<pre lang="...">
az network vpn-connection show --name to-onprem --resource-group Hub --query "{status: connectionStatus}"
</pre>


Key Cisco commands
- show interface tunnel 11
- show crypto session)
- show crypto ipsec transform-set
- show crypto ikev2 proposal

**List BGP advertised routes per peer**
<pre lang="...">
az network vnet-gateway list-advertised-routes -g Hub -n Azure-VNG --peer 192.168.1.1

PS Azure:\> az network vnet-gateway list-advertised-routes -g Hub -n Azure-VNG --peer 192.168.1.1
{
  "value": [
    {
      "asPath": "65001",
      "localAddress": "10.0.0.254",
      "network": "10.0.0.0/16",
      "nextHop": "10.0.0.254",
      "origin": "Igp",
      "sourcePeer": null,
      "weight": 0
    },
</pre>
