# Azure Networking Lab- Expressroute- VRF Lite + BGP
This lab guide shows how to enable VRF lite and Bidirectional Forwarding Detection (BFD) protocol for Expressroute. BFD is a detection protocol that is designed to provide fast path failure detection times. A traditional single Expressroute circuit has 2 physical paths (A and B) between the provider and the Microsoft edge routers (MSEE). BFD for Expressroute provides significantly faster failover times vs relying on BGP reconvergence. This lab simulates a L2 circuit and you have switched the appropriate VLANs.

Notes:
-BFD is enabled by default on all new private peering circuits
-You can enable BFD on an existing ER circuit by resetting (not destroying) your circuit on the Azure side
-Verify your edge termination device supports BFD enabled BGP

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/vrf%20lite%20and%20bfd.PNG)

**CE configs for VRF Lite and BFD enabled BGP**
<pre lang="...">
ip vrf private-peering
 rd 10:1

interface Loopback0
 ip vrf forwarding private-peering
 ip address 1.1.1.1 255.255.255.255
!
interface GigabitEthernet1
 ip vrf forwarding private-peering
 ip address 10.1.1.1 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
!
interface GigabitEthernet2
 ip vrf forwarding private-peering
 ip address 10.2.1.1 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3

router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 maximum-paths 2
 !
 address-family ipv4 vrf private-peering
  network 1.1.1.1 mask 255.255.255.255
  neighbor 10.1.1.2 remote-as 12076
  neighbor 10.1.1.2 fall-over bfd
  neighbor 10.1.1.2 activate
  neighbor 10.1.1.2 soft-reconfiguration inbound
  neighbor 10.2.1.2 remote-as 12076
  neighbor 10.2.1.2 fall-over bfd
  neighbor 10.2.1.2 activate
  neighbor 10.2.1.2 soft-reconfiguration inbound
 exit-address-family
</pre>


**MSEE1 configs for VRF Lite and BFD enabled BGP**
<pre lang="...">
ip vrf private-peering
rd 10:1

interface Loopback0
 ip vrf forwarding private-peering
 ip address 2.2.2.2 255.255.255.255
!
interface GigabitEthernet1
 ip vrf forwarding private-peering
 ip address 10.1.1.2 255.255.255.252
 negotiation auto
 bfd interval 300 min_rx 300 multiplier 3

router bgp 12076
 bgp router-id 2.2.2.2
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 2.2.2.2 mask 255.255.255.255
  neighbor 10.1.1.1 remote-as 65001
  neighbor 10.1.1.1 fall-over bfd
  neighbor 10.1.1.1 activate
  neighbor 10.1.1.1 soft-reconfiguration inbound
 exit-address-family
</pre>


**MSEE2 configs for VRF Lite and BFD enabled BGP**
<pre lang="...">
ip vrf private-peering
 rd 10:1

interface Loopback0
 ip vrf forwarding private-peering
 ip address 3.3.3.3 255.255.255.255
!
interface GigabitEthernet1
 no ip address
 negotiation auto
!
interface GigabitEthernet2
 ip vrf forwarding private-peering
 ip address 10.2.1.2 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3

router bgp 12076
 bgp router-id 3.3.3.3
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 3.3.3.3 mask 255.255.255.255
  neighbor 10.2.1.1 remote-as 65001
  neighbor 10.2.1.1 fall-over bfd
  neighbor 10.2.1.1 activate
  neighbor 10.2.1.1 soft-reconfiguration inbound
 exit-address-family
</pre>

**VRF verification**
<pre lang="...">
CE#sh ip vrf
  Name                             Default RD            Interfaces
  private-peering                  10:1                  Lo0
                                                         Gi1
                                                         Gi2
CE#sh ip route vrf private-peering

Routing Table: private-peering
Codes: L - local, C - connected, S - static, R - RIP, M - mobile, B - BGP
       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area 
       N1 - OSPF NSSA external type 1, N2 - OSPF NSSA external type 2
       E1 - OSPF external type 1, E2 - OSPF external type 2
       i - IS-IS, su - IS-IS summary, L1 - IS-IS level-1, L2 - IS-IS level-2
       ia - IS-IS inter area, * - candidate default, U - per-user static route
       o - ODR, P - periodic downloaded static route, H - NHRP, l - LISP
       a - application route
       + - replicated route, % - next hop override, p - overrides from PfR

Gateway of last resort is not set

      1.0.0.0/32 is subnetted, 1 subnets
C        1.1.1.1 is directly connected, Loopback0
      2.0.0.0/32 is subnetted, 1 subnets
B        2.2.2.2 [20/0] via 10.1.1.2, 02:45:03
      3.0.0.0/32 is subnetted, 1 subnets
B        3.3.3.3 [20/0] via 10.2.1.2, 02:43:02
      10.0.0.0/8 is variably subnetted, 4 subnets, 2 masks
