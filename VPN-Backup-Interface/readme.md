# Cisco CSR Backup Link VPN
This lab builds a Hub VNET and a VNET that simulates on prem. The Hub VNET has A/A Azure VPN GWs. On prem has a single CSR with 3 interface- 2 outside interfaces each with its own unique public IPs and a single LAN side interface. The CSR will have a tunnel to each VPN GW. The goal for this lab is for the CSR to use path 1 as primary for VPN connectivity to Azure. Path 2 should remain down until path 1 has failed reachability to Google DNS 8.8.8.8. The CSR is using EEM to monitor reachability 8.8.8.8 out path 1. If path 1 fails, path 2 should establish a tunnel to Azure+ BGP. The CSR should revert to path 1 when reachability to 8.8.8.8 has been restored and shut down the back up link. BGP is used over both tunnels. All configurations are done through Azure CLI. All VM username/password are azureuser/Msft123Msft123

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/vpn-backup-interface-topo.PNG)

**Before deploying CSR in the next step, you may have to accept license agreement unless you have used it before. You can accomplish this through deploying a CSR in the portal or Powershell commands via Cloudshell**
<pre lang="...">
az vm image terms accept --urn cisco:cisco-csr-1000v:17_3_4a-byol:latest
</pre>

**Create VNETS, VPN GW, CSR, route tables and test VMs. The VPN GWs will take approximately 20 minutes to deploy.**
<pre lang="...">
RG="VPN"
Location="eastus2"

az group create --name $RG --location $Location
az network vnet create --resource-group $RG --name VPNhub --location $Location --address-prefixes 10.0.0.0/16 --subnet-name VPNhubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group $RG --vnet-name VPNhub
az network vnet create --resource-group $RG --name onprem --location $Location --address-prefixes 10.1.0.0/16 --subnet-name onpremVM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group $RG --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group $RG --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.2.0/24 --name twonet --resource-group $RG --vnet-name onprem
az network public-ip create --name Azure-VNGpubip1 --resource-group $RG --allocation-method Dynamic
az network public-ip create --name Azure-VNGpubip2 --resource-group $RG --allocation-method Dynamic
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip1 Azure-VNGpubip2 --resource-group $RG --vnet VPNhub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw3 --asn 65515 --no-wait 
az network public-ip create --name CSRPublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network public-ip create --name CSRPublicIP2 --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name CSROutsideInterface --resource-group $RG --subnet zeronet --vnet onprem --public-ip-address CSRPublicIP --ip-forwarding true --private-ip-address 10.1.0.4
az network nic create --name CSRInsideInterface --resource-group $RG --subnet onenet --vnet onprem --ip-forwarding true --private-ip-address 10.1.1.4
az network nic create --name CSROutsideInterface2 --resource-group $RG --subnet twonet --vnet onprem --public-ip-address CSRPublicIP2 --ip-forwarding true --private-ip-address 10.1.2.4
az vm create --resource-group $RG --location $Location --name CSR --size Standard_DS3_v2 --nics CSROutsideInterface CSRInsideInterface CSROutsideInterface2 --image cisco:cisco-csr-1000v:17_3_4a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait 

az network public-ip create --name VPNhubVM --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n VPNVMNIC --location $Location --subnet VPNhubVM --private-ip-address 10.0.10.10 --vnet-name VPNhub --public-ip-address VPNhubVM --ip-forwarding true
az vm create -n VPNVM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics VPNVMNIC --no-wait 
az network public-ip create --name onpremVM --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n onpremVMNIC --location $Location --subnet onpremVM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVM --ip-forwarding true
az vm create -n onpremVM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait 
az network route-table create --name vm-rt --resource-group $RG
az network route-table route create --name vm-rt --resource-group $RG --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name onpremVM --vnet-name onprem --resource-group $RG --route-table vm-rt

#Wait for VPNGW to be fully provisioned
echo Checking Azure-VNG provisioning status...
# Checking Azure-VNG provisioning
vpnState=''
while [[ $vpnState != 'Succeeded' ]];
do
    vpnState=$(az network vnet-gateway show --name Azure-VNG --resource-group $RG --query 'provisioningState' -o tsv)
    echo "Azure-VNG provisioning State="$vpnState
    sleep 5
done
</pre>

**Document public IPs into notepad**
<pre lang="...">
az network public-ip show --resource-group $RG --name Azure-VNGpubip1 --query [ipAddress] --output tsv
az network public-ip show --resource-group $RG --name Azure-VNGpubip2 --query [ipAddress] --output tsv
az network public-ip show --resource-group $RG --name CSRPublicIP --query [ipAddress] --output tsv
az network public-ip show --resource-group $RG --name CSRPublicIP2 --query [ipAddress] --output tsv
az network public-ip show --resource-group $RG --name VPNhubVM --query [ipAddress] --output tsv
az network public-ip show --resource-group $RG --name onpremVM --query [ipAddress] --output tsv
</pre>

**Document BGP information for the VPN GWs**
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group $RG
</pre>

**Create the VPN LNG and connection to the CSR primary path 1. Insert correct public IP**
<pre lang="...">
az network local-gateway create --gateway-ip-address "CSRPublicIP" --name to-onprem --resource-group $RG --local-address-prefixes 192.168.1.1/32 --asn 65002 --bgp-peering-address 192.168.1.1
az network vpn-connection create --name to-onprem --resource-group $RG --vnet-gateway1 Azure-VNG -l $Location --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp
</pre>

