## BGP Remove Private AS Notes

- Used on edge routers to remove sending private ASNs to an upstream peer.
- Remove private AS can only be used for eBGP neighbors.
- You can't remove private AS for an eBGP peer if the local device is originating the network.
- By default, if you have a mix of public and private ASNs, the router won’t remove any ASNs.
- If the AS path contains the AS number of the eBGP neighbor then it won’t be removed.
- Lab is preconfigured with basic BGP info. R1 is advertising loopback 1.1.1.1/32

**By default, R3 will prefix 1.1.1.1/32 with ASN 2 and 65001.**
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
