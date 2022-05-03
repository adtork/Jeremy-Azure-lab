# Azure Networking Lab- UDR Service Tags

This lab guide illustrates how to test UDR Service Tags. The environment includes a site to site tunnel (via Cisco CSR) from a simulated on premises network terminating on an Azure VPN GW. The CSR is injecting 0/0 over the tunnel to simulate forced tunneling which can be done over S2S tunnels or Expressroute. The Azure Hub vm will traverse the S2S tunnel and be NAT'd by the CSR out to the Internet. The lab also includes a Palo Alto firewall servicing the Azure side Hub VNET. The firewall has an untrust and a trust interface. The inital flow for outbound Internet is the Azure side vm has a 0/0 UDR pointed to the firewall trust interface. The firewall is allowing all 10/8 and provides NAT. The firewall has a default route of the fabric, the fabric sees the next hop of 0/0 as the VPN GW since the CSR is advertising 0/0 over the tunnel. Towards the end of this lab, we will add a web server in Azure West. Before you implement the UDR with Service Tags, the web server will see the CSR public IP as the source since it's advertising 0/0 and provides NAT. After implementing the UDR Service Tag, traffic sourced from the Hub vm will go to PAN, PAN will follow it's default route out the untrust interface to the fabric, the fabric will then see all of the public IPs associated with Azure West with next hop Internet. The web server will now see traffic source from the Hub vm with a source IP of the PAN untrust public IP. Traffic sourced from the Hub vm to anything on the Internet, besides public IPs of Azure West, will continue to flow over the tunnel and use the CSR.  This is for lab testing purposes only. All Azure configs are done in Azure CLI so you can change them as needed to match your environment. The entire lab including simulated on prem is done in Azure. No hardware required. Current CSR image used is 17.3.4a. CSR will be managed via SSH from the on premises vm. All vm username/passwords are azureuser/Msft123Msft123

**Before deploying CSR in the next step, you may have to accept license agreement for Cisco and PAN unless you have used it before. You can accomplish this through deploying a CSR in the portal or Azure CLI commands via Cloudshell**
<pre lang="...">
az vm image terms accept --urn cisco:cisco-csr-1000v:17_3_4a-byol:latest
az vm image terms accept --urn paloaltonetworks:vmseries1:byol:latest
</pre>

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/service-tag-udr-topo.PNG)

**Set your variables. Make sure to change "sourceIP" to the public IP you are sourcing traffic from EX: SSH to the vms**
<pre lang="...">
##Variables##
RG="UDR-Service-Tag-RG"
Location="eastus"
hubname="hub"
location2="westus"
sourceIP="x.x.x.x/32"
</pre>


**Create Hub VNET, PAN FW, Azure VPN GW and Hub vm.**
<pre lang="...">
az group create --name UDR-Service-Tag-RG --location $Location
az network vnet create --resource-group $RG --name $hubname --location $Location --address-prefixes 10.0.0.0/16 --subnet-name HubVM --subnet-prefix 10.0.10.0/24
az network vnet subnet create --address-prefix 10.0.100.0/24 --name GatewaySubnet --resource-group $RG --vnet-name $hubname
az network vnet subnet create --address-prefix 10.0.0.0/24 --name zeronet --resource-group $RG --vnet-name $hubname
az network vnet subnet create --address-prefix 10.0.1.0/24 --name onenet --resource-group $RG --vnet-name $hubname
az network vnet subnet create --address-prefix 10.0.2.0/24 --name twonet --resource-group $RG --vnet-name $hubname

# Create a Palo Alto firewall in the hub VNET
az network public-ip create --name PAN1MgmtIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network public-ip create --name PAN-Outside-PublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name PAN1MgmtInterface --resource-group $RG --subnet twonet --vnet-name $hubname --public-ip-address PAN1MgmtIP --private-ip-address 10.0.2.4 --ip-forwarding true
az network nic create --name PAN1OutsideInterface --resource-group $RG --subnet zeronet --vnet-name $hubname --public-ip-address PAN-Outside-PublicIP --private-ip-address 10.0.0.4 --ip-forwarding true
az network nic create --name PAN1InsideInterface --resource-group $RG --subnet onenet --vnet-name $hubname --private-ip-address 10.0.1.4 --ip-forwarding true
az vm create --resource-group $RG --location $Location --name PAN --size Standard_D3_v2 --nics PAN1MgmtInterface PAN1OutsideInterface PAN1InsideInterface  --image paloaltonetworks:vmseries1:byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait

# Create Azure VPN GW in the hub
az network public-ip create --name Azure-VNGpubip --resource-group $RG --allocation-method Dynamic
az network vnet-gateway create --name Azure-VNG --public-ip-address Azure-VNGpubip --resource-group $RG --vnet $hubname --gateway-type Vpn --vpn-type RouteBased --sku VpnGw3 --no-wait --asn 65001

