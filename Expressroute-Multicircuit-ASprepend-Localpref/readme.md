# Azure Networking Lab- Basic Multi-Circuit Expressroute Private Peering Configurations- BGP AS PAth Prepending/Local Preference
This lab shows the basic configs for multi-circuit Expressroute Private Peering with BGP AS Path Prepending and BGP Local Preference. Customers do not have access to the Microsoft Edge routers (MSEEs) or the VNET "router" in Azure. The lab includes configurations for the simulated MSEEs and VNET routers. 

- "Core" is advertising 192.168.0.0/24 and 192.168.1.0.0, VNETs are advertising 172.16.0.0/24 and 172.16.1.0/24

- The goal of the lab is for traffic sourced from the Core router destination 172.16.0.0/24 to use CE1 (Expressroute Circuit 1) as the primary exit point with a backup path through CE2 (Expressroute Circuit 2). Traffic sourced from the Core router to destination 172.16.1.0/24 should use CE2 as the primary exit point with a backup path through CE1. BGP Local preference is used to influence path selection. 

- Traffic sourced from VNET1 to Core prefix 192.168.0.0/24 should go to MSEE1 and MSEE2 (Expressroute Circuit 1) with a backup path to MSEE3 and MSEE4 (Expressroute Circuit 2). Traffic sourced from VNET2 to Core prefix 192.168.1.0/24 should go to MSEE3 and MSEE4 (Expressroute Circuit 2) with a backup path to MSEE1 and MSEE2 (Expressroute Circuit 1). BGP AS path prepending is used on CE1 and CE2 to influence path selection for the simulated VNETs.

# Notes:
- Assumes ER L2, ER GW and a connection is esablished, switch has correct VLAN/port configs
- BFD is not used in this lab
- BGP between the VNETs and MSEEs are simulating "connections" between the ER GW that resides in your VNET and the "circuit"
- VRF lite is used through the entire topology for segmentation but not required on the CE router
- MSEEs are always the even number of the /30 for ER Private Peering
- MSEEs are using remove-private-AS towards CE (not required)
- BGP/iBGP ECMP load sharing is used throughout the lab
- Loopbacks are for lab only
- VNET to VNET communication is not part of this lab
- alias "vp" is used for show ip bgp vpnv4 vrf private-peering
- clearing any BGP peering is not shown

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/er%20multicircuit.PNG)

**Core paths to both VNET prefixes (172.16.0.0/24 and 172.16.1.0/24) before changing AS path or local pref. Notice it is ECMP load sharing to both CE1 and CE2. VNET1 has 4 ECMP paths to CE prefixes (192.168.0.0/24 and 192.168.1.0/24)**
<pre lang="...">
Core#vp
BGP table version is 38, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *>   1.1.1.1/32       0.0.0.0                  0         32768 i
 *>i  2.2.2.2/32       10.1.12.2                0    100      0 i
 *>i  3.3.3.3/32       10.1.13.2                0    100      0 i
 *>i  4.4.4.4/32       10.1.12.2                0    100      0 12076 i
 *>i  5.5.5.5/32       10.1.12.2                0    100      0 12076 i
 *>i  6.6.6.6/32       10.1.13.2                0    100      0 12076 i
 *>i  7.7.7.7/32       10.1.13.2                0    100      0 12076 i
 * i  8.8.8.8/32       10.1.13.2                0    100      0 12076 i
 *>i                   10.1.12.2                0    100      0 12076 i
 * i  9.9.9.9/32       10.1.13.2                0    100      0 12076 i
 *>i                   10.1.12.2                0    100      0 12076 i
 * i  172.16.0.0/24    10.1.13.2                0    100      0 12076 i
     Network          Next Hop            Metric LocPrf Weight Path
 *>i                   10.1.12.2                0    100      0 12076 i
 * i  172.16.1.0/24    10.1.13.2                0    100      0 12076 i
 *>i                   10.1.12.2                0    100      0 12076 i
 *>   192.168.0.0      0.0.0.0                  0         32768 i
 *>   192.168.1.0      0.0.0.0                  0         32768 i

VNET1#vp
BGP table version is 54, local router ID is 8.8.8.8
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *m   1.1.1.1/32       10.1.78.1                              0 12076 65001 i
 *m                    10.1.68.1                              0 12076 65001 i
 *m                    10.1.58.1                              0 12076 65001 i
 *>                    10.1.48.1                              0 12076 65001 i
 *m   2.2.2.2/32       10.1.78.1                              0 12076 65001 i
 *m                    10.1.68.1                              0 12076 65001 i
 *m                    10.1.58.1                              0 12076 65001 i
 *>                    10.1.48.1                              0 12076 65001 i
 *m   3.3.3.3/32       10.1.58.1                              0 12076 65001 i
 *m                    10.1.48.1                              0 12076 65001 i
 *m                    10.1.78.1                              0 12076 65001 i
 *>                    10.1.68.1                              0 12076 65001 i
     Network          Next Hop            Metric LocPrf Weight Path
 *>   4.4.4.4/32       10.1.48.1                0             0 12076 i
 *>   5.5.5.5/32       10.1.58.1                0             0 12076 i
 *>   6.6.6.6/32       10.1.68.1                0             0 12076 i
 *>   7.7.7.7/32       10.1.78.1                0             0 12076 i
 *>   8.8.8.8/32       0.0.0.0                  0         32768 i
 *>   172.16.0.0/24    0.0.0.0                  0         32768 i
 *m   192.168.0.0      10.1.78.1                              0 12076 65001 i
 *m                    10.1.68.1                              0 12076 65001 i
 *m                    10.1.58.1                              0 12076 65001 i
 *>                    10.1.48.1                              0 12076 65001 i
 *m   192.168.1.0      10.1.78.1                              0 12076 65001 i
 *m                    10.1.68.1                              0 12076 65001 i
 *m                    10.1.58.1                              0 12076 65001 i
 *>                    10.1.48.1                              0 12076 65001 i
