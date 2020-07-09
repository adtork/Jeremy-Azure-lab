# Azure Firewall Routing Lab: Inter/Intra-region Hub and Spoke Connectivity Via Global VNET Peering, Local Azure Outbound Internet, Expressroute 
The lab deploys 2 hub and spoke environments in different regions. Hub1 is peered with spoke1/spoke2, all 3 VNETs in Azure region WestUS2. Hub2 is peered with spoke3/spoke4, all 3 VNETs in Azure region EastUS. Both Hubs have an Azure Firewall and the hubs are connected via Global VNET peering. Spoke1 and Spoke 2 have a default route pointed to Azure FW1. Spoke 3 and Spoke 4 have a default route pointed to Azure FW2. Spokes will use their peered Hubs regional Internet access via Azure Firewall. BGP propagation is disabled on all spokes so all traffic (including to on prem) will flow through Azure Firewall. Summary routes are used between hubs to keep routing easy. Inter-region connectivity traverses Global VNET peering and does not hairpin of the Microsoft Edge Routers. This lab does not cover detailed Expressroute configurations.

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/inter-region-azfw-topo.PNG)
Note- the entire lab uses Azure CLI. Please make sure you have the latest version and the firewall extension added. The firewall rules can be modified to be more restrictive as needed. There is a single jump VM (with a public ip) in spoke1. The other 4 VMs (1 in each spoke) do not have a public ip. You will be able to SSH from the jump VM to the other VMs to test connectivity. All VMs have a username/password of azureuser/Msft123Msft123

<pre lang="...">
az extension list-available --output table
az extension add --name azure-firewall
</pre>

**Build all Hub and Spoke VNETs**
<pre lang="...">
az group create --name AZFW --location westus2
az network vnet create --resource-group AZFW --name Hub1 --location westus2 --address-prefixes 10.10.0.0/24 --subnet-name AzureFirewallSubnet --subnet-prefix 10.10.0.0/26
az network vnet subnet create --address-prefix 10.10.0.64/26 --name GatewaySubnet --resource-group AZFW --vnet-name Hub1
az network vnet create --resource-group AZFW --name Spoke1 --location westus2 --address-prefixes 10.10.1.0/24 10.10.10.0/24 --subnet-name Spoke1VMSubnet --subnet-prefix 10.10.1.0/24
az network vnet subnet create --address-prefix 10.10.10.0/24 --name JumpSubnet --resource-group AZFW --vnet-name Spoke1
az network vnet create --resource-group AZFW --name Spoke2 --location westus2 --address-prefixes 10.10.2.0/24 --subnet-name Spoke2VMSubnet --subnet-prefix 10.10.2.0/24
az network vnet create --resource-group AZFW --name Hub2 --location eastus --address-prefixes 10.20.0.0/24 --subnet-name AzureFirewallSubnet --subnet-prefix 10.20.0.0/26
az network vnet subnet create --address-prefix 10.20.0.64/26 --name GatewaySubnet --resource-group AZFW --vnet-name Hub2
az network vnet create --resource-group AZFW --name Spoke3 --location eastus --address-prefixes 10.20.1.0/24 --subnet-name Spoke3VMSubnet --subnet-prefix 10.20.1.0/24
az network vnet create --resource-group AZFW --name Spoke4 --location eastus --address-prefixes 10.20.2.0/24 --subnet-name Spoke4VMSubnet --subnet-prefix 10.20.2.0/24
</pre>

**Build Azure Firewall 1 and 2**
<pre lang="...">
az network public-ip create --name AZFW1-pip --resource-group AZFW --location westus2 --allocation-method static --sku standard
az network firewall create --name AZFW1 --resource-group AZFW --location westus2
az network firewall ip-config create --firewall-name AZFW1 --name FW-config --public-ip-address AZFW1-pip --resource-group AZFW --vnet-name Hub1
az network firewall update --name AZFW1 --resource-group AZFW 
az network public-ip create --name AZFW2-pip --resource-group AZFW --location eastus --allocation-method static --sku standard
az network firewall create --name AZFW2 --resource-group AZFW --location eastus
az network firewall ip-config create --firewall-name AZFW2 --name FW-config --public-ip-address AZFW2-pip --resource-group AZFW --vnet-name Hub2
az network firewall update --name AZFW2 --resource-group AZFW 
</pre>

