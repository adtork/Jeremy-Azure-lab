##VWAN Lab
This lab guide illustrates how to build a basic VWAN infrastructure including simulated on prem sites (no hardware needed). This is for testing purposes only and should not be considered production configurations. The lab builds two "on prem" VNETs allowing you to simulate your infrastructure. The two on prem sites connect to 2 different VWAN hubs via an IPSEC/IKEv2 tunnel based on their geo that are also connected to 2 VNETs. At the end of the lab, the two on prem sites will be able to talk to the VNETs as well as each other through the tunnel.  All configs are done in Azure CLI or Cisco CLI (minus determining VWAN Public IPs (PIP) or BGP peer info) so you can easily change them as needed to match your environment.

Notes:
- Please ensure you are using the latest version of Azure CLI. You can view the extensions by running "az extension list-available --output table". Install the extension "az extension add --name virtual-wan". If it says there's an update available for the extension, use "az extension update --name virtual-wan".

- All VM have Internet access, username/passwords are azureuser/Msft123Msft123 -No NSGs are used

- When deleting the lab, make sure to gracefully delete VWAN components (connections, sites, vwan hub) and not the entire VWAN resource group. The other resource groups can be completely deleted.

- VWAN is in ASN 65515, DC1 is ASN 65001, DC2 is ASN 65002

- The VPN GWs take 30-45 minutes to provision. Please make sure they are done provisioning before moving further in the lab. This is called out again later in the lab as well as how to verify

**VWAN Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/vwan%20topo.png)

**You may have to accept the NVA agreement if you've never deployed this image before. You can do that by accepting the agreement when deploying the NVA through the portal and then deleting the NVA. You can also do this via CLI. Example:**
<pre lang="...">
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>


**Create the VWAN hub that allows on prem to on prem to hairpin through the tunnel. The address space used should not overlap. VWAN deploys 2 "appliances" as well as a number of underlying components. We're starting here as the last command in this section can take 30+ minutes to deploy. By specifying "--no-wait", you can move on to other steps while this section of VWAN continues to deploy in the background.**
<pre lang="...">
az group create --name VWAN --location eastus2
az network vwan create --name VWAN --resource-group VWAN --branch-to-branch-traffic true --location eastus2 --vnet-to-vnet-traffic true
az network vhub create --address-prefix 192.168.0.0/24 --name VWANEAST --resource-group VWAN --vwan VWAN --location eastus2 --sku basic
az network vpn-gateway create --name VWANEAST --resource-group VWAN --vhub VWANEAST --location eastus2 --no-wait
az network vhub create --address-prefix 192.168.1.0/24 --name VWANWEST --resource-group VWAN --vwan VWAN --location westus2 --sku basic
az network vpn-gateway create --name VWANWEST --resource-group VWAN --vhub VWANWEST --location westus2 --no-wait
</pre>

**Deploy the infrastructure for simulated on prem DC1 (10.100.0.0/16). This builds out all of the VNET/subnet/routing/VMs needed to simulate on prem including a Cisco CSR and test Linux machine.**
<pre lang="...">
az group create --name DC1 --location eastus2
az network vnet create --resource-group DC1 --name DC1 --location eastus2 --address-prefixes 10.100.0.0/16 --subnet-name VM --subnet-prefix 10.100.10.0/24
az network vnet subnet create --address-prefix 10.100.0.0/24 --name zeronet --resource-group DC1 --vnet-name DC1
az network vnet subnet create --address-prefix 10.100.1.0/24 --name onenet --resource-group DC1 --vnet-name DC1
az network public-ip create --name CSR1PublicIP --resource-group DC1 --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g DC1 --subnet zeronet --vnet DC1 --public-ip-address CSR1PublicIP --ip-forwarding true --private-ip-address 10.100.0.4
az network nic create --name CSR1InsideInterface -g DC1 --subnet onenet --vnet DC1 --ip-forwarding true --private-ip-address 10.100.1.4
az vm create --resource-group DC1 --location eastus2 --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_10-BYOL:16.10.220190622 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network public-ip create --name DC1VMPubIP --resource-group DC1 --location eastus2 --allocation-method Dynamic
az network nic create --resource-group DC1 -n DC1VMNIC --location eastus2 --subnet VM --vnet-name DC1 --public-ip-address DC1VMPubIP --private-ip-address 10.100.10.4
az vm create -n DC1VM -g DC1 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics DC1VMNIC --no-wait
az network route-table create --name DC1-RT --resource-group DC1
az network route-table route create --name To-VNET10 --resource-group DC1 --route-table-name DC1-RT --address-prefix 10.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name To-VNET20 --resource-group DC1 --route-table-name DC1-RT --address-prefix 10.20.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name To-VNET30 --resource-group DC1 --route-table-name DC1-RT --address-prefix 10.30.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
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
az VM create --resource-group DC2 --location westus2 --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:16_10-BYOL:16.10.220190622 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network public-ip create --name DC2VMPubIP --resource-group DC2 --location westus2 --allocation-method Dynamic
az network nic create --resource-group DC2 -n DC2VMNIC --location westus2 --subnet DC2VM --vnet-name DC2 --public-ip-address DC2VMPubIP --private-ip-address 10.101.10.4
az VM create -n DC2VM -g DC2 --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics DC2VMNIC --no-wait
az network route-table create --name DC2-RT --resource-group DC2
az network route-table route create --name To-VNET10 --resource-group DC2 --route-table-name DC2-RT --address-prefix 10.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network route-table route create --name To-VNET20 --resource-group DC2 --route-table-name DC2-RT --address-prefix 10.20.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network route-table route create --name To-VNET30 --resource-group DC2 --route-table-name DC2-RT --address-prefix 10.30.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network route-table route create --name To-DC1 --resource-group DC2 --route-table-name DC2-RT --address-prefix 10.100.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network vnet subnet update --name DC2VM --vnet-name DC2 --resource-group DC2 --route-table DC2-RT
</pre>

