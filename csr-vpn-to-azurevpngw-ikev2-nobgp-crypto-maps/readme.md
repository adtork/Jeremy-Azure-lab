# S2S between CSR and Azure VPN Gateway using crypto maps
This lab guide illustrates how to build a basic IPSEC VPN tunnel w/IKEv2 between a Cisco CSR and the Azure VPN gateway. Some edge envrionments don't have the ability to use BGP but want the flexibility to use it in the future with minimal downtime. The Azure VPN Gateway will use a route based VPN and the remote site will use ACL based crypto maps, no BGP or VTI. The local network gateway will specify the on prem prefix and be in position to enable BGP at a future time. Azure configs are done in Azure CLI so you can change them as needed to match your environment. The on prem environment is simulated in a VNET so no hardware is required.

# Base Topology
The lab deploys an Azure VPN gateway into a VNET. We will also deploy a Cisco CSR in a seperate VNET to simulate on prem.
![alt text](https://github.com/jwrightazure/lab/blob/master/images/csrvpnikev2.png)

**Before deploying CSR in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands**
<pre lang="...">
Sample Powershell:
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Build Hub Resource Groups, VNETs and Subnets. Note- the Azure VPN GW will take 20+ minutes to provision.**
<pre lang="...">
az group create --name Hub --location eastus
az network vnet create --resource-group Hub --name Hub --location eastus --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group Hub --vnet-name Hub
az network public-ip create --name HubVMPubIP --resource-group Hub --location eastus --allocation-method Dynamic
az network nic create --resource-group Hub -n HubVMNIC --location eastus --subnet HubVM --private-ip-address 10.0.10.10 --vnet-name Hub --public-ip-address HubVMPubIP --ip-forwarding true
az vm create -n HubVM -g Hub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVMNIC --no-wait 
az network public-ip create --name Azure-VNGpubip --resource-group Hub --allocation-method Dynamic
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group Hub --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait 
</pre>

**Build On Prem Resource Groups, VNETs and Subnets**
<pre lang="...">
az group create --name onprem --location eastus
az network vnet create --resource-group onprem --name onprem --location eastus --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.2.0/24 --name twonet --resource-group onprem --vnet-name onprem
az network public-ip create --name onpremVMPubIP --resource-group onprem --location eastus --allocation-method Dynamic
az network nic create --resource-group onprem -n onpremVMNIC --location eastus --subnet VM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --ip-forwarding true
az vm create -n onpremVM -g onprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait 
az network public-ip create --name CSR1PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g onprem --subnet zeronet --vnet onprem --public-ip-address CSR1PublicIP --ip-forwarding true --private-ip-address 10.1.0.4
az network nic create --name CSR1InsideInterface -g onprem --subnet onenet --vnet onprem --ip-forwarding true --private-ip-address 10.1.1.4
az vm create --resource-group onprem --location eastus --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_10-BYOL:16.10.220190622 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name onprem --resource-group onprem --route-table vm-rt
</pre>

**Document public IPs in Notepad. The VPN Gateway is not provisioned if the address is null.**
<pre lang="...">
az network public-ip show -g onprem -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show -g Hub -n Azure-VNGpubip --query "{address: ipAddress}"
</pre>

**Do not move forward with the lab until the VPN GW is fully provisioned. The GW is fully provisioned when the previous command returns a public IP adress. Build the local network gaetway. Make sure to change "CSR1OutsideIP" to the correct public IP**
<pre lang="...">
az network local-gateway create --gateway-ip-address ***CSR1OutsideIP*** --name to-onprem --resource-group Hub --local-address-prefixes 10.1.0.0/16
az network vpn-connection create --name to-onprem --resource-group Hub --vnet-gateway1 Azure-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-onprem
</pre>

**SSH to the CSR and paste in the configs. Make sure to change "Azure-VNGpubip" to the public IP of the Azure VPN GW**
<pre lang="...">
crypto ikev2 proposal to-azure-prop 
 encryption aes-cbc-256 aes-cbc-128 3des
 integrity sha1
 group 2
!
crypto ikev2 policy to-azure-pol 
 proposal to-azure-prop
!
crypto ikev2 keyring to-azure-keyring
 peer Azure-peer
  address "Azure-VNGpubip"
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile prof
 match address local 10.1.0.4
 match identity remote address "Azure-VNGpubip" 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-azure-keyring
 lifetime 28800
!
crypto ipsec transform-set AZURE esp-aes 256 esp-sha-hmac 
 mode tunnel
!
crypto map AZURE 10 ipsec-isakmp 
 set peer "Azure-VNGpubip"
 set security-association lifetime seconds 28800
 set transform-set AZURE 
 set pfs group2
 set ikev2-profile prof
 match address VPN-Azure-to-Onprem
!
ip route 10.1.10.0 255.255.255.0 10.1.1.1
ip route "Azure-VNGpubip" 255.255.255.255 10.1.0.1

ip access-list extended VPN-Azure-to-Onprem
 permit ip 10.1.0.0 0.0.255.255 10.0.0.0 0.0.255.255
!
interface GigabitEthernet1
crypto map AZURE
</pre>