**Build Jump and spoke VMs**
<pre lang="...">
az network public-ip create --name JumpVM-pip --resource-group AZFW --location westus2 --allocation-method Dynamic
az network nic create --resource-group AZFW -n JumpVMNIC --location westus2 --subnet JumpSubnet --private-ip-address 10.10.10.4 --vnet-name Spoke1 --public-ip-address JumpVM-pip --ip-forwarding true
az vm create -n JumpVM -g AZFW --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics JumpVMNIC --no-wait --location westus2
az network nic create --resource-group AZFW -n Spoke1VMNIC --location westus2 --subnet Spoke1VMSubnet --private-ip-address 10.10.1.4 --vnet-name Spoke1 --ip-forwarding true
az vm create -n Spoke1VM -g AZFW --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke1VMNIC --no-wait --location westus2
az network nic create --resource-group AZFW -n Spoke2VMNIC --location westus2 --subnet Spoke2VMSubnet --private-ip-address 10.10.2.4 --vnet-name Spoke2 --ip-forwarding true
az vm create -n Spoke2VM -g AZFW --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke2VMNIC --no-wait --location westus2
az network nic create --resource-group AZFW -n Spoke3VMNIC --location eastus --subnet Spoke3VMSubnet --private-ip-address 10.20.1.4 --vnet-name Spoke3 --ip-forwarding true
az vm create -n Spoke3VM -g AZFW --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke3VMNIC --no-wait --location eastus
az network nic create --resource-group AZFW -n Spoke4VMNIC --location eastus --subnet Spoke4VMSubnet --private-ip-address 10.20.2.4 --vnet-name Spoke4 --ip-forwarding true
az vm create -n Spoke4VM -g AZFW --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke4VMNIC --no-wait --location eastus
</pre>

**Build VNET peering. Make sure to change XXXX to your subscription**
<pre lang="...">
az network vnet peering create -g AZFW -n Hub1-To-Hub2 --vnet-name Hub1 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Hub2 
az network vnet peering create -g AZFW -n Hub2-To-Hub1 --vnet-name Hub2 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Hub1

az network vnet peering create -g AZFW -n Hub1-To-Spoke1 --vnet-name Hub1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Spoke1
az network vnet peering create -g AZFW -n Spoke1-To-Hub1 --vnet-name Spoke1 --allow-vnet-access --allow-forwarded-traffic  --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Hub1

az network vnet peering create -g AZFW -n Hub1-To-Spoke2 --vnet-name Hub1 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Spoke2
az network vnet peering create -g AZFW -n Spoke2-To-Hub1 --vnet-name Spoke2 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Hub1

az network vnet peering create -g AZFW -n Hub2-To-Spoke3 --vnet-name Hub2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Spoke3
az network vnet peering create -g AZFW -n Spoke3-To-Hub2 --vnet-name Spoke3 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Hub2

az network vnet peering create -g AZFW -n Hub2-To-Spoke4 --vnet-name Hub2 --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Spoke4
az network vnet peering create -g AZFW -n Spoke4-To-Hub2 --vnet-name Spoke4 --allow-vnet-access --allow-forwarded-traffic --remote-vnet /subscriptions/XXXX/resourceGroups/AZFW/providers/Microsoft.Network/virtualNetworks/Hub2
</pre>

**Create route tables for firewalls and spokes. This assumes AZFW1 is 10.10.0.4 and AZFW2 is 10.20.0.4**
<pre lang="...">
az network route-table create --name AZFW1-RT --resource-group AZFW --location westus2
az network route-table route create --resource-group AZFW --name to-Internet --route-table-name AZFW1-RT --address-prefix 0.0.0.0/0 --next-hop-type Internet
az network route-table route create --resource-group AZFW --name to-Spoke3-Spoke4 --route-table-name AZFW1-RT --address-prefix 10.20.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.0.4
az network vnet subnet update -n AzureFirewallSubnet -g AZFW --vnet-name Hub1 --address-prefixes 10.10.0.0/26 --route-table AZFW1-RT
az network route-table create --name AZFW2-RT --resource-group AZFW --location eastus
az network route-table route create --resource-group AZFW --name to-Internet --route-table-name AZFW2-RT --address-prefix 0.0.0.0/0 --next-hop-type Internet
az network route-table route create --resource-group AZFW --name to-Hub1 --route-table-name AZFW2-RT --address-prefix 10.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.10.0.4
az network vnet subnet update -n AzureFirewallSubnet -g AZFW --vnet-name Hub2 --address-prefixes 10.20.0.0/26 --route-table AZFW2-RT
az network route-table create --name Spoke1-RT --resource-group AZFW --location westus2 --disable-bgp-route-propagation
az network route-table route create --resource-group AZFW --name Default-Route --route-table-name Spoke1-RT --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.10.0.4
az network vnet subnet update -n Spoke1VMSubnet -g AZFW --vnet-name Spoke1 --address-prefixes 10.10.1.0/24 --route-table Spoke1-RT
az network route-table create --name Spoke2-RT --resource-group AZFW --location westus2 --disable-bgp-route-propagation
az network route-table route create --resource-group AZFW --name Default-Route --route-table-name Spoke2-RT --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.10.0.4
az network vnet subnet update -n Spoke2VMSubnet -g AZFW --vnet-name Spoke2 --address-prefixes 10.10.2.0/24 --route-table Spoke1-RT
az network route-table create --name Spoke3-RT --resource-group AZFW --location eastus --disable-bgp-route-propagation
az network route-table route create --resource-group AZFW --name Default-Route --route-table-name Spoke3-RT --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.0.4
az network vnet subnet update -n Spoke3VMSubnet -g AZFW --vnet-name Spoke3 --address-prefixes 10.20.1.0/24 --route-table Spoke3-RT
az network route-table create --name Spoke4-RT --resource-group AZFW --location eastus --disable-bgp-route-propagation
az network route-table route create --resource-group AZFW --name Default-Route --route-table-name Spoke4-RT --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.0.4
az network vnet subnet update -n Spoke4VMSubnet -g AZFW --vnet-name Spoke4 --address-prefixes 10.20.2.0/24 --route-table Spoke3-RT
</pre>

