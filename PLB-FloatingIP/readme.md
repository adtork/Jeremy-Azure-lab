# This lab builds an Azure Public Load balancer and a single backend Windows 2019 Server with a web server. The lab also configures the LB rule to use Floating IP as well as the steps to configure the loopback on the Windows Server. You can also add new Frontends/Backends with/without Floating IP to test different LB port mappings. Note- The LB does not pass x-forwarded-for (unlike App GW).A Bastion jump box is also created to access the VMs since the VMs do not have public IPs. Username/pw is azureuser/Msft123Msft123

<pre lang="...">
# Floating IP Notes:
If you enable Floating IP** 
•	The traffic from the client will reach the LB
•	The LB will forward the traffic to the backend server without NATting
•	The backend server receives the packet with destination IP = the Loadbalancer’s IP !!!
•	The backend server replies directly to the client
•	The return traffic DOES NOT go through the load balancer anymore (direct server return J 

If you Disable Floating IP (default behavior) 
•	The traffic from the client will reach the LB
•	The LB does IP NATting and sends the traffic to the DIP of the backend server
•	The LB also does port NATting (if you configured different frontend and backend ports)
•	The backend server receives traffic on his DIP and normally replies - traffic goes back to the LB
•	The LB does NAT back (IP and eventually port) to the client.
</pre>

<pre lang="...">
# Define resource group and region location variables
rg="LB-test"
location="eastus2"

# Create a resource group named $rg and basic VNET
az group create --name $rg --location $location
az network vnet create --name VNET --resource-group $rg --address-prefix 10.100.0.0/16 --subnet-name web --subnet-prefix 10.100.0.0/24
az network vnet subnet create --resource-group $rg --vnet-name VNET -n LBsubnet --address-prefixes 10.100.100.0/24

# Create Bastion host
az network public-ip create --resource-group $rg --name myBastionIP --sku Standard 
az network vnet subnet create --resource-group $rg --name AzureBastionSubnet --vnet-name VNET --address-prefixes 10.100.1.0/27
az network bastion create --resource-group $rg --name myBastionHost --public-ip-address myBastionIP --vnet-name VNET --location $location

# Create NSG allowing any source to hit the web server on port 80
az network nsg create --resource-group $rg --name web-nsg --location $location
az network nsg rule create --resource-group $rg --nsg-name web-nsg --name allow-web --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 80

# Create LB, Frontend, Backend and LB rule with Floating IP enabled.
az network public-ip create --resource-group $rg --name myPublicIP --sku Standard 
az network lb create --resource-group $rg --name myLoadBalancer --sku Standard --public-ip-address myPublicIP --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool
az network lb probe create --resource-group $rg --lb-name myLoadBalancer --name myHealthProbe --protocol tcp --port 80
az network lb rule create --resource-group $rg --lb-name myLoadBalancer --name myHTTPRule --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name myFrontEnd --backend-pool-name myBackEndPool --probe-name myHealthProbe --disable-outbound-snat true --idle-timeout 15 --enable-tcp-reset true --floating-ip true

#Create Web VM, add it to the LB pool and install the web server
az network nic create --resource-group $rg --name web1-vmnic --vnet-name VNET --subnet web --network-security-group web-nsg
az vm create --resource-group $rg --name myVM1 --nics web1-vmnic --image win2019datacenter --admin-username azureuser --admin-password Msft123Msft123 --zone 1 --no-wait
az network nic ip-config address-pool add --address-pool myBackendPool --ip-config-name ipconfig1 --nic-name web1-vmnic --resource-group $rg --lb-name myLoadBalancer
az vm run-command invoke -g $rg -n myVM1 --command-id RunPowerShellScript --scripts "Install-WindowsFeature -name Web-Server -IncludeManagementTools"

#In order for Floating IP to work with the Windows backend, you must configure the a loopback with parameters. Each VM OS may behave differently. Bastion to the web server, open up a command prompt

#validate the name of the loopback interface
netsh interface ipv4 show interface

#Assuming the name of the interface is "Loopback Pseudo-Interface 1' enter the floowing commands
netsh interface ipv4 set interface "Loopback Pseudo-Interface 1" weakhostreceive=enabled
netsh interface ipv4 add addr "Loopback Pseudo-Interface 1" 172.176.128.174 255.255.255.255
netsh interface ipv4 set interface "Loopback Pseudo-Interface 1" weakhostreceive=enabled  weakhostsend=enabled
netsh int ipv4 set int "Ethernet" weakhostreceive=enabled
netsh int ipv4 add addr "Loopback Pseudo-Interface 1" 1.2.3.4 255.255.255.0
netsh int ipv4 set int "Loopback Pseudo-Interface 1" weakhostreceive=enabled weakhostsend=enabled
netsh advfirewall firewall add rule name="http" protocol=TCP localport=80 dir=in action=allow enable=yes
</pre>

