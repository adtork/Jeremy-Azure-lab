# Basic Azure NAT Gateway Lab 
This lab guide illustrates how to build a basic NAT Gateway in Azure and a simulated destination web server. The goal of the lab is to quickly spin up a test environment and validate basic features. All configurations are done in Azure CLI so you can manipulate fields as needed. Everything is done using Azure so no hardware is needed. 

# Base Topology
The lab deploys 2 isolated VNETs. The source VNET will have 2 Linux VM machines and a Cisco CSR. SourceVM1 will route through the CSR before going out to the Internet through NAT Gateway. SourceVM2 will not route through the CSR but will use NAT Gateway for Internet connectivity. SourceVM1, SourceVM2 and the CSR will not have a public IP (PIP). The Jump VM will be used to SSH to SourceVM1, SourceVM2 and the CSR. The SourceVM1 subnet will have a default route pointed to the "inside" interface of the CSR. All credentials are azureuser/Msft123Msft123

![alt text](https://github.com/jwrightazure/lab/blob/master/images/basicnattopo2.PNG)

**Before deploying CSR in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands via Cloudshell**
<pre lang="...">
Sample Powershell:
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Build resources for source VNET**
<pre lang="...">
az group create --name NAT-RG --location eastus2
az network vnet create --resource-group NAT-RG --location eastus2 --name VNETSource --address-prefix 10.0.0.0/16 --subnet-name VMSubnetSource1 --subnet-prefix 10.0.0.0/24
az network vnet subnet create --address-prefix 10.0.1.0/24 --name VMSubnetSource2 --resource-group NAT-RG --vnet-name VNETSource
az network vnet subnet create --address-prefix 10.0.100.0/24 --name jump --resource-group NAT-RG --vnet-name VNETSource
az network vnet subnet create --address-prefix 10.0.200.0/24 --name CSRoutside --resource-group NAT-RG --vnet-name VNETSource
az network vnet subnet create --address-prefix 10.0.199.0/24 --name CSRinside --resource-group NAT-RG --vnet-name VNETSource
az network nsg create --resource-group NAT-RG --name NSGsource
az network nsg rule create --resource-group NAT-RG --nsg-name NSGsource --priority 100 --name SSH --description "SSH access" --access allow --protocol tcp --direction inbound --destination-port-ranges 22
az network nsg rule create --resource-group NAT-RG --nsg-name NSGsource --priority 200 --name TENS --description "TENS" --source-address-prefixes 10.0.0.0/8 --source-port-ranges * --destination-address-prefixes * --destination-port-ranges * --access allow --direction inbound
az network public-ip create --resource-group NAT-RG --name JumpVM --sku standard
az network nic create --resource-group NAT-RG --name JumpNIC --vnet-name VNETSource --subnet jump --public-ip-address JumpVM --private-ip-address 10.0.100.4 --network-security-group NSGsource
az vm create --resource-group NAT-RG --name JumpVM --nics JumpNIC --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network nic create --resource-group NAT-RG --name SourceVMNIC --vnet-name VNETSource --subnet VMSubnetSource1 --private-ip-address 10.0.0.4 --network-security-group NSGsource
az vm create --resource-group NAT-RG --name SourceVM1 --nics SourceVMNIC --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network nic create --resource-group NAT-RG --name SourceVMNIC2 --vnet-name VNETSource --subnet VMSubnetSource2 --private-ip-address 10.0.1.4 --network-security-group NSGsource
az vm create --resource-group NAT-RG --name SourceVM2 --nics SourceVMNIC2 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network nic create --name CSR1mgmtInterface -g NAT-RG --subnet jump --vnet VNETSource --ip-forwarding true --private-ip-address 10.0.100.5 --network-security-group NSGsource
az network nic create --name CSR1OutsideInterface -g NAT-RG --subnet CSRoutside --vnet VNETSource --ip-forwarding true --private-ip-address 10.0.200.4 --network-security-group NSGsource 
az network nic create --name CSR1InsideInterface -g NAT-RG --subnet CSRinside --vnet VNETSource --ip-forwarding true --private-ip-address 10.0.199.4 --network-security-group NSGsource
az vm create --resource-group NAT-RG --location eastus2 --name CSR1 --size Standard_D3 --nics CSR1mgmtInterface CSR1OutsideInterface CSR1InsideInterface --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network public-ip create --resource-group NAT-RG --name NATGW-PublicIPsource --sku standard
az network nat gateway create --resource-group NAT-RG --name NATGW --public-ip-addresses NATGW-PublicIPsource --idle-timeout 10
az network vnet subnet update --resource-group NAT-RG --vnet-name VNETSource --name CSRoutside --nat-gateway NATGW
az network vnet subnet update --resource-group NAT-RG --vnet-name VNETSource --name VMSubnetSource2 --nat-gateway NATGW
az network route-table create --name vm-rt --resource-group NAT-RG
az network route-table route create --name vm-rt --resource-group NAT-RG --route-table-name vm-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.199.4
az network vnet subnet update --name VMSubnetSource1 --vnet-name VNETSource --resource-group NAT-RG --route-table vm-rt
</pre>

**Build resources for destination VNET**
<pre lang="...">
az network vnet create --resource-group NAT-RG --location westus --name VNETdestination --address-prefix 192.168.0.0/16 --subnet-name SubnetdestinationVM --subnet-prefix 192.168.0.0/24
az network public-ip create --resource-group NAT-RG --name PublicIPdestinationVM --sku standard --location westus
az network nsg create --resource-group NAT-RG --name NSGdestination --location westus
az network nsg rule create --resource-group NAT-RG --nsg-name NSGdestination --priority 100 --name ssh --description "SSH access" --access allow --protocol tcp --direction inbound --destination-port-ranges 22
az network nsg rule create --resource-group NAT-RG --nsg-name NSGdestination --priority 101 --name http --description "HTTP access" --access allow --protocol tcp --direction inbound --destination-port-ranges 80
az network nic create --resource-group NAT-RG --name NicdestinationVM --vnet-name VNETdestination --subnet SubnetdestinationVM --public-ip-address PublicIPdestinationVM --network-security-group NSGdestination --location westus --private-ip-address 192.168.0.4
az vm create --resource-group NAT-RG --name VMdestination --nics NicdestinationVM --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --no-wait --location westus
</pre>

**Document the PIPs for the DestinationVM, NAT Gateway and JUMP 
<pre lang="...">
az network public-ip show --resource-group NAT-RG --name PublicIPdestinationVM --query [ipAddress] --output tsv
az network public-ip show --resource-group NAT-RG --name NATGW-PublicIPsource --query [ipAddress] --output tsv
az network public-ip show --resource-group NAT-RG --name JumpVM --query [ipAddress] --output tsv
</pre>

**SSH to destination server and install a web server**
<pre lang="...">
sudo apt-get update & sudo apt-get install nginx
</pre>

**SSH to CSR1 from the Jump VM. Paste in the below config:**
<pre lang="...">
interface Gi1
no ip nat outside

interface Gi3
ip address dhcp
no shut

ip route 0.0.0.0 0.0.0.0 10.0.200.1
ip route 10.0.0.0 255.255.255.0 10.0.199.1
ip route 10.0.1.0 255.255.255.0 10.0.199.1
ip access-list extended nat
permit ip 10.0.0.0 0.255.255.255 any
ip nat inside source list nat interface GigabitEthernet2 overload

int gi2
ip nat outside
int gi3
ip nat inside
</pre>

**SSH to the Jump VM and curl ipconfig.io from both SourceVM1 and SourceVM2. This will return the PIP of the NAT GW.**
<pre lang="...">
curl ipconfig.io
</pre>

**Turn on tcpdump destination VM. Insert the NAT GW PIP**
<pre lang="...">
sudo tcpdump -i any -c5 -nn "port 80 and (src "NATGW-PublicIPsource")"
</pre>

**Curl the destination web server IP from both SourceVM1 and SourceVM2. The source IP in the destination VM tcpdump will be the NAT GW PIP.**
<pre lang="...">
curl "PIP destination VM"
</pre>
