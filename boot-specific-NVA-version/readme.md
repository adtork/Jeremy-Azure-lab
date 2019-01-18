# Azure CLI to find a NVA Marketplace image. In this example, we will search Azure East for a Cisco ASAv version.

**Fill in Azure region**

$locName="East US"
Get-AzureRMVMImagePublisher -Location $locName | Select PublisherName

**Insert the publisher name. This example is Cisco**

$pubName="Cisco"
Get-AzureRMVMImageOffer -Location $locName -Publisher $pubName | Select Offer

**Fill in offer based on previous command. This example is ASAv.**

$offerName="cisco-asav"
Get-AzureRMVMImageSku -Location $locName -Publisher $pubName -Offer $offerName | Select Skus

**Fill in SKU from previous command to get available images**

$skuName="asav-azure-byol"
Get-AzureRMVMImage -Location $locName -Publisher $pubName -Offer $offerName -Sku $skuName | Select Version

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
az vm create --resource-group onprem --location eastus --name ASA1 --size Standard_D3_v2 --nics ASA1OutsideInterface ASA1InsideInterface  --image cisco:cisco-asav:910.1.0 --admin-username azureuser --admin-password Msft123Msft123

az vm create --resource-group onprem --location eastus --name ASA1 --size Standard_D3_v2 --nics ASA1OutsideInterface ASA1InsideInterface  --image cisco:cisco-asav:910.1.0 --admin-username azureuser --admin-password Msft123Msft123
</pre>