**Build VNET 10 which includes a test VM. No routing needs to be defined as VWAN will inject routes.**
<pre lang="...">
az group create --name VNET10 --location eastus2
az network vnet create --resource-group VNET10 --name VNET10 --location eastus2 --address-prefixes 10.10.0.0/16 --subnet-name VNET10VM --subnet-prefix 10.10.10.0/24
az network vnet subnet create --address-prefix 10.10.0.0/24 --name zeronet --resource-group VNET10 --vnet-name VNET10
az network vnet subnet create --address-prefix 10.10.1.0/24 --name onenet --resource-group VNET10 --vnet-name VNET10
az network public-ip create --name VNET10VMPubIP --resource-group VNET10 --location eastus2 --allocation-method Dynamic
az network nic create --resource-group VNET10 -n VNET10VMNIC --location eastus2 --subnet VNET10VM --vnet-name VNET10 --public-ip-address VNET10VMPubIP --private-ip-address 10.10.10.4
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
az VM create -n VNET20VM -g VNET20 --image UbuntuLTS --admin-password Msft123Msft123 --nics VNET20VMNIC --no-wait
</pre>

**Validate "provisioningstate" of the VPN GWs are successful. Do not continue if provisioning was not successful. The VPN appliances can take 30+ minutes to create.**
<pre lang="...">
az network vpn-gateway list --resource-group VWAN -o table
</pre>

**Build a connection between the VWANEAST hub and VNET10. Also build a connection between VWANWEST and VNET 20. Replace XX with your subscription.**
<pre lang="...">
az network vhub connection create --name toVNET10 --remote-vnet /subscriptions/XX/resourceGroups/VNET10/providers/Microsoft.Network/virtualNetworks/VNET10 --resource-group VWAN --vhub-name VWANEAST --remote-vnet-transit true --use-hub-vnet-gateways true

az network vhub connection create --name toVNET20 --remote-vnet /subscriptions/XX/resourceGroups/VNET20/providers/Microsoft.Network/virtualNetworks/VNET20 --resource-group VWAN --vhub-name VWANWEST --remote-vnet-transit true --use-hub-vnet-gateways true
</pre>

**Get the public IP of the CSR in DC1. This is the address of on the on prem DC1 side that the VPN tunnels will terminate on. Copy it to notepad.**
<pre lang="...">
az network public-ip show -g DC1 -n CSR1PublicIP --query "{address: ipAddress}"
</pre>

**Build a VPN site and connection between VWANEAST and the DC1 CSR. Replace "CSR1PublicIP" with the IP address from the previous step. Remember a VPN site "connection" in Azure will build a S2S VPN from both VPN appliances in VWAN Hub VWANEAST. For BGP over IPSEC, this assumes CSR1 BGP ASN is 65001 and the VTI is 172.16.0.1 (not the PIP of the CSR). **
<pre lang="...">
az network vpn-site create --ip-address "CSR1PublicIP" --name DC1 --resource-group VWAN --location eastus2 --virtual-wan VWAN --asn 65001 --bgp-peering-address 172.16.0.1

az network vpn-gateway connection create --gateway-name VWANEAST --name DC1 --remote-vpn-site DC1 --resource-group VWAN --protocol-type IKEv2 --shared-key Msft123Msft123 --enable-bgp
</pre>

**Get the public IP of the CSR in DC2. This is the address of on the on prem side that the VPN tunnels will terminate on. Copy it to notepad.**
<pre lang="...">
az network public-ip show -g DC2 -n CSR2PublicIP --query "{address: ipAddress}"
</pre>

