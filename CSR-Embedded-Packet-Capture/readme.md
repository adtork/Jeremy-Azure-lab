# Embedded packet capture on CSR- capture is named "bgp", monitoring tunnel interface 0, copy trace to tftp server (there are many transfer protocols and destination options). Other advanced filtering options will be added.

<pre lang="...">
ip access-list extended telnet
permit ip host 10.0.0.4 host 10.0.0.5 dscp cs5

monitor capture bgp buffer circular size 100 access-list telnet
monitor capture bgp match any interface gi 1 in
monitor capture bgp start

monitor capture bgp stop
monitor capture bgp export tftp://1.1.1.1/telnet.pcap


show monitor capture bgp
</pre>
