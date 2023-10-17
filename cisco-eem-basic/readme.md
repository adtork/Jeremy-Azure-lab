# Basic Cisco EEM
Basic Cisco EEM config that shuts down a loopback interface if a BGP neighbor drops. The loopback is enabled when BGP is up.

# Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/cisco-eem-basic/basic-eem.png)

```bash
R1:
event manager applet bgp-neighbor-down
event syslog pattern " %BGP-5-ADJCHANGE: neighbor.*Down" 
action 1.0 syslog msg "shutdown loopback interface"
action 1.5 cli command "enable"
action 2.0 cli command "conf t"
action 2.5 cli command "int lo0"
action 3.0 cli command "shutdown"
action 3.5 cli command "end"

event manager applet bgp-neighbor-up
event syslog pattern " %BGP-5-ADJCHANGE: neighbor.*Up" 
action 1.0 syslog msg "shutdown loopback interface"
action 1.5 cli command "enable"
action 2.0 cli command "conf t"
action 2.5 cli command "int lo0"
action 3.0 cli command "no shut"
action 3.5 cli command "end"
```
