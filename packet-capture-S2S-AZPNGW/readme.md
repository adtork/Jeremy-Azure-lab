# BGP over IPSEC VPN (IKEv2) between Cisco CSR and Azure VPN Gateway with packet capture

This lab guide illustrates how to build a basic IPSEC VPN tunnel w/IKEv2 between a Cisco CSR and the Azure VPN gateway with BGP. The CSR is built in a VNET to simulate an on prem environment so no hardware is needed for this environment. After the tunnel is built, we will configure a packet capture for the Azure VPN GW to see both outer and inner packets (IPSEC,BGP,ICMP). All configurations for the base topology are done in Azure CLI so you can change them as needed. This is a valuable tool for troubleshooting VPN as well as determining what packets are being sent over the tunnel. Updates to packet capture ideas will be here: https://github.com/dmauser/Lab/tree/master/AZVPNGW/PacketCapture

Notes:
- Lab assumes you have installed the latest version of Azure CLI, PowerShell, Azure PowerShell, Azure Storage Explorer and linked them to your Azure account. The examples shown are all on Windows 10 including Wireshark. 
- Powershell: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7
- Azure Powershell: https://docs.microsoft.com/en-in/powershell/azure/install-az-ps?view=azps-2.8.0
- Azure Storage Explorer: https://azure.microsoft.com/en-us/features/storage-explorer/
- Username/password for CSR and test VMs is azureuser/Msft123Msft123

