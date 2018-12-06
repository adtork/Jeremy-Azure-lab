# Azure Networking Lab- accessing PAAS over VPN through Azure Firewall (DRAFT)

This lab guide illustrates how to build a basic Azure environment for routing PAAS over a site to site VPN. After traffic is routed to Azure over VPN, traffic destin for a test BLob will be routed through the Azure Firewall. The lab takes a building block approach using the portal and Azure CLI instead of provisioning the entire topology with Powershell or other automation tools. Azure Firewall is used between the VNET and PAAS for simplicity purposes although 3rd party NVAs are an option. The lab focuses on VPN and VNET networking and not any PAAS/SAAS related security controls. Azure public prefixes can change which is outside the scope of this lab.

Assumptions:
-	A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Azure CLI 2.0, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 



The labs cover:
-	Building VNETs and subnets
-	Deployment of Azure VPN gateways
-	Configuring BGP over IPSEC
-	Deployment of Azure Firewall with basic rules
-	Validate default routing behavior with PAAS
-	Manipulate routing to send traffic destin to PAAS through the Azure Firewall
-	Validation and further testing

# Base Topology
 
![alt text](https://github.com/jwrightazure/lab/blob/master/paas-over-vpn/paasvpn.png)
 

**Build Resource Groups, VNETs and Subnets in West. Azure CLI on Windows 10 is used through the lab.**
<pre lang="...">
az group create --name Hub --location westus
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

**Build Azure VPN Gateway. My lab uses BGP and sets ASN in this section. Deployment will take some time**
<pre lang="...">
az network vnet-gateway create --name West-VNG --public-ip-address West-VNGpubip --resource-group Hub --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65001
az network vnet-gateway create --name East-VNG --public-ip-address East-VNGpubip --resource-group East --vnet East --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65002
</pre>


**After the gateways have been created, document the public IP address for both East and West VPN Gateways. Value will be null until it has been successfully provisioned.**
<pre lang="...">
az network public-ip show -g Hub -n West-VNGpubip --query "{address: ipAddress}"
az network public-ip show -g East -n East-VNGpubip --query "{address: ipAddress}"
</pre>

**Document BGP peer IP and ASN**
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group Hub
</pre>
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group East
</pre>

**Create Local Network Gateway**
<pre lang="...">
az network local-gateway create --gateway-ip-address "insert east VPN GW IP" --name to-east --resource-group Hub --local-address-prefixes 10.100.0.0/16 --asn 65002 --bgp-peering-address 10.100.0.254
az network local-gateway create --gateway-ip-address "insert west VPN GW IP"  --name to-west --resource-group East --local-address-prefixes 10.0.0.0/16 --asn 65001 --bgp-peering-address 10.0.0.254
</pre>

**Create VPN connections**
<pre lang="...">
az network vpn-connection create --name to-east --resource-group Hub --vnet-gateway1 West-VNG -l westus --shared-key Msft123Msft123 --local-gateway2 to-east 
az network vpn-connection create --name to-west --resource-group East --vnet-gateway1 East-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-west 
</pre>

**Validate VPN connection status**
<pre lang="...">
az network vpn-connection show --name to-east --resource-group Hub --query "{status: connectionStatus}"
</pre>

**Create Azure Firewall subnet, required for Azure Firewall**
<pre lang="...">
az network vnet subnet create --address-prefix 10.0.100.0/24 --name AzureFirewallSubnet --resource-group Hub --vnet-name Hub
</pre>

**Create Azure Firewall using the portal**
![alt text](https://github.com/jwrightazure/lab/blob/master/paas-over-vpn/fw1.png)

**Create Network Rule. Obviously be more granular if needed.**
![alt text](https://github.com/jwrightazure/lab/blob/master/paas-over-vpn/fw2.png)

**Create test VM in East (simulating on-prem) and open RDP access**
<pre lang="...">
az network public-ip create --resource-group East --name EastVMPublicIP
az network nsg create --resource-group East --name myNetworkSecurityGroup
az network nic create --resource-group East --name myNic --vnet-name East --subnet VM --network-security-group myNetworkSecurityGroup --public-ip-address EastVMPublicIP
az vm create --resource-group East --name EastVM --location eastus --nics myNic --image win2016datacenter --admin-username azureuser --admin-password Msft123Msft123
az vm open-port --port 3389 --resource-group East --name EastVM
</pre>

**Create a storage account with anonymous read access in the West region.**
-Upload basic text file to test with. Steps omitted.<br/>
-Document Blob URL ex:https://paasvpn.blob.core.windows.net/paasvpn/testjw.txt.<br/>

-nslookup paasvpn.blob.core.windows.net and document the IP.<br/>
-Go to http://iprange.omartin2010.com/ and select prefix search tool.<br/>
-Paste in the IP of the Blob to determine the Azure region and prefix.<br/>
EX:<br/>
52.239.229.100 resolves to ...<br/>
52.239.229.100/32 is part of 52.239.228.0/23 in region uswest<br/>
*Document the public prefix. Ex:52.239.228.0/23

**Update East Local Network Gateway to attract the PAAS prefix over VPN. This is specific to making this work over Azure to Azure VPN Gateways**
<pre lang="...">
az network local-gateway update --local-address-prefixes 52.239.228.0/23 --name to-west --resource-group East
</pre>

**Verify VM route table for the East VM NIC**
<pre lang="...">
az network nic show-effective-route-table --resource-group East --network-interface-name myNic
</pre>

As you can see, traffic destin for the PAAS public prefix will route to the Azure VPN gateway and across the tunnel to West.<br/>
![alt text](https://github.com/jwrightazure/lab/blob/master/paas-over-vpn/lng.png)<br/>
Although the traffic goes over the tunnel, the traffic hits the Azure VPN Gateway in West and is dropped. The Gateway Subnet in West needs to route traffic to the PAAS prefix over to the Azure Firewall. The Azure firewall has access to the Microsoft backbone where PAAS resources reside.

**Create a route table and routes for the Gateway Subnet with correct association**
<pre lang="...">
az network route-table create --name gwsubnet-rt --resource-group Hub 
az network route-table route create --route-table-name gwsubnet-rt --resource-group Hub --name to-paas --address-prefix 52.239.228.0/23 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.100.4
az network vnet subnet update --virtual-network-name Hub --subnet-name GatewaySubnet --resource-group Hub --route-table gwsubnet-rt
</pre>

Traffic is now routing from on-prem over VPN through the Azure Firewall.

**Azure Firewall log showing the connection SIP/DIP/Port and allow
![alt text](https://github.com/jwrightazure/lab/blob/master/paas-over-vpn/fwlog.png)




