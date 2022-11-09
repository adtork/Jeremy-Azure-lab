#Define resource group and region location variables
rg="LB-test"
location="eastus2"

#Create a resource group named $rg and basic VNET
az group create --name $rg --location $location
az network vnet create --name VNET --resource-group $rg --address-prefix 10.100.0.0/16 --subnet-name web --subnet-prefix 10.100.0.0/24
az network vnet subnet create --resource-group $rg --vnet-name VNET -n LBsubnet --address-prefixes 10.100.100.0/24

az network public-ip create --resource-group $rg --name myBastionIP --sku Standard 
az network vnet subnet create --resource-group $rg --name AzureBastionSubnet --vnet-name VNET --address-prefixes 10.100.1.0/27
az network bastion create --resource-group $rg --name myBastionHost --public-ip-address myBastionIP --vnet-name VNET --location $location

#Create NSG allowing any source to hit the web server on port 80
az network nsg create --resource-group $rg --name web-nsg --location $location
az network nsg rule create --resource-group $rg --nsg-name web-nsg --name allow-web --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 80
az network nsg rule create --resource-group $rg --nsg-name web-nsg --name allow-ssh --access Allow --protocol Tcp --direction Inbound --priority 200 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22

az network public-ip create --resource-group $rg --name myPublicIP --sku Standard 
az network lb create --resource-group $rg --name myLoadBalancer --sku Standard --public-ip-address myPublicIP --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool

az network lb probe create --resource-group $rg --lb-name myLoadBalancer --name myHealthProbe --protocol tcp --port 80

az network lb rule create --resource-group $rg --lb-name myLoadBalancer --name myHTTPRule --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool --probe-name myHealthProbe --disable-outbound-snat true --idle-timeout 15 --enable-tcp-reset true --floating-ip true

 array=(myNicVM1 myNicVM2)
  for vmnic in "${array[@]}"
  do
    az network nic create \
        --resource-group $rg \
        --name $vmnic \
        --vnet-name VNET \
        --subnet web \
        --network-security-group web-nsg
  done

az vm create \
    --resource-group $rg \
    --name myVM1 \
    --nics myNicVM1 \
    --image win2019datacenter \
    --admin-username azureuser \
    --admin-password Msft123Msft123 \
    --zone 1 \
    --no-wait

 az vm create \
    --resource-group $rg \
    --name myVM2 \
    --nics myNicVM2 \
    --image win2019datacenter \
    --admin-username azureuser \
    --admin-password Msft123Msft123 \
    --zone 2 \
    --no-wait

 array=(myNicVM1 myNicVM2)
  for vmnic in "${array[@]}"
  do
    az network nic ip-config address-pool add \
     --address-pool myBackendPool \
     --ip-config-name ipconfig1 \
     --nic-name $vmnic \
     --resource-group $rg \
     --lb-name myLoadBalancer
  done


az vm run-command invoke -g $rg -n myVM1 --command-id RunPowerShellScript --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools"
az vm run-command invoke -g $rg -n myVM2 --command-id RunPowerShellScript --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools"


#On each web server for floating ip (use plb frotend)
netsh interface ipv4 show interface
netsh interface ipv4 set interface "Loopback Pseudo-Interface 1" weakhostreceive=enabled
netsh interface ipv4 add addr "Loopback Pseudo-Interface 1" 20.97.241.224 255.255.255.255
netsh interface ipv4 set interface "Loopback Pseudo-Interface 1" weakhostreceive=enabled  weakhostsend=enabled
netsh int ipv4 set int "Ethernet" weakhostreceive=enabled
netsh int ipv4 add addr "Loopback Pseudo-Interface 1" 1.2.3.4 255.255.255.0
netsh int ipv4 set int "Loopback Pseudo-Interface 1" weakhostreceive=enabled weakhostsend=enabled
netsh advfirewall firewall add rule name="http" protocol=TCP localport=80 dir=in action=allow enable=yes
