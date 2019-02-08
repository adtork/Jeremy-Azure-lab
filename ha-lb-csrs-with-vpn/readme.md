**placeholder**

az group create --name CSR --location "East US"
az network vnet create --name CSR --resource-group CSR --address-prefix 10.0.0.0/16
az network vnet subnet create --address-prefix 10.0.1.0/24 --name InsideSubnet --resource-group CSR --vnet-name CSR 
az network vnet subnet create --address-prefix 10.0.0.0/24 --name OutsideSubnet --resource-group CSR --vnet-name CSR
az network vnet subnet create --address-prefix 10.0.3.0/24 --name LBSubnet --resource-group CSR --vnet-name CSR
az network vnet subnet create --address-prefix 10.0.10.0/24 --name testVMSubnet --resource-group CSR --vnet-name CSR
az vm availability-set create --resource-group CSR --name myAvailabilitySet --platform-fault-domain-count 2 --platform-update-domain-count 2
az network nsg create --resource-group CSR --name csrssh
az network nsg rule create -g CSR --name csrssh --nsg-name csrssh --priority 100 --source-address-prefixes * --destination-address-prefixes * --destination-port-ranges 22

##
az network lb create --name csr-lb --resource-group CSR --sku Standard --private-ip-address 10.0.3.100 --subnet lbsubnet --vnet-name CSR
az network lb address-pool create -g CSR --lb-name csr-lb -n csr-backendpool
az network lb probe create --resource-group CSR --lb-name csr-lb --name myHealthProbe --protocol tcp --port 22
az network lb rule create -g CSR --lb-name csr-lb -n MyHAPortsRule  --protocol All --frontend-port 0 --backend-port 0 --backend-pool-name csr-backendpool --floating-ip true --probe-name myHealthProbe
##

az network public-ip create --name CSR1PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR1OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR1PublicIP --private-ip-address 10.0.0.4 --ip-forwarding true --network-security-group csrssh

az network nic create --name CSR1InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.4 --network-security-group csrssh --lb-name csr-lb --lb-address-pools csr-backendpool

az vm create --resource-group CSR --location eastus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_7:16.7.120171201 --admin-username jewrigh --admin-password Msft123Msft123 --availability-set myAvailabilitySet --no-wait

az network public-ip create --name CSR2PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR2OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR2PublicIP --ip-forwarding true --private-ip-address 10.0.0.5 --network-security-group csrssh

az network nic create --name CSR2InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.5 --network-security-group csrssh --lb-name csr-lb --lb-address-pools csr-backendpool

az vm create --resource-group CSR --location eastus --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:16_7:16.7.120171201 --admin-username jewrigh --admin-password Msft123Msft123 --availability-set myAvailabilitySet --no-wait



###################################################
az group create --name onprem --location "East US 2"
az network vnet create --name onprem --resource-group onprem --address-prefix 10.100.0.0/16
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group onprem --vnet-name onprem
az vm availability-set create --resource-group onprem --name myAvailabilitySet2 --platform-fault-domain-count 2 --platform-update-domain-count 2

az network nsg create --resource-group onprem --name csrssh
az network nsg rule create -g onprem --name csrssh --nsg-name csrssh --priority 100 --source-address-prefixes * --destination-address-prefixes * --destination-port-ranges 22

az network public-ip create --name CSR3PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR3OutsideInterface -g onprem --subnet OutsideSubnet --vnet onprem --public-ip-address CSR3PublicIP --private-ip-address 10.100.0.4 --ip-forwarding true --network-security-group csrssh
az network nic create --name CSR3InsideInterface -g onprem --subnet InsideSubnet --vnet onprem --ip-forwarding true --private-ip-address 10.100.1.4 --network-security-group csrssh

az vm create --resource-group onprem --location eastus2 --name CSR3 --size Standard_D2_v2 --nics CSR3OutsideInterface CSR3InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108 --admin-username jewrigh --admin-password Msft123Msft123 --availability-set myAvailabilitySet2 --no-wait

####
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
####
