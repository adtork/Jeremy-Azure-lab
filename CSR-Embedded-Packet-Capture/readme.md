# Embedded packet capture on CSR- capture is named "bgp", monitoring tunnel interface 0, copy trace to tftp server (there are many transfer protocols and destination options). Other advanced filtering options will be added.

<pre lang="...">
monitor capture bgp buffer circular size 100
monitor capture bgp match any interface tunnel 0 both
show monitor capture bgp
monitor capture bgp start
monitor capture bgp stop
monitor capture bgp export tftp://10.1.1.1/r1.pcap
</pre>
