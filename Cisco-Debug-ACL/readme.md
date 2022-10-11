# Cisco Debug to ACL
This lab creates a basic topology where ping treffic is sent from a VM to a Catalyst 8000v. In order to validate the traffic is being sent to C8V, we will configure a basic ACL and turn on debugs against that ACL. At the end of this lab, you will be able to validate traffic is routed correctly through Azure and is received by the C8V. All username/passwords are azureuser/Msft123Msft123

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/Cisco-Debug-ACL/debug-acl-topo.png)

**Before deploying C8V in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a C8V in the portal or Powershell commands via Cloudshell**
<pre lang="...">
Sample Azure CLI:
az vm image terms accept --urn cisco:cisco-c8000v:17_09_01a-byol:latest
</pre>

**Create basic variables, VNET, test VM and C8V**
<pre lang="...">
RG="Cisco-Debug-ACL-Lab"
Location="eastus2"

az group create --name $RG --location $Location
az network vnet create --resource-group $RG --name Hub --location $Location --address-prefixes 10.1.0.0/16 --subnet-name HubVM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group $RG --vnet-name Hub
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group $RG --vnet-name Hub

az network nsg create --resource-group $RG --name NSG --location $Location
az network nsg rule create --resource-group $RG --nsg-name NSG --name SSH --access Allow --protocol "TCP" --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "22"

az network public-ip create --name VMPublicIP --resource-group $RG --location $Location --version IPv4 --sku Standard --allocation-method Static
az network nic create --resource-group $RG -n VMNIC --location $Location --subnet HubVM --private-ip-address 10.1.10.10 --vnet-name Hub --public-ip-address VMPublicIP --network-security-group NSG
az vm create -n VM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics VMNIC --no-wait

az network public-ip create --name C8KPublicIP --resource-group $RG --idle-timeout 30 --version IPv4 --sku Standard --allocation-method Static
az network nic create --name C8KOutsideInterface --resource-group $RG --subnet zeronet --vnet Hub --public-ip-address C8KPublicIP --ip-forwarding true --network-security-group NSG
az network nic create --name C8KInsideInterface --resource-group $RG --subnet onenet --vnet Hub --ip-forwarding true
az vm create --resource-group $RG --location $Location --name C8K --size Standard_D2_v2 --nics C8KOutsideInterface C8KInsideInterface  --image cisco:cisco-c8000v:17_09_01a-byol:latest --admin-username azureuser --admin-password Msft123Msft123
</pre>

**Document public IPs of the test VM and C8V**
<pre lang="...">
az network public-ip show --resource-group $RG -n C8KPublicIP --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n VMPublicIP --query "{address: ipAddress}"
</pre>

**SSH to the C8V and paste in the following config. Initiate a ping from the test VM to 10.1.0.4 (C8V)**
<pre lang="...">
term mon
conf t
ip access-list extended 100
permit ip host 10.1.10.10 host 10.1.0.4 log
permit ip any any
int gi1
ip access-group 100 in
</pre>

**Sample output from the C8V log showing traffic routed correctly.**
<pre lang="...">
*Oct 11 17:32:16.298: %FMANFP-6-IPACCESSLOGDP: F0/0: fman_fp_image: list 100 permitted icmp 10.1.10.10 -> 10.1.0.4 (2048/0), 1 packet
</pre>
