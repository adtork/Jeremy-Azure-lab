# Azure Networking Lab- Basic VWAN- Site to Site with Static Routes
This lab guide illustrates how to build a basic VWAN infrastructure including simulated on prem sites (no hardware needed). This is for testing purposes only and should not be considered production configurations. The lab builds two "on prem" VNETs allowing you to simulate your infrastructure. The two on prem sites connect to the VWAN hub via an IPSEC/IKEv2 tunnel that is also connected to two VNETs. At the end of the lab, the two on prem sites will be able to talk to the VNETs as well as each other through the tunnel. The base infrastructure configurations for the on prem environments will not be described in detail. The main goal is to quickly build a test VWAN environment so that you can overlay 3rd party integration tools if needed. You only need to access the portal to download the configuration file of VWAN to determine the public IPs of the VPN gateways. All other configs are done in Azure CLI or Cisco CLI so you can change them as needed to match your environment.    

Assumptions:
- A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Latest Azure CLI, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 
- Intermediate/advanced Azure networking knowledge

Note:
- Azure CLI and Cloud Shell for VWAN are in preview and require the "virtual-wan" extension. You can view the extensions by running "az extension list-available --output table". Install the extension "az extension add --name virtual-wan".

-All VM have Internet access, username/passwords are azureuser/Msft123Msft123
-NO NSGs are used


# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/vwan%20static%20routes.PNG)

**You may have to accept the NVA agreement if you've never deployed this image before. You can do that by accepting the agreement when deploying the NVA through the portal and then deleting the NVA. You can also do this via CLI. Example:**
<pre lang="...">
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

**Create the VWAN hub that allows on prem to on prem to hairping through the tunnel. The address space used should not overlap. VWAN deploys 2 "appliances" as well as a number of underlying components. We're starting here as the last command can take 30+ minutes to deploy. By specifying "--no-wait", you can move on to other steps while this section of VWAN continues to deploy in the background. **

<pre lang="...">
az group create --name VWANWEST --location westus2
az network vwan create --name VWANWEST --resource-group VWANWEST --branch-to-branch-traffic true --location westus2 --vnet-to-vnet-traffic true
az network vhub create --address-prefix 192.168.0.0/24 --name VWANWEST --resource-group VWANWEST --vwan VWANWEST --location westus2
az network vpn-gateway create --name VWANWEST --resource-group VWANWEST --vhub VWANWEST --location westus2 --no-wait
</pre>

**Deploy the infrastructure for simulated on prem DC1 (10.100.0.0/16). This builds out all of the VNET/subnet/routing/VMs needed to simulate on prem including a Cisco CSR and test Linux machine.**

<pre lang="...">
az group create --name DC1 --location westus2
az network vnet create --resource-group DC1 --name DC1 --location westus2 --address-prefixes 10.100.0.0/16 --subnet-name VM --subnet-prefix 10.100.10.0/24
az network vnet subnet create --address-prefix 10.100.0.0/24 --name zeronet --resource-group DC1 --vnet-name DC1
az network vnet subnet create --address-prefix 10.100.1.0/24 --name onenet --resource-group DC1 --vnet-name DC1

az network public-ip create --name CSR1PublicIP --resource-group DC1 --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g DC1 --subnet zeronet --vnet DC1 --public-ip-address CSR1PublicIP --ip-forwarding true --private-ip-address 10.100.0.4
az network nic create --name CSR1InsideInterface -g DC1 --subnet onenet --vnet DC1 --ip-forwarding true --private-ip-address 10.100.1.4
az vm create --resource-group DC1 --location westus2 --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_6:16.6.220171219 --admin-username azureuser --admin-password Msft123Msft123 --no-wait

az network public-ip create --name DC1VMPubIP --resource-group DC1 --location westus2 --allocation-method Dynamic
az network nic create --resource-group DC1 -n DC1VMNIC --location westus2 --subnet VM --vnet-name DC1 --public-ip-address DC1VMPubIP --private-ip-address 10.100.10.4
az vm create -n DC1VM -g DC1 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics DC1VMNIC --no-wait

az network route-table create --name DC1-RT --resource-group DC1
az network route-table route create --name To-VNET10 --resource-group DC1 --route-table-name DC1-RT --address-prefix 10.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name To-VNET20 --resource-group DC1 --route-table-name DC1-RT --address-prefix 10.20.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name To-DC2 --resource-group DC1 --route-table-name DC1-RT --address-prefix 10.101.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name VM --vnet-name DC1 --resource-group DC1 --route-table DC1-RT
</pre>