C        10.1.1.0/30 is directly connected, GigabitEthernet1
L        10.1.1.1/32 is directly connected, GigabitEthernet1
C        10.2.1.0/30 is directly connected, GigabitEthernet2
L        10.2.1.1/32 is directly connected, GigabitEthernet2


CE#sh ip bgp vpnv4 vrf private-peering neighbors 10.1.1.2
BGP neighbor is 10.1.1.2,  vrf private-peering,  remote AS 12076, external link
 Fall over configured for session
 BFD is configured. BFD peer is Up. Using BFD to detect fast fallover (single-hop).
  BGP version 4, remote router ID 2.2.2.2
  BGP state = Established, up for 02:46:47
  Last read 00:00:03, last write 00:00:06, hold time is 180, keepalive interval is 60 seconds
 
          
CE#sh ip bgp vpnv4 vrf private-peering neighbors 10.2.1.2 
BGP neighbor is 10.2.1.2,  vrf private-peering,  remote AS 12076, external link
 Fall over configured for session
 BFD is configured. BFD peer is Up. Using BFD to detect fast fallover (single-hop).
  BGP version 4, remote router ID 3.3.3.3
  BGP state = Established, up for 02:45:03
  
CE#ping vrf private-peering 2.2.2.2 source 1.1.1.1
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 2.2.2.2, timeout is 2 seconds:
Packet sent with a source address of 1.1.1.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 1/29/142 ms
CE#ping vrf private-peering 3.3.3.3 source 1.1.1.1
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 3.3.3.3, timeout is 2 seconds:
Packet sent with a source address of 1.1.1.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 1/36/175 ms
</pre>

**BFD verification**
<pre lang="...">
CE#sh bfd neighbors vrf private-peering

IPv4 Sessions
NeighAddr                              LD/RD         RH/RS     State     Int
10.1.1.2                             4097/4097       Up        Up        Gi1
10.2.1.2                             4098/4097       Up        Up        Gi2

CE#sh bfd neighbors history 

IPv4 Sessions
NeighAddr                              LD/RD         RH/RS     State     Int
10.1.1.2                             4097/4097       Up        Up        Gi1
History information:
[Oct 14 15:29:53.862] Event: resetting timestamps ld:4097 handle:1
[Oct 14 15:25:38.735] Event: notify client(BGP) IP:10.1.1.2, ld:4097, handle:1, event:UP, 
[Oct 14 15:25:38.735] Event: notify client(CEF) IP:10.1.1.2, ld:4097, handle:1, event:UP, 
[Oct 14 15:25:38.735] Event: V1 FSM ld:4097 handle:1 event:RX UP state:UP
[Oct 14 15:25:38.735] Event: notify client(CEF) IP:10.1.1.2, ld:4097, handle:1, event:UP, 
[Oct 14 15:25:38.734] Event: V1 FSM ld:4097 handle:1 event:RX INIT state:DOWN
[Oct 14 15:25:35.113] Event: 
 bfd_session_destroyed, proc:BGP, handle:1 act
[Oct 14 15:23:53.019] Event: notify client(CEF) IP:10.1.1.2, ld:4097, handle:1, event:DOWN adminDown, 
[Oct 14 15:23:53.019] Event: notify client(BGP) IP:10.1.1.2, ld:4097, handle:1, event:DOWN adminDown, 
[Oct 14 15:23:53.019] Event: notify client(CEF) IP:10.1.1.2, ld:4097, handle:1, event:DOWN adminDown, 
[Oct 14 15:23:53.018] Event: V1 FSM ld:4097 handle:1 event:RX ADMINDOWN state:UP
IPv4 Sessions
NeighAddr                              LD/RD         RH/RS     State     Int
[Oct 14 15:17:05.288] Event: notify client(CEF) IP:10.1.1.2, ld:4097, handle:1, event:UP, 
[Oct 14 15:17:05.288] Event: notify client(BGP) IP:10.1.1.2, ld:4097, handle:1, event:UP, 
[Oct 14 15:17:05.287] Event: notify client(CEF) IP:10.1.1.2, ld:4097, handle:1, event:UP, 
[Oct 14 15:17:05.283] Event: V1 FSM ld:4097 handle:1 event:RX UP state:INIT
[Oct 14 15:17:05.259] Event: V1 FSM ld:4097 handle:1 event:RX DOWN state:DOWN
[Oct 14 15:17:04.474] 
 bfd_session_created, proc:BGP, idb:GigabitEthernet1 handle:1 act 

