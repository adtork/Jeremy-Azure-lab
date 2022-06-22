# Azure Networking Lab- IPSEC VPN (IKEv2) between Cisco ASAv and Azure VPN Gateway with BGP

This lab guide illustrates how to build a basic IKEv2 tunnel between a Cisco ASAv and the Azure VPN gateway with BGP. NAT and security proposals shown can be narrowed down as needed. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. The on prem VNET is used to simulate on prem connectivity so there is no required hardware. This is for lab testing purposes only.


# Base Topology
The lab deploys an Azure VPN gateway into a VNET. We will also deploy a Cisco ASAv in a seperate VNET to simulate on prem. On prem ASN is 65002 and Azure VPN GW is 65515.
![alt text](https://github.com/jwrightazure/lab/blob/master/images/asavlab.png)

**Build Resource Groups, VNETs, Subnets and test VMs**
<pre lang="...">
##Variables#
RG="VWAN-PAN-Lab"
Location="eastus2"

az group create --name $RG --location $Location
az network vnet create --name Hub --resource-group $RG --location $Location --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group $RG --vnet-name Hub

az network vnet create --resource-group $RG --name onprem --location $Location --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group $RG --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group $RG --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.2.0/24 --name twonet --resource-group $RG --vnet-name onprem

az network public-ip create --name HubVMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n HubVMNIC --location $Location --subnet HubVM --private-ip-address 10.0.10.10 --vnet-name Hub --public-ip-address HubVMPubIP --ip-forwarding true
az vm create -n HubVM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics HubVMNIC --no-wait --location $Location

az network public-ip create --name onpremVMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n onpremVMNIC --location $Location --subnet VM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --ip-forwarding true
az vm create -n onpremVM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait --location $Location
</pre>

**Build Public IP and Azure VPN Gateway. Deployment will take some time.**
<pre lang="...">
az network public-ip create --name Azure-VNGpubip --resource-group $RG --allocation-method Dynamic --location $Location
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group $RG --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw3 --no-wait --location $Location
</pre>

**Before deploying ASA in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a ASA in the portal or Powershell/Azure CLI commands.**
<pre lang="...">
az vm image terms accept --urn cisco:cisco-asav:asav-azure-byol:latest
</pre>

**Build ASAv in the on prem VNET.**
<pre lang="...">
az network public-ip create --name ASA1MgmtIP --resource-group $RG --idle-timeout 30 --allocation-method Static --location $Location
az network public-ip create --name ASA1VPNPublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static --location $Location
az network nic create --name ASA1MgmtInterface --resource-group $RG --subnet twonet --vnet onprem --public-ip-address ASA1MgmtIP --private-ip-address 10.1.2.4 --ip-forwarding true --location $Location
az network nic create --name ASA1OutsideInterface --resource-group $RG --subnet zeronet --vnet onprem --public-ip-address ASA1VPNPublicIP --private-ip-address 10.1.0.4 --ip-forwarding true --location $Location
az network nic create --name ASA1InsideInterface --resource-group $RG --subnet onenet --vnet onprem --private-ip-address 10.1.1.4 --ip-forwarding true --location $Location
az vm create --resource-group $RG --location $Location --name ASA1 --size Standard_D3_v2 --nics ASA1MgmtInterface ASA1OutsideInterface ASA1InsideInterface  --image cisco:cisco-asav:asav-azure-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait
</pre>

**After the gateway and ASAv have been created, document the public IP address for the VPN GW and ASA. The VPN GW value will be null until it has been successfully provisioned. *Do not continue with the lab until there is an IP associated with the VPN GW* Please note that the ASA VPN interface and management interfaces are different**
<pre lang="...">
az network public-ip show -g $RG -n Azure-VNGpubip --query "{address: ipAddress}"
az network public-ip show -g $RG -n ASA1VPNPublicIP --query "{address: ipAddress}"
az network public-ip show -g $RG -n ASA1MgmtIP --query "{address: ipAddress}"
</pre>

**Verify BGP information on the Azure VPN GW**
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group $RG
</pre>

**Create a route table and routes for the Azure VNET with correct association. This is for the onprem simulation to route traffic to the ASAv.**
<pre lang="...">
az network route-table create --name vm-rt --resource-group $RG
az network route-table route create --name vm-rt --resource-group $RG --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name onprem --resource-group $RG --route-table vm-rt
</pre>

**Create Local Network Gateway and connection. Change the "ASA1VPNPublicIP" public IP. On prem BGP peer over IPSEC is in ASN 65002. 192.168.2.1 is the VTI on the ASAv**
<pre lang="...">
az network local-gateway create --gateway-ip-address "ASA1VPNPublicIP" --name to-onprem --resource-group $RG --asn 65002 --bgp-peering-address 192.168.2.1
az network vpn-connection create --name to-onprem --resource-group $RG --vnet-gateway1 Azure-VNG --location $Location --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp
</pre>

**SSH to ASAv "ASA1MgmtIP". Change any reference to "Azure-VNGpubip". Also, make sure to use the correct BGP peer IP for the Azure VPN Gateway.**
<pre lang="...">
interface GigabitEthernet0/0
 nameif outside
 security-level 0
 ip address 10.1.0.4 255.255.255.0 
 no shut
!
interface GigabitEthernet0/1
 nameif inside
 security-level 100
 ip address 10.1.1.4 255.255.255.0
 no shut

!By default, ASAv has default route (burned in) pointing out the Mgmt interface. Route Azure VPN GW out the outside interface which we're using for VPN termination
route OUTSIDE "Azure-VNGpubip" 255.255.255.255 10.1.0.1 1

!route traffic from the ASAv destin for the on prem subnet to the fabric
route inside 10.1.10.0 255.255.255.0 10.1.1.1 1

!Must create crypto profiles first
crypto ipsec ikev2 ipsec-proposal Azure-Ipsec-PROP-to-onprem
 protocol esp encryption aes-256 aes-192 aes
 protocol esp integrity sha-256 sha-1
crypto ipsec ikev2 ipsec-proposal AES256
 protocol esp encryption aes-256
 protocol esp integrity sha-1 md5
crypto ipsec ikev2 ipsec-proposal AES192
 protocol esp encryption aes-192
 protocol esp integrity sha-1 md5
crypto ipsec ikev2 ipsec-proposal AES
 protocol esp encryption aes
 protocol esp integrity sha-1 md5
crypto ipsec ikev2 ipsec-proposal 3DES
 protocol esp encryption 3des
 protocol esp integrity sha-1 md5
crypto ipsec ikev2 ipsec-proposal DES
 protocol esp encryption des
 protocol esp integrity sha-1 md5
crypto ipsec profile Azure-Ipsec-PROF-to-onprem
 set ikev2 ipsec-proposal Azure-Ipsec-PROP-to-onprem
 set security-association lifetime kilobytes unlimited
 set security-association lifetime seconds 3600
crypto ipsec security-association lifetime seconds 3600
crypto ipsec security-association lifetime kilobytes unlimited
crypto ipsec security-association replay disable
crypto ipsec security-association pmtu-aging infinite
crypto ca trustpool policy
crypto isakmp disconnect-notify

crypto ikev2 policy 1
 encryption aes-256 aes-192 aes 3des
 integrity sha256 sha
 group 2
 prf sha256 sha
 lifetime seconds 28800

!Tunnel IP must not conflict with any prefixes. This can be a /30
interface Tunnel11
 nameif vti-to-onprem
 ip address 192.168.2.1 255.255.255.0 
 tunnel source interface OUTSIDE
 tunnel destination "Azure-VNGpubip"
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile Azure-Ipsec-PROF-to-onprem
 no shut


!route traffic for Azure over the tunnel to the tunnel interface
route vti-to-onprem 10.0.0.254 255.255.255.255 "Azure-VNGpubip" 1

crypto ikev2 enable OUTSIDE
crypto ikev2 notify invalid-selectors

group-policy AzureGroupPolicy internal
group-policy AzureGroupPolicy attributes
 vpn-tunnel-protocol ikev2 l2tp-ipsec 
dynamic-access-policy-record DfltAccessPolicy
tunnel-group "Azure-VNGpubip" type ipsec-l2l
tunnel-group "Azure-VNGpubip" general-attributes
 default-group-policy AzureGroupPolicy
tunnel-group "Azure-VNGpubip" ipsec-attributes
 ikev2 remote-authentication pre-shared-key Msft123Msft123
 ikev2 local-authentication pre-shared-key Msft123Msft123
no tunnel-group-map enable peer-ip
tunnel-group-map default-group "Azure-VNGpubip"
!
class-map inspection_default
 match default-inspection-traffic

router bgp 65002
 bgp log-neighbor-changes
 bgp graceful-restart
 bgp router-id 192.168.2.1
 address-family ipv4 unicast
  neighbor 10.0.0.254 remote-as 65001
  neighbor 10.0.0.254 ebgp-multihop 255
  neighbor 10.0.0.254 activate
  network 10.1.10.0 mask 255.255.255.0
  no auto-summary
  no synchronization
 exit-address-family
</pre>

**Validation**
<pre lang="...">
Validate VPN connection status in Azure CLI
 az network vpn-connection show --name to-onprem --resource-group $RG --query "{status: connectionStatus}"

 Validate BGP routes being advetised from the Azure VPN GW to the ASA
 az network vnet-gateway list-advertised-routes -g $RG -n Azure-VNG --peer 192.168.2.1 -o table

 Validate BGP routes the Azure VPN GW is receiving from the ASA
 az network vnet-gateway list-learned-routes -g $RG -n Azure-VNG -o table

 You can also add static routes or network statements to the ASA to validate new prefixes are added to the Azure effective route table.
ASA1(config)# route null0 2.2.2.2 255.255.255.255
ASA1(config)# route null0 3.3.3.3 255.255.255.255
ASA1(config-router)# address-family ipv4 unicast 
ASA1(config)# router bgp 65002
ASA1(config-router-af)# network 2.2.2.2 mask 255.255.255.255
</pre>
