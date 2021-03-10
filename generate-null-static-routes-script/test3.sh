az group create --name udr-test --location westus2
az network vnet create --resource-group udr-test --name VNET --location westus2 --address-prefixes 10.10.0.0/24 --subnet-name test --subnet-prefix 10.10.0.0/26
az network route-table create --name RT --resource-group udr-test --location westus2
az network route-table route create --resource-group udr-test --name route0 --route-table-name RT --address-prefix 10.0.0.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.0.4
az network vnet subnet update --name test --resource-group udr-test --vnet-name VNET --address-prefixes 10.10.0.0/26 --route-table RT
