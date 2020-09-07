# Injecting BGP routes into VNETs when terminating S2S VPN tunnels on a 3rd party virtual appliance. 

3rd party virtual appliances currently cannot inject BGP routes into the fabric. Meaning a S2S tunnel from a remote site cannot dynamically update Azure with BGP routes. The Azure VPN Gatewaye is integrated into the Azure fabric and has the ability to run BGP over IPSEC. Any routes the VPN GW learns via BGP will be injected into the fabric. Some vendors will terminate their branch tunnels (including SD-WAN) on a virtual appliance(s) in Azure and then build a BGP over IPSEC tunnel to the Azure VPN gateway in the same VNET. The result is any BGP updates from remote sites (including new tunnels) will automatically update the fabric. Also, any updates within the VNET(s) will automatically be sent to the connected remote sites. In this lab, on prem will be able to connect to a VM in spoke1 via this method. There are also some test BGP advertisements added to show propagation. The environment uses simulated environments in Azure so no hardware is required. All configurations are done in Azure CLI and Cisco CLI. You can access Azure cli in a variety of ways including Cloudshell and shell.azure.com. 

**Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/nva-route-injection/routeinjectiontopo.PNG)

**Before deploying CSRs in the next steps, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands via Cloudshell**
<pre lang="...">
Sample Powershell:
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "17_2_1-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

<pre lang="...">
#Create the Resource Group, Hub1 VNET, Azure VPN Gateway and the CSR in the hub.
rg="route-injection"
location="eastus"

az group create --name route-injection --location $location --output none
az network vnet create --name Hub1 --resource-group $rg --address-prefix 10.0.0.0/16 --output none
az network vnet subnet create --address-prefix 10.0.1.0/24 --name InsideSubnet --resource-group $rg --vnet-name Hub1 --output none
az network vnet subnet create --address-prefix 10.0.0.0/24 --name OutsideSubnet --resource-group $rg --vnet-name Hub1 --output none
az network vnet subnet create --address-prefix 10.0.100.0/24 --name GatewaySubnet --resource-group $rg --vnet-name Hub1 --output none
az network public-ip create --name Azure-VNGpubip --resource-group $rg --allocation-method Dynamic -l $location --output none
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group $rg --vnet Hub1 --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65003 -l $location
az network public-ip create --name CSR1PublicIP --resource-group $rg --idle-timeout 30 --allocation-method Static --location $location
az network nic create --name CSR1OutsideInterface --resource-group $rg --subnet OutsideSubnet --vnet Hub1 --public-ip-address CSR1PublicIP --ip-forwarding true --location $location
az network nic create --name CSR1InsideInterface --resource-group $rg --subnet InsideSubnet --vnet Hub1 --ip-forwarding true --location $location
az vm create --resource-group $rg --location $location --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait

#Create simulated on prem VNET, on prem CSR, text VM and route table. Route table is only needed to simulate on prem.
az network vnet create --name onprem --resource-group $rg --address-prefix 10.100.0.0/16
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group $rg --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group $rg --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group $rg --vnet-name onprem
az network public-ip create --name CSRonpremPublicIP --resource-group $rg --idle-timeout 30 --allocation-method Static --location $location
az network nic create --name CSRonpremOutsideInterface --resource-group $rg --subnet OutsideSubnet --vnet onprem --public-ip-address CSRonpremPublicIP --ip-forwarding true --location $location
az network nic create --name CSRonpremInsideInterface --resource-group $rg --subnet InsideSubnet --vnet onprem --ip-forwarding true --location $location
az vm create --resource-group $rg --location $location --name CSRonprem --size Standard_D2_v2 --nics CSRonpremOutsideInterface CSRonpremInsideInterface  --image cisco:cisco-csr-1000v:17_2_1-byol:17.2.120200508 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network public-ip create --name onpremVMPubIP --resource-group $rg --location $location --allocation-method Static
az network nic create --resource-group $rg -n onpremVMNIC --location $location --subnet testVMSubnet --private-ip-address 10.100.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --ip-forwarding true
az vm create -n onpremVM -g $rg --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait
az network route-table create --name onprem-rt --resource-group $rg
az network route-table route create --name onprem-rt --resource-group $rg --route-table-name onprem-rt --address-prefix 10.1.10.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name testVMSubnet --vnet-name onprem --resource-group $rg --route-table onprem-rt

#Create spoke1 VNET and test VM.
az network vnet create --name spoke1 --resource-group $rg --address-prefix 10.1.10.0/24 --output none
az network vnet subnet create --address-prefix 10.1.10.0/24 --name vmSubnet --resource-group $rg --vnet-name spoke1
az network public-ip create --name spoke1VMPubIP --resource-group $rg --location $location --allocation-method Static
az network nic create --resource-group $rg -n spoke1VMNIC --location $location --subnet vmSubnet --private-ip-address 10.1.10.10 --vnet-name spoke1 --public-ip-address spoke1VMPubIP --ip-forwarding true
az vm create -n spoke1VM -g $rg --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics spoke1VMNIC --no-wait

#Gather public IPs and save them to notepad. Do not continue until the Azure VPN GW has a public ip.
az network public-ip show -g $rg -n onpremVMPubIP --query "{address: ipAddress}" --out tsv
az network public-ip show -g $rg -n spoke1VMPubIP --query "{address: ipAddress}" --out tsv
az network public-ip show -g $rg -n CSR1PublicIP --query "{address: ipAddress}" --out tsv
az network public-ip show -g $rg -n CSRonpremPublicIP --query "{address: ipAddress}" --out tsv
az network public-ip show -g $rg -n Azure-VNGpubip --query "{address: ipAddress}" --out tsv

