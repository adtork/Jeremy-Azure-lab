## Expressroute Private Peering Quick Troubleshooting
This doc provides some quick troubleshooting ideas when dealing with Expressroute (ER). From a network perspective, you are often looking for key information for L1/L2/L3. All of the output from the commands are available in the Azure portal. However, finding this information could potentially be time consuming or difficult to interpret unless you are experienced with ER operations. Powershell 7 for Windows 10 is used for this lab but can also be done in Cloud Shell in the portal. The commands are shown individually and are purely a baseline for ideas that can be expanded on. I'm a network guy, not a Powershell expert, so I'm sure there are better ways to optimize the script. I've also provided all of the commands in a Powershell script (more details described later) saved in this repo so you can copy it and change the attributes. Before starting the lab, document the Subscription ID that owns the ER circuit, Resource Group and the name of the ER circuit.

Quick notes:

- ER ASN is always 12076
- A single ER circuit is comprised of 2 paths, Primary and Secondary
- 2x /30s are required and provided by the customer, Azure always takes the even numbererd IP out of the subnet
- ER terminates on the Microsoft edge routers and not in the VNET
- ER GWs build a connection to the ER "circuit" (technically it's the MSEEs)
- Communication between the ER GW and the MSEEs crosses the Microsoft Backbone



**WAN Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/er-wan-injection.PNG)

The topology above shows the CPE in private ASN 65001 and the MSEEs in ASN 12076. BGP peering is established between 172.16.1.1 and .2 as well as 172.16.2.1 and .2. 
On prem is advertising 10/8 to both peers. There is an existing connection between the ER GW in the VNET and the MSEE routers. At this point, on prem knows about the VNET address space and the VNET knows about 10/8. If you look at the VM effective route table, it will show 2 next hops for destination 10/8. The next hop will be both MSEEs. Please note that all inbound traffic to a VNET traverses the ER GW (except for Fastpath, seperate topic) and the responses will go directly to the MSEEs. Traffic
sourced from a VNET VM to destination 10/8 will go directly to the MSEEs and the ER GW is not in path. The responses back from on prem will go through the ER GW. By default, the 2 x/30s are not in the VM effective route table. 

**CPE device is a CSR with the key configurations below**
<pre lang="...">
interface Loopback200
 ip address 2.2.2.2 255.255.255.255
!
interface GigabitEthernet1
 ip address 192.168.1.1 255.255.255.0
 negotiation auto
!
interface GigabitEthernet2
 ip address 172.16.1.1 255.255.255.252
 negotiation auto
!
interface GigabitEthernet3
 ip address 172.16.2.1 255.255.255.252
 negotiation auto
!
router bgp 65100
 bgp log-neighbor-changes
 neighbor 172.16.1.2 remote-as 12076
 neighbor 172.16.2.2 remote-as 12076
 !        
 address-family ipv4
  network 2.2.2.2 mask 255.255.255.255
  network 172.16.1.0 mask 255.255.255.252
  network 172.16.2.0 mask 255.255.255.252
  network 192.168.1.0
  neighbor 172.16.1.2 activate
  neighbor 172.16.1.2 soft-reconfiguration inbound
  neighbor 172.16.1.2 prefix-list filter-primary out
  neighbor 172.16.2.2 activate
  neighbor 172.16.2.2 soft-reconfiguration inbound
  neighbor 172.16.2.2 prefix-list filter-secondary out
  maximum-paths 4
 exit-address-family
!                
ip prefix-list filter-primary seq 5 permit 2.2.2.2/32
ip prefix-list filter-primary seq 10 permit 192.168.1.0/24
ip prefix-list filter-primary seq 15 permit 172.16.2.0/30
!         
ip prefix-list filter-secondary seq 5 permit 2.2.2.2/32
ip prefix-list filter-secondary seq 10 permit 192.168.1.0/24
ip prefix-list filter-secondary seq 15 permit 172.16.1.0/30
</pre>

**Within Powershell, configure your variables (Sub ID, Resource Group, ER Circuit name). Replace XYZ with your subcription ID.
<pre lang="...">
# Variables
$SubID = 'XYZ'
$cktname = 'CIRCUIT_EQUINIX'
$RG = 'RG_US_W2_ER'
</pre>

