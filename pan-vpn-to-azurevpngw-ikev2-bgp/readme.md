##Placeholder##

az group create --name PANHub --location eastus
az network vnet create --resource-group PANHub --name PANHub --location eastus --address-prefixes 10.255.0.0/16 --subnet-name PANHubVM --subnet-prefix 10.255.10.0/24
az network vnet subnet create --address-prefix 10.255.0.0/24 --name GatewaySubnet --resource-group PANHub --vnet-name PANHub
###########################

az group create --name PANonprem --location eastus
az network vnet create --resource-group PANonprem --name PANonprem --location eastus --address-prefixes 10.254.0.0/16 --subnet-name PANonpremVM --subnet-prefix 10.254.10.0/24
az network vnet subnet create --address-prefix 10.254.0.0/24 --name zeronet --resource-group PANonprem --vnet-name PANonprem
az network vnet subnet create --address-prefix 10.254.1.0/24 --name onenet --resource-group PANonprem --vnet-name PANonprem
az network vnet subnet create --address-prefix 10.254.2.0/24 --name twonet --resource-group PANonprem --vnet-name PANonprem

############################

az network public-ip create --name PANHubtestVMPubIP --resource-group PANHub --location eastus --allocation-method Dynamic
az network nic create --resource-group PANHub -n PANHubtestVMNIC --location eastus --subnet PANHubVM --private-ip-address 10.255.10.10 --vnet-name PANHub --public-ip-address PANHubtestVMPubIP
az vm create -n PANHubtestVM -g PANHub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics PANHubtestVMNIC

#############################

az network public-ip create --name PANonpremVMPubIP --resource-group PANonprem --location eastus --allocation-method Dynamic
az network nic create --resource-group PANonprem -n PANonpremVMNIC --location eastus --subnet PANonpremVM --private-ip-address 10.254.10.10 --vnet-name PANonprem --public-ip-address PANonpremVMPubIP
az vm create -n PANonpremVM -g PANonprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics PANonpremVMNIC

#############################
az network public-ip create --name Azure-VNGpubip --resource-group PANHub --allocation-method Dynamic
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group PANHub --vnet PANHub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65001
#############################

az network public-ip create --name PAN1MgmtIP --resource-group PANonprem --idle-timeout 30 --allocation-method Static
az network public-ip create --name PAN1VPNPublicIP --resource-group PANonprem --idle-timeout 30 --allocation-method Static

az network nic create --name PAN1MgmtInterface -g PANonprem --subnet twonet --vnet PANonprem --public-ip-address PAN1MgmtIP --private-ip-address 10.254.2.4 --ip-forwarding true
az network nic create --name PAN1OutsideInterface -g PANonprem --subnet zeronet --vnet PANonprem --public-ip-address PAN1VPNPublicIP --private-ip-address 10.254.0.4 --ip-forwarding true
az network nic create --name PAN1InsideInterface -g PANonprem --subnet onenet --vnet PANonprem --private-ip-address 10.254.1.4 --ip-forwarding true

az vm create --resource-group PANonprem --location eastus --name PANFW1 --size Standard_D3_v2 --nics PAN1MgmtInterface PAN1OutsideInterface PAN1InsideInterface  --image paloaltonetworks:vmseries1:byol:8.1.0 --admin-username azureuser --admin-password Msft123Msft123

###############################

az network public-ip show -g PANHub -n Azure-VNGpubip --query "{address: ipAddress}"
az network public-ip show -g PANonprem -n PAN1VPNPublicIP --query "{address: ipAddress}"
############################
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group PANHub
############################
az network route-table create --name vm-rt --resource-group PANonprem
az network route-table route create --name vm-rt --resource-group PANonprem --route-table-name vm-rt --address-prefix 10.255.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.254.1.4
az network vnet subnet update --name PANonpremVM --vnet-name PANonprem --resource-group PANonprem --route-table vm-rt
############################
az network local-gateway create --gateway-ip-address 23.96.108.14 --name to-onprem --resource-group PANHub --local-address-prefixes 192.168.3.1/32 --asn 65002 --bgp-peering-address 192.168.3.1
############################
az network vpn-connection create --name to-onprem --resource-group PANHub --vnet-gateway1 Azure-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp
#############################
az network vpn-connection show --name to-onprem --resource-group PANHub --query "{status: connectionStatus}"
az network vnet-gateway list-advertised-routes -g PANHub -n Azure-VNG --peer 192.168.3.1
az network vnet-gateway list-learned-routes -g PANHub -n Azure-VNG
