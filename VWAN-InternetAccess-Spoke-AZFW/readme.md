# Azure Networking Lab- VWAN with Internet access through firewall in a spoke.

This lab illustrates how to build a basic VWAN environment with Internet access provided by an Azure Firewall in the spoke. The same principles apply if you were to use an NVA in the spoke in place of the Azure Firewall. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. Note- VM username is "azureuser" and passwords are "Msft123Msft123". The VM in Spoke2 will have outbound Internet access through the firewall in Spoke1. VWAN Hub is injecting a default route out all of the connections with a next hop of Azure Firewall. In order to test connectivity, you will need to console/Bastion into the Spoke2 VM to test access or apply a UDR with your source IP to next hop Internet.

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/vwan-inet-spoke.PNG)

**Before deploying CSR in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands via Cloudshell**
<pre lang="...">
Sample Azure CLI:
az vm image terms accept --urn cisco:cisco-csr-1000v:17_3_4a-byol:latest
</pre>

**Build Resource Groups, VNETs and Subnets**
<pre lang="...">
##Variables#
RG="VWAN-test"
Location="eastus"
hubname="vhub1"

##Create RG and VWAN Hub
az group create --name VWAN-test --location $Location
az network vwan create --name VWAN --resource-group $RG --branch-to-branch-traffic true --location $Location
az network vhub create --address-prefix 192.168.0.0/24 --name $hubname --resource-group $RG --vwan VWAN --location $Location --sku basic
</pre>

##Create Spoke 1 and Spoke 2 with a VM in each.
<pre lang="...">
az network vnet create --resource-group $RG --name Spoke1 --location $Location --address-prefixes 10.1.0.0/16 --subnet-name Spoke1VM --subnet-prefix 10.1.10.0/24
az network public-ip create --name Spoke1VMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n Spoke1VMNIC --location $Location --subnet Spoke1VM --vnet-name Spoke1 --public-ip-address Spoke1VMPubIP --private-ip-address 10.1.10.4
az VM create -n Spoke1VM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke1VMNIC --no-wait

az network vnet create --resource-group $RG --name Spoke2 --location $Location --address-prefixes 10.2.0.0/16 --subnet-name Spoke2VM --subnet-prefix 10.2.10.0/24
az network public-ip create --name Spoke2VMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n Spoke2VMNIC --location $Location --subnet Spoke2VM --vnet-name Spoke2 --public-ip-address Spoke2VMPubIP --private-ip-address 10.2.10.4
az VM create -n Spoke2VM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke2VMNIC --no-wait
</pre>

##Create Azure Firewall and route table for 0/0 to the Internet. The route table is required since the VWAN hub will be advertising 0/0.
<pre lang="...">
az network vnet subnet create --address-prefix 10.1.100.0/24 --name AzureFirewallSubnet --resource-group $RG --vnet-name Spoke1
az network public-ip create --name AZFW1-pip --resource-group $RG --location $Location --allocation-method static --sku standard
az network firewall create --name AZFW1 --resource-group $RG --location $Location
az network firewall ip-config create --firewall-name AZFW1 --name FW-config --public-ip-address AZFW1-pip --resource-group $RG --vnet-name Spoke1
az network firewall update --name AZFW1 --resource-group $RG

az network route-table create --name AZFW1-RT --resource-group $RG --location $Location
az network route-table route create --resource-group $RG --name to-Internet --route-table-name AZFW1-RT --address-prefix 0.0.0.0/0 --next-hop-type Internet
az network vnet subnet update --name AzureFirewallSubnet --vnet-name Spoke1 --resource-group $RG --route-table AZFW1-RT
az network firewall network-rule create --collection-name ALL --priority 100 --action Allow --name Allow-All --protocols Any --source-addresses "*" --destination-addresses "*" --destination-ports "*" --resource-group $RG --firewall-name AZFW1
</pre>

##Check VWAN hub routing status. Do not proceed until the service is provisioned.
<pre lang="...">
az network vhub show -g $RG -n $hubname --query 'routingState' -o tsv
</pre>

##Create connections from the VWAN hub to each spoke. Inject 0/0 into the fabric pointing to next hop of the private IP of Azure Firewall in Spoke1.
<pre lang="...">
connname=to-spoke1
az network vhub connection create --name to-Spoke1 --resource-group $RG --remote-vnet Spoke1 --vhub-name $hubname
az network vhub connection create --name to-Spoke2 --resource-group $RG --remote-vnet Spoke2 --vhub-name $hubname 
connid=$(az network vhub connection show -g $RG -n to-Spoke1 --vhub-name $hubname --query id -o tsv)
az network vhub route-table route add --name defaultRouteTable --vhub-name $hubname --resource-group $RG --route-name default --destination-type CIDR --destinations "0.0.0.0/0" --next-hop-type ResourceID --next-hop $connid
vnetid=$(az network vnet show -g $RG -n Spoke1 --query id --out tsv)
az network vhub connection create --name to-Spoke1 --resource-group $RG --remote-vnet $vnetid --vhub-name $hubname --route-name default --address-prefixes "0.0.0.0/0" --next-hop "10.1.100.4"
</pre>

##From the VM in Spoke2, curl ipconfig.io. The output should be the public IP of Azure Firewall. 
<pre lang="...">
az network public-ip show --resource-group $RG -n AZFW1-pip --query "{address: ipAddress}"
</pre>
