#Go to shell.azure.com, make sure your mode is "Bash" and not "Powershell" located at the top left of the screen.Define variables
rg=JW-SDWAN
loc=eastus

#accept marketplace terms for your particular version EX:
az vm image terms accept --urn cisco:cisco_cloud_vwan_csr:cisco_cloud_vwan_csr_17_3_0_2938:17.4.20201218

#create vnet and subnets
az group create --name $rg --location $loc
az network vnet create --resource-group $rg --name vnet-site1 --location $loc --address-prefixes 10.255.0.0/16 --subnet-name VPN0-transport --subnet-prefix 10.255.0.0/24
az network vnet subnet create --address-prefix 10.255.1.0/24 --name csr-service --resource-group $rg --vnet-name vnet-site1
az network vnet subnet create --address-prefix 10.255.100.0/24 --name load-balancer --resource-group $rg --vnet-name vnet-site1
az network vnet subnet create --address-prefix 10.255.10.0/24 --name test-vm --resource-group $rg --vnet-name vnet-site1

#create lb, front end vip, health check, HA ports
az network lb create --name csr-lb --resource-group $rg --sku Standard --private-ip-address 10.255.100.100 --subnet load-balancer --vnet-name vnet-site1
az network lb address-pool create --resource-group $rg --lb-name csr-lb --name csr-backendpool
az network lb probe create --resource-group $rg --lb-name csr-lb --name myHealthProbe --protocol tcp --port 22
az network lb rule create --resource-group $rg --lb-name csr-lb -n MyHAPortsRule  --protocol All --frontend-port 0 --backend-port 0 --backend-pool-name csr-backendpool --probe-name myHealthProbe

#create nsg that all VMs will use. Replace public x.x.x.x with your source IP. This example includes allowing all PIPs asspciated with Azure East.
az network nsg create --resource-group $rg --name SDWAN-NSG --location $loc
az network nsg rule create --resource-group $rg --nsg-name SDWAN-NSG --name SDWAN-NSG --access Allow --protocol "*" --direction Inbound --priority 100 --source-address-prefix x.x.x.x 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name SDWAN-NSG --name all-out --access Allow --protocol "*" --direction Outbound --priority 350 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $rg --nsg-name SDWAN-NSG --name Azure --access Allow --protocol "*" --direction Inbound --priority 400 --source-address-prefix AzureCloud.EastUS --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"

#create csr1 and add it to the backend pool. This assumes you have already accepted the Marketplace terms for the image version.
az network public-ip create --name csr1-PIP --resource-group $rg --allocation-method static --idle-timeout 30 --sku Standard
az network nic create --name csr1-vpn0 --resource-group $rg --subnet VPN0-transport  --vnet-name vnet-site1 --public-ip-address csr1-PIP --ip-forwarding true --private-ip-address 10.255.0.4 --network-security-group SDWAN-NSG
az network nic create --name csr1-service --resource-group $rg --subnet csr-service --vnet-name vnet-site1 --ip-forwarding true --private-ip-address 10.255.1.4 --network-security-group SDWAN-NSG --lb-name csr-lb --lb-address-pools csr-backendpool
az vm create --resource-group $rg --location $loc --name csr1 --size Standard_DS3_v2 --nics csr1-vpn0 csr1-service --image cisco:cisco_cloud_vwan_csr:cisco_cloud_vwan_csr_17_3_0_2938:17.4.20201218 --admin-username azureuser --admin-password Msft123Msft123 --no-wait

#create csr2 and add it to the backend pool
az network public-ip create --name csr2-PIP --resource-group $rg --allocation-method static --idle-timeout 30 --sku Standard
az network nic create --name csr2-vpn0 --resource-group $rg --subnet VPN0-transport  --vnet-name vnet-site1 --public-ip-address csr2-PIP --ip-forwarding true --private-ip-address 10.255.0.5 --network-security-group SDWAN-NSG
az network nic create --name csr2-service --resource-group $rg --subnet csr-service --vnet-name vnet-site1 --ip-forwarding true --private-ip-address 10.255.1.5 --network-security-group SDWAN-NSG --lb-name csr-lb --lb-address-pools csr-backendpool
az vm create --resource-group $rg --location $loc --name csr2 --size Standard_DS3_v2 --nics csr2-vpn0 csr2-service --image cisco:cisco_cloud_vwan_csr:cisco_cloud_vwan_csr_17_3_0_2938:17.4.20201218 --admin-username azureuser --admin-password Msft123Msft123 --no-wait

#create test vm
az network public-ip create --name Test-VM-PIP --location $loc --resource-group $rg --allocation-method static --sku Standard
az network nic create --resource-group $rg --name Test-VM-NIC --location $loc --subnet test-vm --private-ip-address 10.255.10.4 --vnet-name vnet-site1 --public-ip-address Test-VM-PIP --ip-forwarding true --network-security-group SDWAN-NSG
az vm create -n Test-VM --resource-group $rg  --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics Test-VM-NIC --no-wait 

#build a route table and associate the test vm. The destination will be 10.0.0.0/8 with a next hop of the load balancer VIP
az network route-table create --name test-vm-rt --resource-group $rg
az network route-table route create --name test-vm-rt --resource-group $rg --route-table-name test-vm-rt --address-prefix 10.0.0.0/8 --next-hop-type VirtualAppliance --next-hop-ip-address 10.255.100.100
az network vnet subnet update --name test-vm --vnet-name vnet-site1 --resource-group $rg --route-table test-vm-rt

#document PIPs for csr1,csr2, and the test vm
az network public-ip show --resource-group $rg -n csr1-PIP --query "{address: ipAddress}"
az network public-ip show --resource-group $rg -n csr2-PIP --query "{address: ipAddress}"
az network public-ip show --resource-group $rg -n Test-VM-PIP --query "{address: ipAddress}"

