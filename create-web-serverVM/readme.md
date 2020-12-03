# Azure CLI to create a basic VM and automate install of NGINX. Add NSG to allow inbound traffic on port 80.

<pre lang="...">
# Define resource group and region location variables
rg="basic-webserver"
location="eastus"

# Create a resource group named $rg and basic VNET
az group create --name $rg --location $location
az network vnet create --name VNET --resource-group $rg --address-prefix 10.0.0.0/16 --subnet-name web --subnet-prefix 10.0.0.0/24

# Create NSG allowing any source to hit the web server on port 80
az network nsg create --resource-group $rg --name web-nsg --location $location
az network nsg rule create --resource-group $rg --nsg-name web-nsg --name allow-web --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 80

# Create a new virtual machine 
az network public-ip create --name Web-PubIP --resource-group $rg --location $location --allocation-method Static
az network nic create --name webserverNIC --resource-group $rg --subnet web --vnet VNET --public-ip-address Web-PubIP --ip-forwarding true --location $location --network-security-group web-nsg
az vm create --resource-group $rg --name mywebserver --image UbuntuLTS --location $location --admin-username azureuser --admin-password Msft123Msft123 --nics webserverNIC

# Use CustomScript extension to install NGINX.
az vm extension set \
  --publisher Microsoft.Azure.Extensions \
  --version 2.0 \
  --name CustomScript \
  --vm-name mywebserver \
  --resource-group $rg \
  --settings '{"commandToExecute":"apt-get -y update && apt-get -y install nginx"}'

# Get the public IP of the web server
az network public-ip show --resource-group $rg -n Web-PubIP --query "{address: ipAddress}" --output tsv

</pre>



  