**Build the same for simulated on prem DC2**
<pre lang="...">
az group create --name DC2 --location westus2
az network vnet create --resource-group DC2 --name DC2 --location westus2 --address-prefixes 10.101.0.0/16 --subnet-name DC2VM --subnet-prefix 10.101.10.0/24
az network vnet subnet create --address-prefix 10.101.0.0/24 --name zeronet --resource-group DC2 --vnet-name DC2
az network vnet subnet create --address-prefix 10.101.1.0/24 --name onenet --resource-group DC2 --vnet-name DC2

az network public-ip create --name CSR2PublicIP --resource-group DC2 --idle-timeout 30 --allocation-method Static
az network nic create --name CSR2OutsideInterface -g DC2 --subnet zeronet --vnet DC2 --public-ip-address CSR2PublicIP --ip-forwarding true --private-ip-address 10.101.0.4
az network nic create --name CSR2InsideInterface -g DC2 --subnet onenet --vnet DC2 --ip-forwarding true --private-ip-address 10.101.1.4
az VM create --resource-group DC2 --location westus2 --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:16_6:16.6.220171219 --admin-username azureuser --admin-password Msft123Msft123 --no-wait

az network public-ip create --name DC2VMPubIP --resource-group DC2 --location westus2 --allocation-method Dynamic
az network nic create --resource-group DC2 -n DC2VMNIC --location westus2 --subnet DC2VM --vnet-name DC2 --public-ip-address DC2VMPubIP --private-ip-address 10.101.10.4
az VM create -n DC2VM -g DC2 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics DC2VMNIC --no-wait

az network route-table create --name DC2-RT --resource-group DC2
az network route-table route create --name To-VNET10 --resource-group DC2 --route-table-name DC2-RT --address-prefix 10.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network route-table route create --name To-VNET20 --resource-group DC2 --route-table-name DC2-RT --address-prefix 10.20.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network route-table route create --name To-DC2 --resource-group DC2 --route-table-name DC2-RT --address-prefix 10.101.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network vnet subnet update --name DC2VM --vnet-name DC2 --resource-group DC2 --route-table DC2-RT
</pre>

**Build VNET 10 which includes a test VM. No routing needs to be defined as VWAN will inject routes.**
<pre lang="...">
az group create --name VNET10 --location westus2
az network vnet create --resource-group VNET10 --name VNET10 --location westus2 --address-prefixes 10.10.0.0/16 --subnet-name VNET10VM --subnet-prefix 10.10.10.0/24
az network vnet subnet create --address-prefix 10.10.0.0/24 --name zeronet --resource-group VNET10 --vnet-name VNET10
az network vnet subnet create --address-prefix 10.10.1.0/24 --name onenet --resource-group VNET10 --vnet-name VNET10

az network public-ip create --name VNET10VMPubIP --resource-group VNET10 --location westus2 --allocation-method Dynamic
az network nic create --resource-group VNET10 -n VNET10VMNIC --location westus2 --subnet VNET10VM --vnet-name VNET10 --public-ip-address VNET10VMPubIP --private-ip-address 10.10.10.4
az VM create -n VNET10VM -g VNET10 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics VNET10VMNIC --no-wait
</pre>

**Build VNET 20**
<pre lang="...">
az group create --name VNET20 --location westus2
az network vnet create --resource-group VNET20 --name VNET20 --location westus2 --address-prefixes 10.20.0.0/16 --subnet-name VNET20VM --subnet-prefix 10.20.10.0/24
az network vnet subnet create --address-prefix 10.20.0.0/24 --name zeronet --resource-group VNET20 --vnet-name VNET20
az network vnet subnet create --address-prefix 10.20.1.0/24 --name onenet --resource-group VNET20 --vnet-name VNET20

az network public-ip create --name VNET20VMPubIP --resource-group VNET20 --location westus2 --allocation-method Dynamic
az network nic create --resource-group VNET20 -n VNET20VMNIC --location westus2 --subnet VNET20VM --vnet-name VNET20 --public-ip-address VNET20VMPubIP --private-ip-address 10.20.10.4
az VM create -n VNET20VM -g VNET20 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics VNET20VMNIC --no-wait
</pre>

**Validate "provisioningstate" of the VPN GWs are successful. Do not continue if provisioning was not successful. The VPN appliances can take 30+ minutes to create.**
<pre lang="...">
az network vpn-gateway list --resource-group VWANWEST
</pre>

