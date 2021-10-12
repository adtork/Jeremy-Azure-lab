rg=BGP
loc=eastus2

az group create --name $rg --location $loc
az network vnet create --resource-group $rg --name vnet-site1 --location $loc --address-prefixes 10.255.0.0/16 --subnet-name CSR1-Outside --subnet-prefix 10.255.0.0/24
az network vnet subnet create --address-prefix 10.255.1.0/24 --name CSR1-Inside --resource-group $rg --vnet-name vnet-site1
az network vnet subnet create --address-prefix 10.255.10.0/24 --name test-vm --resource-group $rg --vnet-name vnet-site1
az network vnet subnet create --address-prefix 10.255.2.0/24 --name CSR2-Outside --resource-group $rg --vnet-name vnet-site1
az network vnet subnet create --address-prefix 10.255.3.0/24 --name CSR2-Inside --resource-group $rg --vnet-name vnet-site1

#replace x.x.x.x with your source IP
az network nsg create --resource-group $rg --name BGP-NSG --location $loc
az network nsg rule create --resource-group $rg --nsg-name BGP-NSG --name BGP-NSG --access Allow --protocol "*" --direction Inbound --priority 100 --source-address-prefix x.x.x.x/32 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name BGP-NSG --name all-out --access Allow --protocol "*" --direction Outbound --priority 200 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"

az network public-ip create --name csr1-PIP --resource-group $rg --allocation-method static --idle-timeout 30 --sku Standard
az network nic create --name CSR1-Outside --resource-group $rg --subnet CSR1-Outside  --vnet-name vnet-site1 --public-ip-address csr1-PIP --ip-forwarding true --private-ip-address 10.255.0.4 --network-security-group BGP-NSG
az network nic create --name CSR1-Inside --resource-group $rg --subnet CSR1-Inside --vnet-name vnet-site1 --ip-forwarding true --private-ip-address 10.255.1.4 --network-security-group BGP-NSG
az vm create --resource-group $rg --location $loc --name csr1 --size Standard_DS3_v2 --nics CSR1-Outside CSR1-Inside --image cisco:cisco_cloud_vwan_csr:cisco_cloud_vwan_csr_17_3_0_2938:17.4.20201218 --admin-username azureuser --admin-password Msft123Msft123 --no-wait

az network public-ip create --name csr2-PIP --resource-group $rg --allocation-method static --idle-timeout 30 --sku Standard
az network nic create --name CSR2-Outside --resource-group $rg --subnet CSR2-Outside  --vnet-name vnet-site1 --public-ip-address csr2-PIP --ip-forwarding true --private-ip-address 10.255.2.4 --network-security-group BGP-NSG
az network nic create --name CSR2-Inside --resource-group $rg --subnet CSR2-Inside --vnet-name vnet-site1 --ip-forwarding true --private-ip-address 10.255.3.4 --network-security-group BGP-NSG
az vm create --resource-group $rg --location $loc --name csr2 --size Standard_DS3_v2 --nics CSR2-Outside CSR2-Inside --image cisco:cisco_cloud_vwan_csr:cisco_cloud_vwan_csr_17_3_0_2938:17.4.20201218 --admin-username azureuser --admin-password Msft123Msft123 --no-wait

az network public-ip create --name Test-VM-PIP --location $loc --resource-group $rg --allocation-method static --sku Standard
az network nic create --resource-group $rg --name Test-VM-NIC --location $loc --subnet test-vm --private-ip-address 10.255.10.4 --vnet-name vnet-site1 --public-ip-address Test-VM-PIP --ip-forwarding true --network-security-group BGP-NSG
az vm create -n Test-VM --resource-group $rg  --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Test-VM-NIC --no-wait 

az network route-table create --name test-vm-rt --resource-group $rg
az network route-table route create --name test-vm-rt --resource-group $rg --route-table-name test-vm-rt --address-prefix 10.0.0.0/8 --next-hop-type VirtualAppliance --next-hop-ip-address 10.255.1.4
az network vnet subnet update --name test-vm --vnet-name vnet-site1 --resource-group $rg --route-table test-vm-rt

az network route-table create --name csr1-rt --resource-group $rg
az network route-table route create --name csr1-rt --resource-group $rg --route-table-name csr1-rt --address-prefix 10.0.0.2/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.255.3.4
az network vnet subnet update --name CSR1-Outside --vnet-name vnet-site1 --resource-group $rg --route-table csr1-rt

az network route-table create --name csr2-rt --resource-group $rg
az network route-table route create --name csr2-rt --resource-group $rg --route-table-name csr2-rt --address-prefix 10.0.0.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.255.0.4
az network vnet subnet update --name CSR2-Inside --vnet-name vnet-site1 --resource-group $rg --route-table csr2-rt
