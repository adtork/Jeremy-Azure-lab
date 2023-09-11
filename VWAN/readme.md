## VWAN Lab
This lab guide illustrates how to build a basic VWAN infrastructure including simulated on prem sites (no hardware needed). This is for testing purposes only and should not be considered production configurations. The lab builds two "on prem" VNETs allowing you to simulate your infrastructure. The two on prem sites connect to 2 different VWAN hubs via an IPSEC/IKEv2 tunnel based on their geo that are also connected to 2 VNETs. At the end of the lab, the two on prem sites will be able to talk to the VNETs as well as each other through the tunnel.  All configs are done in Azure CLI or Cisco CLI so you can easily change them as needed to match your environment. All test VMs use serial console to connect.



**VWAN Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/vwan%20topo.png)

**#Accept user agreement for CSR. The CSR is used in the simulated on prem VNET and will have a S2S tunnel to the VPNGW**
<pre lang="...">
az vm image terms accept --urn cisco:cisco-csr-1000v:17_03_07-byol:latest
</pre>


**Create the VWAN hub that allows on prem to on prem to hairpin through the tunnel. The address space used should not overlap. VWAN deploys 2 "appliances" as well as a number of underlying components. We're starting here as the last command in this section can take 30+ minutes to deploy. By specifying "--no-wait", you can move on to other steps while this section of VWAN continues to deploy in the background.**
<pre lang="...">

#Create variables
RG="VWAN"
Location="eastus2"
Location2="westus2"

az group create --name VWAN --location eastus2
az network vwan create --name VWAN --resource-group $RG --branch-to-branch-traffic true --location eastus2
az network vhub create --address-prefix 192.168.0.0/24 --name VWANEAST --resource-group $RG --vwan VWAN --location eastus2 --sku basic
az network vpn-gateway create --name VWANEAST --resource-group $RG --vhub VWANEAST --location eastus2 --no-wait
az network vhub create --address-prefix 192.168.1.0/24 --name VWANWEST --resource-group $RG --vwan VWAN --location westus2 --sku basic
az network vpn-gateway create --name VWANWEST --resource-group $RG --vhub VWANWEST --location westus2 --no-wait
</pre>

**Deploy the infrastructure for simulated on prem DC1 (10.100.0.0/16). This builds out all of the VNET/subnet/routing/VMs needed to simulate on prem including a Cisco CSR and test Linux machine.**
<pre lang="...">

az network vnet create --resource-group $RG --name DC1 --location eastus2 --address-prefixes 10.100.0.0/16 --subnet-name VM --subnet-prefix 10.100.10.0/24
az network vnet subnet create --address-prefix 10.100.0.0/24 --name zeronet --resource-group $RG --vnet-name DC1
az network vnet subnet create --address-prefix 10.100.1.0/24 --name onenet --resource-group $RG --vnet-name DC1
az network public-ip create --name CSR1PublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface --resource-group $RG --subnet zeronet --vnet DC1 --public-ip-address CSR1PublicIP --ip-forwarding true --private-ip-address 10.100.0.4
az network nic create --name CSR1InsideInterface --resource-group $RG --subnet onenet --vnet DC1 --ip-forwarding true --private-ip-address 10.100.1.4
az vm create --resource-group $RG --location eastus2 --name CSR1 --size Standard_D2as_v4 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:17_03_07-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network nic create --resource-group $RG -n DC1VMNIC --location eastus2 --subnet VM --vnet-name DC1 --private-ip-address 10.100.10.4
az vm create -n DC1VM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics DC1VMNIC --no-wait --size Standard_D2as_v4
az network route-table create --name DC1-RT --resource-group $RG
az network route-table route create --name To-VNET10 --resource-group $RG --route-table-name DC1-RT --address-prefix 10.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name To-VNET20 --resource-group $RG --route-table-name DC1-RT --address-prefix 10.20.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name To-VNET30 --resource-group $RG --route-table-name DC1-RT --address-prefix 10.30.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network route-table route create --name To-DC2 --resource-group $RG --route-table-name DC1-RT --address-prefix 10.101.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4
az network vnet subnet update --name VM --vnet-name DC1 --resource-group $RG --route-table DC1-RT
</pre>