# Create test VM in the hub and on premises
az network public-ip create --name HubVMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n AzureVMNIC --location $Location --subnet HubVM --private-ip-address 10.0.10.10 --vnet-name $hubname --public-ip-address HubVMPubIP --ip-forwarding true
az vm create -n HubVM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics AzureVMNIC --no-wait

# Create route table for hub VM with next hop PAN Trust
az network route-table create --name Hub-rt --resource-group $RG
az network route-table route create --name Default --resource-group $RG --route-table-name Hub-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.1.4
az network route-table route create --name Source-IP-rt --resource-group $RG --route-table-name Hub-rt --address-prefix $sourceIP --next-hop-type Internet
</pre>

**Create a VNET to simulate on premises, CSR and on premises vm.**
<pre lang="...">
az network vnet create --resource-group $RG --name onprem --location $Location --address-prefixes 10.1.0.0/16 --subnet-name VM --subnet-prefix 10.1.10.0/24
az network vnet subnet create --address-prefix 10.1.0.0/24 --name zeronet --resource-group $RG --vnet-name onprem
az network vnet subnet create --address-prefix 10.1.1.0/24 --name onenet --resource-group $RG --vnet-name onprem

# Create a CSR to be used to connect to the VPN GW
az network public-ip create --name CSR1PublicIP --resource-group $RG --idle-timeout 30 --allocation-method Static
az network nic create --name CSR1OutsideInterface --resource-group $RG --subnet zeronet --vnet onprem --public-ip-address CSR1PublicIP --private-ip-address 10.1.0.4 --ip-forwarding true 
az network nic create --name CSR1InsideInterface --resource-group $RG --subnet onenet --vnet onprem --ip-forwarding true --private-ip-address 10.1.1.4
az vm create --resource-group $RG --location $Location --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface --image cisco:cisco-csr-1000v:17_3_4a-byol:latest --admin-username azureuser --admin-password Msft123Msft123 --no-wait

# Create route table for on premises
az network route-table create --name vm-rt --resource-group $RG
az network route-table route create --name vm-rt --resource-group $RG --route-table-name vm-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address 10.1.1.4
az network route-table route create --name Source-IP-rt  --resource-group $RG --route-table-name vm-rt --address-prefix $sourceIP --next-hop-type Internet

# Create on premises vm
az network public-ip create --name onpremVMPubIP --resource-group $RG --location $Location --allocation-method Dynamic
az network nic create --resource-group $RG -n onpremVMNIC --location $Location --subnet VM --private-ip-address 10.1.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --ip-forwarding true
az vm create -n onpremVM --resource-group $RG --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait
</pre>

**Create a route table for your source IP to be able to access PAN's management interface. Otherwise it will follow 0/0 advertised from on premises.**
<pre lang="...">
az network route-table create --name PAN-mgmt-rt --resource-group $RG
az network route-table route create --resource-group $RG --route-table-name PAN-mgmt-rt -n Source-IP --address-prefix $sourceIP --next-hop-type Internet
</pre>

**Document public IPs for the VPN GW and CSR. Do not continue until you see an IP address associated with the VPN GW. This could take 15-20min.**
<pre lang="...">
az network public-ip show --resource-group $RG -n Azure-VNGpubip --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show --resource-group $RG -n onpremVMPubIP --query "{address: ipAddress}"
</pre>

**Update route tables. This is intentionally placed here due to timing of resources being provisioned in this lab.**
<pre lang="...">
az network vnet subnet update --name HubVM --vnet-name $hubname --resource-group $RG --route-table Hub-rt
az network vnet subnet update --name twonet --vnet-name $hubname --resource-group $RG --route-table PAN-mgmt-rt
az network vnet subnet update --name VM --vnet-name onprem --resource-group $RG --route-table vm-rt
</pre>

**Create the Local Network Gateway and Connection for the VPN connection to the CSR. Change "CSR1PublicIP" to the CSR public IP.**
<pre lang="...">
az network local-gateway create --gateway-ip-address "CSR1PublicIP" --name to-onprem --resource-group $RG --local-address-prefixes 192.168.1.1/32 --asn 65002 --bgp-peering-address 192.168.1.1

az network vpn-connection create --name to-onprem --resource-group $RG --vnet-gateway1 Azure-VNG -l $Location --shared-key Msft123Msft123 --local-gateway2 to-onprem --enable-bgp

# Verify BGP information on the VPN GW
az network vnet-gateway list --query [].[name,bgpSettings.asn,bgpSettings.bgpPeeringAddress] -o table --resource-group $RG
</pre>

**SSH to the onpremises vm. From there, SSH to azureuser@10.1.1.4 and paste in the following configuration AFTER changing "Azure-VNGpubip" to the VPN GW public IP. This will build a S2S tunnel to the VPN GW with BGP over IPSEC. The CSR will be injecting a default route into BGP and provide NAT services. Traffic sourced from the hub VNET will flow over the tunnel to the CSR and be NATd to the public IP address of the CSR.**

