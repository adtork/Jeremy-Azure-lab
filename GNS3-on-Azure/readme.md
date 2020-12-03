# Azure CLI to create GNS3 on Azure

**Azure CLI to create a VNET, NSG and a VM to host GNS3. The script also installs OpenVPN on the GNS3 server in Azure. You will be able to run the GNS3 app on your local machine and connect to the Azure VM. This allows you to offload the horsepower you need to a VM in Azure. To access the GNS3, you will need to install OpenVPN on your local machine. Please make sure to specify your source IP in the "sip" variable. I have specified a server size of "Standard_E20s_v3" that can be changed to meet your needs. **
<pre lang="...">
rg="my-GNS3-resource-group"
loc="eastus2"
sip="change-to-your-source-IP"

# Create resource group and VNET
az group create --name $rg --location $loc
az network vnet create --name GNS3 --resource-group $rg --address-prefix 192.168.100.0/24 --subnet-name vm --subnet-prefix 192.168.100.0/24 --location $loc

# Create NSG to allow your source IP. Make sure to change the "sip" variable above to your source IP
az network nsg create --resource-group $rg --name GNS3-NSG --location $loc
az network nsg rule create --resource-group $rg --nsg-name GNS3-NSG --name Allow-HomeSIP --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix $sip --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"

# Create public IP, NIC and GNS3 VM
az network public-ip create --name GNS3-publicIP --resource-group $rg --location $loc --allocation-method Static
az network nic create --resource-group $rg --name GNS3nic --location $loc --subnet vm --vnet-name GNS3 --public-ip-address GNS3-publicIP --ip-forwarding true --network-security-group GNS3-NSG
az vm create -n MyGNS3VM --resource-group $rg --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics GNS3nic --location $loc --size Standard_E20s_v3

# Use CustomScript extension to install GNS3
az vm extension set \
  --publisher Microsoft.Azure.Extensions \
  --version 2.0 \
  --name CustomScript \
  --vm-name MyGNS3VM \
  --resource-group $rg \
  --settings '{"commandToExecute":"cd /tmp && curl https://raw.githubusercontent.com/GNS3/gns3-server/master/scripts/remote-install.sh > gns3-remote-install.sh && sudo bash gns3-remote-install.sh --with-openvpn --with-iou --with-i386-repository"}'

# Get the public IP of the web server and SSH to the server with azureuser/Msft123Msft123
az network public-ip show --resource-group $rg -n GNS3-publicIP --query "{address: ipAddress}" --output tsv
</pre>

**The SSH prompt will include a download link for the OpenVPN profile for your local machine. When you go the link, it will automatically download the profile. Important- in SSH, run "sudo reboot" before trying to connect to VPN. Import the file you downloaded into your OpenVPN client. Connect using VPN and you will get an IP in the 172.16.253.x range. Make sure your local GNS3 client is pointing to 172.16.253.1:3080 as the server.**