**Create the VPN LNG and connection to the CSR path 2. Insert correct public IP**
<pre lang="...">
az network local-gateway create --gateway-ip-address "CSRPublicIP2" --name to-onprem2 --resource-group $RG --local-address-prefixes 192.168.1.2/32 --asn 65002 --bgp-peering-address 192.168.1.2
az network vpn-connection create --name to-onprem2 --resource-group $RG --vnet-gateway1 Azure-VNG -l $Location --shared-key Msft123Msft123 --local-gateway2 to-onprem2 --enable-bgp
</pre>

**SSH to the public IP of the onpremVM. From there, SSH to the CSR inside interface 10.1.1.4. Paste in the below config and change the public IPs. Make sure that the static routes pointed over the tunnel match the BGP info for the VPN GWs. The example assumes 10.0.0.4 and .5 as the peer. The CSR config intentionally shows multiple Ikev2 proposals, transform sets etc so it is easier to read.**
<pre lang="...">
int gi3
ip address 10.1.2.4 255.255.255.0
shut

ip route Azure-VNGpubip2 255.255.255.255 10.1.2.1
ip route 10.1.10.0 255.255.255.0 10.1.1.1

crypto ikev2 proposal Azure-Ikev2-Proposal 
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 proposal Azure-Ikev2-Proposal2
 encryption aes-cbc-256
 integrity sha1
 group 2
!
crypto ikev2 policy Azure-Ikev2-Policy 
 match address local 10.1.0.4
 proposal Azure-Ikev2-Proposal

crypto ikev2 policy Azure-Ikev2-Policy2 
 match address local 10.1.2.4
 proposal Azure-Ikev2-Proposal2
!         
crypto ikev2 keyring to-onprem-keyring
 peer Azure-VNGpubip1
  address Azure-VNGpubip1
  pre-shared-key Msft123Msft123

crypto ikev2 keyring to-onprem-keyring2
peer Azure-VNGpubip2
  address Azure-VNGpubip2
  pre-shared-key Msft123Msft123
 !
 !
crypto ikev2 profile Azure-Ikev2-Profile
 match address local 10.1.0.4
 match identity remote address Azure-VNGpubip1 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-onprem-keyring
 lifetime 28800
 dpd 10 5 on-demand
!
crypto ikev2 profile Azure-Ikev2-Profile2
 match address local 10.1.2.4
 match identity remote address Azure-VNGpubip2 255.255.255.255 
 authentication remote pre-share
 authentication local pre-share
 keyring local to-onprem-keyring2
 lifetime 28800
 dpd 10 5 on-demand
!
crypto ipsec transform-set to-Azure-TransformSet esp-gcm 256 
 mode tunnel
!
crypto ipsec transform-set to-Azure-TransformSet2 esp-gcm 256 
 mode tunnel
!
crypto ipsec profile to-Azure-IPsecProfile
 set transform-set to-Azure-TransformSet 
 set ikev2-profile Azure-Ikev2-Profile

 crypto ipsec profile to-Azure-IPsecProfile2
 set transform-set to-Azure-TransformSet2 
 set ikev2-profile Azure-Ikev2-Profile2
!
interface Tunnel11
 ip address 192.168.1.1 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.1.0.4
 tunnel mode ipsec ipv4
 tunnel destination Azure-VNGpubip1
 tunnel protection ipsec profile to-Azure-IPsecProfile

 interface Tunnel12
 ip address 192.168.1.2 255.255.255.255
 ip tcp adjust-mss 1350
 tunnel source 10.1.2.4
 tunnel mode ipsec ipv4
 tunnel destination Azure-VNGpubip2
 tunnel protection ipsec profile to-Azure-IPsecProfile2

router bgp 65002
 bgp log-neighbor-changes
 neighbor 10.0.0.4 remote-as 65515
 neighbor 10.0.0.4 ebgp-multihop 255
 neighbor 10.0.0.5 remote-as 65515
 neighbor 10.0.0.5 ebgp-multihop 255
 !
 address-family ipv4
  network 10.1.10.0 mask 255.255.255.0
  neighbor 10.0.0.4 activate
  neighbor 10.0.0.5 activate
  maximum-paths 2
 exit-address-family

ip route 10.0.0.4 255.255.255.255 Tunnel11
ip route 10.0.0.5 255.255.255.255 Tunnel12
</pre>

**Create EEM script on the CSR. Gi1 is the primary path. Gi3 is the backup path and should only be used in the event that interface Gi1 can't reach 8.8.8.8. Once Gi1 has recovered reachability to 8.8.8.8, interface Gi3 should be shut down. The EEM script could be shortened and is intentionally longer so it's easier to read.**
<pre lang="...">
ip sla 100
icmp-echo 8.8.8.8 source-interface gi1
threshold 1000
frequency 15
ip sla schedule 100 life forever start-time now

track 60 ip sla 100 reachability
event manager applet Monitor-Google-DNS
event track 60 state down
action 1 cli command "enable"
action 2 cli command "configure terminal"
action 3 cli command "interface Gi3"
action 4 cli command "no shutdown"
action 5 cli command "end"
action 99 syslog msg "Activating backup interface"

Track 61 ip sla 100 reachability
Event manager app Enable-Backup-Interface-if-DNS-Down
event track 61 state up
action 1 cli command "enable"
action 2 cli command "configure terminal"
action 3 cli command "interface gi3"
action 4 cli command "shutdown"
action 5 cli command "end"
action 99 syslog msg "Reverting to primary link"
</pre>

**At this point tunnel 11 should be up over path 1. If you shut Gi1, Gi3 will come up and establish a tunnel + BGP. Enable interface Gi1, 8.8.8.8 becomes reachable, Gi3 will be shut down. If you see any BGP "collision" errors when bouncing between paths, clear ip bpp *.**
