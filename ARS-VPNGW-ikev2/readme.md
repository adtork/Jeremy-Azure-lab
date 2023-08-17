<pre lang="...">
Lab builds a Hub VNET with ARS, VPN GW and a VNET CSR to inject routes into ARS. On prem is simulated with a VNET and a CSR. On prem CSR has an ikev2 tunnel to the VPNGW with BGP. On prem is advertising 10.1.10.0/24, ASN 65002. CSR in the VNET is advertising 1.1.1.1/32, ASN 65003

#Accept user agreement for CSR. The CSR is used in the simulated on prem VNET and will have a S2S tunnel to the VPNGW
az vm image terms accept --urn cisco:cisco-csr-1000v:17_3_4a-byol:latest

#Create variables
RG="ARS-VPNGW-rg"
Location="eastus2"

#Create VNETS, A/A VPN GWs, ARS and CSR
az group create --name $RG --location $Location
az network vnet create --resource-group $RG --name $RG --location $Location --address-prefixes 10.0.0.0/16 --subnet-name VM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group $RG --vnet-name $RG
az network vnet subnet create --address-prefix 10.0.100.0/24 --name RouteServerSubnet --resource-group $RG --vnet-name $RG
az network vnet subnet create --address-prefix 10.0.200.0/24 --name NVASubnet --resource-group $RG --vnet-name $RG
az network vnet create --resource-group $RG --name onprem --location $Location --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group $RG --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group $RG --vnet-name onprem

#Create A/A VPN GW
az network public-ip create --name VPNGW1pubip --resource-group $RG --allocation-method Static --sku standard
az network public-ip create --name VPNGW1pubip2 --resource-group $RG --allocation-method Static --sku standard
az network vnet-gateway create --name VPNGW1 --public-ip-address VPNGW1pubip VPNGW1pubip2 --resource-group $RG --vnet $RG --gateway-type Vpn --vpn-type RouteBased --sku VpnGw3 --no-wait --asn 65515

#Before proceeding, you may need to validate the Azure region has the available VM Sku size
az vm list-skus --location eastus2 --output table | grep Standard_D
    
#Create on prem CSR
az network public-ip create --name CSRPublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name CSROutsideInterface --resource-group $RG --subnet zeronet --vnet onprem --public-ip-address CSRPublicIP --ip-forwarding true
az network nic create --name CSRInsideInterface --resource-group $RG --subnet onenet --vnet onprem --ip-forwarding true
az vm create --resource-group $RG --location $Location --name Onprem-CSR --size Standard_D2_v2 --nics CSROutsideInterface CSRInsideInterface  --image cisco:cisco-csr-1000v:17_3_4a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait

#Create a CSR in the VNET
az network public-ip create --name CSR2PublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name CSR-VNET --resource-group $RG --subnet NVASubnet --vnet $RG --public-ip-address CSR2PublicIP --ip-forwarding true
az vm create --resource-group $RG --location $Location --name VNET-CSR --size Standard_D2_v2 --nics CSR-VNET --image cisco:cisco-csr-1000v:17_3_4a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait

#Wait for VPNGW to be fully provisioned
echo Checking VPNGW1 provisioning status...
# Checking VPNGW1 provisioning
vpnState=''
ERState=''
while [[ $vpnState != 'Succeeded' ]];
do
    vpnState=$(az network vnet-gateway show --name VPNGW1 --resource-group $RG --query 'provisioningState' -o tsv)
    echo "VPNGW1 provisioning State="$vpnState
    sleep 5
done

#Create Azure Route Server
az network public-ip create --name RouteServerIP --resource-group $RG --version IPv4 --sku Standard --location $Location
subnet_id=$(az network vnet subnet show --name RouteServerSubnet --resource-group $RG --vnet-name $RG --query id -o tsv) 
az network routeserver create --name RouteServer --resource-group $RG --hosted-subnet $subnet_id --public-ip-address RouteServerIP --location $Location
az network routeserver update --name RouteServer --resource-group $RG --allow-b2b-traffic true

#Validate BGP peering information on the VPN GWs. *make sure to document the BGP IPs on the GW*
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group $RG

#Document public IPs of CSR and A/A VPN GWs for VPN.
az network public-ip show --resource-group $RG -n VPNGW1pubip --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n CSRPublicIP --query "{address: ipAddress}"

#Create LNG and VPN connection. Replace "insert CSR Public IP"
az network local-gateway create --gateway-ip-address "insert CSR Public IP" --name to-onprem --resource-group $RG --local-address-prefixes 192.168.1.1/32 --asn 65002 --bgp-peering-address 192.168.1.1

az network vpn-connection create --name to-onprem --resource-group $RG --vnet-gateway1 VPNGW1 -l $Location --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp


#SSH to CSR and paste in the following. Replace "Azure-VNGpubip1". **Important: the below configs have a static route and a BGP peering config when the VPN GW are 10.0.0.4. Make sure to replace these IPs if needed based on the previous command that validates the VPN GW BGP peering information**
ip route 10.1.10.0 255.255.255.0 10.1.1.1
crypto ikev2 proposal Azure-Ikev2-Proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy Azure-Ikev2-Policy 
 match address local 10.1.0.4
 proposal Azure-Ikev2-Proposal
!         
crypto ikev2 keyring to-onprem-keyring
 peer "Azure-VNGpubip1"
  address "Azure-VNGpubip1"
  pre-shared-key Msft123Msft123
 !
