<pre lang="...">
r1#sh run

interface Loopback0
 ip address 1.1.1.1 255.255.255.255
!
interface Ethernet0/0
 ip address 10.0.12.1 255.255.255.0
 duplex auto
!
router bgp 1
 bgp log-neighbor-changes
 network 1.1.1.1 mask 255.255.255.255
 neighbor 10.0.12.2 remote-as 2
 neighbor 10.0.12.2 route-map NEXT-HOP out
!
route-map NEXT-HOP permit 10
 set ip next-hop 10.0.12.3
!         
</pre>


<pre lang="...">
router bgp 1
 bgp log-neighbor-changes
 network 1.1.1.1 mask 255.255.255.255
 neighbor 10.0.0.2 remote-as 2
 neighbor 10.0.0.2 default-originate
 neighbor 10.0.0.2 soft-reconfiguration inbound
 neighbor 10.0.0.2 route-map FILTER out
!
ip prefix-list FILTER seq 10 permit 0.0.0.0/0
!
route-map FILTER permit 10
 match ip address prefix-list FILTER
 set ip next-hop 10.140.140.4
!
route-map FILTER permit 20
</pre>