</pre>

**Edit CE1 and CE2 with AS path prepending. The goal is for VNET1 to traverse MSEE1/2 for destination 192.168.0.0/24 with a backup path to MSEE3/4. VNET2 should traverse MSEE3/4 for destination 192.168.1.0/24 with a backup path of MSEE1/2.**


<pre lang="...">
CE1:
ip prefix-list prepend-192-168-1 seq 20 permit 192.168.1.0/24
!
route-map prepend permit 10
 match ip address prefix-list prepend-192-168-1
 set as-path prepend 65001 65001 65001
!
route-map prepend permit 20

router bgp 65001
address-family ipv4 vrf private-peering
neighbor 10.1.24.2 route-map prepend out
neighbor 10.1.25.2 route-map prepend out

CE2:
ip prefix-list prepend-192-168-0 seq 20 permit 192.168.0.0/24
!
route-map prepend permit 10
 match ip address prefix-list prepend-192-168-0
 set as-path prepend 65001 65001 65001
!
route-map prepend permit 20

router bgp 65001
address-family ipv4 vrf private-peering
neighbor 10.1.26.2 route-map prepend out
neighbor 10.1.27.2 route-map prepend out
</pre>

**Validate VNET1 and VNET2 are receiving prepend information and selecting the outbound path.**
<pre lang="...">
VNET1#vp
BGP table version is 98, local router ID is 8.8.8.8
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *m   1.1.1.1/32       10.1.78.1                              0 12076 65001 i
 *m                    10.1.68.1                              0 12076 65001 i
 *m                    10.1.58.1                              0 12076 65001 i
 *>                    10.1.48.1                              0 12076 65001 i
 *m   2.2.2.2/32       10.1.78.1                              0 12076 65001 i
 *m                    10.1.68.1                              0 12076 65001 i
 *m                    10.1.58.1                              0 12076 65001 i
 *>                    10.1.48.1                              0 12076 65001 i
 *m   3.3.3.3/32       10.1.58.1                              0 12076 65001 i
 *m                    10.1.48.1                              0 12076 65001 i
 *m                    10.1.78.1                              0 12076 65001 i
 *>                    10.1.68.1                              0 12076 65001 i
 *>   4.4.4.4/32       10.1.48.1                0             0 12076 i
     Network          Next Hop            Metric LocPrf Weight Path
 *>   5.5.5.5/32       10.1.58.1                0             0 12076 i
 *>   6.6.6.6/32       10.1.68.1                0             0 12076 i
 *>   7.7.7.7/32       10.1.78.1                0             0 12076 i
 *>   8.8.8.8/32       0.0.0.0                  0         32768 i
 *>   172.16.0.0/24    0.0.0.0                  0         32768 i
 *    192.168.0.0      10.1.78.1                              0 12076 65001 65001 65001 65001 i
 *                     10.1.68.1                              0 12076 65001 65001 65001 65001 i
 *m                    10.1.58.1                              0 12076 65001 i
 *>                    10.1.48.1                              0 12076 65001 i
 *m   192.168.1.0      10.1.78.1                              0 12076 65001 i
 *>                    10.1.68.1                              0 12076 65001 i
 *                     10.1.58.1                              0 12076 65001 65001 65001 65001 i
 *                     10.1.48.1                              0 12076 65001 65001 65001 65001 i

 VNET2#vp