**Build the same for simulated on prem DC2**
<pre lang="...">
az network vnet create --resource-group $RG --name DC2 --location westus2 --address-prefixes 10.101.0.0/16 --subnet-name DC2VM --subnet-prefix 10.101.10.0/24 --location $Location2
az network vnet subnet create --address-prefix 10.101.0.0/24 --name zeronet --resource-group $RG --vnet-name DC2 
az network vnet subnet create --address-prefix 10.101.1.0/24 --name onenet --resource-group $RG --vnet-name DC2
az network public-ip create --name CSR2PublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static --location $Location2
az network nic create --name CSR2OutsideInterface --resource-group $RG --subnet zeronet --vnet DC2 --public-ip-address CSR2PublicIP --ip-forwarding true --private-ip-address 10.101.0.4 --location $Location2
az network nic create --name CSR2InsideInterface --resource-group $RG --subnet onenet --vnet DC2 --ip-forwarding true --private-ip-address 10.101.1.4 --location $Location2
az VM create --resource-group $RG --location $Location2 --name CSR2 --size Standard_D2as_v4 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:17_03_07-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait
az network nic create --resource-group $RG -n DC2VMNIC --location westus2 --subnet DC2VM --vnet-name DC2 --private-ip-address 10.101.10.4 --location $Location2
az VM create -n DC2VM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics DC2VMNIC --no-wait --size Standard_D2as_v4 --location $Location2
az network route-table create --name DC2-RT --resource-group $RG --location $Location2
az network route-table route create --name To-VNET10 --resource-group $RG --route-table-name DC2-RT --address-prefix 10.10.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network route-table route create --name To-VNET20 --resource-group $RG --route-table-name DC2-RT --address-prefix 10.20.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network route-table route create --name To-VNET30 --resource-group $RG --route-table-name DC2-RT --address-prefix 10.30.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network route-table route create --name To-DC1 --resource-group $RG --route-table-name DC2-RT --address-prefix 10.100.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.101.1.4
az network vnet subnet update --name DC2VM --vnet-name DC2 --resource-group $RG --route-table DC2-RT
</pre>

**Build VNET 10 which includes a test VM. No routing needs to be defined as VWAN will inject routes.**
<pre lang="...">
az network vnet create --resource-group $RG --name VNET10 --location eastus2 --address-prefixes 10.10.0.0/16 --subnet-name VNET10VM --subnet-prefix 10.10.10.0/24
az network vnet subnet create --address-prefix 10.10.0.0/24 --name zeronet --resource-group $RG --vnet-name VNET10
az network vnet subnet create --address-prefix 10.10.1.0/24 --name onenet --resource-group $RG --vnet-name VNET10
az network nic create --resource-group $RG -n VNET10VMNIC --location eastus2 --subnet VNET10VM --vnet-name VNET10 --private-ip-address 10.10.10.4
az VM create -n VNET10VM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics VNET10VMNIC --no-wait --size Standard_D2as_v4
</pre>

**Build VNET 20**
<pre lang="...">
az network vnet create --resource-group $RG --name VNET20 --location westus2 --address-prefixes 10.20.0.0/16 --subnet-name VNET20VM --subnet-prefix 10.20.10.0/24
az network vnet subnet create --address-prefix 10.20.0.0/24 --name zeronet --resource-group $RG --vnet-name VNET20
az network vnet subnet create --address-prefix 10.20.1.0/24 --name onenet --resource-group $RG --vnet-name VNET20
az network nic create --resource-group $RG -n VNET20VMNIC --location westus2 --subnet VNET20VM --vnet-name VNET20 --private-ip-address 10.20.10.4
az VM create -n VNET20VM --resource-group $RG --image UbuntuLTS --admin-password Msft123Msft123 --nics VNET20VMNIC --no-wait --size Standard_D2as_v4
</pre>

