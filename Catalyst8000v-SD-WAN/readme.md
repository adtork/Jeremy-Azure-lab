# Draft- Catalyst 8000v SD-WAN in Azure
This lab builds 2 different VNETs, each with a Catalyst 8000v and test VMs. The 8ks will be onboarded to an existing SD-WAN fabric. The configurations assume an existing Cisco SD-WAN fabric with available licensing and vManage acting as the CA. The 8kv will be onboarded and configured via CLI, not through vManage templates. All Azure configurations are done with Azure CLI through shell.azure.com. At the end of this lab, each VM will be able to communicate via the SD-WAN tunnel.

# Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/8k-sdwan-branch-topo.drawio.png)

**Define variables and accept terms to use the 8kv. Change "x.x.x.x/32" to your source IP.**
<pre lang="...">
rg=Branch1
loc=eastus
sourceIP="$x.x.x.x/32"
az vm image terms accept --urn Cisco:cisco-c8000v:17_09_02a-byol:latest
</pre>

**Create RG,VNET and VMs for site1**
<pre lang="...">
az group create --name $rg --location $loc
az network nsg create --resource-group $rg --name 8k1-transport --location $loc
az network nsg rule create --resource-group $rg --nsg-name 8k1-transport --name Azure --access Allow --protocol "*" --direction Inbound --priority 400 --source-address-prefix AzureCloud --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name 8k1-transport --name home --access Allow --protocol "*" --direction Inbound --priority 500 --source-address-prefix $sourceIP --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg create --resource-group $rg --name VM1 --location $loc
az network nsg rule create --resource-group $rg --nsg-name VM1 --name Azure --access Allow --protocol "*" --direction Inbound --priority 400 --source-address-prefix AzureCloud --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name VM1 --name home --access Allow --protocol "*" --direction Inbound --priority 500 --source-address-prefix $sourceIP --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network vnet create --resource-group $rg --name site1 --location $loc --address-prefixes 10.1.0.0/16 --subnet-name 8k1-transport --subnet-prefix 10.1.0.0/24 
az network vnet subnet create --address-prefix 10.1.1.0/24 --name 8k1-service --resource-group $rg --vnet-name site1 
az network vnet subnet create --address-prefix 10.1.10.0/24 --name site1-vm --resource-group $rg --vnet-name site1 
az network public-ip create --name 8k1-pip --resource-group $rg --allocation-method static --idle-timeout 30 --location $loc
az network nic create --name 8k1-transport --resource-group $rg --subnet 8k1-transport --vnet-name site1 --public-ip-address 8k1-pip --private-ip-address 10.1.0.4 --ip-forwarding true --network-security-group 8k1-transport
az network nic create --name 8k1-service --resource-group $rg --subnet 8k1-service  --vnet-name site1 --ip-forwarding true --private-ip-address 10.1.1.4  --location $loc
az vm create --resource-group $rg --location $loc --name 8k1 --size Standard_DS3_v2 --nics 8k1-transport 8k1-service --image Cisco:cisco-c8000v:17_09_02a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --location $loc --no-wait
az network public-ip create --name VM1-PIP --location $loc --resource-group $rg --allocation-method static
az network nic create --resource-group $rg --name VM1-NIC --location $loc --subnet site1-vm --private-ip-address 10.1.10.10 --vnet-name site1 --public-ip-address VM1-PIP --ip-forwarding true --network-security-group VM1
az vm create -n VM1 --resource-group $rg  --image UbuntuLTS --size Standard_DS3_v2 --admin-username azureuser --admin-password Msft123Msft123 --nics VM1-NIC --location $loc --no-wait 
az network route-table create --name site1-VM1-rt --resource-group $rg
az network route-table route create --name VM1-rt --resource-group $rg --route-table-name site1-VM1-rt --address-prefix 10.0.0.0/8 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name site1-vm --vnet-name site1 --resource-group $rg --route-table site1-VM1-rt
</pre>