crypto ikev2 profile Azure-Ikev2-Profile
 match address local 10.1.0.4
 match identity remote address "Azure-VNGpubip1" 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-onprem-keyring
 lifetime 28800
 dpd 10 5 on-demand

crypto ipsec transform-set to-Azure-TransformSet esp-gcm 256 
 mode tunnel
!
!
crypto ipsec profile to-Azure-IPsecProfile
 set transform-set to-Azure-TransformSet 
 set ikev2-profile Azure-Ikev2-Profile
!
interface Loopback11
 ip address 192.168.1.1 255.255.255.255
!
interface Tunnel11
 ip address 192.168.2.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.1.0.4
 tunnel mode ipsec ipv4
 tunnel destination "Azure-VNGpubip1"
 tunnel protection ipsec profile to-Azure-IPsecProfile

router bgp 65002
 bgp router-id 192.168.1.1
 bgp log-neighbor-changes
 neighbor 10.0.0.4 remote-as 65515
 neighbor 10.0.0.4 ebgp-multihop 255
 neighbor 10.0.0.4 update-source Loopback11
 !
 address-family ipv4
  network 10.1.10.0 mask 255.255.255.0
  neighbor 10.0.0.4 activate
 exit-address-family

ip route 10.0.0.4 255.255.255.255 Tunnel11

#Validate ARS BGP Peer IPs
az network routeserver show --name RouteServer --resource-group $RG

#Document VNET-CSR IP
az network public-ip show --resource-group $RG -n CSR2PublicIP --query "{address: ipAddress}"

#SSH to VNET-CSR and create a basic BGP peering and route advertisement
!null route for BGP advertisement
ip route 1.1.1.1 255.255.255.255 null0

!/32 routes for ARS, procautionary
ip route 10.0.100.4 255.255.255.255 10.0.200.1
ip route 10.0.100.5 255.255.255.255 10.0.200.1

!BGP
router bgp 65003
network 1.1.1.1 mask 255.255.255.255
neighbor 10.0.100.4 remote-as 65515
neighbor 10.0.100.5 remote-as 65515
neighbor 10.0.100.4 ebgp-multihop 10
neighbor 10.0.100.5 ebgp-multihop 10

#Create BGP from ARS to VNET-CSR
az network routeserver peering create --name CSR --peer-ip 10.0.200.4 --peer-asn 65003 --routeserver RouteServer --resource-group $RG

#Verify ARS is seeing 1.1.1.1/32 being advertised from the VNET-CSR
az network routeserver peering list-learned-routes --name CSR --routeserver RouteServer --resource-group $RG

#Verify VPN GW is receiving 1.1.1.1/32 from ARS
az network vnet-gateway list-learned-routes -g $RG -n VPNGW1

#Verify VPN GW is advertising 1.1.1.1/32 to on prem
az network vnet-gateway list-advertised-routes -g $RG -n VPNGW1 --peer 192.168.1.1

#Verify on prem CSR is learning 1.1.1.1/32
CSR#sh ip route bgp
Codes: L - local, C - connected, S - static, R - RIP, M - mobile, B - BGP
       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area 
       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2
       E1 - OSPF external type 1, E2 - OSPF external type 2, m - OMP
       n - NAT, Ni - NAT inside, No - NAT outside, Nd - NAT DIA
       i - IS-IS, su - IS-IS summary, L1 - IS-IS level-1, L2 - IS-IS level-2
       ia - IS-IS inter area, * - candidate default, U - per-user static route
       H - NHRP, G - NHRP registered, g - NHRP registration summary
       o - ODR, P - periodic downloaded static route, l - LISP
       a - application route
       + - replicated route, % - next hop override, p - overrides from PfR
       & - replicated local route overrides by connected

Gateway of last resort is 10.1.0.1 to network 0.0.0.0

      1.0.0.0/32 is subnetted, 1 subnets
B        1.1.1.1 [20/0] via 10.0.0.4, 00:03:28
      10.0.0.0/8 is variably subnetted, 7 subnets, 3 masks
B        10.0.0.0/16 [20/0] via 10.0.0.4, 00:17:01

#Verify VNET-CSR is receiving 10.1.10.0/24
VNET-CSR#sh ip route bgp
Codes: L - local, C - connected, S - static, R - RIP, M - mobile, B - BGP
       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area 
       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2
       E1 - OSPF external type 1, E2 - OSPF external type 2, m - OMP
       n - NAT, Ni - NAT inside, No - NAT outside, Nd - NAT DIA
       i - IS-IS, su - IS-IS summary, L1 - IS-IS level-1, L2 - IS-IS level-2
       ia - IS-IS inter area, * - candidate default, U - per-user static route
       H - NHRP, G - NHRP registered, g - NHRP registration summary
       o - ODR, P - periodic downloaded static route, l - LISP
       a - application route
       + - replicated route, % - next hop override, p - overrides from PfR
       & - replicated local route overrides by connected

Gateway of last resort is 10.0.200.1 to network 0.0.0.0

      10.0.0.0/8 is variably subnetted, 6 subnets, 3 masks
B        10.0.0.0/16 [20/0] via 10.0.100.5, 00:07:34
B        10.1.10.0/24 [20/0] via 10.0.100.5, 00:07:34
</pre>