<pre lang="...">
ip route 10.1.10.0 255.255.255.0 10.1.1.1

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

access-list 100 deny   ip 10.1.10.0 0.0.0.255 10.0.10.0 0.0.0.255
access-list 100 deny   ip 10.0.10.0 0.0.0.255 10.1.10.0 0.0.0.255
access-list 100 permit ip 10.0.0.0 0.255.255.255 any


ip nat inside source list 100 interface GigabitEthernet1 overload
ip nat inside source list GS_NAT_ACL interface GigabitEthernet1 vrf GS overload

router bgp 65002
  bgp      log-neighbor-changes
  neighbor 10.0.100.254 remote-as 65001
  neighbor 10.0.100.254 ebgp-multihop 255
  neighbor 10.0.100.254 update-source tunnel 11

  address-family ipv4
    neighbor 10.0.100.254 default-originate
    neighbor 10.0.100.254 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 10.0.100.254 255.255.255.255 Tunnel 11
</pre>

**Document PAN's public IP for management and follow the below steps to configure PAN. The XML file provides basic configurations for interfaces, security policies, NAT and Virtual Router.**
<pre lang="...">
az network public-ip show --resource-group $RG -n PAN1MgmtIP --query "{address: ipAddress}"

**Firewall configuration**
- Download the firewall configuration XML in this repo. https://github.com/jwrightazure/lab/blob/master/UDR-Service-Tag/pan-udr-service-tag-final.xml
- HTTPS to the firewall management IP.
- Select Device tab
- Select Operations tab
- Select Import Named Configuration Snapshot. Upload the .xml file your downloaded from this repo.
- Select Load Named Configuration Snapshot. Select the firewall XML you previously uploaded.
- Select Commit (top right) and then commit the configuration
</pre>

**Create a VNET and web server in Azure West. The NSGs created allow port 80 and 22.**
<pre lang="...">
az network vnet create --name VNET --resource-group $RG --address-prefix 10.0.0.0/16 --subnet-name web --subnet-prefix 10.0.0.0/24 --location $location2

# Create NSG allowing any source to hit the web server on port 80 and SSH
az network nsg create --resource-group $RG --name web-nsg --location $location2
az network nsg rule create --resource-group $RG --nsg-name web-nsg --name allow-web --access Allow --protocol Tcp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 80 
az network nsg rule create --resource-group $RG --nsg-name web-nsg --name allow-ssh --access Allow --protocol Tcp --direction Inbound --priority 200 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22 

# Create a new virtual machine 
az network public-ip create --name Web-PubIP --resource-group $RG --location $location2 --allocation-method Static
az network nic create --name webserverNIC --resource-group $RG --subnet web --vnet VNET --public-ip-address Web-PubIP --ip-forwarding true --location $location2 --network-security-group web-nsg
az vm create --resource-group $RG --name mywebserver --image UbuntuLTS --location $location2 --admin-username azureuser --admin-password Msft123Msft123 --nics webserverNIC

# Use CustomScript extension to install NGINX.
az vm extension set \
  --publisher Microsoft.Azure.Extensions \
  --version 2.0 \
  --name CustomScript \
  --vm-name mywebserver \
  --resource-group $RG \
  --settings '{"commandToExecute":"apt-get -y update && apt-get -y install nginx"}'
</pre>

**Document web server IP and test connectivityfrom your local browser. Also document the Hub vm.**
<pre lang="...">
az network public-ip show --resource-group $RG -n Web-PubIP --query "{address: ipAddress}" --output tsv
az network public-ip show --resource-group $RG -n HubVMPubIP --query "{address: ipAddress}"
</pre>

**SSH to the web server. Enable TCP for inbound port 80 requests (minus internal Azure management communication)**
<pre lang="...">
sudo tcpdump -i eth0 -nn -s0 -v port 80 and host not 168.63.129.16
</pre>

**SSH to the Hub vm. Curl ipconfig.io. The source IP address in the output of the tcpdump will be the CSR public IP.**
<pre lang="...">
az network public-ip show --resource-group $RG -n CSR1PublicIP --query "{address: ipAddress}"
</pre>

**Change the route table associated with the PAN untrust interface to route the service tag of Azure West US with next hop Internet. PAN OS only has a default route pointing 0/0 out its untrust interface(10.0.0.4/24) with next hop of the fabric(10.0.0.1/24). After adding the UDR, the fabric will route traffic directly out its untrust interface, NATd to it's public IP and out the Azure backbone. After adding the UDR, the web server will see the PAN untrust public IP as the source.**

<pre lang="...">
az network route-table create --name Service-Tag-rt --resource-group $RG
az network route-table route create --resource-group $RG --route-table-name Service-Tag-rt -n Azure-West --address-prefix AzureCloud.westus --next-hop-type Internet
az network vnet subnet update --name zeronet --vnet-name $hubname --resource-group $RG --route-table Service-Tag-r
</pre>