#Create VNET peering
Hub1Id=$(az network vnet show --resource-group $rg --name Hub1 --query id --out tsv)
Spoke1Id=$(az network vnet show --resource-group $rg --name spoke1 --query id --out tsv)
az network vnet peering create --name Hub1-To-spoke1 --resource-group $rg --vnet-name Hub1 --remote-vnet $Spoke1Id --allow-vnet-access --allow-forwarded-traffic --allow-gateway-transit
az network vnet peering create --name Spoke1-to-Hub1 --resource-group $rg --vnet-name spoke1 --remote-vnet $Hub1Id --allow-vnet-access --allow-forwarded-traffic --use-remote-gateways

#Create Local Network Gateway and VPN connection from the Azure VPN Gateway to CSR1. Note- only the VTI address is needed for peering
az network local-gateway create --gateway-ip-address 40.117.100.197 --name to-csr1 --resource-group $rg --local-address-prefixes 192.168.1.3/32 --asn 65001 --bgp-peering-address 192.168.1.3
az network vpn-connection create --name to-csr1 --resource-group $rg --vnet-gateway1 Azure-VNG -l $location --shared-key Msft123Msft123 --local-gateway2 to-csr1 --enable-bgp

#SSH to the on prem CSR and paste in the below configs. Change "CSR1PublicIP" to the correct public IP.
crypto ikev2 proposal to-csr1-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!         
crypto ikev2 policy to-csr1-policy 
 match address local 10.100.0.4
 proposal to-csr1-proposal
!
crypto ikev2 keyring to-csr1-keyring
 peer "CSR1PublicIP"
  address "CSR1PublicIP"
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile to-csr1-profile
 match address local 10.100.0.4
 match identity remote address 10.0.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr1-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-csr1-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-csr1-IPsecProfile
 set transform-set to-csr1-TransformSet 
 set ikev2-profile to-csr1-profile
!
interface Loopback1
 ip address 2.2.2.2 255.255.255.255
!
interface Tunnel11
 ip address 192.168.1.2 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.0.4
 tunnel mode ipsec ipv4
 tunnel destination "CSR1PublicIP"
 tunnel protection ipsec profile to-csr1-IPsecProfile
!
router bgp 65002
 bgp log-neighbor-changes
 neighbor 192.168.1.4 remote-as 65001
 neighbor 192.168.1.4 ebgp-multihop 255
 neighbor 192.168.1.4 update-source Tunnel11
 !
 address-family ipv4
  network 2.2.2.2 mask 255.255.255.255
  network 10.100.0.0 mask 255.255.0.0
  neighbor 192.168.1.4 activate
 exit-address-family
!
ip route 10.100.0.0 255.255.0.0 Null0
ip route 10.100.10.0 255.255.255.0 10.100.1.1
ip route 192.168.1.4 255.255.255.255 Tunnel11


#Connect to CSR1 and paste in the below configs. Change "Azure-VNGpubip" and "CSRonpremPublicIP" to the correct public IPs.
crypto ikev2 proposal to-onprem-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
crypto ikev2 proposal to-vpngw-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-onprem-policy 
 match address local 10.0.0.4
 proposal to-onprem-proposal
crypto ikev2 policy to-vpngw-policy 
 match address local 10.0.0.4
 proposal to-vpngw-proposal
!
crypto ikev2 keyring to-vpngw-keyring
 peer "Azure-VNGpubip"
  address "Azure-VNGpubip"
  pre-shared-key Msft123Msft123
crypto ikev2 keyring to-onprem-keyring
 peer "CSRonpremPublicIP"
  address "CSRonpremPublicIP"
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile to-vpngw-profile
 match address local 10.0.0.4
 match identity remote address "Azure-VNGpubip" 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-vpngw-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ikev2 profile to-onprem-profile
 match address local 10.0.0.4
 match identity remote address 10.100.0.4 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-onprem-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-vpngw-TransformSet esp-gcm 256 
 mode tunnel
crypto ipsec transform-set to-onprem-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-onprem-IPsecProfile
 set transform-set to-onprem-TransformSet 
 set ikev2-profile to-onprem-profile
!
crypto ipsec profile to-vpngw-IPsecProfile
 set transform-set to-vpngw-TransformSet 
 set ikev2-profile to-vpngw-profile
!
interface Loopback1
 ip address 1.1.1.1 255.255.255.255
!
interface Tunnel11
 ip address 192.168.1.3 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.0.0.4
 tunnel mode ipsec ipv4
 tunnel destination "Azure-VNGpubip"
 tunnel protection ipsec profile to-vpngw-IPsecProfile
!
interface Tunnel12
 ip address 192.168.1.4 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.0.0.4
 tunnel mode ipsec ipv4
 tunnel destination "CSRonpremPublicIP"
 tunnel protection ipsec profile to-onprem-IPsecProfile
!
router bgp 65001
 bgp log-neighbor-changes
 neighbor 10.0.100.254 remote-as 65003
 neighbor 10.0.100.254 ebgp-multihop 255
 neighbor 10.0.100.254 update-source Tunnel11
 neighbor 192.168.1.2 remote-as 65002
 neighbor 192.168.1.2 ebgp-multihop 255
 neighbor 192.168.1.2 update-source Tunnel12
 !
 address-family ipv4
  network 1.1.1.1 mask 255.255.255.255
  neighbor 10.0.100.254 activate
  neighbor 192.168.1.2 activate
 exit-address-family
!
ip route 10.0.100.254 255.255.255.255 Tunnel11
ip route 192.168.1.2 255.255.255.255 Tunnel12
</pre>