BGP table version is 94, local router ID is 9.9.9.9
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *m   1.1.1.1/32       10.1.79.1                              0 12076 65001 i
 *m                    10.1.69.1                              0 12076 65001 i
 *m                    10.1.59.1                              0 12076 65001 i
 *>                    10.1.49.1                              0 12076 65001 i
 *m   2.2.2.2/32       10.1.79.1                              0 12076 65001 i
 *m                    10.1.69.1                              0 12076 65001 i
 *m                    10.1.59.1                              0 12076 65001 i
 *>                    10.1.49.1                              0 12076 65001 i
 *m   3.3.3.3/32       10.1.59.1                              0 12076 65001 i
 *m                    10.1.49.1                              0 12076 65001 i
 *m                    10.1.79.1                              0 12076 65001 i
 *>                    10.1.69.1                              0 12076 65001 i
 *>   4.4.4.4/32       10.1.49.1                0             0 12076 i
     Network          Next Hop            Metric LocPrf Weight Path
 *>   5.5.5.5/32       10.1.59.1                0             0 12076 i
 *>   6.6.6.6/32       10.1.69.1                0             0 12076 i
 *>   7.7.7.7/32       10.1.79.1                0             0 12076 i
 *>   9.9.9.9/32       0.0.0.0                  0         32768 i
 *>   172.16.1.0/24    0.0.0.0                  0         32768 i
 *    192.168.0.0      10.1.79.1                              0 12076 65001 65001 65001 65001 i
 *                     10.1.69.1                              0 12076 65001 65001 65001 65001 i
 *m                    10.1.59.1                              0 12076 65001 i
 *>                    10.1.49.1                              0 12076 65001 i
 *m   192.168.1.0      10.1.79.1                              0 12076 65001 i
 *>                    10.1.69.1                              0 12076 65001 i
 *                     10.1.59.1                              0 12076 65001 65001 65001 65001 i
 *                     10.1.49.1                              0 12076 65001 65001 65001 65001 i

 </pre>

**Notice the Core is still ECMP load sharing across both connections.**
<pre lang="...">
Core#vp
BGP table version is 46, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *>   1.1.1.1/32       0.0.0.0                  0         32768 i
 *>i  2.2.2.2/32       10.1.12.2                0    100      0 i
 *>i  3.3.3.3/32       10.1.13.2                0    100      0 i
 *>i  4.4.4.4/32       10.1.12.2                0    100      0 12076 i
 *>i  5.5.5.5/32       10.1.12.2                0    100      0 12076 i
 *>i  6.6.6.6/32       10.1.13.2                0    100      0 12076 i
 *>i  7.7.7.7/32       10.1.13.2                0    100      0 12076 i
 *mi  8.8.8.8/32       10.1.13.2                0    100      0 12076 i
 *>i                   10.1.12.2                0    100      0 12076 i
 *mi  9.9.9.9/32       10.1.13.2                0    100      0 12076 i
 *>i                   10.1.12.2                0    100      0 12076 i
 *mi  172.16.0.0/24    10.1.13.2                0    100      0 12076 i
     Network          Next Hop            Metric LocPrf Weight Path
 *>i                   10.1.12.2                0    100      0 12076 i
 *mi  172.16.1.0/24    10.1.13.2                0    100      0 12076 i
 *>i                   10.1.12.2                0    100      0 12076 i
 *>   192.168.0.0      0.0.0.0                  0         32768 i
 *>   192.168.1.0      0.0.0.0                  0         32768 i
 </pre>

 **Change BGP local preference on CE1 and CE2 to control the required exit points and backup paths.**
<pre lang="...">
CE1:
ip prefix-list 172-16-1-local-pref seq 5 permit 172.16.0.0/24

route-map 172-16-0-local-pref permit 10
 match ip address prefix-list 172-16-0-local-pref
 set local-preference 150

 route-map 172-16-1-local-pref permit 20

router bgp 65001
address-family ipv4 vrf private-peering
neighbor 10.1.24.2 route-map 172-16-1-local-pref in
neighbor 10.1.25.2 route-map 172-16-1-local-pref in


CE2:
ip prefix-list 172-16-1-local-pref seq 5 permit 172.16.1.0/24

route-map 172-16-1-local-pref permit 10
 match ip address prefix-list 172-16-1-local-pref
 set local-preference 150

 route-map 172-16-1-local-pref permit 20

router bgp 65001
address-family ipv4 vrf private-peering
neighbor 10.1.26.2 route-map 172-16-1-local-pref in
neighbor 10.1.27.2 route-map 172-16-1-local-pref in

 </pre>

 **Validate Core is taking the appropriate exit point and Local Preference has been distributed to AS 65001. Drop interfaces on CE1 towards MSEEs to validate backup path is working.**
<pre lang="...">
Core#vp
BGP table version is 21, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *>   1.1.1.1/32       0.0.0.0                  0         32768 i
 *>i  2.2.2.2/32       10.1.12.2                0    100      0 i
 *>i  3.3.3.3/32       10.1.13.2                0    100      0 i
 *>i  4.4.4.4/32       10.1.12.2                0    100      0 12076 i
 *>i  5.5.5.5/32       10.1.12.2                0    100      0 12076 i
 *>i  6.6.6.6/32       10.1.13.2                0    100      0 12076 i
 *>i  7.7.7.7/32       10.1.13.2                0    100      0 12076 i
 *mi  8.8.8.8/32       10.1.13.2                0    100      0 12076 i
 *>i                   10.1.12.2                0    100      0 12076 i
 *mi  9.9.9.9/32       10.1.13.2                0    100      0 12076 i
 *>i                   10.1.12.2                0    100      0 12076 i
 *>i  172.16.0.0/24    10.1.12.2                0    150      0 12076 i
     Network          Next Hop            Metric LocPrf Weight Path
 *>i  172.16.1.0/24    10.1.13.2                0    150      0 12076 i
 *>   192.168.0.0      0.0.0.0                  0         32768 i
 *>   192.168.1.0      0.0.0.0                  0         32768 i

