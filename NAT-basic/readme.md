## Basic NAT Labs
Basic Cisco configs convering PAT, NAT pools, and VRF aware NAT. 

## Base Topology- PAT
R1 BGP peers with R2, R2 peers with R1 and C8k, C8k peers with R2. R1 advertises the 192.168.0.0/24 into BGP since we are NATing (PAT) to interface e0/0.10 192.168.0.1. C8k is avertising 2.2.2.2/32. Any traffic that is sourced from 10.0.0.0/8 arriving on e0/1 or loopback100 (test interface) of R1 will be tranlated to the interface IP. When the PC sends traffic to 2.2.2.2, C8k will see the source as 192.168.0.1. C8k will use the Embedded Packet Capture feature for verification.

![alt text](https://github.com/jwrightazure/lab/blob/master/NAT-basic/PAT-topo.drawio.png)

**Configs**<br/>
<pre lang="...">
R1:
interface Loopback100
 description test-interface
 ip address 10.2.2.2 255.255.255.0
 ip nat inside
!
interface Ethernet0/0.10
 encapsulation dot1Q 10
 ip address 192.168.0.1 255.255.255.0
 ip nat outside
!
interface Ethernet0/1
 ip address 10.1.1.1 255.255.255.0
 ip nat inside
!
ip nat inside source list nat interface Ethernet0/0.10 overload
!
ip access-list extended nat
 deny   ip 192.168.0.0 0.0.0.255 192.168.0.0 0.0.0.255
 permit ip 10.0.0.0 0.255.255.255 any
!
ip prefix-list msft-peering seq 10 permit 192.168.0.0/24
router bgp 65001
 bgp log-neighbor-changes
 network 192.168.0.0
 neighbor 192.168.0.2 remote-as 12076
 neighbor 192.168.0.2 prefix-list msft-peering out

R2:
interface Ethernet0/0.10
 encapsulation dot1Q 10
 ip address 192.168.0.2 255.255.255.0
!
interface Ethernet0/1
 ip address 192.168.1.1 255.255.255.0
!
router bgp 12076
 bgp log-neighbor-changes
 neighbor 192.168.0.1 remote-as 65001
 neighbor 192.168.1.2 remote-as 1
 neighbor 192.168.1.2 prefix-list msft-peering out
!
ip prefix-list msft-peering seq 10 permit 192.168.0.0/24

C8k:
interface Loopback0
 ip address 2.2.2.2 255.255.255.255
!
interface GigabitEthernet1
 ip address 192.168.1.2 255.255.255.0
!
router bgp 1
 bgp log-neighbor-changes
 network 2.2.2.2 mask 255.255.255.255
 neighbor 192.168.1.1 remote-as 12076
</pre>

**Enable Embedded Pacet Capture on C8kv. Including the clear monitor command as a reference.**
<pre lang="...">
monitor capture TEST interface GigabitEthernet 1 both match any start
mon cap TEST clear
</pre>

**Initiate ping from R1's test loopback as the source or from the VM 10.1.1.10**
<pre lang="...">
C8k#show mon cap TEST buffer brief
 ----------------------------------------------------------------------------
 #   size   timestamp     source             destination      dscp    protocol
 ----------------------------------------------------------------------------
   0  114    0.000000   192.168.0.1      ->  2.2.2.2          0  BE   ICMP
   1  114    0.000991   2.2.2.2          ->  192.168.0.1      0  BE   ICMP
   2  114    0.000991   192.168.0.1      ->  2.2.2.2          0  BE   ICMP
   3  114    0.000991   2.2.2.2          ->  192.168.0.1      0  BE   ICMP
   4  114    0.001998   192.168.0.1      ->  2.2.2.2          0  BE   ICMP
   5  114    0.001998   2.2.2.2          ->  192.168.0.1      0  BE   ICMP
   6  114    0.001998   192.168.0.1      ->  2.2.2.2          0  BE   ICMP
   7  114    0.001998   2.2.2.2          ->  192.168.0.1      0  BE   ICMP
   8  114    0.002990   192.168.0.1      ->  2.2.2.2          0  BE   ICMP
   9  114    0.002990   2.2.2.2          ->  192.168.0.1      0  BE   ICMP


##Validate NAT translations on R1

r1#sh ip nat trans
Pro Inside global      Inside local       Outside local      Outside global
icmp 192.168.0.1:17984 10.1.1.10:17984    2.2.2.2:17984      2.2.2.2:17984
</pre>

## Base Topology- NAT POOL
Same topology as above except R1 will have a NAT pool 1.1.1.0/30 instead of interface PAT. R1 will advertise 1.1.1.0/30 into BGP instead of 192.168.0.0/24. Traffic sourced from 10/8 to 2.2.2.2 will appear as SIP 1.1.1.1 or .2 on C8k.

![alt text](https://github.com/jwrightazure/lab/blob/master/NAT-basic/NAT-pool-lab1-topo.drawio.png)


**Configs**<br/>
<pre lang="...">
R1:
interface Loopback100
 ip address 10.2.2.2 255.255.255.0
 ip nat inside
!
interface Ethernet0/0.10
 encapsulation dot1Q 10
 ip address 192.168.0.1 255.255.255.0
 ip nat outside
!
interface Ethernet0/1
 ip address 10.1.1.1 255.255.255.0
 ip nat inside
!
router bgp 65001
 bgp log-neighbor-changes
 network 1.1.1.0 mask 255.255.255.252
 neighbor 192.168.0.2 remote-as 12076
 neighbor 192.168.0.2 prefix-list msft-peering out

ip nat pool nat 1.1.1.1 1.1.1.2 netmask 255.255.255.252
ip nat inside source list nat pool nat
ip route 1.1.1.0 255.255.255.252 Null0
!
ip access-list extended nat
 deny   ip 192.168.0.0 0.0.0.255 192.168.0.0 0.0.0.255
 permit ip 10.0.0.0 0.255.255.255 any
!
ip prefix-list msft-peering seq 5 permit 1.1.1.0/30
</pre>

**Enable Embedded Pacet Capture on C8kv. Including the clear monitor command as a reference.**
<pre lang="...">
monitor capture TEST interface GigabitEthernet 1 both match any start
mon cap TEST clear
</pre>

**Initiate ping from R1's test loopback as the source or from the VM 10.1.1.10**
<pre lang="...">
C8k#sho mon cap TEST buffer brief 
 ----------------------------------------------------------------------------
 #   size   timestamp     source             destination      dscp    protocol
 ----------------------------------------------------------------------------
   0  114    0.000000   1.1.1.1          ->  2.2.2.2          0  BE   ICMP
   1  114    0.000992   2.2.2.2          ->  1.1.1.1          0  BE   ICMP
   2  114    0.000992   1.1.1.1          ->  2.2.2.2          0  BE   ICMP
   3  114    0.001999   2.2.2.2          ->  1.1.1.1          0  BE   ICMP


##Validate NAT translations on R1
r1#sh ip nat translations 
Pro Inside global      Inside local       Outside local      Outside global
icmp 1.1.1.1:6         10.2.2.2:6         2.2.2.2:6          2.2.2.2:6
</pre>

## Base Topology- VRF Aware NAT Pool
This section is the same as NAT pool section with the addition of VRF customer1.

![alt text](https://github.com/jwrightazure/lab/blob/master/NAT-basic/NAT-pool-lab1-topo.drawio.png)

**Configs**<br/>
<pre lang="...">
R1:
ip vrf customer1
 rd 65001:1

interface Loopback100
 ip vrf forwarding customer1
 ip address 10.2.2.2 255.255.255.0
 ip nat inside
!
interface Ethernet0/0.10
 encapsulation dot1Q 10
 ip vrf forwarding customer1
 ip address 192.168.0.1 255.255.255.0
 ip nat outside
!
interface Ethernet0/1
 ip vrf forwarding customer1
 ip address 10.1.1.1 255.255.255.0
 ip nat inside
!
router bgp 65001
 bgp router-id vrf auto-assign
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf customer1
  bgp router-id 10.2.2.2
  network 1.1.1.0 mask 255.255.255.252
  neighbor 192.168.0.2 remote-as 12076
  neighbor 192.168.0.2 activate
  neighbor 192.168.0.2 prefix-list msft-peering out
 exit-address-family
!
ip nat pool nat 1.1.1.1 1.1.1.2 netmask 255.255.255.252
ip nat inside source list nat pool nat vrf customer1
ip route vrf customer1 1.1.1.0 255.255.255.252 Null0
!
ip access-list extended nat
 deny   ip 192.168.0.0 0.0.0.255 192.168.0.0 0.0.0.255
 permit ip 10.0.0.0 0.255.255.255 any
!         
ip prefix-list msft-peering seq 5 permit 1.1.1.0/30
ip prefix-list msft-peering seq 10 permit 192.168.0.0/24
</pre>
## Basic NAT Outside Source Lab
This lab provides sample configurations when using the "ip nat outside source list" command. IP NAT outside is used to translate the source address of the IP packets that travel through the outside interface defined in NAT to an IP (specific IP in this lab) on the inside of the NAT "zone". The goal is for R2 to NAT traffic when the SIP is R1's loopback address and the DIP is R3's loopback. All other traffic should not be NAT'd. All networks are advertised in OSPF area 0.

## Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/basic-NAT-lab/nat-lab-topo.PNG)

**Order of operations**<br/>
When traffic is sourced from R1's loopback to R3's loopback:

R1 and R3 are learning a default route from R2 via the "default-information originate always" command.  R1 sends traffic sourcing from the loopback 0 (1.1.1.1) to R3's loopback (3.3.3.3). The traffic will arrive on the "outside" interface of R2 with a SIP of 1.1.1.1 and a DIP of 3.3.3.3. The SIP is referenced/permitted in access-list 1 and is used by the "ip nat outside source" list command. It is then translated to an address from the NAT pool Net10.
The SIP will be translated to 10.10.10.10 which is the first available address in the NAT pool. 

R3 sees the packet on its incoming interface with a SIP of 10.10.10.10 and a DIP of 3.3.3.3. R3 will send the response to its default route (R2) since 10.10.10.x is not advertised into OSPF. The response from R3 will have a SIP of 3.3.3.3 and a DIP of 10.10.10.10. The "add-route" NAT config adds a host route based on the translation between the outside global and outside local address. Traffic will not flow correctly between NAT interfaces without this command in this particular scenario. If traffic sources from a different interface of R1 to DIP 3.3.3.3, no NAT will occur since the SIP/network is not referenced in the NAT ACL.

**Configs**<br/>
<pre lang="...">
R1:
interface Loopback0
 ip address 1.1.1.1 255.255.255.255
!
interface GigabitEthernet0/0
 ip address 10.1.1.1 255.255.255.0
!
router ospf 1
 network 0.0.0.0 255.255.255.255 area 0
 
---------------------------------------------
R2:
interface GigabitEthernet0/0
 ip address 10.1.1.2 255.255.255.0
 ip nat outside
 
interface GigabitEthernet0/1
 ip address 10.2.2.2 255.255.255.0
 ip nat inside
!
router ospf 1
 network 0.0.0.0 255.255.255.255 area 0
 default-information originate always

ip nat pool Net10 10.10.10.10 10.10.10.20 netmask 255.255.255.0
ip nat outside source list 1 pool Net10 add-route
!
access-list 1 permit 1.1.1.1

---------------------------------------------
R3:
interface Loopback0
 ip address 3.3.3.3 255.255.255.255
!
interface GigabitEthernet0/0
 ip address 10.2.2.3 255.255.255.0
!
router ospf 1
 network 0.0.0.0 255.255.255.255 area 0

</pre>