**The lab is accessing a circuit I have access to in a seperate subscription. You may not need to do this step if the circuit is already in your subscription.**
<pre lang="...">
Get-AzSubscription -SubscriptionId $SubID | Out-Null
Set-AzContext -SubscriptionId $SubID | Out-Null
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
</pre>

**Validate circuit Name, Resource Group it is in, provisioning state and circuit provisioning state**
<pre lang="...">
Get-AzExpressRouteCircuit -Name $cktname -ResourceGroupName $RG | Select-Object Name,ResourceGroupName,ProvisioningState,CircuitProvisioningState | Format-Table" -ForegroundColor Green

##Output##
Name            ResourceGroupName ProvisioningState CircuitProvisioningState
----            ----------------- ----------------- ------------------------
CIRCUIT_EQUINIX RG_US_W2_ER       Succeeded         Enabled
</pre>

**Verify primary path ARP. MAC addresses listed should match on prem interfaces**
<pre lang="...">
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -PeeringType AzurePrivatePeering -DevicePath Primary | Format-Table

##Output##
Age InterfaceProperty IpAddress  MacAddress
--- ----------------- ---------  ----------
154 On-Prem           172.16.1.1 0050.56b4.d8aa
  0 Microsoft         172.16.1.2 f40f.1b7f.6670

##Validate MAC address on the CSR matches the output##
CISCO_ROUTER#sh arp gi2
Protocol  Address          Age (min)  Hardware Addr   Type   Interface
Internet  172.16.1.1              -   0050.56b4.d8aa  ARPA   GigabitEthernet2
Internet  172.16.1.2            156   f40f.1b7f.6670  ARPA   GigabitEthernet2
</pre>

**Verify secondary path ARP. MAC addresses listed should match on prem interfaces**
<pre lang="...">
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -PeeringType AzurePrivatePeering -DevicePath Secondary | Format-Table

##Output##
Age InterfaceProperty IpAddress  MacAddress
--- ----------------- ---------  ----------
 98 On-Prem           172.16.2.1 0050.56b4.7658
  0 Microsoft         172.16.2.2 5087.89fd.ca70

##Validate MAC address on the CSR matches the output##
CISCO_ROUTER#sh arp gi3
Protocol  Address          Age (min)  Hardware Addr   Type   Interface
Internet  172.16.2.1              -   0050.56b4.7658  ARPA   GigabitEthernet3
Internet  172.16.2.2            101   5087.89fd.ca70  ARPA   GigabitEthernet3
</pre>

**Get Azure ASN, defined on prem ASN and peering info**
<pre lang="...">
$ckt = Get-AzExpressRouteCircuit -Name $cktname -ResourceGroupName $RG
Get-AzexpressRouteCircuitPeeringConfig -Name "AzurePrivatePeering" -ExpressRouteCircuit $ckt | Select-Object AzureASN,PeerASN,PrimaryPeerAddressPrefix,SecondaryPeerAddressPrefix | Format-Table

##Output##
AzureASN PeerASN PrimaryPeerAddressPrefix SecondaryPeerAddressPrefix
-------- ------- ------------------------ --------------------------
   12076   65100 172.16.1.0/30            172.16.2.0/30
</pre>

**Validate peer on primary path in AS 65100(on prem), BGP uptime and the number of prefixes on prem is advertising**
<pre lang="...">
Get-AzExpressRouteCircuitRouteTableSummary -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Primary' -PeeringType AzurePrivatePeering | where-object {$_.AsProperty -eq “65100”} | Format-Table

##Output##
Neighbor   V AsProperty UpDown StatePfxRcd
--------   - ---------- ------ -----------
172.16.1.1 4      65100 1d13h  3
</pre>

**Validate peer on secondary path in AS 65100(on prem), BGP uptime and the number of prefixes on prem is advertising**
<pre lang="...">
Get-AzExpressRouteCircuitRouteTableSummary -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Secondary' -PeeringType AzurePrivatePeering | where-object {$_.AsProperty -eq “65100”} | Format-Table