Core#ping vrf private-peering 172.16.0.1 source lo1
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 172.16.0.1, timeout is 2 seconds:
Packet sent with a source address of 192.168.0.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 4/5/8 ms
Core#ping vrf private-peering 172.16.0.1 source lo2
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 172.16.0.1, timeout is 2 seconds:
Packet sent with a source address of 192.168.1.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 3/4/6 ms

CE1(config)#int gi0/2
CE1(config-if)#shut
CE1(config-if)#int gi0/2
*Oct 18 14:14:45.992: %BGP-5-NBR_RESET: Neighbor 10.1.24.2 reset (Interface flap)
*Oct 18 14:14:45.997: %BGP-5-ADJCHANGE: neighbor 10.1.24.2 vpn vrf private-peering Down Interface flap
*Oct 18 14:14:45.998: %BGP_SESSION-5-ADJCHANGE: neighbor 10.1.24.2 IPv4 Unicast vpn vrf private-peering topology base removed from session  Interface fla3
CE1(config-if)#shut
CE1(config-if)#
*Oct 18 14:14:47.962: %LINK-5-CHANGED: Interface GigabitEthernet0/2, changed state to administratively down
*Oct 18 14:14:48.962: %LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet0/2, changed state to down
*Oct 18 14:14:49.403: %BGP-5-NBR_RESET: Neighbor 10.1.25.2 reset (Interface flap)
*Oct 18 14:14:49.406: %BGP-5-ADJCHANGE: neighbor 10.1.25.2 vpn vrf private-peering Down Interface flap
*Oct 18 14:14:49.407: %BGP_SESSION-5-ADJCHANGE: neighbor 10.1.25.2 IPv4 Unicast vpn vrf private-peering topology base removed from session  Interface flap
CE1(config-if)#
*Oct 18 14:14:51.374: %LINK-5-CHANGED: Interface GigabitEthernet0/3, changed state to administratively down
*Oct 18 14:14:52.374: %LINEPROTO-5-UPDOWN: Line protocol on Interface GigabitEthernet0/3, changed state to down
CE1(config-if)#

Core#vp
BGP table version is 29, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *>   1.1.1.1/32       0.0.0.0                  0         32768 i
 *>i  2.2.2.2/32       10.1.12.2                0    100      0 i
 *>i  3.3.3.3/32       10.1.13.2                0    100      0 i
 *>i  6.6.6.6/32       10.1.13.2                0    100      0 12076 i
 *>i  7.7.7.7/32       10.1.13.2                0    100      0 12076 i
 *>i  8.8.8.8/32       10.1.13.2                0    100      0 12076 i
 *>i  9.9.9.9/32       10.1.13.2                0    100      0 12076 i
 *>i  172.16.0.0/24    10.1.13.2                0    100      0 12076 i
 *>i  172.16.1.0/24    10.1.13.2                0    150      0 12076 i
 *>   192.168.0.0      0.0.0.0                  0         32768 i
 *>   192.168.1.0      0.0.0.0                  0         32768 i

Core#ping vrf private-peering 172.16.0.1 source lo2
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 172.16.0.1, timeout is 2 seconds:
Packet sent with a source address of 192.168.1.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 5/5/7 ms
Core#ping vrf private-peering 172.16.1.1 source lo2
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 172.16.1.1, timeout is 2 seconds:
Packet sent with a source address of 192.168.1.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 4/5/7 ms

</pre>

**All router configs**
<pre lang="...">
Core#sh run
Building configuration...

ip vrf private-peering
 rd 10:1

interface Loopback0
 ip vrf forwarding private-peering
 ip address 1.1.1.1 255.255.255.255
!
interface Loopback1
 ip vrf forwarding private-peering
 ip address 192.168.0.1 255.255.255.0
!
interface Loopback2
 ip vrf forwarding private-peering
 ip address 192.168.1.1 255.255.255.0
!
interface GigabitEthernet0/0
 ip vrf forwarding private-peering
 ip address 10.1.12.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/1
 ip vrf forwarding private-peering
 ip address 10.1.13.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/2
 no ip address
 shutdown
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/3
 no ip address
 shutdown
 duplex auto
 speed auto
 media-type rj45
!
router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 1.1.1.1 mask 255.255.255.255
  network 192.168.0.0
  network 192.168.1.0
  neighbor 10.1.12.2 remote-as 65001
  neighbor 10.1.12.2 activate
  neighbor 10.1.12.2 next-hop-self
  neighbor 10.1.12.2 soft-reconfiguration inbound
  neighbor 10.1.12.2 prefix-list to-azure out
  neighbor 10.1.13.2 remote-as 65001
  neighbor 10.1.13.2 activate
  neighbor 10.1.13.2 next-hop-self
  neighbor 10.1.13.2 soft-reconfiguration inbound
  neighbor 10.1.13.2 prefix-list to-azure out
  maximum-paths 4
  maximum-paths ibgp 4
 exit-address-family
!

ip prefix-list to-azure seq 5 permit 1.1.1.1/32
ip prefix-list to-azure seq 10 permit 192.168.0.0/24
ip prefix-list to-azure seq 15 permit 192.168.1.0/24
ipv6 ioam timestamp

