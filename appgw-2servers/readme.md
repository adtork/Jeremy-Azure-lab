# Lab builds appgw and 2 backend servers with IIS. At the end of this lab, you can install Wireshark on the servers and filter on "http.x_forwarded_for" to verify the client IP is maintained through the flow. 

**Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/appgw-2servers/appgw-basic-topo.PNG)

<pre lang="...">
# Define resource group and region location variables
rg="appgw-test"
location="eastus2"

# Create a resource group named $rg and basic VNET
az group create --name $rg --location $location
az network vnet create --name VNET --resource-group $rg --address-prefix 10.100.0.0/16 --subnet-name web --subnet-prefix 10.100.0.0/24
az network vnet subnet create --resource-group $rg --vnet-name VNET -n appgwsubnet --address-prefixes 10.100.100.0/24

# Create NSG allowing any source to hit the web server on port 80
az network nsg create --resource-group $rg --name web-nsg --location $location
az network nsg rule create --resource-group $rg --nsg-name web-nsg --name allow-web --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 80
az network nsg rule create --resource-group $rg --nsg-name web-nsg --name allow-ssh --access Allow --protocol Tcp --direction Inbound --priority 200 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22

# Create 2 web servers with IIS
az network public-ip create --name Web1 --resource-group $rg --idle-timeout 30 --allocation-method Static
az network nic create --name web1-nic --resource-group $rg --subnet web --vnet VNET --public-ip-address Web1 --ip-forwarding true --network-security-group web-nsg
az vm create --resource-group $rg --location $location --name Web1 --size Standard_D2_v2 --nics web1-nic --image MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest --admin-username azureuser --admin-password Msft123Msft123

az vm run-command invoke -g $rg -n Web1 --command-id RunPowerShellScript --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools"

az network public-ip create --name Web2 --resource-group $rg --idle-timeout 30 --allocation-method Static
az network nic create --name web2-nic --resource-group $rg --subnet web --vnet VNET --public-ip-address Web2 --ip-forwarding true --network-security-group web-nsg
az vm create --resource-group $rg --location $location --name Web2 --size Standard_D2_v2 --nics web2-nic --image MicrosoftWindowsServer:WindowsServer:2019-Datacenter:latest --admin-username azureuser --admin-password Msft123Msft123

az vm run-command invoke -g $rg -n Web2 --command-id RunPowerShellScript --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools"

# Create App GW 
az network public-ip create --resource-group $rg --name myAGPublicIPAddress --allocation-method Static --sku Standard
address1=$(az network nic show --name web1-nic --resource-group $rg | grep "\"privateIpAddress\":" | grep -oE '[^ ]+$' | tr -d '",')
address2=$(az network nic show --name web2-nic --resource-group $rg | grep "\"privateIpAddress\":" | grep -oE '[^ ]+$' | tr -d '",')

az network application-gateway create --name myAppGateway --location $location --resource-group $rg --capacity 2 --sku Standard_v2 --public-ip-address myAGPublicIPAddress --vnet-name VNET --subnet appgwsubnet --servers "$address1" "$address2" --priority 100

az network public-ip show --resource-group $rg --name myAGPublicIPAddress --query [ipAddress] --output tsv
</pre>

# Wireshark
<pre lang="...">
http.x_forwarded_for
</pre>

# Wireshark showing that App GW private IP is the source, but the original client IP is maintained in x-forwarded-for. The original client IP has been blurred.
**Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/appgw-2servers/appgw-cap1.PNG)
