#CSR1
ip access-list extended TELNET
permit tcp any any eq 23

class-map TELNET
match access-group name TELNET

policy-map CLASSIFY
class TELNET

int gig1
service-policy output CLASSIFY
no shut

show policy-map interface gig1


CSR2
ip access-list extended 100
10 permit ip any any dscp cs6
 
debug ip packet 100 detail
