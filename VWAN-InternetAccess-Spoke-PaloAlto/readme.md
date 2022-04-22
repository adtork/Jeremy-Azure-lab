# Azure Networking Lab- VWAN with Internet access through Palo Alto Firewall in a spoke.

This lab illustrates how to build a basic VWAN environment with Internet access provided by a Palo Alto Firewall in the spoke. The same principles apply if you were to use other vendor's NVA in the spoke in place of PAN. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. Note- VM username is "azureuser" and passwords are "Msft123Msft123". The VM in Spoke2 will have outbound Internet access through the FW in Spoke1. VWAN Hub is injecting a default route out all of the connections with a next hop of the PAN trust interface. The FW is providing NAT functionality which will map to it's public IP associated with the untrust NIC. In order to test connectivity, you will need to console/Bastion into the Spoke in VM2 to test access or apply a UDR with your source IP to next hop Internet. 

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/vwan-PAN-in-spoke)

**Build Resource Groups, VNETs and Subnets**
<pre lang="...">
##Variables#
RG="VWAN-PAN-Lab"
Location="eastus2"
hubname="vhub1"
</pre>

**Before deploying PAN, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying PAN in the portal or Powershell/Azure CLI commands via Cloudshell**
<pre lang="...">
Sample Azure CLI:
az vm image terms accept --urn paloaltonetworks:vmseries1:byol:latest
</pre>

##Create RG and VWAN Hub
<pre lang="...">
az group create --name VWAN-PAN-Lab --location $Location
az network vwan create --name VWAN --resource-group $RG --branch-to-branch-traffic true --location $Location
az network vhub create --address-prefix 192.168.0.0/24 --name $hubname --resource-group $RG --vwan VWAN --location $Location --sku basic
</pre>

##Create Spoke 1 and Spoke 2. Spoke 1 will have the FW providing outbound Internet access. Spoke 2 will have the test VM.
<pre lang="...">
az network vnet create --resource-group $RG --name Spoke1 --location $Location --address-prefixes 10.1.0.0/16 --subnet-name Spoke1VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group $RG --vnet-name Spoke1
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group $RG --vnet-name Spoke1
az network vnet subnet create --address-prefix 10.1.2.0/24 --name twonet --resource-group $RG --vnet-name Spoke1

az network public-ip create --name PAN1MgmtIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network public-ip create --name PAN-Outside-PublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name PAN1MgmtInterface --resource-group $RG --subnet twonet --vnet Spoke1 --public-ip-address PAN1MgmtIP --private-ip-address 10.1.2.4 --ip-forwarding true
az network nic create --name PAN1OutsideInterface --resource-group $RG --subnet zeronet --vnet Spoke1 --public-ip-address PAN-Outside-PublicIP --private-ip-address 10.1.0.4 --ip-forwarding true
az network nic create --name PAN1InsideInterface --resource-group $RG --subnet onenet --vnet Spoke1 --private-ip-address 10.1.1.4 --ip-forwarding true
az vm create --resource-group $RG --location $Location --name PAN --size Standard_D3_v2 --nics PAN1MgmtInterface PAN1OutsideInterface PAN1InsideInterface  --image paloaltonetworks:vmseries1:byol:latest --admin-username azureuser --admin-password Msft123Msft123

az network vnet create --resource-group $RG --name Spoke2 --location $Location --address-prefixes 10.2.0.0/16 --subnet-name Spoke2VM --subnet-prefix 10.2.10.0/24
az network public-ip create --name Spoke2VMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n Spoke2VMNIC --location $Location --subnet Spoke2VM --vnet-name Spoke2 --public-ip-address Spoke2VMPubIP --private-ip-address 10.2.10.4
az VM create -n Spoke2VM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke2VMNIC --no-wait

az network route-table create --name PAN-RT --resource-group $RG --location $Location
az network route-table route create --resource-group $RG --name to-Internet --route-table-name PAN-RT --address-prefix 0.0.0.0/0 --next-hop-type Internet
az network vnet subnet update --name zeronet --vnet-name Spoke1 --resource-group $RG --route-table PAN-RT
az network vnet subnet update --name twonet --vnet-name Spoke1 --resource-group $RG --route-table PAN-RT
</pre>

##Check VWAN hub routing status. Do not proceed until the service is provisioned.
<pre lang="...">
az network vhub show -g $RG -n $hubname --query 'routingState' -o tsv
</pre>

##Create connections from the VWAN hub to each spoke. Inject 0/0 into the fabric pointing to next hop of the private IP of the CSR in Spoke1.
<pre lang="...">
connname=to-spoke1
az network vhub connection create --name to-Spoke1 --resource-group $RG --remote-vnet Spoke1 --vhub-name $hubname
az network vhub connection create --name to-Spoke2 --resource-group $RG --remote-vnet Spoke2 --vhub-name $hubname 
connid=$(az network vhub connection show -g $RG -n to-Spoke1 --vhub-name $hubname --query id -o tsv)
az network vhub route-table route add --name defaultRouteTable --vhub-name $hubname --resource-group $RG --route-name default --destination-type CIDR --destinations "0.0.0.0/0" --next-hop-type ResourceID --next-hop $connid
vnetid=$(az network vnet show -g $RG -n Spoke1 --query id --out tsv)
az network vhub connection create --name to-Spoke1 --resource-group $RG --remote-vnet $vnetid --vhub-name $hubname --route-name default --address-prefixes "0.0.0.0/0" --next-hop "10.1.1.4"
</pre>

**Firewall configuration**
- Download Firewall XML file: https://github.com/jwrightazure/lab/blob/master/pan-vpn-to-azurevpngw-ikev2-bgp/running-config.xml
- Open the XML file and replace references to "Azure-VNGpubip" with the public IP addresses for the Azure VPN gateway and save.
- HTTPS to the firewall
- Select Device tab
- Select Operations tab
- Select Import Named Configuration Snapshot. Upload the running-config.xml file in this repo.
- Select Load Named Configuration Snapshot. Select the firewall XML you previously uploaded.
- Select Commit (top right) and then commit the configuration



##From the VM in Spoke2, curl ipconfig.io. The output should be the public IP of the CSR 
<pre lang="...">
az network public-ip show --resource-group $RG -n PAN1MgmtIP --query "{address: ipAddress}"
</pre>
