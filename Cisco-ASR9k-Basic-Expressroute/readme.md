# Basic Cisco ASR 9k Configurations for Expressroute
<pre lang="...">
RP/0/0/CPU0:ios#sh run
Thu Jul 23 19:31:37.017 UTC
Building configuration...
!! IOS XR Configuration 6.0.1
!! Last configuration change at Thu Jul 23 19:31:33 2020 by cisco
!
interface Loopback0
 ipv4 address 1.1.1.1 255.255.255.255
!
interface MgmtEth0/0/CPU0/0
 shutdown
!
interface GigabitEthernet0/0/0/0
 description Expressroute-Circuit1-PathA
 ipv4 address 10.1.1.1 255.255.255.252
!
interface GigabitEthernet0/0/0/1
 description Expressroute-Circuit1-PathB
 ipv4 address 10.2.1.1 255.255.255.252
!
interface GigabitEthernet0/0/0/2
 shutdown
!
route-policy pass_all
  pass
end-policy
!
router bgp 65001
 address-family ipv4 unicast
  network 1.1.1.1/32
  redistribute connected
 !
 neighbor 10.1.1.2
  remote-as 12076
  address-family ipv4 unicast
   route-policy pass_all in
   route-policy pass_all out
   soft-reconfiguration inbound
  !
 !
 neighbor 10.2.1.2
  remote-as 12076
  address-family ipv4 unicast
   route-policy pass_all in
   route-policy pass_all out
   soft-reconfiguration inbound
  !
 !
!
end

</pre>
