# How to find and use a specific NVA image. Examples include an Cisco ASAv/CSR and Palo Alto Networks in Azure region East. 

**Fill in Azure region to find available publishers.**
<pre lang="...">
$locName="East US"
Get-AzureRMVMImagePublisher -Location $locName | Select PublisherName
</pre>

**Insert the publisher name from previous output. This example is Cisco.**
<pre lang="...">
$pubName="Cisco"
Get-AzureRMVMImageOffer -Location $locName -Publisher $pubName | Select Offer
</pre>

**Fill in offer based on previous command. This example is ASAv.**
<pre lang="...">
$offerName="cisco-asav"
Get-AzureRMVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Select Skus
</pre>

**Fill in SKU from previous command to get available images**
<pre lang="...">
$skuName="asav-azure-byol"
Get-AzureRMVMImage -Location $locName -Publisher $pubName -Offer $offerName -Sku $skuName | Select Version
</pre>

**Sample output:**</br>
Version</br>
-------</br>
910.1.0</br>
99.1.6</br>
99.2.18</br>

**Example:**
<pre lang="...">
az group create --name onprem --location eastus
az network vnet create --resource-group onprem --name onprem --location eastus --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group onprem --vnet-name onprem

az network public-ip create --name ASA1PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static
az network nic create --name ASA1OutsideInterface -g onprem --subnet zeronet --vnet onprem --public-ip-address ASA1PublicIP --ip-forwarding true
az network nic create --name ASA1InsideInterface -g onprem --subnet onenet --vnet onprem --ip-forwarding true
az vm create --resource-group onprem --location eastus --name ASA1 --size Standard_D3_v2 --nics ASA1OutsideInterface ASA1InsideInterface  --image cisco:cisco-asav:asav-azure-byol:910.1.0 --admin-username azureuser --admin-password Msft123Msft123
</pre>
**CSR example**
<pre lang="...">
$locName="East US"
Get-AzureRMVMImagePublisher -Location $locName | Select PublisherName
-output truncated

PS Azure:\> $pubName="Cisco"
Azure:/
PS Azure:\> Get-AzureRMVMImageOffer -Location $locName -Publisher $pubName | Select Offer

Offer
-----
cisco-asav
cisco-csr-1000v
cisco-fmcv
cisco-ftdv
cisco-meraki-vmx100
cisco-ngfwv-vm-test-unsupported
cisco_cloud_vedge_17_2_4
cos65
cos72
cos72_main_dev
uos14
vwaas-azure

PS Azure:\> $offerName="cisco-csr-1000v"
Azure:/
PS Azure:\> Get-AzureRMVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Select Skus

Skus
----
16_10-byol
16_10-payg-ax
16_10-payg-sec
16_4
16_5
16_6
16_7
16_9-byol
3_16
csr-azure-byol

PS Azure:\> $skuName="16_10-byol"
Azure:/
PS Azure:\> Get-AzureRMVMImage -Location $locName -Publisher $pubName -Offer $offerName -Sku $skuName | Select Version

Version
-------
16.10.120190108
</pre>

**CSR example quick**
<pre lang="...">
$locName="East US"
Get-AzureRMVMImagePublisher -Location $locName | Select PublisherName
$pubName="Cisco"
Get-AzureRMVMImageOffer -Location $locName -Publisher $pubName | Select Offer
$offerName="cisco-csr-1000v"
Get-AzureRMVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Select Skus

Skus
----
16_10-byol
16_10-payg-ax
16_10-payg-sec
16_4
16_5
16_6
16_7
16_9-byol
3_16
csr-azure-byol

PS Azure:\> $skuName="16_10-byol"
Azure:/
PS Azure:\> Get-AzureRMVMImage -Location $locName -Publisher $pubName -Offer $offerName -Sku $skuName | Select Version
</pre>
**PAN VM Series Example**
<pre lang="...">
$locName="East US"
Get-AzureRMVMImagePublisher -Location $locName | Select PublisherName

$pubName="paloaltonetworks"
Get-AzureRMVMImageOffer -Location $locName -Publisher $pubName | Select Offer

$offerName="vmseries1"
Get-AzureRMVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Select Skus

$skuName="byol"
Get-AzureRMVMImage -Location $locName -Publisher $pubName -Offer $offerName -Sku $skuName | Select Version
</pre>
