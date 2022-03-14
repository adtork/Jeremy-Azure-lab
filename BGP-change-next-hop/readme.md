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
