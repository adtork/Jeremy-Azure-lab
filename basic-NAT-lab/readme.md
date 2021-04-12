## Basic NAT Lab
This lab provides sample configurations when using the "ip nat outside source list" command. IP NAT outside is used to translate the source address of the IP packets that travel through the outside interface defined in NAT to an IP (specific IP in this lab) on the inside of the NAT "zone". The goal is for R2 to NAT traffic when the SIP is R1's loopback address and the DIP is R3's loopback. All other traffic should not be NAT'd. All networks are advertised in OSPF area 0.

## Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/basic-NAT-lab/nat-lab-topo.PNG)

**Order of operations**
Order of operations when traffic is sourced from R1's loopback to R3's loopback:

R1 and R3 are learning a default route from R2 via the "default-information originate always" command.  R1 sends traffic sourcing from the loopback 0 (1.1.1.1) to R3's loopback (3.3.3.3). The traffic will arrive on the "outside" interface of R2 with a SIP of 1.1.1.1 and a DIP of 3.3.3.3. The SIP is referenced/permitted in access-list 1 and is used by the "ip nat outside source" list command. It is then translated to an address from the NAT pool Net10.
The SIP will be translated to 10.10.10.10 which is the first available address in the NAT pool. 

R3 sees the packet on its incoming interface with a SIP of 10.10.10.10 and a DIP of 3.3.3.3. R3 will send the response to its default route (R2) since 10.10.10.x is not advertised into OSPF. The response from R3 will have a SIP of 3.3.3.3 and a DIP of 10.10.10.10. The "add-route" NAT config adds a host route based on the translation between the outside global and outside local address. Traffic will not flow correctly between NAT interfaces without this command in this particular scenario. If traffic sources from a different interface of R1 to DIP 3.3.3.3, no NAT will occur since the SIP/network is not referenced in the NAT ACL.

<pre lang="...">


</pre>
