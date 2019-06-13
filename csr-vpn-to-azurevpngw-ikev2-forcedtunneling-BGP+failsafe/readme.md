# Azure Networking Lab- IPSEC VPN (IKEv2) between Cisco CSR and Azure VPN Gateway - BGP default route advertisement + fail-safe 

This lab guide illustrates how to build a basic IPSEC VPN tunnel w/IKEv2 between a Cisco CSR and the Azure VPN gateway with forced tunneling. Forced tunneling is an Azure term for steering a default route over VPN (this lab) or Expressroute (not this lab). The goal of this lab is for the Azure VM to traverse the IPSEC tunnel to the on prem CSR for all traffic including Internet while denying Internet if BGP is down. Key points with forced tunneling and the Azure VPN GW:

 - You can use User Defined Routes (UDR) or BGP to steer a default path over VPN
 - UDR or BGP method requires a route based VPN type
 - UDR method requires defining a "default site" on the Azure VPN GW. You have to configure this with Powershell or Azure CLI. Azure portal does not support this configuration at this point (we are using BGP in this lab)
 - Injecting a default route over VPN via BGP does not require you to define a default site
 - Do not apply a 0/0 UDR on the GatewaySubnet
 - Do not apply an NSG to the GatewaySubnet
 - Do not turn off BGP on the GatewaySubnet

VMs in a VNET have access to the Internet by default (0/0->Internet). At the end of this lab, the 2 VMs will be able to ping each other over the tunnel. The on prem VM will be able to access the Internet through NAT on the CSR. The Hub VM will also have Internet access by following the default route over the tunnel where the CSR will provide NAT. A layered Network Security Group (NSG) will be used to deny Internet if BGP is down. A default route with a UDR with next hop "none" will not solve this problem since it will win the tie break vs the default route advertised by BGP.

All lab configs are done in Azure CLI so you can change them as needed to match your environment. There is no hardware reuored for this lab. The layered NSGs will be configured through the portal as it's easier to visual.

Assumptions:
- A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- Latest Azure CLI, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli 
- Fundamental Azure networking knowledge

