# Define variables. Change "x.x.x.x/32" to your source IP
RG="PAN-ARS-RG"
Location="eastus"
hubname="Transit-VNET"
sourceIP="47.196.199.19/32"

# Accept terms for Cisco and PAN
az vm image terms accept --urn paloaltonetworks:vmseries1:byol:latest

# Create RG and VNET/subnets
az group create --name PAN-ARS-RG --location $Location
az network vnet create --resource-group $RG --name $hubname --location $Location --address-prefixes 10.0.0.0/16 --subnet-name GatewaySubnet --subnet-prefix 10.0.0.0/24
az network vnet subnet create --address-prefix 10.0.1.0/24 --name VMSubnet --resource-group $RG --vnet-name $hubname
az network vnet subnet create --address-prefix 10.0.2.0/24 --name FirewallSubnet --resource-group $RG --vnet-name $hubname
az network vnet subnet create --address-prefix 10.0.3.0/24 --name Mgmt --resource-group $RG --vnet-name $hubname
az network vnet subnet create --address-prefix 10.0.10.0/24 --name RouteServerSubnet --resource-group $RG --vnet-name $hubname

# Create Route Server
az network public-ip create --name RouteServerIP --resource-group $RG --version IPv4 --sku Standard --location $Location
subnet_id=$(az network vnet subnet show --name RouteServerSubnet --resource-group $RG --vnet-name Transit-VNET --query id -o tsv) 
az network routeserver create --name RouteServer --resource-group $RG --hosted-subnet $subnet_id --public-ip-address RouteServerIP --location $Location
az network routeserver update --name RouteServer --resource-group $RG --allow-b2b-traffic true

# Create NSG for PANs
az network nsg create --resource-group $RG --name PAN-NSG --location $Location
az network nsg rule create --resource-group $RG --nsg-name PAN-NSG --name PAN-NSG --access Allow --protocol "*" --direction Inbound --priority 100 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group $RG --nsg-name PAN-NSG --name SSH --access Allow --protocol "TCP" --direction Inbound --priority 200 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "22"
az network nsg rule create --resource-group $RG --nsg-name PAN-NSG --name HTTPS --access Allow --protocol "TCP" --direction Inbound --priority 300 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "443"
az network nsg rule create --resource-group $RG --nsg-name PAN-NSG --name Azure --access Allow --protocol "*" --direction Inbound --priority 400 --source-address-prefix AzureCloud.EastUS --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"

# Create a Palo Alto firewalls in the hub VNET
az network public-ip create --name PAN1MgmtIP --resource-group $RG --idle-timeout 30 --sku Standard
az network public-ip create --name PAN1-Trust-PublicIP --resource-group $RG --idle-timeout 30 --sku Standard
az network nic create --name PAN1MgmtInterface --resource-group $RG --subnet Mgmt --vnet-name $hubname --public-ip-address PAN1MgmtIP --private-ip-address 10.0.3.4 --ip-forwarding true --network-security-group PAN-NSG
az network nic create --name PAN1TrustInterface --resource-group $RG --subnet FirewallSubnet --vnet-name $hubname --private-ip-address 10.0.2.4 --ip-forwarding true --network-security-group PAN-NSG --public-ip-address PAN1-Trust-PublicIP 
az vm create --resource-group $RG --location $Location --name PAN1 --size Standard_D3_v2 --nics PAN1MgmtInterface PAN1TrustInterface  --image paloaltonetworks:vmseries1:byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait

az network public-ip create --name PAN2MgmtIP --resource-group $RG --idle-timeout 30 --sku Standard
az network public-ip create --name PAN2-Trust-PublicIP --resource-group $RG --idle-timeout 30 --sku Standard
az network nic create --name PAN2MgmtInterface --resource-group $RG --subnet Mgmt --vnet-name $hubname --public-ip-address PAN2MgmtIP --private-ip-address 10.0.3.5 --ip-forwarding true --network-security-group PAN-NSG
az network nic create --name PAN2TrustInterface --resource-group $RG --subnet FirewallSubnet --vnet-name $hubname --private-ip-address 10.0.2.5 --ip-forwarding true --network-security-group PAN-NSG --public-ip-address PAN2-Trust-PublicIP 
az vm create --resource-group $RG --location $Location --name PAN2 --size Standard_D3_v2 --nics PAN2MgmtInterface PAN2TrustInterface  --image paloaltonetworks:vmseries1:byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait

# Create test VM in the Hub
az network public-ip create --name HubVMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n HubVMNIC --location $Location --subnet VMSubnet --private-ip-address 10.0.1.4 --vnet-name $hubname --public-ip-address HubVMPubIP --ip-forwarding true
az vm create -n HubVM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVMNIC --no-wait

az network route-table create --name Hub-vm-rt --resource-group $RG
az network route-table route create --name source-ip --resource-group $RG --route-table-name Hub-vm-rt --address-prefix $sourceIP --next-hop-type Internet
az network vnet subnet update --name VMSubnet --vnet-name $hubname --resource-group $RG --route-table Hub-vm-rt

az network route-table create --name PANmgmt-vm-rt --resource-group $RG --disable-bgp-route-propagation true
az network route-table route create --name default --resource-group $RG --route-table-name PANmgmt-vm-rt --address-prefix "0.0.0.0/0" --next-hop-type Internet
az network vnet subnet update --name Mgmt --vnet-name $hubname --resource-group $RG --route-table PANmgmt-vm-rt

az network routeserver peering create --name to-PAN1 --peer-ip 10.0.2.4 --peer-asn 65010 --routeserver RouteServer --resource-group $RG
az network routeserver peering create --name to-PAN2 --peer-ip 10.0.2.5 --peer-asn 65010 --routeserver RouteServer --resource-group $RG
az network routeserver show --name RouteServer --resource-group $RG

az network routeserver peering list-learned-routes --name to-PAN1 --routeserver RouteServer --resource-group $RG
az network routeserver peering list-learned-routes --name to-PAN1 --routeserver RouteServer --resource-group $RG

# Document public IPs
az network public-ip show --resource-group $RG -n Azure-VNGpubip1 --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n Azure-VNGpubip2 --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n PAN1MgmtIP --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n PAN2MgmtIP --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n HubVMPubIP --query "{address: ipAddress}"

# Verify Hub VM effective route table shows both PAN Trust interfaces for 0/0.
az network nic show-effective-route-table -g $RG -n HubVMNIC -o table