**Enable the Gi2 on 8k1 which will be used for the service VPN.**
<pre lang="...">
int gi2
ip address dhcp
no shut
ip route 10.1.10.0 255.255.255.0 10.1.1.1
</pre>

**Important- The vManage used in this lab has a root certificate named "ROOTCA.pem". From vManage vshell, cat ROOTCA.pem to view the certificate. Transfer the ROOTCA.pem file to 8k1. EX: on vManage- cat ROOTCA.pem, copy the output to your local machine, save the file, scp the file to VM1, on 8k1- "copy scp: bootflash:" and follow the prompts. The cert will be installed in a later step.** 

**Change the 8k from autonomous mode to controller mode. Confirm the change and then no to the init file. The 8k will reboot at this time.**
<pre lang="...">
controller-mode enable
</pre>

**Onboard 8k1 to the existing SD-WAN fabric. Note- in controller mode you have to use "config-t" and you have to "commit" the config changes. Make sure to change the fabric setting match your environment.**
<pre lang="...">
config-t
hostname 8k1
system
organization-name "your-existing-org-name"
sp-organization-name "your-existing-org-name"
site-id 10
vbond x.x.x.x
system-ip 111.111.111.111
commit
exit
interface Tunnel1
no shut
ip unnumbered GigabitEthernet1
tunnel source GigabitEthernet1
tunnel mode sdwan
sdwan
interface GigabitEthernet1
tunnel-interface
encapsulation ipsec
color biz-internet
commit
exit
exit
vrf definition 100
address-family ipv4
interface GigabitEthernet 2
vrf forwarding 100
ip address dhcp
no shut
commit
exit
ip route vrf 100 10.1.10.0 255.255.255.0 10.1.1.1
commit
exit
</pre>

**Install the root certificate that was previously transferred.**
<pre lang="...">
request platform software sdwan root-cert-chain install bootflash:ROOTCA.pem
</pre>

**Configure 8k1 to join the existing SD-WAN fabric. Change the chassis and token.**
<pre lang="...">
request platform software sdwan vedge_cloud activate chassis-number C8K-19D16B9C-8037-F6CC-14B5-5C9523F558E3 token ca89876d04f5410a857fa6b1ff2c1fca
</pre>

**Create RG,VNET and VMs for site2**
<pre lang="...">
rg=Branch2
loc=eastus

az group create --name $rg --location $loc
az network nsg create --resource-group $rg --name 8k2-transport --location $loc
az network nsg rule create --resource-group $rg --nsg-name 8k2-transport --name Azure --access Allow --protocol "*" --direction Inbound --priority 400 --source-address-prefix AzureCloud --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name 8k2-transport --name home --access Allow --protocol "*" --direction Inbound --priority 500 --source-address-prefix $sourceIP --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg create --resource-group $rg --name VM2 --location $loc
az network nsg rule create --resource-group $rg --nsg-name VM2 --name Azure --access Allow --protocol "*" --direction Inbound --priority 400 --source-address-prefix AzureCloud --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name VM2 --name home --access Allow --protocol "*" --direction Inbound --priority 500 --source-address-prefix $sourceIP --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network vnet create --resource-group $rg --name site2 --location $loc --address-prefixes 10.2.0.0/16 --subnet-name 8k2-transport --subnet-prefix 10.2.0.0/24 
az network vnet subnet create --address-prefix 10.2.1.0/24 --name 8k2-service --resource-group $rg --vnet-name site2 
az network vnet subnet create --address-prefix 10.2.10.0/24 --name site2-vm --resource-group $rg --vnet-name site2 
az network public-ip create --name 8k2-pip --resource-group $rg --allocation-method static --idle-timeout 30 --location $loc
az network nic create --name 8k2-transport --resource-group $rg --subnet 8k2-transport --vnet-name site2 --public-ip-address 8k2-pip --private-ip-address 10.2.0.4 --ip-forwarding true --network-security-group 8k2-transport
az network nic create --name 8k2-service --resource-group $rg --subnet 8k2-service  --vnet-name site2 --ip-forwarding true --private-ip-address 10.2.1.4  --location $loc
az vm create --resource-group $rg --location $loc --name 8k2 --size Standard_DS3_v2 --nics 8k2-transport 8k2-service --image Cisco:cisco-c8000v:17_09_02a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --location $loc --no-wait
az network public-ip create --name VM2-PIP --location $loc --resource-group $rg --allocation-method static
az network nic create --resource-group $rg --name VM2-NIC --location $loc --subnet site2-vm --private-ip-address 10.2.10.10 --vnet-name site2 --public-ip-address VM2-PIP --ip-forwarding true --network-security-group VM2
az vm create -n VM2 --resource-group $rg  --image UbuntuLTS --size Standard_DS3_v2 --admin-username azureuser --admin-password Msft123Msft123 --nics VM2-NIC --location $loc --no-wait 
az network route-table create --name site2-VM2-rt --resource-group $rg
az network route-table route create --name VM2-rt --resource-group $rg --route-table-name site2-VM2-rt --address-prefix 10.0.0.0/8 --next-hop-type VirtualAppliance --next-hop-ip-address 10.2.1.4
az network vnet subnet update --name site2-vm --vnet-name site2 --resource-group $rg --route-table site2-VM2-rt
</pre>

