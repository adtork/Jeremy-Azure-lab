## Expressroute- injecting WAN interfaces into VNET (Private Peering)
A single Expressroute (ER) circuit has 2 physical paths requiring 2x /30s. Your edge device connects to the Microsoft Edge routers (MSEEs) via BGP. In some scenarios, customers would like to ping the CPE interfaces sourcing from a device in the VNET. By default, this is not allowed based on how ER injects routes. Even though the /30s are locally connected to the MSEEs, the VNET does not see the routes. In order to do this, the CPE must advertise the /30s into BGP. This applies to traditional ER and ER Direct.

Quick notes:

- ER ASN is always 12076
- 2x /30s are required and provided by the customer, Azure always takes the even numbererd IP out of the subnet
- ER terminates on the Microsoft edge routers and not in the VNET
- ER GWs build a connection to the ER "circuit" (technically it's the MSEEs)
- Communication between the ER GW and the MSEEs crosses the Microsoft Backbone
- MSEEs will respond to ping if it has a valid route


**VWAN Topology**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/er-wan-injection.PNG)

The topology above shows the CPE in private ASN 65001 and the MSEEs in ASN 12076. BGP peering is established between 172.16.1.1 and .2 as well as 172.16.2.1 and .2. 
On prem is advertising 10/8 to both peers. There is an existing connection between the ER GW in the VNET and the MSEE routers. At this point, on prem knows about the VNET address space and the VNET knows about 10/8. If you look at the VM effective route table, it will show 2 next hops for destination 10/8. The next hop will be both MSEEs. Please note that all inbound traffic to a VNET traverses the ER GW (except for Fastpath, seperate topic) and the responses will go directly to the MSEEs. Traffic
sourced from a VNET VM to destination 10/8 will go directly to the MSEEs and the ER GW is not in path. The responses back from on prem will go through the ER GW. By default, the 2 x/30s are not in the VM effective route table. 

**ER Circuit route table**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/er-route-table-primary.PNG)

In the above diagram, the CPE is now advertising the 2x /30s into BGP. Azure views 172.16.1.0/30 as the "primary" path. Notice there is a secondary path tab as well. Primary and secondary is purely a naming convention for path A/B. Routing advertisement from on prem will dictate which path Azure will select. As you can see, the primary path sees 172.16.2.0/30 (path B) in it's BGP table with next hop 172.16.1.1 ASN 65100 (path A). You will see the reverse on the secondary path. You also see other prefixes connected with ASN 65515 which is reserved in Azure and represents connected VNETs. 

**VM effective route table**
![alt text](https://github.com/jwrightazure/lab/blob/master/images/vm-effective-route-wan-injection.PNG)

The VM effective route table now shows both /30s with next hop of the MSEEs. By default, it will ECMP load share to those destinations. The MSEEs will not advertise the /30s back to the CPE. If a device in 10/8 needs to reach those interfaces, the CPE will need to advertise those into your on prem routing domain.