**Validate "provisioningstate" of the VPN GWs are successful. Do not continue if provisioning was not successful. The VPN appliances can take 30+ minutes to create.**
<pre lang="...">
az network vpn-gateway list --resource-group $RG -o table
</pre>

**Build a connection between the VWANEAST hub and VNET10. Also build a connection between VWANWEST and VNET 20. Replace XX with your subscription.**
<pre lang="...">
az network vhub connection create --name toVNET10 --remote-vnet /subscriptions/XX/resourceGroups/VNET10/providers/Microsoft.Network/virtualNetworks/VWAN --resource-group $RG --vhub-name VWANEAST

az network vhub connection create --name toVNET20 --remote-vnet /subscriptions/XX/resourceGroups/VNET20/providers/Microsoft.Network/virtualNetworks/VWAN --resource-group $RG --vhub-name VWANWEST
</pre>

**Get the public IP of the CSR in DC1. This is the address of on the on prem DC1 side that the VPN tunnels will terminate on. Copy it to notepad.**
<pre lang="...">
az network public-ip show --resource-group $RG -n CSR1PublicIP --query "{address: ipAddress}"
</pre>

**Build a VPN site and connection between VWANEAST and the DC1 CSR. Replace "CSR1PublicIP" with the IP address from the previous step. Remember a VPN site "connection" in Azure will build a S2S VPN from both VPN appliances in VWAN Hub VWANEAST. For BGP over IPSEC, this assumes CSR1 BGP ASN is 65001 and the VTI is 172.16.0.1 (not the PIP of the CSR).**
<pre lang="...">
az network vpn-site create --ip-address "CSR1PublicIP" --name DC1 --resource-group $RG --location eastus2 --virtual-wan VWAN --asn 65001 --bgp-peering-address 172.16.0.1

az network vpn-gateway connection create --gateway-name VWANEAST --name DC1 --remote-vpn-site DC1 --resource-group $RG --protocol-type IKEv2 --shared-key Msft123Msft123 --enable-bgp
</pre>

**Get the public IP of the CSR in DC2. This is the address of on the on prem side that the VPN tunnels will terminate on. Copy it to notepad.**
<pre lang="...">
az network public-ip show --resource-group $RG -n CSR2PublicIP --query "{address: ipAddress}"
</pre>

**Build a VPN site and connection between VWAN and the DC2 CSR. Replace "CSR2PublicIP" with the IP address from the previous step.**
<pre lang="...">
az network vpn-site create --ip-address "CSR2PublicIP" --name DC2 --resource-group $RG --location westus2 --virtual-wan VWAN --asn 65002 --bgp-peering-address 172.16.0.4

az network vpn-gateway connection create --gateway-name VWANWEST --name DC2 --remote-vpn-site DC2 --resource-group $RG --protocol-type IKEv2 --shared-key Msft123Msft123 --enable-bgp
</pre>

**Document the public IPs of Instance0 and Instance1 for VWAN EAST**
<pre lang="...">
az network vpn-gateway show -n VWANEAST -g $RG --query 'ipConfigurations'
</pre>

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
az network nic show-effective-route-table --resource-group $RG -n VNET10VMNIC --output table
az network nic show-effective-route-table --resource-group $RG -n VNET20VMNIC --output table
</pre>

**Document the public IPs of Instance0 and Instance1 of VWANWEST**
<pre lang="...">
az network vpn-gateway show -n VWANWEST -g $RG --query 'ipConfigurations'
</pre>

**Connect to CSR2 and paste in the below config. Replace "Instance0" and "Instance1" with the PIPs of VWANWEST. Make sure the static routes at the end of the config are pointing to the correct peering IP and routing across the right tunnel.**
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