# Base Topology
The lab deploys an Azure VPN gateway into a VNET. We will also deploy a Cisco CSR in a seperate VNET to simulate on prem.
![alt text](https://github.com/jwrightazure/lab/blob/master/images/csrvpnikev2.png)

**Build Resource Groups, VNETs and Subnets**
<pre lang="...">
az group create --name Hub --location westus
az network vnet create --resource-group Hub --name Hub --location westus --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group Hub --vnet-name Hub
</pre>

**Build Resource Groups, VNETs and Subnets to simulate on prem**
<pre lang="...">
az group create --name onprem --location westus
az network vnet create --resource-group onprem --name onprem --location westus --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group onprem --vnet-name onprem
</pre>

**Build Azure side and on prem Linux VM**
<pre lang="...">
az network public-ip create --name HubVMPubIP --resource-group Hub --location westus --allocation-method Dynamic
az network nic create --resource-group Hub -n HubVMNIC --location westus --subnet HubVM --private-ip-address 10.0.10.10 --vnet-name Hub --public-ip-address HubVMPubIP
az vm create -n HubVM -g Hub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVMNIC --no-wait
az network public-ip create --name onpremVMPubIP --resource-group onprem --location westus --allocation-method Dynamic
az network nic create --resource-group onprem -n onpremVMNIC --location westus --subnet VM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP
az vm create -n onpremVM -g onprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait
</pre>

**Build Public IP and Azure VPN Gateway. Enable BGP with ASN 65001. Deployment will take some time.** for Azure VPN Gateway**
<pre lang="...">
az network public-ip create --name Azure-VNGpubip --resource-group Hub --allocation-method Dynamic
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group Hub --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --asn 65001 --no-wait 
</pre>

**Before deploying CSR in the next step, you have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands**
<pre lang="...">
Sample Powershell:
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Build onprem CSR. CSR image is specified from the Marketplace in this example. Image version may change- check CSR example: https://github.com/jwrightazure/lab/tree/master/boot-specific-NVA-version**
<pre lang="...">
az network public-ip create --name CSR1PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g onprem --subnet zeronet --vnet onprem --public-ip-address CSR1PublicIP --ip-forwarding true
az network nic create --name CSR1InsideInterface -g onprem --subnet onenet --vnet onprem --ip-forwarding true
az vm create --resource-group onprem --location westus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_10-BYOL:16.10.220190622 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
</pre>

**Create a route table and routes for the Azure VNET with correct association. This is for the onprem simulation to route traffic to the CSR**
<pre lang="...">
az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name onprem --resource-group onprem --route-table vm-rt
</pre>

**After the gateway and CSR have been created, document the public IP address for both. The Azure VPN GW is not fully provisioned if the public IP value is null.**
<pre lang="...">
az network public-ip show -g Hub -n Azure-VNGpubip --query "{address: ipAddress}"
az network public-ip show -g onprem -n CSR1PublicIP --query "{address: ipAddress}"
</pre>

**Document BGP peer IP and ASN for the Azure VPN GW**
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group Hub
</pre>

**Create Local Network Gateway. The 192.168.1.1 addrees is the IP of the tunnel interface on the CSR in BGP ASN 65002.**
<pre lang="...">
az network local-gateway create --gateway-ip-address "insert CSR Public IP" --name to-onprem --resource-group Hub --local-address-prefixes 192.168.1.1/32 --asn 65002 --bgp-peering-address 192.168.1.1
</pre>

**Create VPN connections**
<pre lang="...">
az network vpn-connection create --name to-onprem --resource-group Hub --vnet-gateway1 Azure-VNG -l westus --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp
</pre>

**SSH to CSR public IP. Public IPs in the below config are an example.**
<pre lang="...">
term mon
conf t
!route for simulate on prem vm
ip route 10.1.10.0 255.255.255.0 10.1.1.1

crypto ikev2 proposal to-onprem-proposal
  encryption aes-cbc-256
  integrity  sha1
  group      2
  exit

crypto ikev2 policy to-onprem-policy
  proposal to-onprem-proposal
  match address local 10.1.0.4
  exit
  
crypto ikev2 keyring to-onprem-keyring
  peer "insert AZ VPN GW Public IP"
    address "insert AZ VPN GW Public IP"
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-onprem-profile
  match address  local 10.1.0.4
  match identity remote address "insert AZ VPN GW Public IP" 255.255.255.255
  authentication remote pre-share
  authentication local  pre-share
  lifetime       3600
  dpd 10 5 on-demand
  keyring local  to-onprem-keyring
  exit

crypto ipsec transform-set to-onprem-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-onprem-IPsecProfile
  set transform-set  to-onprem-TransformSet
  set ikev2-profile  to-onprem-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.1 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.1.0.4
  tunnel destination "insert AZ VPN GW Public IP"
  tunnel protection ipsec profile to-onprem-IPsecProfile
  exit

router bgp 65002
  bgp      log-neighbor-changes
  neighbor 10.0.0.254 remote-as 65001
  neighbor 10.0.0.254 ebgp-multihop 255
  neighbor 10.0.0.254 update-source tunnel 11

  address-family ipv4
    network 10.1.10.0 mask 255.255.255.0
    neighbor 10.0.0.254 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 10.0.0.254 255.255.255.255 Tunnel 11

</pre>

**Validate VPN connection status in Azure CLI**
<pre lang="...">
az network vpn-connection show --name to-onprem --resource-group Hub --query "{status: connectionStatus}"
</pre>


Key Cisco commands
- show interface tunnel 11
- show crypto session
- show crypto ipsec transform-set
- show crypto ikev2 proposal
- sh ip bgp sum
- sh ip bgp neighbor 10.0.0.254 advertised-routes
- sh ip route bgp


**List BGP advertised routes per peer on the Azure VPN GW.**
<pre lang="...">
az network vnet-gateway list-advertised-routes -g Hub -n Azure-VNG --peer 192.168.1.1
</pre>

**Document and SSH to the VM in the Hub and onprem**
<pre lang="...">
az network public-ip show -g Hub -n HubVMPubIP --query "{address: ipAddress}"
az network public-ip show -g onprem -n onpremVMPubIP --query "{address: ipAddress}"
</pre>

# At this point the VMs have connectivity to each other. We will now capture packets at the Hub VNET for the S2S tunnel we just created. 

**Create a storage account to store the capture. The resource group must be the same as the Azure VPN GW.**
<pre lang="...">
az storage account create -n packetcapturelabtest -g Hub -l westus --sku Standard_LRS --kind StorageV2
</pre>

# Add container for the capture to log to
Open Storage explorer. Navigate to your subscription, Storage Accounts, packetcapturelabtest, right click blob container and create new and name it packetcapturelabtest
![alt text](https://github.com/jwrightazure/lab/blob/master/images/container%20creation.png)

**Paste the below script into Powershell. This will launch an interactive window to launch the capture. The capture is running and writing to your storage account for the amount of time you selected. You can control-c to stop it early. **
<pre lang="...">
<#Prerequesits:
- Install Azure Powershell Module (http://aka.ms/azps)
- For now only Powershell 5.1 supported.
- Create a Storage Account and Container in the same Resource Group as VPN Gateway.
#>

Connect-AzAccount
$SubID = (Get-AzSubscription | Out-GridView -Title "Select Subscription ..."-PassThru )
Set-AzContext -Subscription $SubID.name
$RG = (Get-AzResourceGroup | Out-GridView -Title "Select an Azure Resource Group ..." -PassThru ).ResourceGroupName
$VNG = (Get-AzVirtualNetworkGateway -ResourceGroupName $RG).Name | Out-GridView -Title "Select an Azure VNET Gateway ..." -PassThru
$storeName = (Get-AzStorageAccount -ResourceGroupName $RG | Out-GridView -Title "Select an Azure Storage Account ..." -PassThru ).StorageAccountName
$key = Get-AzStorageAccountKey -ResourceGroupName $RG -Name $storeName
$context = New-AzStorageContext -StorageAccountName $storeName -StorageAccountKey $key[0].Value
$containerName = (Get-AzStorageContainer -Context $context | Out-GridView -Title "Select Container Name..." -PassThru ).Name
$now=get-date
$sasurl = New-AzStorageContainerSASToken -Name $containerName -Context $context -Permission "rwd" -StartTime $now.AddHours(-1) -ExpiryTime $now.AddDays(1) -FullUri
$minutes = 5, 7, 15, 20 | Out-Gridview -Title "How many Minutes network capture should run?" -OutputMode Single
$seconds = 60*$minutes

#Start packet capture for a VPN gateway
Write-Host "Starting capture for $VNG Azure VPN Gateway" -ForegroundColor Magenta
$a = "{`"TracingFlags`": 15,`"MaxPacketBufferSize`": 1500,`"MaxFileSize`": 500,`"Filters`" :[{`"CaptureSingleDirectionTrafficOnly`": false}]}"
Start-AzVirtualnetworkGatewayPacketCapture -ResourceGroupName $RG -Name $VNG -FilterData $a
Write-Host "Wait about $minutes minutes as capture is running on $VNG Azure VPN Gateway" -ForegroundColor Red
Start-Sleep -Seconds $seconds
#Stop packet capture for a VPN gateway
Stop-AzVirtualNetworkGatewayPacketCapture -ResourceGroupName $RG -Name $VNG -SasUrl $sasurl
#Script finished
Write-Host "Process has been completed - Use Storage Explorer and download $VNG network captures on $containerName inside Storage Account $storeName" -ForegroundColor Magenta
</pre>

Refresh your blob container in Storage Explorer and drill down to the pcap file. There will be 2 folders a few directories in since Azure VPN GW is deployed in active/standby in this lab. Download the pcap and open it with Wireshark. 
# Example wireshark filtering on UDP port 4500, BGP or ICMP. You can see the outer IPSEC information as well as the inner BGP session and ICMP that is running between the VMs.
![alt text](https://github.com/jwrightazure/lab/blob/master/images/wireshark.PNG)