# Base Topology
The lab deploys an Azure VPN gateway into a VNET. We will also deploy a Cisco CSR in a seperate VNET to simulate on prem.
![alt text](https://github.com/jwrightazure/lab/blob/master/images/csrvpnikev2.png)

**Build Resource Groups, VNETs and Subnets for the Azure Hub VNET**
<pre lang="...">
az group create --name Hub --location eastus
az network vnet create --resource-group Hub --name Hub --location eastus --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.0.0/24 --name GatewaySubnet --resource-group Hub --vnet-name Hub
</pre>

**Build Resource Groups, VNETs and Subnets for the VNET that simulates on prem**
<pre lang="...">
az group create --name onprem --location eastus2
az network vnet create --resource-group onprem --name onprem --location eastus2 --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group onprem --vnet-name onprem
</pre>

**Create basic NSGs for the CSR. You can modify these as needed**
<pre lang="...">
az network nsg create --resource-group onprem --name onprem-CSR-NSG --location eastus2
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-192 --access Allow --protocol "*" --direction Inbound --priority 135 --source-address-prefix 192.168.0.0/16 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
</pre>

**Create a public IP address, NICs and CSR VM**
<pre lang="...">
az network public-ip create --name CSR1PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface -g onprem --subnet zeronet --vnet onprem --public-ip-address CSR1PublicIP --private-ip-address 10.1.0.4 --ip-forwarding true --network-security-group onprem-CSR-NSG
az network nic create --name CSR1InsideInterface -g onprem --subnet onenet --vnet onprem --ip-forwarding true --private-ip-address 10.1.1.4 --network-security-group onprem-CSR-NSG
az vm create --resource-group onprem --location eastus2 --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108 --admin-username azureuser --admin-password Msft123Msft123 --no-wait
</pre>

**Create a route table for the on prem VNET and point the default route to the CSR inside interface. Note- you may need to update the route table to point your SSH SIP to next hop Internet**
<pre lang="...">
az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network vnet subnet update --name VM --vnet-name onprem --resource-group onprem --route-table vm-rt
</pre>

**Document the CSR public IP**
<pre lang="...">
az network public-ip show -g onprem -n CSR1PublicIP --query "{address: ipAddress}"
</pre>

**Create a public IP address and local gateway (this is the CSR). Make sure to replace "CSR1PublicIP" with the correct IP. The 192. address will be the tunnel IP on the CSR. The CSR wukk be in BGP ASN 65002.**
<pre lang="...">
az network public-ip create --name Azure-VNGpubip --resource-group Hub --allocation-method Dynamic
az network local-gateway create --gateway-ip-address CSR1PublicIP --name to-onprem --resource-group Hub --local-address-prefixes 192.168.1.1/32 --asn 65002 --bgp-peering-address 192.168.1.1
</pre>


**Create the Azure VPN GW and define the default site. It will take 15-30 minutes for this process to complete.**
<pre lang="...">
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group Hub --vnet Hub --gateway-type Vpn --vpn-type RouteBased --sku VpnGw1 --no-wait --asn 65001
</pre>

**Do not move on in the lab until the Azure VPN GW shows a public IP address. The VPN GW is still provisioning if the value is null**
<pre lang="...">
az network public-ip show -g Hub -n Azure-VNGpubip --query "{address: ipAddress}"
</pre>

**Document the VPN Gateway BGP information**
<pre lang="...">
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group Hub
</pre>

**Define the connection and bind it to the Azure VPN GW**
<pre lang="...">
az network vpn-connection create --name to-onprem --resource-group Hub --vnet-gateway1 Azure-VNG -l eastus --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp
</pre>

**SSH to the CSR and paste in configs. Be sure to change the "Azure-VNGpubip" to the public IP address of the VPN GW**
<pre lang="...">
!route for simulate on prem vm
ip route 10.1.10.0 255.255.255.0 10.1.1.1

access-list 100 deny   ip 10.1.10.0 0.0.0.255 10.0.10.0 0.0.0.255
access-list 100 deny   ip 10.0.10.0 0.0.0.255 10.1.10.0 0.0.0.255
access-list 100 permit ip 10.1.10.0 0.0.0.255 any
access-list 100 permit ip 10.0.10.0 0.0.0.255 any

ip nat inside source list 100 interface GigabitEthernet1 overload
ip nat inside source list GS_NAT_ACL interface GigabitEthernet1 vrf GS overload

interface GigabitEthernet1
ip nat outside

interface GigabitEthernet2
ip nat inside

crypto ikev2 proposal to-onprem-proposal
  encryption aes-cbc-256
  integrity  sha1
  group      2
  exit

crypto ikev2 policy to-onprem-policy
  proposal to-onprem-proposal
  match address local 10.1.0.4
  exit
  
crypto ikev2 keyring to-onprem-keyring
  peer Azure-VNGpubip
    address Azure-VNGpubip
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-onprem-profile
  match address  local 10.1.0.4
  match identity remote address Azure-VNGpubip 255.255.255.255
  authentication remote pre-share
  authentication local  pre-share
  lifetime       3600
  dpd 10 5 on-demand
  keyring local  to-onprem-keyring
  exit

crypto ipsec transform-set to-onprem-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-onprem-IPsecProfile
  set transform-set  to-onprem-TransformSet
  set ikev2-profile  to-onprem-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.1 255.255.255.255
  ip nat inside
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.1.0.4
  tunnel destination Azure-VNGpubip
  tunnel protection ipsec profile to-onprem-IPsecProfile
  exit

router bgp 65002
  bgp      log-neighbor-changes
  neighbor 10.0.0.254 remote-as 65001
  neighbor 10.0.0.254 ebgp-multihop 255
  neighbor 10.0.0.254 update-source tunnel 11

  address-family ipv4
    neighbor 10.0.0.254 default-originate
    neighbor 10.0.0.254 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 10.0.0.254 255.255.255.255 Tunnel 11
</pre>

**Build test VM on the Azure side. Note- this VM will have Internet access over the tunnel. If the tunnel fails, Internet access will go out the local Azure Internet path**
<pre lang="...">
az network nsg create --resource-group Hub --name Azure-VM-NSG --location EastUS
az network nsg rule create --resource-group Hub --nsg-name Azure-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group Hub --nsg-name Azure-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network public-ip create --name AzureVMPubIP --resource-group Hub --location EastUS --allocation-method Dynamic
az network nic create --resource-group Hub -n AzureVMNIC --location EastUS --subnet HubVM --private-ip-address 10.0.10.10 --vnet-name Hub --public-ip-address AzureVMPubIP --network-security-group Azure-VM-NSG --ip-forwarding true
az vm create -n AzureVM -g Hub --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics AzureVMNIC --no-wait
</pre>

**Build test VM on the onprem side. Note- this VM will have Internet access over the tunnel.**
<pre lang="...">
az network nsg create --resource-group onprem --name onprem-VM-NSG --location EastUS2
az network nsg rule create --resource-group onprem --nsg-name onprem-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group onprem --nsg-name onprem-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network public-ip create --name onpremVMPubIP --resource-group onprem --location EastUS2 --allocation-method Dynamic
az network nic create --resource-group onprem -n onpremVMNIC --location EastUS2 --subnet VM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --network-security-group onprem-VM-NSG --ip-forwarding true
az vm create -n onpremVM -g onprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait
</pre>


Verification before layered NSG:
  - On prem should be able to ping the Azure VM 10.0.10.10
  - Azure VM should be able to ping the on prem VM 10.1.10.10
  - On prem should be able to ping 8.8.8.8. CSR providing outbound Internet connectivity
  - Azure VM should be able to ping 8.8.8.8. Traffic will follow the default route over the tunnel. CSR providing outbound Internet connectivity
  - Validate effective route table on Azure VM shows a default route pointed to the Azure VPN GW (displayed as Virtual Network Gateway)
  - Validate effective route table on on prem VM shows a default route pointed to the CSR inside interface (displayed as virtual appliance 10.1.1.4)

![alt text](https://github.com/jwrightazure/lab/blob/master/images/rt1.png)


Azure Internet:
  - Shut down tunnel 11 on the CSR which will stop the advertisement of 0/0
![alt text](https://github.com/jwrightazure/lab/blob/master/images/rt2.png)
  - Verify Azure VM is going out local Internet
  - After verifying local Internet, enable tunnel 11 on the CSR. Internet will now go over the tunnel

Configure layered NSGs to stop Internet access for the Azure VM when BGP is down:
  - Locate the NSG configured for the Auze VM "Azure-VM-NSG". Note it allows Internet access by default
![alt text](https://github.com/jwrightazure/lab/blob/master/images/nsg1.png)
 
  - Configured outbound layered NSG"
![alt text](https://github.com/jwrightazure/lab/blob/master/images/nsg2.png)
![alt text](https://github.com/jwrightazure/lab/blob/master/images/nsg3.png)
![alt text](https://github.com/jwrightazure/lab/blob/master/images/nsg4.png)

  - Shut down tunnel 11 on the CSR which will stop the advertisement of 0/0
  - Internet access will now be denied