##Output##
Neighbor   V AsProperty UpDown StatePfxRcd
--------   - ---------- ------ -----------
172.16.2.1 4      65100 1d13h  3
</pre>

**Validate what routes Azure is receiving from on prem on the Primary path**
<pre lang="...">
Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Primary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65100”} | Format-Table

##Output##
Network       NextHop    LocPrf Weight Path
-------       -------    ------ ------ ----
2.2.2.2/32    172.16.1.1             0 65100
172.16.2.0/30 172.16.1.1             0 65100
192.168.1.0   172.16.1.1             0 65100
</pre>

**Validate what routes Azure is receiving from on prem on the Secondary path**
<pre lang="...">
Get-AzexpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Secondary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65100”} | Format-Table

##Output##
Network       NextHop    LocPrf Weight Path
-------       -------    ------ ------ ----
2.2.2.2/32    172.16.2.1             0 65100
172.16.1.0/30 172.16.2.1             0 65100
192.168.1.0   172.16.2.1             0 65100
</pre>

**Validate what VNET address spaces are seen on the Primary path(router)**
<pre lang="...">
Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Primary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65515”} | Format-Table

##Output##
Network       NextHop      LocPrf Weight Path
-------       -------      ------ ------ ----
10.1.0.0/20   10.1.0.13                0 65515
10.1.0.0/20   10.1.0.12*               0 65515
10.1.16.0/20  10.1.0.13                0 65515
10.1.16.0/20  10.1.0.12*               0 65515
10.1.32.0/20  10.1.0.13                0 65515
10.1.32.0/20  10.1.0.12*               0 65515
10.1.48.0/20  10.1.0.13                0 65515
10.1.48.0/20  10.1.0.12*               0 65515
10.50.0.0/20  10.50.1.13               0 65515
10.50.0.0/20  10.50.1.12*              0 65515
10.50.16.0/20 10.50.1.12               0 65515
10.50.16.0/20 10.50.1.13*              0 65515
10.255.0.0/16 10.255.0.13              0 65515
10.255.0.0/16 10.255.0.12*             0 65515
</pre>

**Validate what VNET address spaces are seen on the Secondary path(router)**
<pre lang="...">
Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Secondary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65515”} | Format-Table

##Output##
Network       NextHop      LocPrf Weight Path
-------       -------      ------ ------ ----
10.1.0.0/20   10.1.0.13                0 65515
10.1.0.0/20   10.1.0.12*               0 65515
10.1.16.0/20  10.1.0.13                0 65515
10.1.16.0/20  10.1.0.12*               0 65515
10.1.32.0/20  10.1.0.13                0 65515
10.1.32.0/20  10.1.0.12*               0 65515
10.1.48.0/20  10.1.0.13                0 65515
10.1.48.0/20  10.1.0.12*               0 65515
10.50.0.0/20  10.50.1.12               0 65515
10.50.0.0/20  10.50.1.13*              0 65515
10.50.16.0/20 10.50.1.12               0 65515
10.50.16.0/20 10.50.1.13*              0 65515
10.255.0.0/16 10.255.0.12              0 65515
10.255.0.0/16 10.255.0.13*             0 65515
</pre>

**Validate paths are sending/receiving traffic**
<pre lang="...">
Get-AzExpressRouteCircuitStats -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -PeeringType 'AzurePrivatePeering'

##Output##
PrimaryBytesIn PrimaryBytesOut SecondaryBytesIn SecondaryBytesOut
-------------- --------------- ---------------- -----------------
    3223706647      3097076399       3233188734        3067851925
</pre>

The Powershell script to run all of these commands together is in this repo (ER-Basic-Troubleshooting.ps1) . Make sure to change the variables to match your environment. The script will log to the path you specify. As you can see at the top of the script, it logs the commands to your screen and writes the commands plus the output. Simply change "Start-Transcript -Path "C:\transcripts\transcript0.txt" to a different path if need. Example: download the Powershell script to your desktop, edit the file with your subscription id, ER circuit name and Resource group. Open Powershell and drag the script to the window to run it. 
