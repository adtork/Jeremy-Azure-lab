# Expressroute Fastpath - draft
Expressroute (ER) Fastpath (FP) is a configuration option for connections between an ER Gateway (GW) and an ER circuit. Without FP, all inbound traffic to a VNET traverses the ER GW. Responses or traffic sourced from a VM will go directly to the Microsoft Edge routers (MSEEs). ER GWs can potentially become a bottleneck based on large amounts of incoming PPS/CPS/load. FP is designed to move the ER GW to the control plane only, allowing inboud requests to go directly to the VMs without traversing the ER GW. Enabling FP will improve performance for traffic sourced from on prem or other VNETs connected to the circuit.

Important points to consider:
- At the time of this writing, you must use Powershell to configure FP. 
- FP still requires an ER GW for control plane
- Ultra Performance or ErGw3AZ is required
- FP configuration/validation is done on the connection to the circuit, not globally on the ER GW
- Available for both ER "traditional" and Direct
- If the "hub" VNET that owns the ER GW with FP also has a spoke, inbound traffic to the spoke is still processed by the ER GW exactly like non-FP 
- FP can be configured on existing or new connections
- Enabling/disabling FP on an existing connection does not impact traffic



Caveats- Private link is not supported. FP configuration requires Powershell (portal in the future). UDRs on the Gateway subnet do not work as they normally do. Please check the documentation

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/fp%20topo.png)

Scenarios:
- Build FP during creation of a connection between the ER GW and ER Circuit. 
- Validate FP and traceroute behavior from a seperate (non-FP) VNET to hub and spoke.
- Define a non-FP connection in the portal between the ER GW and circuit. Configure FP on existing connection, validate FP enabled, and run previous traceroute.


**VNETs, peerings, VMs and ER GWs (and conn2) are already created to match the diagram. Use Powershell to build an FP connection between ER GW1 and the circuit. The ER circuit is in a seperate subscription so an authorization token is used. $id is the path to the ER circuit (XXXXX is the subscription). "AuthorizationKey" (YYYYY) is the key generated from the authorization process.**

<pre lang="...">

$id = "/subscriptions/XXXXX/resourceGroups/RG_US_W2_ER/providers/Microsoft.Network/expressRouteCircuits/CIRCUIT_EQUINIX"  

$gw = Get-AzVirtualNetworkGateway -Name "ERGW1" -ResourceGroupName "FP"

$connection = New-AzVirtualNetworkGatewayConnection -Name "conn1" -ResourceGroupName "FP" -ExpressRouteGatewayBypass -Location "East US" -VirtualNetworkGateway1 $gw -PeerId $id -ConnectionType ExpressRoute -AuthorizationKey "YYYYY"

Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection


###Validate FP. Result should be true.###

$connection.ExpressRouteGatewayBypass 
</pre>

**After conn1 is built, all VNETs will be able to communicate including on prem. Notice that traffic between the remote VNET and the Hub VM (Connection has FP) shows direct communication. If the ER GW was in path, it would be represented by "*" which will be shown later.**
<pre lang="...">
azureuser@remote-vm:~$ traceroute 10.255.10.4
traceroute to 10.255.10.4 (10.255.10.4), 64 hops max
  1   10.253.0.4  70.105ms  69.961ms  70.035ms 
  2   10.255.10.4  140.715ms  137.713ms  137.029ms
</pre>

**Notice traffic sourced from the remote VNET to the spoke VNET traverses ER GW1**
<pre lang="...">
azureuser@remote-vm:~$ traceroute 10.254.10.4
traceroute to 10.254.10.4 (10.254.10.4), 64 hops max
  1   10.253.0.5  66.275ms  66.192ms  66.188ms 
  2   *  *  * 
  3   10.254.10.4  135.693ms  134.123ms  133.970ms
</pre>

**Traffic from on prem to spoke and the remote VNET is processed by the ER GWs represented by the "*". On prem to the Hub VM will be FP (no "*").**
<pre lang="...">
##to remote VNET##
CISCO_ROUTER#traceroute 10.253.10.4
Type escape sequence to abort.
Tracing the route to 10.253.10.4
VRF info: (vrf in name/id, vrf out name/id)
  1 172.16.1.2 1 msec 1 msec 1 msec
  2  *  *  * 
  3 10.253.10.4 [AS 12076] 75 msec 73 msec 73 msec

##to spoke VM##
CISCO_ROUTER#traceroute 10.254.10.4
Type escape sequence to abort.
Tracing the route to 10.254.10.4
VRF info: (vrf in name/id, vrf out name/id)
  1 172.16.1.2 1 msec 1 msec 1 msec
  2  *  *  * 
  3 10.254.10.4 [AS 12076] 71 msec 71 msec 68 msec

##to Hub VM##
CISCO_ROUTER#traceroute 10.255.10.4
Type escape sequence to abort.
Tracing the route to 10.255.10.4
VRF info: (vrf in name/id, vrf out name/id)
  1 172.16.1.2 1 msec 1 msec 1 msec
  2 10.255.10.4 [AS 12076] 72 msec 71 msec 73 msec
</pre>

**Conn1 has been intentionally deleted and a new non-FP connection has been built. Continual traffic is being sent from the remote VNET and on prem to the Hub VM and Spoke. You will see no traffic interruption when enabling FP on an existing connection. Use the following commands to enable FP on an existing connection.**
<pre lang="...">
$connection = Get-AzVirtualNetworkGatewayConnection -Name "conn1" -ResourceGroupName "FP" 

$connection.ExpressRouteGatewayBypass = $True

Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection 
</pre>

**You will observe the same traceroute behavior as the previous tests.**
