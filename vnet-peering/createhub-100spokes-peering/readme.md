# This lab creates 1 hub, 100 spokes and peers them together.

#!/bin/bash
#Create basic variables for Resource Group, Azure Region, and a number variable for the number of spoke VNETs you want to create. 
#The "NUM" variable wil determine the number of spokes that are provisioned. Lab is set to 100 spokes. Change the number to the amount of spokes needed.
rgname="test"
US="eastus"
NUM=100

#Create the Resource Group, Hub1 VNET and an Azure Firewall Subnet (Azure Firewall will be used in a seperate lab)
az group create --name $rgname --location $US --output none
az network vnet create --resource-group $rgname --name Hub1 --address-prefixes 10.1.0.0/24 --subnet-name AzureFirewallSubnet --subnet-prefix 10.1.0.0/26 --location $US --output none

#Create the amount of spoke VNETs specified in the "NUM" value with the first 2 octets being 10.1 and the 3rd octect will increment by one as the spoke VNETS are created.
#Spoke1 will get 10.1.1/24, spoke2 will get 10.1.2/24 up until the number of spokes you specified.
for ((i=0; i<NUM; i++)); do
    echo az network vnet create --resource-group $rgname --name spoke$(( $i + 1 )) --address-prefixes 10.1.$(( $i + 1 )).0/24  --subnet-name default --subnet-prefix 10.1.$(( $i + 1 )).0/24 --location $US --output none
    az network vnet create --resource-group $rgname --name spoke$(( $i + 1 )) --address-prefixes 10.1.$(( $i + 1 )).0/24  --subnet-name default --subnet-prefix 10.1.$(( $i + 1 )).0/24 --location $US --output none
done

#Set Hub1 variable for VNET peering use.
vnets=$(az network vnet list --resource-group $rgname --output yaml | grep name | cut -d ':' -f 2 | sed 's/[[:space:]]//g')
for vnet in $vnets; do
    if [[ $vnet =~ "Hub1" ]]
    then
        hubid=$(az network vnet show --resource-group $rgname --name $vnet --query id --out tsv)
        hubname=$vnet
    fi
done

#Set all of the spoke variables for VNET peering use. Build VNET peering between the hub and all spokes.
for vnet in $vnets; do
    if [[ $vnet =~ "spoke" ]]
    then
        spokeid=$(az network vnet show --resource-group $rgname --name $vnet --query id --out tsv)
        spokename=$vnet
        az network vnet peering create --name $hubname-To-$spokename --resource-group $rgname --vnet-name $hubname --remote-vnet $spokeid --allow-vnet-access --output none
        az network vnet peering create --name $spokename-to-$hubname --resource-group $rgname --vnet-name $spokename --remote-vnet $hubid --allow-vnet-access --output none
    fi
done

#View all of Hub1 peerings.
az network vnet peering list -g test --vnet-name Hub1 --out table 

#Count peerings
az network vnet peering list -g test --vnet-name Hub1 --out table | wc -l

