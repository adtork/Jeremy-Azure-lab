# Azure Networking Lab- IPSEC VPN (IKEv2) between Palo Alto Networks Firewall and Azure VPN Gateway with BGP

This lab guide illustrates how to build a basic IPSEC VPN tunnel w/IKEv2 between a Palo Alto Network firewall and the Azure VPN gateway with BGP. This is for lab testing purposes only and should not be considered production configuration. Security policies and configurations can be further optimized if need be. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. The lab uses an on prem VNET to simulate on prem connectivity. All PAN firewall configurations are provided via the XML file in Github.

Assumptions:
- A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Latest Azure CLI, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 


# Base Topology
The lab deploys an active/active Azure VPN gateway into a VNET. We will also deploy a Cisco ASA in a seperate VNET to simulate on prem.
![alt text](https://github.com/jwrightazure/lab/blob/master/images/pan%20to%20azure%20vpn%20with%20bgp.PNG)


**Build Resource Groups, VNETs and Subnets for the Azure side VNET**
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
az network vnet subnet create --address-prefix 10.1.2.0/24 --name twonet --resource-group onprem --vnet-name onprem
</pre>

**Build Public IP for Azure VPN Gateway**
<pre lang="...">
az network public-ip create --name Azure-VNGpubip --resource-group Hub --allocation-method Dynamic
</pre>

**Build Azure VPN Gateways. Deployment will take some time. Azure side BGP ASN is 65001.**
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group Hub --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65001
</pre>

**Before deploying PAN in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a PAN VM in the portal or through Powershell. This is a sample for a Cisco CSR**
<pre lang="...">
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Build PAN VM in the on prem VNET. It specifies a specific image that you can change**
<pre lang="...">
az network public-ip create --name PAN1MgmtIP --resource-group onprem --idle-timeout 30 --allocation-method Static
az network public-ip create --name PAN1VPNPublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static
az network nic create --name PAN1MgmtInterface -g onprem --subnet twonet --vnet onprem --public-ip-address PAN1MgmtIP --private-ip-address 10.1.2.4 --ip-forwarding true
az network nic create --name PAN1OutsideInterface -g onprem --subnet zeronet --vnet onprem --public-ip-address PAN1VPNPublicIP --private-ip-address 10.1.0.4 --ip-forwarding true
az network nic create --name PAN1InsideInterface -g onprem --subnet onenet --vnet onprem --private-ip-address 10.1.1.4 --ip-forwarding true
az vm create --resource-group onprem --location eastus --name PAN1 --size Standard_D3_v2 --nics PAN1MgmtInterface PAN1OutsideInterface PAN1InsideInterface  --image paloaltonetworks:vmseries1:byol:8.1.0 --admin-username azureuser --admin-password Msft123Msft123
</pre>

**Build Azure side Linux VM**
<pre lang="...">
az network public-ip create --name HubVMPubIP --resource-group Hub --location eastus --allocation-method Dynamic
az network nic create --resource-group Hub -n HubVMNIC --location eastus --subnet HubVM --private-ip-address 10.0.10.10 --vnet-name Hub --public-ip-address HubVMPubIP
az vm create -n HubVM -g Hub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVMNIC
</pre>

**Build on prem Linux VM**
<pre lang="...">
az network public-ip create --name onpremVMPubIP --resource-group onprem --location eastus --allocation-method Dynamic
az network nic create --resource-group onprem -n onpremVMNIC --location eastus --subnet VM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP
az vm create -n onpremVM -g onprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC
</pre>

**After the gateway and PAN VM have been created, document the public IP address for both. Value will be null until it has been successfully provisioned. Please note that the PAN VPN interfaces and management interface are different. Do not move onto next step until the Azure VPN GW has a public IP which will take a few minutes.**
<pre lang="...">
az network public-ip show -g Hub -n Azure-VNGpubip --query "{address: ipAddress}"
az network public-ip show -g onprem -n PAN1VPNPublicIP --query "{address: ipAddress}"
az network public-ip show -g onprem -n PAN1MgmtIP --query "{address: ipAddress}"
</pre>

**Verify BGP information on the Azure VPN GWs. The IP address listed is the "VTI" on the Azure VPN Gateway.**
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group Hub
</pre>

**Create a route table and routes for the Azure VNET with correct association. This is for the onprem simulation to route traffic to the PAN VM.**
<pre lang="...">
az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name onprem --resource-group onprem --route-table vm-rt
</pre>

**Create Local Network Gateway and VPN Connection. Establish BGP peer over IPSEC to the PAN VTI in ASN 65002 with an IP of 192.168.2.1. Make sure to replace "PAN1VPNPublicIP".**
<pre lang="...">
az network local-gateway create --gateway-ip-address "PAN1VPNPublicIP" --name to-onprem --resource-group Hub --local-address-prefixes 192.168.2.1/32 --asn 65002 --bgp-peering-address 192.168.2.1
az network vpn-connection create --name to-onprem --resource-group Hub --vnet-gateway1 Azure-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp
</pre>

**HTTPS to the PAN management address.**
- Download Firewall XML file: https://github.com/jwrightazure/lab/blob/master/pan-vpn-to-azurevpngw-ikev2-bgp/PAN-IKEv2-BGP.xml
- Open the XML file and replace references to "Azure-VNGpubip1" with the public IP addresses for the Azure VPN gateway and save.

**Validate VPN connection status in Azure CLI**
<pre lang="...">
az network vpn-connection show --name to-onprem --resource-group Hub --query "{status: connectionStatus}"
</pre>

**Validate BGP routes being advetised from the Azure VPN GW to PAN**
<pre lang="...">
az network vnet-gateway list-advertised-routes -g Hub -n Azure-VNG --peer 192.168.2.1
</pre>

**Validate BGP routes the Azure VPN GW is receiving from PAN**
<pre lang="...">
az network vnet-gateway list-learned-routes -g Hub -n Azure-VNG
</pre>

# At this point, the Hub and On Prem VMs should be able to talk to each other via the tunnel.

**Manually add a new address space 1.1.1.0/24 to the Hub VNET. Validate PAN's Untrust VR routing table sees the new prefix.**








