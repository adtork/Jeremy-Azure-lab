# Azure Networking Lab- Create a linux vm with an NGINX web server, iperf, traceroute, and NMAP.

This will build an Ubuntu server and install NGINX, iperf, traceroute and NMAP. The lab includes an NSG allowing inbound port 80 and 22.

<pre lang="...">
# Define resource group and region location variables
rg="webserver-iperf-traceroute"
location="eastus"

# Create a resource group named $rg and basic VNET
az group create --name $rg --location $location
az network vnet create --name VNET --resource-group $rg --address-prefix 10.0.0.0/16 --subnet-name web --subnet-prefix 10.0.0.0/24

# Create NSG allowing any source to hit the web server on port 80
az network nsg create --resource-group $rg --name web-nsg --location $location
az network nsg rule create --resource-group $rg --nsg-name web-nsg --name allow-web --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 80
az network nsg rule create --resource-group $rg --nsg-name web-nsg --name allow-ssh --access Allow --protocol Tcp --direction Inbound --priority 200 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22

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
  --settings '{"commandToExecute":"apt-get -y update && apt-get -y install nginx && sudo apt update && sudo apt install iperf && sudo apt-get update && sudo apt-get install traceroute && sudo apt-get install nmap -y"}'

# Get the public IP of the web server
az network public-ip show --resource-group $rg -n Web-PubIP --query "{address: ipAddress}" --output tsv
</pre>

# TCPdump example in Azure
<pre lang="...">
sudo tcpdump -i eth0 -nn -s0 -v port 80 and host not 168.63.129.16
</pre>
