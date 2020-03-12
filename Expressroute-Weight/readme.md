# Expressroute Weight
Expressroute Weight is a configuration option that can be used to select a preferred Expressroute Circuit when receiving the same prefix from multiple connections. There are several items to consider when working with weight:
- VNETs with connections to Expressroute (ER) Circuits via Expressroute Gateways (ER GW) will always select the longest prefix before weight or AS path prepend
- Weight is used before AS path prepending when receiving the same prefix from multiple ER circuits
- Weight is local to the ER GW and is not exchanged with other ER GWs or the Microsoft Edge Routers (MSEE)
- Default weight is 0 with a max value of 32000
- You can’t customize weight at a prefix/subnet level or other metric
- It’s important to understand the impact of weight for inter-VNET communication as well as to on prem. Asymmetric/suboptimal traffic is a possibility if you do not  understand the forwarding behavior
- VNET peering and Global Reach options are outside the scope of this document
- Weight is configured on individual connections. Higher weight is the preferred path

![alt text](https://github.com/jwrightazure/lab/blob/master/images/connectionweight.png)

# Scenario 1

![alt text](https://github.com/jwrightazure/lab/blob/master/images/weightscenario1.png)
The above topology has three VNETs, two in Azure region West and one in Central. The ER location is San Jose which is connected to on prem. Assuming BGP is configured correctly, on prem and each VNET will be able to communicate. All 3 VNETs will be able to talk to each other by hairpinning off the MSEEs via the backbone The traffic will not traverse the ER1 “WAN” link. Connection weights are irrelevant since there is only 1 path to each prefix.

# Scenario 2

![alt text](https://github.com/jwrightazure/lab/blob/master/images/weightscenario2.png)
We now have a second ER circuit (ER2) located in Chicago. Each VNET will see ER1 and ER2 MSEEs as next hop for inter-VNET traffic. The default behavior will result in ECMP load sharing Ex: Traffic between 10.1 to 10.2 will ECMP across San Jose and Chicago MSEEs. This will be suboptimal as some traffic from West to West will traverse across the backbone and hairpin off the Chicago MSEEs. By setting the weight on conn1 between 10.1 ER GW and the San Jose ER circuit to >0, it will choose conn1 for 10.1 to 10.2.  However, 10.2 will still see San Jose and Chicago as the next hop so the response back will load share. The 10.1 ER GW will not care if the response comes from one or multiple connection paths. In order to make the flow optimal, you will need to set the weight on conn3 to >0. It’s imperative to understand how setting the weight impacts traffic flows between on prem and the VNETs. Assuming on prem1 and on prem2 are advertising 10.10 over ER1 and ER2, the 10.1 VNET will receive 10.10 from both San Jose and Chicago but will prefer conn1 since you previously configured the weight. Prepending the 10.10 prefix on either circuit is irrelevant since weight is the deciding factor when receiving it from multiple paths. Assuming weight is set on conn1, there could be a scenario where on prem2 send traffic on ER2, but the response traverses ER1. There could be a negative impact such as backhauling the traffic, appliances in path that enforce traffic symmetry etc. This could be controlled by manipulating metrics such as local preference to make sure on prem1 and on prem2 select the correct outbound path. The same applies if you were to advertise a summary route 10/8 from on prem1 and on prem2. If ER1 or conn1 were to fail, one prem1 to 10.1 would traverse ER2 (assuming on prem routing is correct) and the response will follow conn2.  

# Scenario 3

![alt text](https://github.com/jwrightazure/lab/blob/master/images/weightscenario3a.png)
In this scenario, we have 3 ER circuits with each on prem device sending a 10/8 summary route only with ASN 65001. Each VNET will see 6 next hops (2 per ER circuit) for destination 10/8. The default behavior will ECMP load share across those paths which could be suboptimal. EX: On prem 1 sends traffic to 10.1, the response could flow over any of the 3 ER circuits. Customer scenario sourcing from VNETs to destination 10/8:
- US West: prefer ER1, secondary ER2, tertiary ER3
- North Central: prefer ER2, secondary ER3, tertiary ER1
- US East: prefer ER3, secondary ER2, tertiary ER3
- Customer is responsible for controlling outbound path selection to Azure
AS path prepending will not work for this scenario based on the requirements. EX: If on prem 1 send 10/8 with AS path 65001, on prem 2 send 10/8 AS path 65001,65001, on prem 3 sends 10/8 AS path 65001,65001,65001. All VNETs will select ER1 based on AS path length since we have equal prefix length advertisement and no connection weights. To solve this, you need to use connection weighting on each connection:

![alt text](https://github.com/jwrightazure/lab/blob/master/images/weightscenario3b.png)

# Scenario 4

![alt text](https://github.com/jwrightazure/lab/blob/master/images/weightscenario4.png)

In this scenario, the customer has offices in San Jose and San Francisco with VNETs located in West and North Central. They are also sending a 10/8 summary route both with AS path 65001. They would like to use ER1 as the primary path from on prem 1 and on prem2 to both VNETs. ER2 is lower bandwidth and should only be used if ER1 fails. Assuming the customer is controlling outbound path selection to Azure correctly, you can solve this with AS path prepending or weight. On prem 2 could send 10/6 and prepend the path to 65001,65001. This can also be solved with weight since (again) the VNET's are receiving the same prefix length and AS path length from 2 different connections. To solve this with weight, set the connection weight on conn1 and conn3 to >0.
