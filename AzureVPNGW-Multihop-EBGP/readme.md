# Azure Networking Lab- eBGP Multihop with Azure VPN Gateway

This lab guide illustrates how to build a basic IKEv2 between a Cisco CSR and the Azure VPN gateway. The goal is to have the IKEv2 tunnel be established between the Azure VPN GW and CSR1 and establish BGP peering between the same VPN GW and CSR2 across the tunnel. This is for lab testing purposes only. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. The entire lab including simulated on prem is done in Azure. No hardware required. Current CSR image used is 17.3.4a. All username/password are azureuser/Msft123Msft123.

# Topology- VPN GW IKEv2 tunnel to CSR1, eBGP between VPN and CSR2
![alt text](https://github.com/jwrightazure/lab/blob/master/images/vpn-ebgp-topo.PNG)

**Before deploying CSR in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands via Cloudshell**
<pre lang="...">
Sample Azure CLI:
az vm image terms accept --urn cisco:cisco-csr-1000v:17_3_4a-byol:latest
</pre>

**Build Resource Groups, VNETs, Subnets, test VM in the hub and the simulated on prem VNET**
<pre lang="...">
RG="VPN-EBGP-RG"
Location="eastus"

az group create --name $RG --location $Location
az network vnet create --resource-group $RG --name Hub --location $Location --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group $RG --vnet-name Hub
az network vnet create --resource-group $RG --name onprem --location $Location --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group $RG --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group $RG --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.2.0/24 --name twonet --resource-group $RG --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.3.0/24 --name threenet --resource-group $RG --vnet-name onprem

az network public-ip create --name HubVMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n HubVMNIC --location $Location --subnet HubVM --private-ip-address 10.0.10.10 --vnet-name Hub --public-ip-address HubVMPubIP
az vm create -n HubVM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVMNIC --no-wait

az network public-ip create --name onpremVMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n onpremVMNIC --location $Location --subnet VM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP
az vm create -n onpremVM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait
</pre>

**Build Azure VPN GW and CSRs**
<pre lang="...">
az network public-ip create --name Azure-VNGpubip --resource-group $RG --allocation-method Dynamic
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group $RG --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw3 --no-wait

az network public-ip create --name CSR1PublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface --resource-group $RG --subnet zeronet --vnet onprem --public-ip-address CSR1PublicIP --ip-forwarding true
az network nic create --name CSR1InsideInterface --resource-group $RG --subnet onenet --vnet onprem --ip-forwarding true
az vm create --resource-group $RG --location $Location --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface --image cisco:cisco-csr-1000v:17_3_4a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait

az network public-ip create --name CSR2PublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name CSR2OutsideInterface --resource-group $RG --subnet twonet --vnet onprem --public-ip-address CSR2PublicIP --ip-forwarding true
az network nic create --name CSR2InsideInterface --resource-group $RG --subnet threenet --vnet onprem --ip-forwarding true
az vm create --resource-group $RG --location $Location --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:17_3_4a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait
</pre>

**Make sure the VPN GW is fully provisioned before continuing. This will take 15+ minutes. Value will be null until it has been successfully provisioned.**
<pre lang="...">
az network public-ip show --resource-group $RG -n Azure-VNGpubip --query "{address: ipAddress}"
</pre>

**Document all pubic IPs**
<pre lang="...">
az network public-ip show --resource-group $RG -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n CSR2PublicIP --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n HubVMPubIP --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n onpremVMPubIP --query "{address: ipAddress}"
</pre>

**Validate Azure VPN GW BGP Information**
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group $RG
</pre>

**Create route tables for on prem. This is only needed to address underlay/overlay forwarding in the simulated on prem environment.**
<pre lang="...">
az network route-table create --name onprem-vm-rt --resource-group $RG
az network route-table route create --name onprem-vm-rt --resource-group $RG --route-table-name onprem-vm-rt --address-prefix 10.0.0.0/8 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.3.4
az network vnet subnet update --name VM --vnet-name onprem --resource-group $RG --route-table onprem-vm-rt

az network route-table create --name CSR1-rt --resource-group $RG
az network route-table route create --name CSR2-loopback --resource-group $RG --route-table-name CSR1-rt --address-prefix 192.168.1.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.2.4
az network route-table route create --name VM --resource-group $RG --route-table-name CSR1-rt --address-prefix 10.1.10.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.2.4
az network route-table route create --name CSR2-inside --resource-group $RG --route-table-name CSR1-rt --address-prefix 10.1.3.0/24 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.2.4
az network vnet subnet update --name onenet --vnet-name onprem --resource-group $RG --route-table CSR1-rt

az network route-table create --name CSR2-rt --resource-group $RG
az network route-table route create --name CSR2-rt --resource-group $RG --route-table-name CSR2-rt --address-prefix 10.0.0.0/8 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name twonet --vnet-name onprem --resource-group $RG --route-table CSR2-rt
</pre>

**Create the local network GW and connection. Please change "CSR1PublicIP" to the appropriate PIP. Notice we are terminating the tunnel on CSR1 but are using multihop BGP to CSR2**
<pre lang="...">
az network local-gateway create --gateway-ip-address "CSR1PublicIP" --name to-onprem --resource-group $RG --local-address-prefixes 192.168.1.1/32 --asn 65002 --bgp-peering-address 192.168.1.1
az network vpn-connection create --name to-onprem --resource-group $RG --vnet-gateway1 Azure-VNG -l $Location --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp
</pre>

**SSH to CSR1 and paste in the below config. Make sure to change "insert Azure VPN GW IP" to the appropriate address.**
<pre lang="...">
crypto ikev2 proposal to-onprem-proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy to-onprem-policy 
 match address local 10.1.0.4
 proposal to-onprem-proposal
!
crypto ikev2 keyring to-onprem-keyring
 peer "insert Azure VPN GW IP"
  address "insert Azure VPN GW IP" 255.255.255.0
  pre-shared-key Msft123Msft123
!
crypto ikev2 profile to-onprem-profile
 match address local 10.1.0.4
 match identity remote address "insert Azure VPN GW IP" 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-onprem-keyring
 lifetime 3600
 dpd 10 5 on-demand

crypto ipsec transform-set to-onprem-TransformSet esp-gcm 256 
 mode tunnel

crypto ipsec profile to-onprem-IPsecProfile
 set transform-set to-onprem-TransformSet 
 set ikev2-profile to-onprem-profile

interface Tunnel1
 ip address 192.168.2.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.1.0.4
 tunnel mode ipsec ipv4
 tunnel destination "insert Azure VPN GW IP"
 tunnel protection ipsec profile to-onprem-IPsecProfile

ip route 0.0.0.0 0.0.0.0 10.1.0.1
ip route 10.0.0.0 255.0.0.0 Tunnel1
ip route 10.1.2.0 255.255.255.0 10.1.1.1
ip route 10.1.3.0 255.255.255.0 10.1.1.1
ip route 10.1.10.0 255.255.255.0 10.1.1.1
ip route 192.168.1.1 255.255.255.255 10.1.1.1
</pre>

**SSH to CSR2 and paste in the below.**
<pre lang="...">
interface Loopback11
 ip address 192.168.1.1 255.255.255.255

router bgp 65002
 bgp router-id 192.168.1.1
 bgp log-neighbor-changes
 neighbor 10.0.0.254 remote-as 65515
 neighbor 10.0.0.254 ebgp-multihop 255
 neighbor 10.0.0.254 update-source Loopback11
 !
 address-family ipv4
  network 10.1.2.0 mask 255.255.255.0
  network 10.1.3.0 mask 255.255.255.0
  network 10.1.10.0 mask 255.255.255.0
  neighbor 10.0.0.254 activate
 exit-address-family

ip route 0.0.0.0 0.0.0.0 10.1.2.1
ip route 10.0.0.254 255.255.255.255 10.1.2.1
ip route 10.1.10.0 255.255.255.0 10.1.3.1
</pre>

**At this point, there should be an IKEv2 tunnel between the VPN GW and CSR1. There is also a BGP session between the VPN GW and CSR2 without a tunnel. Both VMs will be able to communicate after BGP is synchronized.**