**Build a VPN site and connection between VWAN and the DC2 CSR. Replace "CSR2PublicIP" with the IP address from the previous step.**
<pre lang="...">
az network vpn-site create --ip-address "CSR2PublicIP" --name DC2 --resource-group VWAN --location westus2 --virtual-wan VWAN --asn 65002 --bgp-peering-address 172.16.0.4

az network vpn-gateway connection create --gateway-name VWANWEST --name DC2 --remote-vpn-site DC2 --resource-group VWAN --protocol-type IKEv2 --shared-key Msft123Msft123 --enable-bgp
</pre>

**At this time, you must download the VWAN configuration in order to display the 2 public IP addresses for the VPN gateways in Azure. In the portal, search for or go to Virtual WANs, select VWANEAST, select "Download VPN configuration" at the top of the overview page. This will drop the configuration into a storage account. Download the file and document the IPs for Instance0 and Instance1 (VWAN VPN gateway public IPs). Highly recommend converting this to a JSON view. (https://jsonformatter.org/)

Sample output: -gatewayConfiguration: Instance0: x.x.x.1, Instance1: x.x.x.2**

**Connect to CSR1 and paste in the below config. Replace "Instance0" and "Instance1" with the PIPs of VWANEAST. Make sure the static routes at the end of the config are pointing to the correct peering IP and routing across the right tunnel.**
<pre lang="...">
ip prefix-list filter-DC1-out seq 5 permit 10.100.0.0/24
ip prefix-list filter-DC1-out seq 10 permit 10.100.1.0/24
ip prefix-list filter-DC1-out seq 15 permit 10.100.10.0/24

crypto ikev2 proposal az-PROPOSAL 
 encryption aes-cbc-256 aes-cbc-128 3des
 integrity sha1
 group 2
!
crypto ikev2 policy az-POLICY 
 proposal az-PROPOSAL
!
crypto ikev2 keyring key-peer1
 peer azvpn1
  address "Instance0"
  pre-shared-key Msft123Msft123
!
crypto ikev2 keyring key-peer2
 peer azvpn2
  address "Instance1"
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile az-PROFILE1
 match address local interface GigabitEthernet1
 match identity remote address "Instance0" 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer1
!
crypto ikev2 profile az-PROFILE2
 match address local interface GigabitEthernet1
 match identity remote address "Instance1" 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer2

crypto ipsec transform-set az-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha-hmac 
 mode tunnel
!
crypto ipsec profile az-VTI1
 set transform-set az-IPSEC-PROPOSAL-SET 
 set ikev2-profile az-PROFILE1
!
crypto ipsec profile az-VTI2
 set transform-set az-IPSEC-PROPOSAL-SET 
 set ikev2-profile az-PROFILE2
!
interface Loopback0
 ip address 172.16.0.1 255.255.255.255
!
interface Tunnel0
 ip address 172.16.0.2 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination "Instance0"
 tunnel protection ipsec profile az-VTI1
!
interface Tunnel1
 ip address 172.16.0.3 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination "Instance1"
 tunnel protection ipsec profile az-VTI2
!
router bgp 65001
 bgp router-id interface Loopback0
 bgp log-neighbor-changes
 neighbor 192.168.0.12 remote-as 65515
 neighbor 192.168.0.12 ebgp-multihop 5
 neighbor 192.168.0.12 update-source Loopback0
 neighbor 192.168.0.13 remote-as 65515
 neighbor 192.168.0.13 ebgp-multihop 5
 neighbor 192.168.0.13 update-source Loopback0
 !
 address-family ipv4
  network 10.100.0.0 mask 255.255.255.0
  network 10.100.1.0 mask 255.255.255.0
  network 10.100.10.0 mask 255.255.255.0
  neighbor 192.168.0.12 activate
  neighbor 192.168.0.12 soft-reconfiguration inbound
  neighbor 192.168.0.13 activate
  neighbor 192.168.0.13 soft-reconfiguration inbound
  neighbor 192.168.0.12 prefix-list filter-DC1-out out
  neighbor 192.168.0.13 prefix-list filter-DC1-out out
  maximum-paths 4
 exit-address-family

ip route 10.100.10.0 255.255.255.0 10.100.1.1
ip route 192.168.0.12 255.255.255.255 Tunnel1
ip route 192.168.0.13 255.255.255.255 Tunnel0
</pre>

**Validate the tunnel is up and basic connectivity**
<pre lang="...">
!validate tunnel0 is up
sh int tu0

!validate tunnel0 is up
sh int tu1

!validate tunnel status is "READY".
sh crypto ikev2 sa

!validate crypto session "Session status: UP-ACTIVE"
show crypto session

!Check that DC1 is controlling outbound BGP advertisement
sh ip bgp neighbors 192.168.0.12 advertised-routes
sh ip bgp neighbors 192.168.0.13 advertised-routes

!Make sure BGP learned routes are now in the route table. Note there are 2 next hops. This is due to the max path configurations under BGP. Traffic to that destination !will load share across both tunnels. You can prepend routes if you want to prefer a specific tunnel.
sh ip route bgp

!Source ping from inside interface of CSR1 to the VMs in VNET 10/20**
ping 10.10.10.4 source gi2
ping 10.20.10.4 source gi2
</pre>

**Validate VMs in VNET10 and VNET20 see 2 paths to DC1 (10.100.0.0/16). Remember we created 2 tunnels to DC1.
<pre lang="...">
az network nic show-effective-route-table -g VNET10 -n VNET10VMNIC --output table
az network nic show-effective-route-table -g VNET20 -n VNET20VMNIC --output table
</pre>

**Connect to CSR1 and paste in the below config. Replace "Instance0" and "Instance1" with the PIPs of VWANEAST. Make sure the static routes at the end of the config are pointing to the correct peering IP and routing across the right tunnel.**
<pre lang="...">

ip prefix-list filter-DC1-out seq 5 permit 10.101.0.0/24
ip prefix-list filter-DC1-out seq 10 permit 10.101.1.0/24
ip prefix-list filter-DC1-out seq 15 permit 10.101.10.0/24

crypto ikev2 proposal az-PROPOSAL 
 encryption aes-cbc-256 aes-cbc-128 3des
 integrity sha1
 group 2
!
crypto ikev2 policy az-POLICY 
 proposal az-PROPOSAL
!
crypto ikev2 keyring key-peer1
 peer azvpn1
  address "Instance0"
  pre-shared-key Msft123Msft123
!
crypto ikev2 keyring key-peer2
 peer azvpn2
  address "Instance1"
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile az-PROFILE1
 match address local interface GigabitEthernet1
 match identity remote address "Instance0" 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer1
!
crypto ikev2 profile az-PROFILE2
 match address local interface GigabitEthernet1
 match identity remote address "Instance1" 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local key-peer2
!
crypto ipsec transform-set az-IPSEC-PROPOSAL-SET esp-aes 256 esp-sha-hmac 
 mode tunnel
!
crypto ipsec profile az-VTI1
 set transform-set az-IPSEC-PROPOSAL-SET 
 set ikev2-profile az-PROFILE1
!
crypto ipsec profile az-VTI2
 set transform-set az-IPSEC-PROPOSAL-SET 
 set ikev2-profile az-PROFILE2
!
interface Loopback0
 ip address 172.16.0.4 255.255.255.255
!
interface Tunnel0
 ip address 172.16.0.5 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination "Instance0"
 tunnel protection ipsec profile az-VTI1
!
interface Tunnel1
 ip address 172.16.0.6 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source GigabitEthernet1
 tunnel mode ipsec ipv4
 tunnel destination "Instance1"
 tunnel protection ipsec profile az-VTI2
!
router bgp 65002
 bgp router-id interface Loopback0
 bgp log-neighbor-changes
 neighbor 192.168.1.12 remote-as 65515
 neighbor 192.168.1.12 ebgp-multihop 5
 neighbor 192.168.1.12 update-source Loopback0
 neighbor 192.168.1.13 remote-as 65515
 neighbor 192.168.1.13 ebgp-multihop 5
 neighbor 192.168.1.13 update-source Loopback0
 !
 address-family ipv4
  network 10.101.0.0 mask 255.255.255.0
  network 10.101.1.0 mask 255.255.255.0
  network 10.101.10.0 mask 255.255.255.0
  neighbor 192.168.1.12 activate
  neighbor 192.168.1.12 soft-reconfiguration inbound
  neighbor 192.168.1.13 activate
  neighbor 192.168.1.13 soft-reconfiguration inbound
  neighbor 192.168.1.12 prefix-list filter-DC1-out out
  neighbor 192.168.1.13 prefix-list filter-DC1-out out
  maximum-paths 4
 exit-address-family

ip route 10.101.10.0 255.255.255.0 10.101.1.1
ip route 192.168.1.13 255.255.255.255 Tunnel1
ip route 192.168.1.12 255.255.255.255 Tunnel0
</pre>

**Repeat validation steps that were used for DC1 in DC2 using correct IPs. DC1 and DC2 can now reach other by hairpinning off the VWAN appliances (we allowed this). DC1 and DC2 can now speak through the VWAN "backbone" as well as VNET10/20.**
