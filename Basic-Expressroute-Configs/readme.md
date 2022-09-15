# Azure Networking Lab- Basic Expressroute Configurations- Private Peering
This lab shows the basic configs for Expressroute Private Peering and a few verification commands. Customers do not have access to the Microsoft Edge routers (MSEEs) or the VNET "router" in Azure.

# Notes:
- Assumes ER L2, ER GW and a connection is esablished, switch has correct VLAN/port configs
- VLAN 100 is used for both path A/B for ER. Provider rewrites to 2 different VLANs (10,20) 
- BFD enabled BGP is used for peerings (BFD not required)
- BFD is enabled by default on all new private peering circuits
- You can enable BFD on an existing ER circuit by resetting (not destroying) your circuit on the Azure side
- Verify your edge termination device supports BFD enabled BGP
- BGP max paths is used for ECMP load sharing
- VRF lite is used through the entire topology for segmentation but not required on the CE router
- MSEEs are always the even number of the /30 for ER Private Peering
- MSEEs are using remove-private-AS towards CE
- CE is advertising 10.0.0.0/8 summary address towards Azure
- Loopbacks are for lab only
- When the ERGW is connected to the circuit, the address prefix of that VNET will be advertised via BGP towards on prem

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/ER%20private%20peering%20basic%20configs.PNG)

**Relevant CE configs- note summary address 10/8 that is being sent to Azure and ECMP going to the VNET prefix 172.16.0.0/24**
<pre lang="...">
CE#sh run
!
ip vrf private-peering
 rd 10:1

interface Loopback0
 ip vrf forwarding private-peering
 ip address 1.1.1.1 255.255.255.255
!
interface GigabitEthernet1
 ip vrf forwarding private-peering
 ip address 10.2.1.1 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
!
interface GigabitEthernet2
 ip vrf forwarding private-peering
 ip address 10.1.1.1 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
!
router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 1.1.1.1 mask 255.255.255.255
  aggregate-address 10.0.0.0 255.0.0.0 as-set summary-only
  redistribute static
  neighbor 10.1.1.2 remote-as 12076
  neighbor 10.1.1.2 fall-over bfd
  neighbor 10.1.1.2 activate
  neighbor 10.1.1.2 soft-reconfiguration inbound
  neighbor 10.1.1.2 prefix-list to-azure out
  neighbor 10.2.1.2 remote-as 12076
  neighbor 10.2.1.2 fall-over bfd
  neighbor 10.2.1.2 activate
  neighbor 10.2.1.2 soft-reconfiguration inbound
  neighbor 10.2.1.2 prefix-list to-azure out
  maximum-paths 2
 exit-address-family

ip route vrf private-peering 10.0.0.0 255.0.0.0 Null0
!
ip prefix-list to-azure seq 5 permit 10.0.0.0/8
ip prefix-list to-azure seq 10 permit 1.1.1.1/32

CE#sh ip bgp vpnv4 vrf private-peering neighbor 10.1.1.2 advertised-routes
BGP table version is 6, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *>   1.1.1.1/32       0.0.0.0                  0         32768 i
 *>   10.0.0.0         0.0.0.0                  0         32768 ?

Total number of prefixes 2 
CE#sh ip bgp vpnv4 vrf private-peering neighbor 10.2.1.2 advertised-routes
BGP table version is 6, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *>   1.1.1.1/32       0.0.0.0                  0         32768 i
 *>   10.0.0.0         0.0.0.0                  0         32768 ?

Total number of prefixes 2 
CE#sh ip bgp vpnv4 vrf private-peering                                    
BGP table version is 6, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *>   1.1.1.1/32       0.0.0.0                  0         32768 i
 *>   2.2.2.2/32       10.1.1.2                 0             0 12076 i
 *>   3.3.3.3/32       10.2.1.2                 0             0 12076 i
 *>   10.0.0.0         0.0.0.0                  0         32768 ?
 *>   172.16.0.0/24    10.1.1.2                               0 12076 i
 *m                    10.2.1.2                               0 12076 i
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
B        2.2.2.2 [20/0] via 10.1.1.2, 00:02:22
      3.0.0.0/32 is subnetted, 1 subnets
B        3.3.3.3 [20/0] via 10.2.1.2, 00:02:22
      10.0.0.0/8 is variably subnetted, 5 subnets, 3 masks
S        10.0.0.0/8 is directly connected, Null0
C        10.1.1.0/30 is directly connected, GigabitEthernet2
L        10.1.1.1/32 is directly connected, GigabitEthernet2
C        10.2.1.0/30 is directly connected, GigabitEthernet1
L        10.2.1.1/32 is directly connected, GigabitEthernet1
      172.16.0.0/24 is subnetted, 1 subnets