alias exec vp show ip bgp vpnv4 vrf private-peering

CE1#term length 0
CE1#sh run
Building configuration...

Current configuration : 4689 bytes
!
! Last configuration change at 14:21:37 UTC Fri Oct 18 2019
!
version 15.7
service timestamps debug datetime msec
service timestamps log datetime msec
no service password-encryption
!
hostname CE1
!
boot-start-marker
boot-end-marker
!
!
!
no aaa new-model
!
!
!
mmi polling-interval 60
no mmi auto-configure
no mmi pvc
mmi snmp-timeout 180
!
!
!
!
!
!
!
!
ip vrf private-peering
 rd 10:1
!
!
!
!
no ip domain lookup
ip cef
no ipv6 cef
!
multilink bundle-name authenticated
!
!
!
!
!
redundancy
!
!
! 
!
!
!
!
!
!
!
!
!
!
!
!
interface Loopback0
 ip vrf forwarding private-peering
 ip address 2.2.2.2 255.255.255.255
!
interface GigabitEthernet0/0
 ip vrf forwarding private-peering
 ip address 10.1.12.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/1
 ip vrf forwarding private-peering
 ip address 10.1.23.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/2
 ip vrf forwarding private-peering
 ip address 10.1.24.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/3
 ip vrf forwarding private-peering
 ip address 10.1.25.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
router bgp 65001
 bgp router-id 2.2.2.2
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 2.2.2.2 mask 255.255.255.255
  neighbor 10.1.12.1 remote-as 65001
  neighbor 10.1.12.1 activate
  neighbor 10.1.12.1 next-hop-self
  neighbor 10.1.12.1 soft-reconfiguration inbound
  neighbor 10.1.23.2 remote-as 65001
  neighbor 10.1.23.2 activate
  neighbor 10.1.23.2 next-hop-self
  neighbor 10.1.23.2 soft-reconfiguration inbound
  neighbor 10.1.24.2 remote-as 12076
  neighbor 10.1.24.2 activate
  neighbor 10.1.24.2 soft-reconfiguration inbound
  neighbor 10.1.24.2 route-map 172-16-0-local-pref in
  neighbor 10.1.24.2 route-map prepend out
  neighbor 10.1.25.2 remote-as 12076
  neighbor 10.1.25.2 activate
  neighbor 10.1.25.2 soft-reconfiguration inbound
  neighbor 10.1.25.2 route-map 172-16-0-local-pref in
  neighbor 10.1.25.2 route-map prepend out
  maximum-paths 4
  maximum-paths ibgp 4
 exit-address-family
!
ip forward-protocol nd
!
!
no ip http server
no ip http secure-server
!
!
ip prefix-list 172-16-0-local-pref seq 5 permit 172.16.0.0/24
!
ip prefix-list prepend-192-168-1 seq 20 permit 192.168.1.0/24
ipv6 ioam timestamp
!
route-map 172-16-0-local-pref permit 10
 match ip address prefix-list 172-16-0-local-pref
 set local-preference 150
!
route-map 172-16-0-local-pref permit 20
!
route-map prepend permit 10
 match ip address prefix-list prepend-192-168-1
 set as-path prepend 65001 65001 65001
!
route-map prepend permit 20
!
!
!
control-plane
!
alias exec vp show ip bgp vpnv4 vrf private-peering

CE2#sh run
Building configuration...

Current configuration : 4689 bytes
!
! Last configuration change at 14:05:09 UTC Fri Oct 18 2019
!
version 15.7
service timestamps debug datetime msec
service timestamps log datetime msec
no service password-encryption
!
hostname CE2
!
boot-start-marker
boot-end-marker
!
!
!
no aaa new-model
!
!
!
mmi polling-interval 60
no mmi auto-configure
no mmi pvc
mmi snmp-timeout 180
!
!
!
!
!
!
!
!
ip vrf private-peering
 rd 10:1
!
!
!
!
no ip domain lookup
ip cef
no ipv6 cef
!
multilink bundle-name authenticated
!
!
!
!
!
redundancy
!
!
! 
!
!
!
!
!
!
!
!
!
!
!
!
interface Loopback0
 ip vrf forwarding private-peering
 ip address 3.3.3.3 255.255.255.255
!
interface GigabitEthernet0/0
 ip vrf forwarding private-peering
 ip address 10.1.13.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/1
 ip vrf forwarding private-peering
 ip address 10.1.23.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/2
 ip vrf forwarding private-peering
 ip address 10.1.26.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/3
 ip vrf forwarding private-peering
 ip address 10.1.27.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
