# Azure Networking Lab- Basic BGP route control
This lab guide illustrates how to control basic BGP prefix control in/out of Azure. The lab is built on simulation software and is not using a live Azure VNET/Expressroute. The goal of the lab is to show default behavior of BGP route propagation. Some customers are sending numerous prefixes into Azure when a summary addres may be more efficient as well as controlling what is leaked into their infrastructure. There are a number of ways to address this challenge with BGP. The lab focuses on summary address behavior and outbound prefix control. This is for testing purposes only. 

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/bgp-summary-lab.PNG)

# Lab Notes
- Loopback100 advertisement is only for testing purposes
- Core router will advertise several loopbacks. The VNET router will initially see all of the advertised prefixes. 
- The simulated VNET will advertise 172.16.0.0/24 and 172.16.1.0/24 (and loopback100)
- Routers Azure and Azure removes the private ASN before sending updates to the ASR



**Core router BGP default behavior. Note- we are advertising several 10.x addresses. We are also receving 172.16.0.0/24 and 172.16.1.0/24 (VNET loopbacks).**
<pre lang="...">
Core#sh run | s bgp
router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 neighbor 10.1.1.2 remote-as 65002
 !
 address-family ipv4
  network 1.1.1.1 mask 255.255.255.255
  network 10.100.0.0 mask 255.255.255.0
  network 10.101.0.0 mask 255.255.255.0
  network 10.102.0.0 mask 255.255.255.0
  network 10.103.0.0 mask 255.255.255.0
  network 10.104.0.0 mask 255.255.255.0
  network 10.105.0.0 mask 255.255.255.0
  neighbor 10.1.1.2 activate
  neighbor 10.1.1.2 soft-reconfiguration inbound
 exit-address-family
Core#sh ip bgp
BGP table version is 18, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       0.0.0.0                  0         32768 i
 *>   2.2.2.2/32       10.1.1.2                 0             0 65002 i
 *>   3.3.3.3/32       10.1.1.2                               0 65002 12076 i
 *>   4.4.4.4/32       10.1.1.2                               0 65002 12076 i
 *>   5.5.5.5/32       10.1.1.2                               0 65002 12076 i
 *>   10.100.0.0/24    0.0.0.0                  0         32768 i
 *>   10.101.0.0/24    0.0.0.0                  0         32768 i
 *>   10.102.0.0/24    0.0.0.0                  0         32768 i
 *>   10.103.0.0/24    0.0.0.0                  0         32768 i
 *>   10.104.0.0/24    0.0.0.0                  0         32768 i
 *>   10.105.0.0/24    0.0.0.0                  0         32768 i
 *>   172.16.0.0/24    10.1.1.2                               0 65002 12076 i
     Network          Next Hop            Metric LocPrf Weight Path
 *>   172.16.1.0/24    10.1.1.2                               0 65002 12076 i
Core#ping 5.5.5.5 source lo100
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 5.5.5.5, timeout is 2 seconds:
Packet sent with a source address of 1.1.1.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 3/4/7 ms
Core#ping 172.16.0.1 source lo100
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 172.16.0.1, timeout is 2 seconds:
Packet sent with a source address of 1.1.1.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 4/5/6 ms

</pre>

**VNET router BGP default behavior. BGP max paths is enabled. As you can see, we are receving 10.x routes.**
<pre lang="...">
VNET#sh run | s bgp
router bgp 65515
 bgp router-id 5.5.5.5
 bgp log-neighbor-changes
 neighbor 10.1.1.13 remote-as 12076
 neighbor 10.1.1.17 remote-as 12076
 !
 address-family ipv4
  network 5.5.5.5 mask 255.255.255.255
  network 172.16.0.0 mask 255.255.255.0
  network 172.16.1.0 mask 255.255.255.0
  neighbor 10.1.1.13 activate
  neighbor 10.1.1.13 soft-reconfiguration inbound
  neighbor 10.1.1.17 activate
  neighbor 10.1.1.17 soft-reconfiguration inbound
  maximum-paths 2
 exit-address-family

