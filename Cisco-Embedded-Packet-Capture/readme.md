# Cisco Embedded Packet Capture
This lab demonstrates Embedded Packet Capture on IOS/XE. The below lab is based on 17.9.2a.

# Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/Cisco-Embedded-Packet-Capture/embedded-packet-capture.drawio.png)

**Define variables and accept terms to use the 8kv. Change "x.x.x.x/32" to your source IP.**
<pre lang="...">
rg=Cisco-EPC
loc=eastus
sourceIP="x.x.x.x/32"
az vm image terms accept --urn Cisco:cisco-c8000v:17_09_02a-byol:latest
</pre>

**Create RG,VNET and VMs**
<pre lang="...">
az group create --name $rg --location $loc
az network nsg create --resource-group $rg --name 8k1 --location $loc
az network nsg rule create --resource-group $rg --nsg-name 8k1 --name home --access Allow --protocol "*" --direction Inbound --priority 500 --source-address-prefix $sourceIP --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name 8k1 --name vms --access Allow --protocol "*" --direction Inbound --priority 600 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name 8k1 --name all-out --access Allow --protocol "*" --direction Outbound --priority 700 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg create --resource-group $rg --name VM1 --location $loc
az network nsg rule create --resource-group $rg --nsg-name VM1 --name home --access Allow --protocol "*" --direction Inbound --priority 500 --source-address-prefix $sourceIP --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name VM1 --name vms --access Allow --protocol "*" --direction Inbound --priority 600 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg create --resource-group $rg --name VM2 --location $loc
az network nsg rule create --resource-group $rg --nsg-name VM2 --name home --access Allow --protocol "*" --direction Inbound --priority 500 --source-address-prefix $sourceIP --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name VM2 --name vms --access Allow --protocol "*" --direction Inbound --priority 600 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network vnet create --resource-group $rg --name Cisco-EPC --location $loc --address-prefixes 10.1.0.0/16 --subnet-name 8k1 --subnet-prefix 10.1.0.0/24 
az network vnet subnet create --address-prefix 10.1.10.0/24 --name Cisco-EPC-vm --resource-group $rg --vnet-name Cisco-EPC 
az network vnet subnet create --address-prefix 10.1.20.0/24 --name Cisco-EPC-vm2 --resource-group $rg --vnet-name Cisco-EPC 
az network public-ip create --name 8k1-pip --resource-group $rg --allocation-method static --idle-timeout 30 --location $loc
az network nic create --name 8k1 --resource-group $rg --subnet 8k1 --vnet-name Cisco-EPC --public-ip-address 8k1-pip --private-ip-address 10.1.0.4 --ip-forwarding true --network-security-group 8k1
az vm create --resource-group $rg --location $loc --name 8k1 --size Standard_DS3_v2 --nics 8k1 --image Cisco:cisco-c8000v:17_09_02a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --location $loc --no-wait
az network public-ip create --name VM1-PIP --location $loc --resource-group $rg --allocation-method static
az network nic create --resource-group $rg --name VM1-NIC --location $loc --subnet Cisco-EPC-vm --private-ip-address 10.1.10.10 --vnet-name Cisco-EPC --public-ip-address VM1-PIP --ip-forwarding true --network-security-group VM1
az vm create -n VM1 --resource-group $rg  --image UbuntuLTS --size Standard_DS3_v2 --admin-username azureuser --admin-password Msft123Msft123 --nics VM1-NIC --location $loc --no-wait 
az network route-table create --name Cisco-EPC-VM1-rt --resource-group $rg
az network route-table route create --name VM1-rt --resource-group $rg --route-table-name Cisco-EPC-VM1-rt --address-prefix 10.1.20.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network vnet subnet update --name Cisco-EPC-vm --vnet-name Cisco-EPC --resource-group $rg --route-table Cisco-EPC-VM1-rt
az network public-ip create --name VM2-PIP --location $loc --resource-group $rg --allocation-method static
az network nic create --resource-group $rg --name VM2-NIC --location $loc --subnet Cisco-EPC-vm2 --private-ip-address 10.1.20.10 --vnet-name Cisco-EPC --public-ip-address VM2-PIP --ip-forwarding true --network-security-group VM2
az vm create -n VM2 --resource-group $rg  --image UbuntuLTS --size Standard_DS3_v2 --admin-username azureuser --admin-password Msft123Msft123 --nics VM2-NIC --location $loc --no-wait 
az network route-table create --name Cisco-EPC-VM2-rt --resource-group $rg
az network route-table route create --name VM2-rt --resource-group $rg --route-table-name Cisco-EPC-VM2-rt --address-prefix 10.1.10.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.0.4
az network vnet subnet update --name Cisco-EPC-vm2 --vnet-name Cisco-EPC --resource-group $rg --route-table Cisco-EPC-VM2-rt
</pre>

**Connect to 8k1 and add routes for VM subnets**
<pre lang="...">
ip route 10.1.10.0 255.255.255.0 10.1.0.1
ip route 10.1.10.0 255.255.255.0 10.1.0.1
</pre>

**Create and start a capture on 8k1 for all traffic. Warning- this could impact performance in a production environment since it is capturing all traffic. Later in the lab it will be limited to an ACL. Commands are implemented in Privileged EXEC mode.**
<pre lang="...">
monitor capture TEST interface GigabitEthernet 1 both match any start
</pre>

**Validate and view buffer packets.**
<pre lang="...">
show mon cap TEST buffer
show mon cap TEST buffer brief

#You can export the capture if needed
mon cap TEST export 

#Clear the buffer, stop the capture, delete the capture 
mon cap TEST clear
mon cap TEST stop
no mon cap TEST
</pre>

**Capture traffic matching an ACL. Remember to swith to Priveleged EXEC mode.**
<pre lang="...">
ip access-list extended ping
permit icmp host 10.1.10.10 10.1.20.10 0.0.0.0

#Start capture and view buffer
mon cap TEST access-list ping interface GigabitEthernet 1 both start
show mon cap TEST buffer brief
</pre>

#Buffer output after ACL
![alt text](https://github.com/jwrightazure/lab/blob/master/Cisco-Embedded-Packet-Capture/cap-output.png)