**Enable the Gi2 on 8k2 which will be used for the service VPN.**
<pre lang="...">
int gi2
ip address dhcp
no shut
ip route 10.2.10.0 255.255.255.0 10.2.1.1
</pre>

**Important- The vManage used in this lab has a root certificate named "ROOTCA.pem". From vManage vshell, cat ROOTCA.pem to view the certificate. Transfer the ROOTCA.pem file to 8k2. EX: on vManage- cat ROOTCA.pem, copy the output to your local machine, save the file, scp the file to VM2, on 8k1- "copy scp: bootflash:" and follow the prompts. The cert will be installed in a later step.** 

**Change the 8k from autonomous mode to controller mode. Confirm the change and then no to the init file. The 8k will reboot at this time.**
<pre lang="...">
controller-mode enable
</pre>

**Onboard 8k2 to the existing SD-WAN fabric. Note- in controller mode you have to use "config-t" and you have to "commit" the config changes. Make sure to change the fabric setting match your environment.**
<pre lang="...">
config-t
hostname 8k2
system
organization-name "your-existing-org-name"
sp-organization-name "your-existing-org-name"
site-id 20
vbond x.x.x.x
system-ip 112.112.112.112
commit
exit
interface Tunnel1
no shut
ip unnumbered GigabitEthernet1
tunnel source GigabitEthernet1
tunnel mode sdwan
sdwan
interface GigabitEthernet1
tunnel-interface
encapsulation ipsec
color biz-internet
commit
exit
exit
vrf definition 100
address-family ipv4
interface GigabitEthernet 2
vrf forwarding 100
ip address dhcp
no shut
commit
exit
ip route vrf 100 10.2.10.0 255.255.255.0 10.2.1.1
commit
exit
</pre>

**Install the root certificate that was previously transferred.**
<pre lang="...">
request platform software sdwan root-cert-chain install bootflash:ROOTCA.pem
</pre>

**Configure 8k2 to join the existing SD-WAN fabric. Change the chassis and token. After 8k2 joins the fabric, VM1 and VM2 will be able to communicate**
<pre lang="...">
request platform software sdwan vedge_cloud activate chassis-number C8K-19D16B9C-8037-F6CC-14B5-5C9523F558E3 token ca89876d04f5410a857fa6b1ff2c1fca
</pre>

**Verification commands on 8ks**
<pre lang="...">
show sdwan running-config
show sdwan control connections
show sdwan bfd sessions
show sdwan omp peers
show sdwan omp routes
show sdwan tunnel statistics
show sdwan ipsec inbound-connections
show sdwan ipsec outbound-connections
show sdwan ipsec local-sa
</pre>