router bgp 65001
 bgp router-id 3.3.3.3
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 3.3.3.3 mask 255.255.255.255
  neighbor 10.1.13.1 remote-as 65001
  neighbor 10.1.13.1 activate
  neighbor 10.1.13.1 next-hop-self
  neighbor 10.1.13.1 soft-reconfiguration inbound
  neighbor 10.1.23.1 remote-as 65001
  neighbor 10.1.23.1 activate
  neighbor 10.1.23.1 next-hop-self
  neighbor 10.1.23.1 soft-reconfiguration inbound
  neighbor 10.1.26.2 remote-as 12076
  neighbor 10.1.26.2 activate
  neighbor 10.1.26.2 soft-reconfiguration inbound
  neighbor 10.1.26.2 route-map 172-16-1-local-pref in
  neighbor 10.1.26.2 route-map prepend out
  neighbor 10.1.27.2 remote-as 12076
  neighbor 10.1.27.2 activate
  neighbor 10.1.27.2 soft-reconfiguration inbound
  neighbor 10.1.27.2 route-map 172-16-1-local-pref in
  neighbor 10.1.27.2 route-map prepend out
  maximum-paths 4
  maximum-paths ibgp 4
 exit-address-family
!
ip forward-protocol nd
!
!
no ip http server
no ip http secure-server
!
!
ip prefix-list 172-16-1-local-pref seq 5 permit 172.16.1.0/24
!
ip prefix-list prepend-192-168-0 seq 20 permit 192.168.0.0/24
ipv6 ioam timestamp
!
route-map 172-16-1-local-pref permit 10
 match ip address prefix-list 172-16-1-local-pref
 set local-preference 150
!
route-map 172-16-1-local-pref permit 20
!
route-map prepend permit 10
 match ip address prefix-list prepend-192-168-0
 set as-path prepend 65001 65001 65001
!
route-map prepend permit 20
!
!
!
control-plane
!
alias exec vp show ip bgp vpnv4 vrf private-peering


MSEE1#sh run
Building configuration...

Current configuration : 3783 bytes
!
version 15.7
service timestamps debug datetime msec
service timestamps log datetime msec
no service password-encryption
!
hostname MSEE1
!
boot-start-marker
boot-end-marker
!
!
!
no aaa new-model
!
!
!
mmi polling-interval 60
no mmi auto-configure
no mmi pvc
mmi snmp-timeout 180
!
!
!
!
!
!
!
!
ip vrf private-peering
 rd 10:1
!
!
!
!
no ip domain lookup
ip cef
no ipv6 cef
!
multilink bundle-name authenticated
!
!
!
!
!
redundancy
!
!
! 
!
!
!
!
!
!
!
!
!
!
!
!
interface Loopback0
 ip vrf forwarding private-peering
 ip address 4.4.4.4 255.255.255.255
!
interface GigabitEthernet0/0
 ip vrf forwarding private-peering
 ip address 10.1.24.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/1
 ip vrf forwarding private-peering
 ip address 10.1.48.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/2
 ip vrf forwarding private-peering
 ip address 10.1.49.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/3
 no ip address
 shutdown
 duplex auto
 speed auto
 media-type rj45
!
router bgp 12076
 bgp router-id 4.4.4.4
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 4.4.4.4 mask 255.255.255.255
  neighbor 10.1.24.1 remote-as 65001
  neighbor 10.1.24.1 activate
  neighbor 10.1.24.1 remove-private-as
  neighbor 10.1.24.1 soft-reconfiguration inbound
  neighbor 10.1.48.2 remote-as 65515
  neighbor 10.1.48.2 activate
  neighbor 10.1.48.2 soft-reconfiguration inbound
  neighbor 10.1.49.2 remote-as 65515
  neighbor 10.1.49.2 activate
  neighbor 10.1.49.2 soft-reconfiguration inbound
  maximum-paths 4
 exit-address-family
!
ip forward-protocol nd
!
!
no ip http server
no ip http secure-server
!
ipv6 ioam timestamp
!
!
!
control-plane
!
alias exec vp show ip bgp vpnv4 vrf private-peering

MSEE2#sh run
Building configuration...

Current configuration : 3783 bytes
!
version 15.7
service timestamps debug datetime msec
service timestamps log datetime msec
no service password-encryption
!
hostname MSEE2
!
boot-start-marker
boot-end-marker
!
!
!
no aaa new-model
!
!
!
mmi polling-interval 60
no mmi auto-configure
no mmi pvc
mmi snmp-timeout 180
!
!
!
!
!
!
!
!
ip vrf private-peering
 rd 10:1
!
!
!
!
no ip domain lookup
ip cef
no ipv6 cef
!
multilink bundle-name authenticated
!
!
!
!
!
redundancy
!
!
! 
!
!
!
!
!
!
!
!
!
!
!
!
interface Loopback0
 ip vrf forwarding private-peering
 ip address 5.5.5.5 255.255.255.255
!
interface GigabitEthernet0/0
 ip vrf forwarding private-peering
 ip address 10.1.25.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/1
 ip vrf forwarding private-peering
 ip address 10.1.58.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/2
 ip vrf forwarding private-peering
 ip address 10.1.59.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/3
 no ip address
 shutdown
 duplex auto
 speed auto
 media-type rj45
!
router bgp 12076
 bgp router-id 5.5.5.5
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 5.5.5.5 mask 255.255.255.255
  neighbor 10.1.25.1 remote-as 65001
  neighbor 10.1.25.1 activate
  neighbor 10.1.25.1 remove-private-as
  neighbor 10.1.25.1 soft-reconfiguration inbound
  neighbor 10.1.58.2 remote-as 65515
  neighbor 10.1.58.2 activate
  neighbor 10.1.58.2 soft-reconfiguration inbound
  neighbor 10.1.59.2 remote-as 65515
  neighbor 10.1.59.2 activate
  neighbor 10.1.59.2 soft-reconfiguration inbound
  maximum-paths 4
 exit-address-family
