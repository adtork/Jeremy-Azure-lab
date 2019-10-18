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

