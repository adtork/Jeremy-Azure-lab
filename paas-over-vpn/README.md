# Azure Networking Lab- accessing PAAS over VPN through Azure Firewall (DRAFT)

# Objectives and initial setup <a name="objectives"></a>

This lab guide illustrates how to deploy a basic environment in Azure that allows you to route traffic destin for PAAS resources over VPN and then traversing an Azure Firewall. The lab takes a building block approach using the portal and Azure CLI instead of provisioning the entire topology with Powershell or other automation tools. The VPN connection is between Azure region East and West with the East region simulating an on-prem connection. Azure firewall is used between the VNET and PAAS for simplicity purposes. 3rd party NVAs could be used as well. The labs focuses on VPN and VNET networking and not any PAAS/SAAS related security controls.

Assumptions:
-	A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
-Azure CLI Options:
      -	If you are using Windows 10, you can install Bash shell on Ubuntu on Windows (http://www.windowscentral.com/how-install-bash-shell-command-line-windows-10).
      -	Azure CLI 2.0, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 
      - https://shell.azure.com/
 - Necessary authorization with Azure


The labs cover:
-	Building VNETs and subnets
-	Deployment of Azure VPN gateways
-	Configuring BGP over IPSEC
-	Deployment of Azure Firewall with basic rules
-	Validate default routing behavior with PAAS
-	Manipulate routing to send traffic destin to PAAS through the Azure Firewall
-	Validation and further testing

# Azure Region _West_ Values
| **Description for Region** | **Values used in this lab guide** |
| --- | --- |
| Username for provisioned VMs | azureuser |
| Password for provisioned VMs | Msft123Msft123 |
| Azure region | westus |
| Vnet Name | Hub |
| Resource Group | Hub |
| VNET Address Space | 10.0.0.0/16 |
| HubVM Subnet | 10.0.10.0/24 |
| GatewaySubnet | 10.0.0.0/24 |
| AzureFirewallSubnet | 10.0.100.0/24 |

# Azure Region _East_ Values
| **Description for Region** | **Values used in this lab guide** |
| --- | --- |
| Username for provisioned VMs | azureuser |
| Password for provisioned VMs | Msft123Msft123 |
| Azure region | eastus |
| Vnet Name | East |
| Resource Group | East |
| VNET Address Space | 10.100.0.0/16 |
| VM Subnet | 10.100.10.0/24 |
| GatewaySubnet | 10.1000.0.0/24 |

 ## Base Topology
 
![alt text](https://github.com/jwrightazure/lab/blob/master/paas-over-vpn/paasvpn.png)
 

**Build Resource Groups, VNETs and Subnets in West. Azure CLI on Windows 10 is used through the lab.**
<pre lang="...">
az group create --name Hub --location westus
az group create --name Spoke1 --location westus
az group create --name Spoke2 --location westus
az network vnet create --resource-group Hub --name Hub --location westus --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group Hub --vnet-name Hub
</pre>

**Build Resource Groups, VNETs and Subnets in East.**
<pre lang="...">
az group create --name East --location eastus
az network vnet create --resource-group East --name East --location eastus --address-prefixes 10.100.0.0/16 --subnet-name VM --subnet-prefix 10.100.10.0/24
az network vnet subnet create --address-prefix 10.100.0.0/24 --name GatewaySubnet --resource-group East --vnet-name East
</pre>

**Build Public IPs for VPN**
<pre lang="...">
az network public-ip create --name West-VNGpubip --resource-group Hub --allocation-method Dynamic
az network public-ip create --name East-VNGpubip --resource-group East --allocation-method Dynamic
</pre>

**Build Azure VPN Gateway. My lab uses BGP and sets ASN in this section. Deployment will take some time **
<pre lang="...">
az network vnet-gateway create --name West-VNG --public-ip-address West-VNGpubip --resource-group Hub --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65001
az network vnet-gateway create --name East-VNG --public-ip-address East-VNGpubip --resource-group East --vnet East --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65002
</pre>

# While waiting, create a storage account with anonymous read access in the West region. 
Upload basic test file to test with. Steps omitted.
Document Blob URL
https://paasvpn.blob.core.windows.net/paasvpn/test jw.txt
nslookup paasvpn.blob.core.windows.net
Document the IP. Go to http://iprange.omartin2010.com/ and select prefix search tool. Paste in the IP of the Blob to determine the Azure region and prefix.
EX: 
13.88.144.240 resolves to ...
13.88.144.240/32 is part of 13.88.128.0/18 in region uswest

# After the gateways have been created, document the public IP address for both East and West VPN Gateways. Value will be null until it has been successfully provisioned.
<pre lang="...">
az network public-ip show -g Hub -n West-VNGpubip --query "{address: ipAddress}"
az network public-ip show -g East -n East-VNGpubip --query "{address: ipAddress}"
</pre>

# Document BGP peer IP and ASN
<pre lang="...">
az network vnet-gateway show -g Hub --name West-VNG
az network vnet-gateway show -g East --name East-VNG
</pre>
# Create VPN connections
az network vpn-connection create --name to-east --resource-group Hub --vnet-gateway1 West-VNG -l westus --shared-key Msft123Msft123 --local-gateway2 to-east 
az network vpn-connection create --name to-west --resource-group East --vnet-gateway1 East-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-west 
# Validate VPN connection status
az network vpn-connection show --name to-east --resource-group Hub --query "{status: connectionStatus}"
# Create Azure Firewall subnet and firewall
<pre lang="...">
az network vnet subnet create --address-prefix 10.0.100.0/24 --name AzureFirewallSubnet --resource-group Hub --vnet-name Hub
</pre>

# Create 
<pre lang="...">
az network local-gateway create --gateway-ip-address "insert east VPN GW IP" --name to-east --resource-group Hub --local-address-prefixes 10.100.0.0/16 --asn 65002 --bgp-peering-address 10.100.0.254
az network local-gateway create --gateway-ip-address "insert west VPN GW IP"  --name to-west --resource-group East --local-address-prefixes 10.0.0.0/16 --asn 65001 --bgp-peering-address 10.0.0.254
</pre>

# Create connections
<pre lang="...">
az network vpn-connection create --name to-east --resource-group Hub --vnet-gateway1 West-VNG -l westus --shared-key Msft123Msft123 --local-gateway2 to-east 
az network vpn-connection create --name to-west --resource-group East --vnet-gateway1 East-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-west
</pre>

# Validate connectivity is successful
<pre lang="...">
az network vpn-connection show --name to-east --resource-group Hub --query "{status: connectionStatus}"
</pre>


# Create test VM in East (simulating on-prem)
<pre lang="...">
az network public-ip create --resource-group East --name EastVMPublicIP
az network nsg create --resource-group East --name myNetworkSecurityGroup
az network nic create --resource-group East --name myNic --vnet-name East --subnet VM --network-security-group myNetworkSecurityGroup --public-ip-address EastVMPublicIP
az vm create --resource-group East --name EastVM --location eastus --nics myNic --image win2016datacenter --admin-username azureuser --admin-password Msft123Msft123
az vm open-port --port 3389 --resource-group East --name EastVM
</pre>


# We can verify what the route tables look like now, and how it has been programmed in one of the NICs associated to the subnet:

<pre lang="...">
<b>az network route-table route list --route-table-name vnet1-subnet1 -o table</b>
AddressPrefix    Name     NextHopIpAddress    NextHopType       ProvisioningState
---------------  -------  ------------------  ----------------  -------------------
10.2.0.0/16      vnet2    10.4.2.101          VirtualAppliance  Succeeded
</pre>

<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet1-vm1-nic</b>
<i>...Output omitted...</i>
    {
      "addressPrefix": [
        "10.2.0.0/16"
      ],
      "name": "vnet2",
      "nextHopIpAddress": [
        "10.4.2.101"
      ],
      "nextHopType": "VirtualAppliance",
      "source": "User",
      "state": "Active"
    }
<i>...Output omitted...</i>
</pre>



## Azure Firewall

<pre lang="...">
<b>az network vnet-gateway list --query [].[name,bgpSettings.asn] -o table</b>
Column1      Column2
---------  ---------
vnet4Gw        65504
vnet5Gw        65505
</pre>




<pre lang="...">
<b>az network nic show-effective-route-table -n myVnet5-vm1-nic | jq -r '.value[] | "\(.addressPrefix)\t\(.nextHopIpAddress)\t\(.nextHopType)"'</b>
["10.5.0.0/16"]         []                      VnetLocal
["10.4.0.254/32"]       ["13.94.129.120"]       VirtualNetworkGateway
["10.4.0.0/16"]         ["13.94.129.120"]       VirtualNetworkGateway
["0.0.0.0/0"]           []                      Internet
["10.0.0.0/8"]          []                      None
["100.64.0.0/10"]       []                      None
["172.16.0.0/12"]       []                      None
["192.168.0.0/16"]      []                      None
</pre>

az network route-table create --name gwsubnet-rt --resource-group Hub 
az network route-table route create --route-table-name gwsubnet-rt --resource-group Hub --route-name to-paas --address-prefix 52.241.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.100.4
az network vnet subnet update --virtual-network-name Hub --subnet-name GatewaySubnet  --resource-group Hub --route-table gwsubnet-rt
####################################

{ "category": "AzureFirewallNetworkRule", "time": "2018-12-05T20:34:22.4850250Z", "resourceId": "/SUBSCRIPTIONS/xxxx/RESOURCEGROUPS/HUB/PROVIDERS/MICROSOFT.NETWORK/AZUREFIREWALLS/FW", "operationName": "AzureFirewallNetworkRuleLog", "properties": {"msg":"TCP request from 10.100.10.4:50072 to 52.241.88.84:443. Action: Allow"}}


In case you are wondering what the 10.4.0.254/32 route is, that is the IP address that the gateways are using to establish the BGP adjacencies. Kind of a loopback interface in a router, if you will.


# Conclusion

I hope you have had fun running through this lab, and that you learnt something that you did not know before. We ran through multiple Azure networking topics like IPSec VPN, vnet peering, global vnet peering, NSGs, Load Balancing, outbound NAT rules, Hub & Spoke vnet topologies and advanced NVA HA concepts, but we covered as well other non-Azure topics such as basic iptables or advanced probes programming with PHP.





