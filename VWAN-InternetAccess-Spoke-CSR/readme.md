# Azure Networking Lab- VWAN with Internet access through CSR in a spoke.

This lab illustrates how to build a basic VWAN environment with Internet access provided by a Cisco CSR in the spoke. The same principles apply if you were to use other vendor's NVA in the spoke in place of the CSR. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. Note- VM username is "azureuser" and passwords are "Msft123Msft123". The VM in Spoke2 will have outbound Internet access through the CSR in Spoke1. VWAN Hub is injecting a default route out all of the connections with a next hop of the CSR inside interface. The CSR is providing NAT functionality which will map to it's public IP associated with outside NIC of the CSR. In order to test connectivity, you will need to console/Bastion into the Spoke in VM2 to test access or apply a UDR with your source IP to next hop Internet. It is also recommended to use the serial console to access the CSR. I've seen sporadic issues losing SSH connectivity to the CSR when enabling NAT. Serial console requires setting up custom boot diagnostics which is outside the scope of this document.

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/csr-in-spoke.PNG)

**Build Resource Groups, VNETs and Subnets**
<pre lang="...">
##Variables#
RG="VWAN-CSR-Lab"
Location="eastus2"
hubname="vhub1"
</pre>

**Before deploying CSR in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands via Cloudshell**
<pre lang="...">
Sample Azure CLI:
az vm image terms accept --urn cisco:cisco-csr-1000v:17_3_4a-byol:latest
</pre>

##Create RG and VWAN Hub
<pre lang="...">
az group create --name VWAN-CSR-Lab --location $Location
az network vwan create --name VWAN --resource-group $RG --branch-to-branch-traffic true --location $Location
az network vhub create --address-prefix 192.168.0.0/24 --name $hubname --resource-group $RG --vwan VWAN --location $Location --sku basic
</pre>

##Create Spoke 1 and Spoke 2. Spoke 1 will have the CSR providing outbound Internet access. Spoke 2 will have the test VM.
<pre lang="...">
az network vnet create --resource-group $RG --name Spoke1 --location $Location --address-prefixes 10.1.0.0/16 --subnet-name Spoke1VM --subnet-prefix 10.1.10.0/24

az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group $RG --vnet-name Spoke1
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group $RG --vnet-name Spoke1

az network public-ip create --name CSRPublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name CSROutsideInterface --resource-group $RG --subnet zeronet --vnet Spoke1 --public-ip-address CSRPublicIP --ip-forwarding true
az network nic create --name CSRInsideInterface --resource-group $RG --subnet onenet --vnet Spoke1 --ip-forwarding true
az vm create --resource-group $RG --location $Location --name CSR --size Standard_D2_v2 --nics CSROutsideInterface CSRInsideInterface  --image cisco:cisco-csr-1000v:17_3_4a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait

az network vnet create --resource-group $RG --name Spoke2 --location $Location --address-prefixes 10.2.0.0/16 --subnet-name Spoke2VM --subnet-prefix 10.2.10.0/24
az network public-ip create --name Spoke2VMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n Spoke2VMNIC --location $Location --subnet Spoke2VM --vnet-name Spoke2 --public-ip-address Spoke2VMPubIP --private-ip-address 10.2.10.4
az VM create -n Spoke2VM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Spoke2VMNIC --no-wait
az network route-table create --name CSR-RT --resource-group $RG --location $Location
az network route-table route create --resource-group $RG --name to-Internet --route-table-name CSR-RT --address-prefix 0.0.0.0/0 --next-hop-type Internet
az network vnet subnet update --name zeronet --vnet-name Spoke1 --resource-group $RG --route-table CSR-RT
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

##Connect to the CSR and paste in the configuration
<pre lang="...">
ip route 10.2.0.0 255.255.0.0 10.1.1.1
access-list 1 permit 10.0.0.0 0.255.255.255
!
ip nat inside source list 1 interface GigabitEthernet1 overload

int GigabitEthernet2
ip nat inside
int GigabitEthernet1
ip nat outside
</pre>


##From the VM in Spoke2, curl ipconfig.io. The output should be the public IP of the CSR 
<pre lang="...">
az network public-ip show --resource-group $RG -n CSRPublicIP --query "{address: ipAddress}"
</pre>