!
ip forward-protocol nd
!
!
no ip http server
no ip http secure-server
!
ipv6 ioam timestamp
!
!
!
control-plane
!
alias exec vp show ip bgp vpnv4 vrf private-peering


MSEE3#sh run
Building configuration...

Current configuration : 3731 bytes
!
version 15.7
service timestamps debug datetime msec
service timestamps log datetime msec
no service password-encryption
!
hostname MSEE3
!
boot-start-marker
boot-end-marker
!
!
!
no aaa new-model
!
!
!
mmi polling-interval 60
no mmi auto-configure
no mmi pvc
mmi snmp-timeout 180
!
!
!
!
!
!
!
!
ip vrf private-peering
 rd 10:1
!
!
!
!
no ip domain lookup
ip cef
no ipv6 cef
!
multilink bundle-name authenticated
!
!
!
!
!
redundancy
!
!
! 
!
!
!
!
!
!
!
!
!
!
!
!
interface Loopback0
 ip vrf forwarding private-peering
 ip address 6.6.6.6 255.255.255.255
!
interface GigabitEthernet0/0
 ip vrf forwarding private-peering
 ip address 10.1.26.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/1
 ip vrf forwarding private-peering
 ip address 10.1.68.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/2
 ip vrf forwarding private-peering
 ip address 10.1.69.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/3
 no ip address
 shutdown
 duplex auto
 speed auto
 media-type rj45
!
router bgp 12076
 bgp router-id 6.6.6.6
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 6.6.6.6 mask 255.255.255.255
  neighbor 10.1.26.1 remote-as 65001
  neighbor 10.1.26.1 activate
  neighbor 10.1.26.1 remove-private-as
  neighbor 10.1.26.1 soft-reconfiguration inbound
  neighbor 10.1.68.2 remote-as 65515
  neighbor 10.1.68.2 activate
  neighbor 10.1.68.2 soft-reconfiguration inbound
  neighbor 10.1.69.2 remote-as 65515
  neighbor 10.1.69.2 activate
  neighbor 10.1.69.2 soft-reconfiguration inbound
  maximum-paths 4
 exit-address-family
!
ip forward-protocol nd
!
!
no ip http server
no ip http secure-server
!
ipv6 ioam timestamp
!
!
!
control-plane
!


MSEE4#sh run
Building configuration...

Current configuration : 3731 bytes
!
version 15.7
service timestamps debug datetime msec
service timestamps log datetime msec
no service password-encryption
!
hostname MSEE4
!
boot-start-marker
boot-end-marker
!
!
!
no aaa new-model
!
!
!
mmi polling-interval 60
no mmi auto-configure
no mmi pvc
mmi snmp-timeout 180
!
!
!
!
!
!
!
!
ip vrf private-peering
 rd 10:1
!
!
!
!
no ip domain lookup
ip cef
no ipv6 cef
!
multilink bundle-name authenticated
!
!
!
!
!
redundancy
!
!
! 
!
!
!
!
!
!
!
!
!
!
!
!
interface Loopback0
 ip vrf forwarding private-peering
 ip address 7.7.7.7 255.255.255.255
!
interface GigabitEthernet0/0
 ip vrf forwarding private-peering
 ip address 10.1.27.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/1
 ip vrf forwarding private-peering
 ip address 10.1.78.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/2
 ip vrf forwarding private-peering
 ip address 10.1.79.1 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/3
 no ip address
 shutdown
 duplex auto
 speed auto
 media-type rj45
!
router bgp 12076
 bgp router-id 7.7.7.7
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 7.7.7.7 mask 255.255.255.255
  neighbor 10.1.27.1 remote-as 65001
  neighbor 10.1.27.1 activate
  neighbor 10.1.27.1 remove-private-as
  neighbor 10.1.27.1 soft-reconfiguration inbound
  neighbor 10.1.78.2 remote-as 65515
  neighbor 10.1.78.2 activate
  neighbor 10.1.78.2 soft-reconfiguration inbound
  neighbor 10.1.79.2 remote-as 65515
  neighbor 10.1.79.2 activate
  neighbor 10.1.79.2 soft-reconfiguration inbound
  maximum-paths 4
 exit-address-family
!
ip forward-protocol nd
!
!
no ip http server
no ip http secure-server
!
ipv6 ioam timestamp
!
!
!
control-plane
!

VNET1#sh run
Building configuration...

Current configuration : 4329 bytes
!
version 15.7
service timestamps debug datetime msec
service timestamps log datetime msec
no service password-encryption
!
hostname VNET1
!
boot-start-marker
boot-end-marker
!
!
!
no aaa new-model
!
!
!
mmi polling-interval 60
no mmi auto-configure
no mmi pvc
mmi snmp-timeout 180
!
!
!
!
!
!
!
!
ip vrf private-peering
 rd 10:1
