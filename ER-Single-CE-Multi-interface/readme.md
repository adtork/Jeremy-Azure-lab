**ER C-tag (defined in Azure portal) is VLAN 100 and using 802.1Q. Customer receives 2 physical hand offs, both are sending VLAN 100. The below config shows how to use 2 different L3 interfaces with VLAN 100 on a single Cisco device. Please check your HW/SW combination to see if they will allow this configuration. **

<pre lang="...">
interface Ethernet0/0.1
encapsulation dot1Q 100
ip address 10.1.1.1 255.255.255.252
!
interface Ethernet0/1.1
encapsulation dot1Q 100
ip address 10.1.1.5 255.255.255.252
</pre>