**Build a connection between the VWAN hub and VNET10/20. Replace XX with your subscription.**
<pre lang="...">
az network vhub connection create --name toVNET10 --remote-vnet /subscriptions/XX/resourceGroups/VNET10/providers/Microsoft.Network/virtualNetworks/VNET10 --resource-group VWANWEST --vhub-name VWANWEST --remote-vnet-transit true --use-hub-vnet-gateways true

az network vhub connection create --name toVNET20 --remote-vnet /subscriptions/XX/resourceGroups/VNET20/providers/Microsoft.Network/virtualNetworks/VNET20 --resource-group VWANWEST --vhub-name VWANWEST --remote-vnet-transit true --use-hub-vnet-gateways true
</pre>

**Get the public IP of the CSR in DC1. This is the address of on the on prem side that the VPN tunnels will terminate on. Copy it to notepad.**
<pre lang="...">
az network public-ip show -g DC1 -n CSR1PublicIP --query "{address: ipAddress}"
</pre>

**Build a VPN site and connection between VWAN and the DC1 CSR. Replace "CSR1PublicIP" with the IP address from the previous step.**
<pre lang="...">
az network vpn-site create --ip-address CSR1PublicIP --name DC1 --resource-group VWANWEST --address-prefixes 10.100.0.0/16 --virtual-wan VWANWEST
az network vpn-gateway connection create --gateway-name VWANWEST --name DC1 --remote-vpn-site DC1 --resource-group VWANWEST --protocol-type IKEv2 --shared-key Msft123Msft123
</pre>

**Get the public IP of the CSR in DC2. This is the address of on the on prem side that the VPN tunnels will terminate on. Copy it to notepad.**
<pre lang="...">
az network public-ip show -g DC2 -n CSR2PublicIP --query "{address: ipAddress}"
</pre>

**Build a VPN site and connection between VWAN and the DC2 CSR. Replace "CSR2PublicIP" with the IP address from the previous step.**
<pre lang="...">
az network vpn-site create --ip-address CSR2PublicIP --name DC2 --resource-group VWANWEST --address-prefixes 10.101.0.0/16 --virtual-wan VWANWEST
az network vpn-gateway connection create --gateway-name VWANWEST --name DC2 --remote-vpn-site DC2 --resource-group VWANWEST --protocol-type IKEv2 --shared-key Msft123Msft123
</pre>