!
!
!
!
no ip domain lookup
ip cef
no ipv6 cef
!
multilink bundle-name authenticated
!
!
!
!
!
redundancy
!
!
! 
!
!
!
!
!
!
!
!
!
!
!
!
interface Loopback0
 ip vrf forwarding private-peering
 ip address 8.8.8.8 255.255.255.255
!
interface Loopback100
 ip vrf forwarding private-peering
 ip address 172.16.0.1 255.255.255.0
!
interface GigabitEthernet0/0
 ip vrf forwarding private-peering
 ip address 10.1.48.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/1
 ip vrf forwarding private-peering
 ip address 10.1.58.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/2
 ip vrf forwarding private-peering
 ip address 10.1.68.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/3
 ip vrf forwarding private-peering
 ip address 10.1.78.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
router bgp 65515
 bgp router-id 8.8.8.8
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 8.8.8.8 mask 255.255.255.255
  network 172.16.0.0 mask 255.255.255.0
  neighbor 10.1.48.1 remote-as 12076
  neighbor 10.1.48.1 activate
  neighbor 10.1.48.1 soft-reconfiguration inbound
  neighbor 10.1.48.1 prefix-list VNET-OUT out
  neighbor 10.1.58.1 remote-as 12076
  neighbor 10.1.58.1 activate
  neighbor 10.1.58.1 soft-reconfiguration inbound
  neighbor 10.1.58.1 prefix-list VNET-OUT out
  neighbor 10.1.68.1 remote-as 12076
  neighbor 10.1.68.1 activate
  neighbor 10.1.68.1 soft-reconfiguration inbound
  neighbor 10.1.68.1 prefix-list VNET-OUT out
  neighbor 10.1.78.1 remote-as 12076
  neighbor 10.1.78.1 activate
  neighbor 10.1.78.1 soft-reconfiguration inbound
  neighbor 10.1.78.1 prefix-list VNET-OUT out
  maximum-paths 4
 exit-address-family
!
ip forward-protocol nd
!
!
no ip http server
no ip http secure-server
!
!
ip prefix-list VNET-OUT seq 5 permit 172.16.0.0/24
ip prefix-list VNET-OUT seq 10 permit 8.8.8.8/32
ipv6 ioam timestamp
!
!
!
control-plane
!
alias exec vp show ip bgp vpnv4 vrf private-peering

VNET2#sh run
Building configuration...

Current configuration : 4329 bytes
!
version 15.7
service timestamps debug datetime msec
service timestamps log datetime msec
no service password-encryption
!
hostname VNET2
!
boot-start-marker
boot-end-marker
!
!
!
no aaa new-model
!
!
!
mmi polling-interval 60
no mmi auto-configure
no mmi pvc
mmi snmp-timeout 180
!
!
!
!
!
!
!
!
ip vrf private-peering
 rd 10:1
!
!
!
!
no ip domain lookup
ip cef
no ipv6 cef
!
multilink bundle-name authenticated
!
!
!
!
!
redundancy
!
!
! 
!
!
!
!
!
!
!
!
!
!
!
!
interface Loopback0
 ip vrf forwarding private-peering
 ip address 9.9.9.9 255.255.255.255
!
interface Loopback100
 ip vrf forwarding private-peering
 ip address 172.16.1.1 255.255.255.0
!
interface GigabitEthernet0/0
 ip vrf forwarding private-peering
 ip address 10.1.49.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/1
 ip vrf forwarding private-peering
 ip address 10.1.59.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/2
 ip vrf forwarding private-peering
 ip address 10.1.69.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
interface GigabitEthernet0/3
 ip vrf forwarding private-peering
 ip address 10.1.79.2 255.255.255.0
 duplex auto
 speed auto
 media-type rj45
!
router bgp 65515
 bgp router-id 9.9.9.9
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 9.9.9.9 mask 255.255.255.255
  network 172.16.1.0 mask 255.255.255.0
  neighbor 10.1.49.1 remote-as 12076
  neighbor 10.1.49.1 activate
  neighbor 10.1.49.1 soft-reconfiguration inbound
  neighbor 10.1.49.1 prefix-list VNET-OUT out
  neighbor 10.1.59.1 remote-as 12076
  neighbor 10.1.59.1 activate
  neighbor 10.1.59.1 soft-reconfiguration inbound
  neighbor 10.1.59.1 prefix-list VNET-OUT out
  neighbor 10.1.69.1 remote-as 12076
  neighbor 10.1.69.1 activate
  neighbor 10.1.69.1 soft-reconfiguration inbound
  neighbor 10.1.69.1 prefix-list VNET-OUT out
  neighbor 10.1.79.1 remote-as 12076
  neighbor 10.1.79.1 activate
  neighbor 10.1.79.1 soft-reconfiguration inbound
  neighbor 10.1.79.1 prefix-list VNET-OUT out
  maximum-paths 4
 exit-address-family
!
ip forward-protocol nd
!
!
no ip http server
no ip http secure-server
!
!
ip prefix-list VNET-OUT seq 5 permit 172.16.1.0/24
ip prefix-list VNET-OUT seq 10 permit 9.9.9.9/32
ipv6 ioam timestamp
!
!
!
control-plane
!


</pre>
