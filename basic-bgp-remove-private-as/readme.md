## BGP Remove Private AS Notes

- Used on edge routers to remove sending private ASNs to an upstream peer.
- Remove private AS can only be used for eBGP neighbors.
- You can't remove private AS for an eBGP peer if the local device is originating the network.
- By default, if you have a mix of public and private ASNs, the router won’t remove any ASNs.
- If the AS path contains the AS number of the eBGP neighbor then it won’t be removed.
- Lab is preconfigured with basic BGP info. R1 is advertising loopback 1.1.1.1/32. Clearing BGP sessions are not shown.

**Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/basic-bgp-remove-private-as/bgp-removeas-topo.PNG)

**By default, R3 will receive prefix 1.1.1.1/32 with ASN 2 and 65001 in the path.**
<pre lang="...">
R3#sh ip bgp
BGP table version is 2, local router ID is 3.3.3.3
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       10.0.23.2                              0 2 65001 i
 </pre>

**Configure R2 to remove ASN 65001 when sending tupdate to R3**
<pre lang="...">
router bgp 2
bgp log-neighbor-changes
neighbor 10.0.12.1 remote-as 65001
neighbor 10.0.23.3 remote-as 3
neighbor 10.0.23.3 remove-private-as
 </pre>
 
**Validate change on R3**
<pre lang="...">
R3#sh ip bgp
BGP table version is 4, local router ID is 3.3.3.3
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       10.0.23.2                              0 2 i
 </pre>
 
**Update R1 to prepend updates to R2. Validate R3 still sees the private AS since a public AS is in the path after prepend.**
 <pre lang="...">
R1:
route-map prepend permit 10
set as-path prepend 1 65001 11 65002 111

router bgp 65001
neighbor 10.0.12.2 route-map prepend out

R3:
R3#sh ip bgp
BGP table version is 6, local router ID is 3.3.3.3
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       10.0.23.2                              0 2 65001 1 65001 11 65002 111 i
  </pre> 
 
 **Update R2 to remove private AS even if there is a public ASN in the path**
 <pre lang="...">
R2:
neighbor 10.0.23.3 remove-private-as all

R3#sh ip bgp
BGP table version is 10, local router ID is 3.3.3.3
Status codes: s suppressed, d damped, h history, * valid, > best, i - internal, 
              r RIB-failure, S Stale, m multipath, b backup-path, f RT-Filter, 
              x best-external, a additional-path, c RIB-compressed, 
              t secondary path, L long-lived-stale,
Origin codes: i - IGP, e - EGP, ? - incomplete
RPKI validation codes: V valid, I invalid, N Not found

     Network          Next Hop            Metric LocPrf Weight Path
 *>   1.1.1.1/32       10.0.23.2                              0 2 1 11 111 i
</pre> 
