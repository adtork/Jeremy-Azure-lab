interface Ethernet0/0
no ip address
duplex auto
!
interface Ethernet0/0.1
encapsulation dot1Q 100
ip address 10.1.1.1 255.255.255.252
!
interface Ethernet0/0.2
!
interface Ethernet0/1
no ip address
duplex auto
!
interface Ethernet0/1.1
encapsulation dot1Q 100
ip address 10.1.1.5 255.255.255.252