B        172.16.0.0 [20/0] via 10.2.1.2, 00:02:22
                    [20/0] via 10.1.1.2, 00:02:22


</pre>



**Relevant VNET configs. Note- ECMP load sharing to 10/8 and 1.1.1.1/32 located on CE**
<pre lang="...">
VNET#sh run
!
ip vrf private-peering
 rd 10:1
!
interface Loopback0
 ip vrf forwarding private-peering
 ip address 4.4.4.4 255.255.255.255
!
interface Loopback100
 ip vrf forwarding private-peering
 ip address 172.16.0.1 255.255.255.0
!
interface GigabitEthernet1
 ip vrf forwarding private-peering
 ip address 10.3.1.2 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
!
interface GigabitEthernet2
 ip vrf forwarding private-peering
 ip address 10.4.1.2 255.255.255.252
 bfd interval 300 min_rx 300 multiplier 3
!
router bgp 65515
 bgp router-id 4.4.4.4
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf private-peering
  network 4.4.4.4 mask 255.255.255.255
  network 172.16.0.0 mask 255.255.255.0
  neighbor 10.3.1.1 remote-as 12076
  neighbor 10.3.1.1 fall-over bfd
  neighbor 10.3.1.1 activate
  neighbor 10.3.1.1 soft-reconfiguration inbound
  neighbor 10.3.1.1 prefix-list filter-vnet out
  neighbor 10.4.1.1 remote-as 12076
  neighbor 10.4.1.1 fall-over bfd
  neighbor 10.4.1.1 activate
  neighbor 10.4.1.1 soft-reconfiguration inbound
  neighbor 10.4.1.1 prefix-list filter-vnet out
  maximum-paths 2
 exit-address-family
!
ip prefix-list filter-vnet seq 5 permit 172.16.0.0/24

VNET#sh ip bgp vpnv4 vrf private-peering neighbors 10.3.1.1 advertised-routes
BGP table version is 32, local router ID is 4.4.4.4
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *>   172.16.0.0/24    0.0.0.0                  0         32768 i

Total number of prefixes 1 
VNET#sh ip bgp vpnv4 vrf private-peering neighbors 10.4.1.1 advertised-routes
BGP table version is 32, local router ID is 4.4.4.4
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *>   172.16.0.0/24    0.0.0.0                  0         32768 i

Total number of prefixes 1 
VNET#sh ip bgp vpnv4 vrf private-peering                            
BGP table version is 32, local router ID is 4.4.4.4
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 10:1 (default for vrf private-peering)
 *m   1.1.1.1/32       10.4.1.1                               0 12076 65001 i
 *>                    10.3.1.1                               0 12076 65001 i
 *>   2.2.2.2/32       10.3.1.1                 0             0 12076 i
 *>   3.3.3.3/32       10.4.1.1                 0             0 12076 i
 *>   4.4.4.4/32       0.0.0.0                  0         32768 i
 *m   10.0.0.0         10.4.1.1                               0 12076 65001 ?
 *>                    10.3.1.1                               0 12076 65001 ?
 *>   172.16.0.0/24    0.0.0.0                  0         32768 i
VNET#sh ip route vrf private-peering

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
B        1.1.1.1 [20/0] via 10.4.1.1, 00:11:16
                 [20/0] via 10.3.1.1, 00:11:16
      2.0.0.0/32 is subnetted, 1 subnets
B        2.2.2.2 [20/0] via 10.3.1.1, 00:50:50
      3.0.0.0/32 is subnetted, 1 subnets
B        3.3.3.3 [20/0] via 10.4.1.1, 00:50:50
      4.0.0.0/32 is subnetted, 1 subnets
C        4.4.4.4 is directly connected, Loopback0
      10.0.0.0/8 is variably subnetted, 5 subnets, 3 masks
B        10.0.0.0/8 [20/0] via 10.4.1.1, 00:11:16
                    [20/0] via 10.3.1.1, 00:11:16
C        10.3.1.0/30 is directly connected, GigabitEthernet1
L        10.3.1.2/32 is directly connected, GigabitEthernet1
C        10.4.1.0/30 is directly connected, GigabitEthernet2
L        10.4.1.2/32 is directly connected, GigabitEthernet2
      172.16.0.0/16 is variably subnetted, 2 subnets, 2 masks
C        172.16.0.0/24 is directly connected, Loopback100
L        172.16.0.1/32 is directly connected, Loopback100

</pre>
