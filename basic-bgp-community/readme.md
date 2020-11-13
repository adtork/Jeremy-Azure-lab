# Basic BGP Community Lab
Sample lab showing how to use BGP communities to control outbound path selection. This particular example is matching on a community value and then setting a weight based on the peer. As mentioned, this is for lab purposes only. 

# Goal:
VNET router is advertising 10.100.100.0/24 to both MSEE1 and MSEE1. You have no control of VNET or MSEEs.
CE1 receives 10.100.100.0/24 from both MSEEs and will select the path towards MSEE1 (based on lowest IP)
The goal is for CE1 to send traffic for 10.100.100.0/24 to MSEE2 based on BGP community
Configure VNET router to send BGP community 100:100 to both MSEE1/2
Configure CE1 to match community value 100:100 and set a higher weight for path selection

# Topology:
![alt text](https://github.com/jwrightazure/lab/blob/master/AZVPNGW-deny-branch-to-branch/s2s-branch-deny-topo.PNG)

**Validation:**
<pre lang="...">
As you can see, CE1 is selecting path to MSEE1 (represented by >)
ce1#sh ip bgp
BGP table version is 2, local router ID is 10.1.13.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *    10.100.100.0/24  10.1.13.3                              0 12076 65515 i
 *>                    10.1.12.2                              0 12076 65515 i
</pre>

**The VNET router is sending community value 100:100 and CE1 sees it. Note- CE1 sees that community value from both CE1 and CE1**
<pre lang="...">
ce1#sh ip bgp 10.100.100.0
BGP routing table entry for 10.100.100.0/24, version 0
Paths: (2 available, no best path)
  Not advertised to any peer
  Refresh Epoch 1
  12076 65515, (received & used)
    10.1.13.3 (inaccessible) from 10.1.13.3 (10.1.34.3)
      Origin IGP, localpref 100, valid, external
      Community: 100:100
      rx pathid: 0, tx pathid: 0
  Refresh Epoch 2
  12076 65515, (received & used)
    10.1.12.2 (inaccessible) from 10.1.12.2 (10.1.24.2)
      Origin IGP, localpref 100, valid, external
      Community: 100:100
      rx pathid: 0, tx pathid: 0
</pre>

**Configure CE1 to match community 100:100 and set a local weight for path selection. We are setting this on only 1 neighbor.**
<pre lang="...">
ce1(config)#ip community-list 1 permit 100:100
ce1(config)#route-map select-path permit 10
ce1(config-route-map)#match comm
ce1(config-route-map)#match community 1
ce1(config-route-map)#set we
ce1(config-route-map)#set weight 1000
ce1(config-route-map)#exit
ce1(config)#route-map select-path permit 20
ce1(config)#router bgp 65001
ce1(config)#neighbor 10.1.13.3 route-map select-path in
ce1(config)#exit
ce1#clear ip bgp *

ce1#sh ip bgp
BGP table version is 3, local router ID is 10.1.13.1
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, 
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *    10.100.100.0/24  10.1.12.2                              0 12076 65515 i
 *>                    10.1.13.3                           1000 12076 65515 i
 
 </pre>
