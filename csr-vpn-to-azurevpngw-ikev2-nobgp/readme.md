# Azure Networking Lab- IPSEC VPN (IKEv2) between Cisco CSR and Azure VPN Gateway (draft)

This lab guide illustrates how to build a basic IPSEC VPN tunnel w/IKEv2 and the Azure VPN gateway without BGP. This is for lab testing purposes only. 

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

**Build CSR configuration**


**Create VPN connections**
<pre lang="...">
az network vpn-connection create --name to-onprem --resource-group onprem --vnet-gateway1 Azure-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-onprem
</pre>

**Validate VPN connection status**
<pre lang="...">
az network vpn-connection show --name to-onprem --resource-group Hub --query "{status: connectionStatus}"
</pre>


**Create test VM in East and open RDP access**
<pre lang="...">
az network public-ip create --resource-group East --name EastVMPublicIP
az network nsg create --resource-group East --name myNetworkSecurityGroup
az network nic create --resource-group East --name myNic --vnet-name East --subnet VM --network-security-group myNetworkSecurityGroup --public-ip-address EastVMPublicIP
az vm create --resource-group East --name EastVM --location eastus --nics myNic --image win2016datacenter --admin-username azureuser --admin-password Msft123Msft123
az vm open-port --port 3389 --resource-group East --name EastVM
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