**Create firewall rules**
<pre lang="...">
az network firewall network-rule create --resource-group AZFW --firewall-name AZFW1 --collection-name AZFW1-rules --priority 100 --action Allow --name Allow-All --protocols Any --source-addresses 10.0.0.0/8 --destination-addresses * --destination-ports *
az network firewall network-rule create --resource-group AZFW --firewall-name AZFW2 --collection-name AZFW2-rules --priority 100 --action Allow --name Allow-All --protocols Any --source-addresses 10.0.0.0/8 --destination-addresses * --destination-ports *
</pre>

**Document public IPs of the Jump VM, Firewalls and save them to notepad**
<pre lang="...">
az network public-ip show --name JumpVM-pip --resource-group AZFW --query [ipAddress] --output tsv
az network public-ip show --name AZFW1-pip --resource-group AZFW --query [ipAddress] --output tsv
az network public-ip show --name AZFW2-pip --resource-group AZFW --query [ipAddress] --output tsv
</pre>

SSH to the Jump VM public IP. From there, SSH to Spoke1VM (10.10.1.4). From Spoke1VM, ping 10.10.0.4 (AZFW1), 10.10.2.4 (Spoke2VM), 10.20.0.4 (AZFW2), 10.20.1.4 (Spoke3VM)and 10.20.2.4 (Spoke4VM). Also curl ipconfig.io and compare that to the public IP previously saved to notepad. SSH from Spoke1VM to Spoke3VM (10.20.1.4). From Spoke3VM, curl ipconfig.io and compare that to the public IP previously saved to notepad.

**Create Expressroute Gateways, 1 in each hub. The configuration for the conenctions between the gateways and circuit is not shown**
<pre lang="...">
az network public-ip create --name ERGW1-pip --resource-group AZFW --location westus2
az network vnet-gateway create --name ERGW1 --resource-group AZFW --location westus2 --public-ip-address ERGW1-pip --vnet Hub1 --gateway-type "ExpressRoute" --sku "Standard" --no-wait
az network public-ip create --name ERGW2-pip --resource-group AZFW --location eastus
az network vnet-gateway create --name ERGW2 --resource-group AZFW --location eastus --public-ip-address ERGW2-pip --vnet Hub2 --gateway-type "ExpressRoute" --sku "Standard" --no-wait
</pre>

**Do not continue until each ERGW is fully provisioned.**
<pre lang="...">
az network vnet-gateway show -g AZFW -n ERGW1 -o table
az network vnet-gateway show -g AZFW -n ERGW2 -o table
</pre>

**Update each spoke peering to utilize the ERGWs**
<pre lang="...">
az network vnet peering update -g AZFW -n Spoke1-To-Hub1 --vnet-name Spoke1 --set useRemoteGateways=true
az network vnet peering update -g AZFW -n Spoke2-To-Hub1 --vnet-name Spoke2 --set useRemoteGateways=true
az network vnet peering update -g AZFW -n Spoke3-To-Hub2 --vnet-name Spoke3 --set useRemoteGateways=true
az network vnet peering update -g AZFW -n Spoke4-To-Hub2 --vnet-name Spoke4 --set useRemoteGateways=true
</pre>

**Update GatewaySubnets to point spoke traffic to AZFW**
<pre lang="...">
az network route-table create --name GWSubnet-RT --resource-group AZFW --location westus2
az network route-table route create --resource-group AZFW --name to-Spoke1 --route-table-name GWSubnet-RT --address-prefix 10.10.1.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.10.0.4
az network route-table route create --resource-group AZFW --name to-Spoke2 --route-table-name GWSubnet-RT --address-prefix 10.10.2.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.10.0.4
az network vnet subnet update -n GatewaySubnet -g AZFW --vnet-name Hub1 --route-table GWSubnet-RT
az network route-table create --name GWSubnet-RT2 --resource-group AZFW --location eastus
az network route-table route create --resource-group AZFW --name to-Spoke3 --route-table-name GWSubnet-RT2 --address-prefix 10.20.1.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.0.4
az network route-table route create --resource-group AZFW --name to-Spoke4 --route-table-name GWSubnet-RT2 --address-prefix 10.10.2.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.0.4
az network vnet subnet update -n GatewaySubnet -g AZFW --vnet-name Hub2 --route-table GWSubnet-RT2
</pre>

Once the connection is built between both ERGWs and the circuit, connectvity to the CPE loopback will be accessible.