BGP table version is 14, local router ID is 5.5.5.5
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       10.1.1.13                              0 12076 65002 65001 i
 *m                    10.1.1.17                              0 12076 65002 65001 i
 *>   2.2.2.2/32       10.1.1.13                              0 12076 65002 i
 *m                    10.1.1.17                              0 12076 65002 i
 *>   3.3.3.3/32       10.1.1.13                0             0 12076 i
 *>   4.4.4.4/32       10.1.1.17                0             0 12076 i
 *>   5.5.5.5/32       0.0.0.0                  0         32768 i
 *>   10.100.0.0/24    10.1.1.13                              0 12076 65002 65001 i
 *m                    10.1.1.17                              0 12076 65002 65001 i
     Network          Next Hop            Metric LocPrf Weight Path
 *>   10.101.0.0/24    10.1.1.13                              0 12076 65002 65001 i
 *m                    10.1.1.17                              0 12076 65002 65001 i
 *>   10.102.0.0/24    10.1.1.13                              0 12076 65002 65001 i
 *m                    10.1.1.17                              0 12076 65002 65001 i
 *>   10.103.0.0/24    10.1.1.13                              0 12076 65002 65001 i
 *m                    10.1.1.17                              0 12076 65002 65001 i
 *>   10.104.0.0/24    10.1.1.13                              0 12076 65002 65001 i
 *m                    10.1.1.17                              0 12076 65002 65001 i
 *>   10.105.0.0/24    10.1.1.13                              0 12076 65002 65001 i
 *m                    10.1.1.17                              0 12076 65002 65001 i
 *>   172.16.0.0/24    0.0.0.0                  0         32768 i
 *>   172.16.1.0/24    0.0.0.0                  0         32768 i
VNET#ping 1.1.1.1 source 5.5.5.5
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 1.1.1.1, timeout is 2 seconds:
Packet sent with a source address of 5.5.5.5 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 3/3/5 ms
VNET#ping 10.100.0.1 source lo100
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.100.0.1, timeout is 2 seconds:
Packet sent with a source address of 5.5.5.5 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 2/3/4 ms

</pre>

**Configure the ASR to only send a summary route for 10/8. Validate a summary is being sent and supressing the specific prefixes from the Core router.**
<pre lang="...">
router bgp 65002
 address-family ipv4
  aggregate-address 10.0.0.0 255.0.0.0 as-set summary-only

ASR#sh ip bgp
BGP table version is 21, local router ID is 2.2.2.2
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       10.1.1.1                 0             0 65001 i
 *>   2.2.2.2/32       0.0.0.0                  0         32768 i
 *>   3.3.3.3/32       10.1.1.6                 0             0 12076 i
 *>   4.4.4.4/32       10.1.1.10                0             0 12076 i
 *    5.5.5.5/32       10.1.1.10                              0 12076 65515 i
 *>                    10.1.1.6                               0 12076 65515 i
 *>   10.0.0.0         0.0.0.0                       100  32768 65001 i
 s>   10.100.0.0/24    10.1.1.1                 0             0 65001 i
 s>   10.101.0.0/24    10.1.1.1                 0             0 65001 i
 s>   10.102.0.0/24    10.1.1.1                 0             0 65001 i
 s>   10.103.0.0/24    10.1.1.1                 0             0 65001 i
 s>   10.104.0.0/24    10.1.1.1                 0             0 65001 i
 s>   10.105.0.0/24    10.1.1.1                 0             0 65001 i
     Network          Next Hop            Metric LocPrf Weight Path
 *    172.16.0.0/24    10.1.1.10                              0 12076 65515 i
 *>                    10.1.1.6                               0 12076 65515 i
 *    172.16.1.0/24    10.1.1.10                              0 12076 65515 i
 *>                    10.1.1.6                               0 12076 65515 i

</pre>

**Verify the VNET router is only seeing a summary route and not the individual 10.x prefixes advertised from the Core router.**
<pre lang="...">
VNET#sh ip bgp
BGP table version is 28, local router ID is 5.5.5.5
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       10.1.1.13                              0 12076 65002 65001 i
 *m                    10.1.1.17                              0 12076 65002 65001 i
 *>   2.2.2.2/32       10.1.1.13                              0 12076 65002 i
 *m                    10.1.1.17                              0 12076 65002 i
 *>   3.3.3.3/32       10.1.1.13                0             0 12076 i
 *>   4.4.4.4/32       10.1.1.17                0             0 12076 i
 *>   5.5.5.5/32       0.0.0.0                  0         32768 i
 *m   10.0.0.0         10.1.1.13                              0 12076 65002 65001 i
 *>                    10.1.1.17                              0 12076 65002 65001 i
     Network          Next Hop            Metric LocPrf Weight Path
 *>   172.16.0.0/24    0.0.0.0                  0         32768 i
 *>   172.16.1.0/24    0.0.0.0                  0         32768 i
VNET#ping 10.100.0.1 source lo100
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 10.100.0.1, timeout is 2 seconds:
Packet sent with a source address of 5.5.5.5 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 3/4/5 ms

</pre>

