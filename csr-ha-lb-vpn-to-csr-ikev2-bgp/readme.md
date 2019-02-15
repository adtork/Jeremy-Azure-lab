
# Objectives and Initial Setup
This lab guide shows how to configure highly available load balanced Cisco CSRs. Each CSR in Azure utilizes BGP over IKEv2 tunnel to a CSR located in a VNET that simulates an on prem environment. The test VM subnet on the Azure side will have UDRs pointed to an Azure Standard Load Balancer with a backend pool of the inside interfaces of CSR1 and CSR2. Traffic is load balanced across the 2 CSRs with the health probe monitoring the inside interfaces. In the event of a failure on CSR1 or CSR2, the load balancer will only steer traffic to the healthy CSR. BGP is also enabled between CSR1 and CSR2 providing tunnel redundancy if one of the tunnels goes down
The main goal of this lab is to quickly stand up a sandbox environment for functionality testing. The test VMs will be able to ping each other, all CSR interfaces including VTIs/loopbacks. Basic BGP prefix filters are in place to control route advertisement. Other methods could be used to filter routes. The entire environment is built on Azure and does not require any hardware. </br>

**Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/dual%20csr%20vpn.PNG)

**Lab IPs**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/labip.PNG)

**Requirements:**
- A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- If you are using Windows 10, you can install Bash shell on Ubuntu on Windows (http://www.windowscentral.com/how-install-bash-shell-command-line-windows-10).
- Azure CLI 2.0, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- Basic knowledge of Azure networking.

**Notes:**
This is for functionality testing purposes only and should not be considered production configurations. There are a number of configuration options (security policies/NSG/timers/CLI etc) and designs you can use, this is just an example to use as a baseline. Azure CLI is used to show the building blocks and order of operations to make the environment work. All CLI is provided so you can fit to your environment. Azure Cloud Shell is an option if you cannot install Azure CLI on your machine. A loopback address is added to each CSR for troubleshooting and validation purposes only. The lab uses CSR IOS-XE 16.10, syntax could very based on code levels. You may need to accept the legal agreement for the CSR BYOL demo image. Below is a Powershell example that you can run in Cloud Shell (in portal) to accept the agreement:
<pre lang="...">
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Step 1:** Login via Azure CLI. EX: I have Azure CLI on Windows 10. Open a command prompt and enter “az login”. It will prompt you for Azure credentials. All commands moving forward are done through Azure CLI and Cisco CLI via SSH.

**Step 2:** Create resource group, VNET + address space and subnets for CSR VNET in East US:
<pre lang="...">
az group create --name CSR --location "EastUS"
az network vnet create --name CSR --resource-group CSR --address-prefix 10.0.0.0/16
az network vnet subnet create --address-prefix 10.0.1.0/24 --name InsideSubnet --resource-group CSR --vnet-name CSR 
az network vnet subnet create --address-prefix 10.0.0.0/24 --name OutsideSubnet --resource-group CSR --vnet-name CSR
az network vnet subnet create --address-prefix 10.0.2.0/24 --name lbSubnet --resource-group CSR --vnet-name CSR
az network vnet subnet create --address-prefix 10.0.10.0/24 --name testVMSubnet --resource-group CSR --vnet-name CSR
</pre>

**Step 3:** Create internal standard load balancer, probe and rule for use in the CSR VNET. We will add backend pool members in future steps. We will be using SSH as the health probe for the inside interface of CSR1 and CSR2 with default timers. Enable floating IP and use of HA ports:
<pre lang="...">
az network lb create --name csr-lb --resource-group CSR --sku Standard --private-ip-address 10.0.2.100 --subnet lbsubnet --vnet-name CSR
az network lb address-pool create -g CSR --lb-name csr-lb -n csr-backendpool
az network lb probe create --resource-group CSR --lb-name csr-lb --name myHealthProbe --protocol tcp --port 22
az network lb rule create -g CSR --lb-name csr-lb -n MyHAPortsRule  --protocol All --frontend-port 0 --backend-port 0 --backend-pool-name csr-backendpool --floating-ip true --probe-name myHealthProbe
</pre>

**Step 4:** Create NSG and rules for the CSR1 and CSR2 interfaces. It allows SSH, UDP 500/4500, 10.x address and all outbound traffic. You can fine tune the NSG to your liking:
<pre lang="...">
az network nsg create --resource-group CSR --name Azure-CSR-NSG --location EastUS
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-192 --access Allow --protocol "*" --direction Inbound --priority 135 --source-address-prefix 192.168.0.0/16 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-1 --access Allow --protocol "*" --direction Inbound --priority 136 --source-address-prefix 1.1.1.1/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-2 --access Allow --protocol "*" --direction Inbound --priority 137 --source-address-prefix 2.2.2.2/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-3 --access Allow --protocol "*" --direction Inbound --priority 138 --source-address-prefix 3.3.3.3/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>

**Step 5:** Create an Availability Set for CSR1 and CSR2:
<pre lang="...">
az vm availability-set create --resource-group CSR --name myAvailabilitySet --platform-fault-domain-count 2 --platform-update-domain-count 2
</pre>
**Step 6:** Create Public IP, 2 NICs (outside/inside), assign static private IPs, apply NSG, add inside subnet NIC for CSR1 to the load balancer backend pool:
<pre lang="...">
az network public-ip create --name CSR1PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR1OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR1PublicIP --private-ip-address 10.0.0.4 --ip-forwarding true --network-security-group Azure-CSR-NSG
az network nic create --name CSR1InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.4 --network-security-group Azure-CSR-NSG --lb-name csr-lb --lb-address-pools csr-backendpool
</pre>
**Step 7:** Create CSR1 VM and specify CSR image 16.10. Tie in the previously created NICs, SSH credentials, and add it to the Availability Set. You can locate the latest available image in a particular region using these steps:
<pre lang="...">
az vm create --resource-group CSR --location EastUS --name CSR1 --size Standard_DS3_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108 --admin-username azureuser --admin-password Msft123Msft123 --availability-set myAvailabilitySet --no-wait
</pre>
**Step 8:** Repeat step 6 and 7 for CSR2:
<pre lang="...">
az network public-ip create --name CSR2PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR2OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR2PublicIP --private-ip-address 10.0.0.5 --ip-forwarding true --network-security-group Azure-CSR-NSG
az network nic create --name CSR2InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.5 --network-security-group Azure-CSR-NSG --lb-name csr-lb --lb-address-pools csr-backendpool
az vm create --resource-group CSR --location EastUS --name CSR2 --size Standard_DS3_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108 --admin-username azureuser --admin-password Msft123Msft123 --availability-set myAvailabilitySet --no-wait
</pre>
**Step 9:** Create resource group, VNET + address space and subnets for onprem VNET in East US2:
<pre lang="...">
az group create --name onprem --location "East US2"
az network vnet create --name onprem --resource-group onprem --address-prefix 10.100.0.0/16
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.2.0/24 --name OutsideSubnet2 --resource-group onprem --vnet-name onprem
</pre>
**Step 10:** Create NSG and rules for the CSR2 interfaces. It allows SSH, UDP 500/4500, 10.x address and all outbound traffic. You can fine tune the NSG to your liking:
<pre lang="...">
az network nsg create --resource-group onprem --name onprem-CSR-NSG --location EastUS2
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-192 --access Allow --protocol "*" --direction Inbound --priority 135 --source-address-prefix 192.168.0.0/16 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-1s --access Allow --protocol "*" --direction Inbound --priority 136 --source-address-prefix 1.1.1.1/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-2s --access Allow --protocol "*" --direction Inbound --priority 137 --source-address-prefix 2.2.2.2/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-3s --access Allow --protocol "*" --direction Inbound --priority 138 --source-address-prefix 3.3.3.3/32 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>
**Step 11:** Create Public IP, 2 NICs (outside/inside), assign static private IPs, apply NSG, add inside subnet NIC for CSR3 to the load balancer backend pool. Note- there is a second NIC with a public IP. We will terminate the IKEv2 tunnel from CSR1 on CSR3PublicIP and the tunnel from CSR2 will terminate on CSR3PublicIP2. More on that later:
<pre lang="...">
az network public-ip create --name CSR3PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static --sku standard
az network public-ip create --name CSR3PublicIP2 --resource-group onprem --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR3OutsideInterface -g onprem --subnet OutsideSubnet --vnet onprem --public-ip-address CSR3PublicIP --private-ip-address 10.100.0.4 --ip-forwarding true --network-security-group onprem-CSR-NSG
az network nic create --name CSR3InsideInterface -g onprem --subnet InsideSubnet --vnet onprem --ip-forwarding true --private-ip-address 10.100.1.4 --network-security-group onprem-CSR-NSG
az network nic create --name CSR3OutsideInterface2 -g onprem --subnet OutsideSubnet2 --vnet onprem --public-ip-address CSR3PublicIP2 --private-ip-address 10.100.2.4 --ip-forwarding true --network-security-group onprem-CSR-NSG
</pre>
**Step 12:** Create CSR2 VM and specify CSR image 16.10. Tie in the previously created NICs, and SSH credentials:
<pre lang="...">
az vm create --resource-group onprem --location EastUS2 --name CSR3 --size Standard_DS3_v2 --nics CSR3OutsideInterface CSR3OutsideInterface2 CSR3InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108  --admin-username azureuser --admin-password Msft123Msft123 --no-wait
</pre>
**Step 13:** It’s highly recommended that you run the following commands to gather the public IP addresses. Copy the output into notepad or editor to reference later
<pre lang="...">
az network public-ip show -g CSR -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show -g CSR -n CSR2PublicIP --query "{address: ipAddress}"
az network public-ip show -g onprem -n CSR3PublicIP --query "{address: ipAddress}"
az network public-ip show -g onprem -n CSR3PublicIP2 --query "{address: ipAddress}"
</pre>