**At this time, you must download the VWAN configuration in order to display the 2 public IP addresses for the VPN gateways in Azure. In the portal, search for or go to Virtual WANs, select VWANWEST, select "Download VPN configuration" at the top of the overview page. This will drop the configuration into a storage account. Download the file and document the IPs for Instance0 and Instance1 (VWAN VPN gateway public IPs). **
Sample output:
"gatewayConfiguration": {
          "IpAddresses": {
            "Instance0": "x.x.x.1",
            "Instance1": "x.x.x.2"


**SSH to CSR1 and paste in the below configurations. Replace "Instance0" and "Instance1" with the public IP addresses from the downloaded configuration.**
<pre lang="...">

crypto ikev2 proposal to-csr-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
crypto ikev2 proposal to-csr-proposal2 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-csr-policy 
 match address local 10.100.0.4
 proposal to-csr-proposal
crypto ikev2 policy to-csr-policy2 
 match address local 10.100.0.4
 proposal to-csr-proposal2
!
crypto ikev2 keyring to-csr-keyring
 peer Instance0
  address Instance0
  pre-shared-key Msft123Msft123
 !
!
crypto ikev2 keyring to-csr-keyring2
 peer Instance1
  address Instance1
  pre-shared-key Msft123Msft123
 !
!
!
crypto ikev2 profile to-csr-profile
 match address local 10.100.0.4
 match identity remote address Instance0 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ikev2 profile to-csr-profile2
 match address local 10.100.0.4
 match identity remote address Instance1 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr-keyring2
 lifetime 3600
 dpd 10 5 on-demand
!

crypto ipsec transform-set to-csr-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-csr-IPsecProfile
 set transform-set to-csr-TransformSet 
 set ikev2-profile to-csr-profile
!
crypto ipsec profile to-csr-IPsecProfile2
 set transform-set to-csr-TransformSet 
 set ikev2-profile to-csr-profile2
!
interface Tunnel1
 ip address 192.168.1.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.0.4
 tunnel mode ipsec ipv4
 tunnel destination Instance0
 tunnel protection ipsec profile to-csr-IPsecProfile
!
interface Tunnel2
 ip address 192.168.2.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.100.0.4
 tunnel mode ipsec ipv4
 tunnel destination Instance1
 tunnel protection ipsec profile to-csr-IPsecProfile2
!
ip route 10.10.0.0 255.255.0.0 Tunnel1
ip route 10.10.0.0 255.255.0.0 Tunnel2
ip route 10.20.0.0 255.255.0.0 Tunnel1
ip route 10.20.0.0 255.255.0.0 Tunnel2
ip route 10.100.10.0 255.255.255.0 10.100.1.1
ip route 10.101.0.0 255.255.0.0 Tunnel1
ip route 10.101.0.0 255.255.0.0 Tunnel2

</pre>

**Validate the tunnel is up and basic connectivity**
<pre lang="...">
sh int tu1
sh int tu2
sh crypto ikev2 sa
show crypto session
show ip route  (make sure Azure prefix is pointing to tu1 and tu2)
show crypto ipsec transform-set
show crypto ikev2 proposal
ping 10.100.0.4
ping 10.10.10.4 source 10.100.1.4
</pre>

**Validate VMs in VNET10 and VNET20 see 2 paths to DC1 (10.100.0.0/16). Remember we created 2 tunnels to DC1.
<pre lang="...">
az network nic show-effective-route-table -g VNET10 -n VNET10VMNIC --output table
az network nic show-effective-route-table -g VNET20 -n VNET20VMNIC --output table
</pre>

**SSH to DC1 VM public IP. It should be able to ping the VM in VNET10 (10.10.10.4) and VNET20 (10.20.10.4). Display DC1 VM PIP (don't use CSR):
<pre lang="...">
az network public-ip list --resource-group DC1 --output table
</pre>

**Run a continuous ping from DC1 VM to 10.10.10.4. SSH to CSR, shut tunnel1 and validate ping still works. Look at effective route table for the VM in VNET10 to make sure it now only sees 1 path.
<pre lang="...">
az network nic show-effective-route-table -g VNET10 -n VNET10VMNIC --output table
</pre>

**Enable tunnel1, look at effective route table for the VM in VNET10 to make sure it now sees 2 paths and ping is functioning.**

**SSH to CSR2 and paste in the below configurations. Replace "Instance0" and "Instance1" with the public IP addresses from the downloaded configuration.**
<pre lang="...">
crypto ikev2 proposal to-csr-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
crypto ikev2 proposal to-csr-proposal2 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-csr-policy 
 match address local 10.101.0.4
 proposal to-csr-proposal
crypto ikev2 policy to-csr-policy2 
 match address local 10.101.0.4
 proposal to-csr-proposal2
!
crypto ikev2 keyring to-csr-keyring
 peer Instance0
  address Instance0
  pre-shared-key Msft123Msft123
 !
!
crypto ikev2 keyring to-csr-keyring2
 peer Instance1
  address Instance1
  pre-shared-key Msft123Msft123
 !
!
!
crypto ikev2 profile to-csr-profile
 match address local 10.101.0.4
 match identity remote address Instance0 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr-keyring
 lifetime 3600
 dpd 10 5 on-demand
!
crypto ikev2 profile to-csr-profile2
 match address local 10.101.0.4
 match identity remote address Instance1 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-csr-keyring2
 lifetime 3600
 dpd 10 5 on-demand
!

crypto ipsec transform-set to-csr-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-csr-IPsecProfile
 set transform-set to-csr-TransformSet 
 set ikev2-profile to-csr-profile
!
crypto ipsec profile to-csr-IPsecProfile2
 set transform-set to-csr-TransformSet 
 set ikev2-profile to-csr-profile2
!
interface Tunnel1
 ip address 192.168.3.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.101.0.4
 tunnel mode ipsec ipv4
 tunnel destination Instance0
 tunnel protection ipsec profile to-csr-IPsecProfile
!
interface Tunnel2
 ip address 192.168.4.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.101.0.4
 tunnel mode ipsec ipv4
 tunnel destination Instance1
 tunnel protection ipsec profile to-csr-IPsecProfile2
!
ip route 10.10.0.0 255.255.0.0 Tunnel1
ip route 10.10.0.0 255.255.0.0 Tunnel2
ip route 10.20.0.0 255.255.0.0 Tunnel1
ip route 10.20.0.0 255.255.0.0 Tunnel2
ip route 10.101.10.0 255.255.255.0 10.101.1.1
ip route 10.100.0.0 255.255.0.0 Tunnel1
ip route 10.100.0.0 255.255.0.0 Tunnel2

</pre>

**Repeat validation steps that were used for DC1 in DC2.**