**Configure the ASR to only allow 172.16.0.0/24 into the Core. Validate the Core is only seeing 172.16.0.0/24 and no longer sees 172.16.1.0/24**
<pre lang="...">
ASR:
ip prefix-list filter-vnet seq 5 permit 172.16.0.0/24

router bgp 65002
address-family ipv4
neighbor 10.1.1.1 prefix-list filter-vnet out

Core#sh ip bgp
BGP table version is 25, local router ID is 1.1.1.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       0.0.0.0                  0         32768 i
 *>   10.100.0.0/24    0.0.0.0                  0         32768 i
 *>   10.101.0.0/24    0.0.0.0                  0         32768 i
 *>   10.102.0.0/24    0.0.0.0                  0         32768 i
 *>   10.103.0.0/24    0.0.0.0                  0         32768 i
 *>   10.104.0.0/24    0.0.0.0                  0         32768 i
 *>   10.105.0.0/24    0.0.0.0                  0         32768 i
 *>   172.16.0.0/24    10.1.1.2                               0 65002 12076 i
Core#ping 172.16.0.1 source lo100
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 172.16.0.1, timeout is 2 seconds:
Packet sent with a source address of 1.1.1.1 
!!!!!
Success rate is 100 percent (5/5), round-trip min/avg/max = 3/3/5 ms
Core#
</pre>

**All router BGP configs**
<pre lang="...">
Core#sh run | s bgp
router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 neighbor 10.1.1.2 remote-as 65002
 !
 address-family ipv4
  network 1.1.1.1 mask 255.255.255.255
  network 10.100.0.0 mask 255.255.255.0
  network 10.101.0.0 mask 255.255.255.0
  network 10.102.0.0 mask 255.255.255.0
  network 10.103.0.0 mask 255.255.255.0
  network 10.104.0.0 mask 255.255.255.0
  network 10.105.0.0 mask 255.255.255.0
  neighbor 10.1.1.2 activate
  neighbor 10.1.1.2 soft-reconfiguration inbound
 exit-address-family
 
 ASR#sh run | s bgp
router bgp 65002
 bgp router-id 2.2.2.2
 bgp log-neighbor-changes
 neighbor 10.1.1.1 remote-as 65001
 neighbor 10.1.1.6 remote-as 12076
 neighbor 10.1.1.10 remote-as 12076
 !
 address-family ipv4
  network 2.2.2.2 mask 255.255.255.255
  aggregate-address 10.0.0.0 255.0.0.0 as-set summary-only
  neighbor 10.1.1.1 activate
  neighbor 10.1.1.1 prefix-list filter-vnet out
  neighbor 10.1.1.6 activate
  neighbor 10.1.1.10 activate
 exit-address-family
 
 Azure#sh run | s bgp
router bgp 12076
 bgp router-id 3.3.3.3
 bgp log-neighbor-changes
 neighbor 10.1.1.5 remote-as 65002
 neighbor 10.1.1.14 remote-as 65515
 !
 address-family ipv4
  network 3.3.3.3 mask 255.255.255.255
  neighbor 10.1.1.5 activate
  neighbor 10.1.1.5 remove-private-as
  neighbor 10.1.1.5 soft-reconfiguration inbound
  neighbor 10.1.1.14 activate
  neighbor 10.1.1.14 soft-reconfiguration inbound
 exit-address-family
 
 Azure2#sh run | s bgp
router bgp 12076
 bgp router-id 4.4.4.4
 bgp log-neighbor-changes
 neighbor 10.1.1.9 remote-as 65002
 neighbor 10.1.1.18 remote-as 65515
 !
 address-family ipv4
  network 4.4.4.4 mask 255.255.255.255
  neighbor 10.1.1.9 activate
  neighbor 10.1.1.9 remove-private-as
  neighbor 10.1.1.9 soft-reconfiguration inbound
  neighbor 10.1.1.18 activate
  neighbor 10.1.1.18 soft-reconfiguration inbound
 exit-address-family
 
 VNET#sh run | s bgp
router bgp 65515
 bgp router-id 5.5.5.5
 bgp log-neighbor-changes
 neighbor 10.1.1.13 remote-as 12076
 neighbor 10.1.1.17 remote-as 12076
 !
 address-family ipv4
  network 5.5.5.5 mask 255.255.255.255
  network 172.16.0.0 mask 255.255.255.0
  network 172.16.1.0 mask 255.255.255.0
  neighbor 10.1.1.13 activate
  neighbor 10.1.1.13 soft-reconfiguration inbound
  neighbor 10.1.1.17 activate
  neighbor 10.1.1.17 soft-reconfiguration inbound
  maximum-paths 2
 exit-address-family
</pre>
