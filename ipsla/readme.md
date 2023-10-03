IP SLA can be configured on Cisco devices to quickly test connectivity, jitter, delay, RTT, packet loss etc. This lab shows a basic VRF configuration testing ICMP and TCP 80. Note- keep in mind what devices you are testing and if they respond to that port. This lab does not cover SLA responder and simply turns the web server funcationality on R2. IP SLA protocol generation may not conform to protocol specs. EX: debugs will show port 80 being used but it does not conform to HTTP specs.

# Topology and Configs
![alt text](https://github.com/jwrightazure/lab/blob/master/ipsla/ip-sla.png)

**Validation**
<pre lang="...">
r1#sh ip sla sum
IPSLAs Latest Operation Summary
Codes: * active, ^ inactive, ~ pending

ID           Type        Destination       Stats       Return      Last
                                           (ms)        Code        Run
-----------------------------------------------------------------------
*1           icmp-echo   2.2.2.2           RTT=1       OK          6 seconds ago
*2           tcp-connect 2.2.2.2           RTT=1       OK          5 seconds ago
</pre>
