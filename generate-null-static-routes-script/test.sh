az network route-table route create --resource-group AZFW --name route0 --route-table-name AZFW1-RT --address-prefix 10.0.0.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.0.4
az network route-table route create --resource-group AZFW --name route1 --route-table-name AZFW1-RT --address-prefix 10.0.1.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.20.0.4