10.2.1.2                             4098/4097       Up        Up        Gi2
History information:
[Oct 14 15:29:53.862] Event: resetting timestamps ld:4098 handle:2
[Oct 14 15:27:38.658] Event: V1 FSM ld:4098 handle:2 event:RX UP state:UP
[Oct 14 15:27:38.649] Event: notify client(CEF) IP:10.2.1.2, ld:4098, handle:2, event:UP, 
[Oct 14 15:27:38.649] Event: notify client(BGP) IP:10.2.1.2, ld:4098, handle:2, event:UP, 
[Oct 14 15:27:38.644] Event: notify client(BGP) IP:10.2.1.2, ld:4098, handle:2, event:UP, 
[Oct 14 15:27:38.643] Event: V1 FSM ld:4098 handle:2 event:RX INIT state:DOWN
[Oct 14 15:27:38.610] Event: V1 FSM ld:4098 handle:2 event:Session create state:DOWN
IPv4 Sessions
NeighAddr                              LD/RD         RH/RS     State     Int
[Oct 14 15:27:38.604] 
 bfd_session_created, proc:BGP, idb:GigabitEthernet2 handle:2 act 

CE#debug bfd event 
BFD event debugging is on
CE(config)#int gi1
CE(config-if)#shut
CE(config-if)#
*Oct 14 18:23:31.113: %BGP-5-NBR_RESET: Neighbor 10.1.1.2 reset (Interface flap)
*Oct 14 18:23:31.119: %BGP-5-ADJCHANGE: neighbor 10.1.1.2 vpn vrf private-peering Down Interface flap
*Oct 14 18:23:31.119: %BGP_SESSION-5-ADJCHANGE: neighbor 10.1.1.2 IPv4 Unicast vpn vrf private-peering topology base removed from session  Interface flap
*Oct 14 18:23:31.120: BFD-DEBUG EVENT: bfd_session_destroyed, proc:BGP, handle:1 act
*Oct 14 18:23:31.120: %BFD-6-BFD_SESS_DESTROYED: BFD-SYSLOG: bfd_session_destroyed,  ld:4097 neigh proc:BGP, handle:1 act
*Oct 14 18:23:31.178: BFD-DEBUG EVENT: bfd_session_destroyed, proc:CEF, handle:1 act
*Oct 14 18:23:31.181: BFD-DEBUG Event: V1 FSM ld:4097 handle:1 event:Session delete state:UP (0)
*Oct 14 18:23:32.962: %LINK-5-CHANGED: Interface GigabitEthernet1, changed state to administratively down
*Oct 14 18:23:33.966: %LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet1, changed state to down
*Oct 14 18:23:34.179: BFD-DEBUG Event: V1 FSM ld:4097 handle:1 event:DETECT TIMER EXPIRED state:ADMIN DOWN (0)
*Oct 14 18:23:34.179: BFD-DEBUG Event: decreasing credits by 12 [to 0] (0)
CE(config)#int gi1
CE(config-if)#no shut
CE(config-if)#
*Oct 14 18:24:26.255: %LINK-3-UPDOWN: Interface GigabitEthernet1, changed state to up
*Oct 14 18:24:27.255: %LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet1, changed state to up
*Oct 14 18:24:29.507: BFD-DEBUG EVENT: bfd_session_created, 10.1.1.2 proc:BGP, idb:GigabitEthernet1 handle:1 act
*Oct 14 18:24:29.507: %BFDFSM-6-BFD_SESS_UP: BFD-SYSLOG: BFD session ld:4099 handle:1 is going UP
*Oct 14 18:24:29.508: %BFD-6-BFD_SESS_CREATED: BFD-SYSLOG: bfd_session_created, neigh 10.1.1.2 proc:BGP, idb:GigabitEthernet1 handle:1 act
*Oct 14 18:24:29.508: %BGP-5-ADJCHANGE: neighbor 10.1.1.2 vpn vrf private-peering Up 
*Oct 14 18:24:29.510: BFD-DEBUG Event: initializing credits to 12 (0)
*Oct 14 18:24:29.512: BFD-DEBUG Event: V1 FSM ld:4099 handle:1 event:Session create state:DOWN (0)
*Oct 14 18:24:29.513: BFD-DEBUG Event: V1 FSM ld:4099 handle:1 event:RX INIT state:DOWN (0)
*Oct 14 18:24:29.513: BFD-DEBUG Event: V1 FSM ld:4099 handle:1 event:RX UP state:UP (0)
*Oct 14 18:24:29.513: BFD-DEBUG Event: notify client(BGP) IP:10.1.1.2, ld:4099, handle:1, event:UP,  (0)
*Oct 14 18:24:29.540: BFD-DEBUG EVENT: bfd_session_created, 10.1.1.2 proc:CEF, idb:GigabitEthernet1 handle:1 act
*Oct 14 18:24:29.542: BFD-DEBUG Event: notify client(BGP) IP:10.1.1.2, ld:4099, handle:1, event:UP,  (0)
*Oct 14 18:24:29.543: BFD-DEBUG Event: notify client(CEF) IP:10.1.1.2, ld:4099, handle:1, event:UP,  (0)

