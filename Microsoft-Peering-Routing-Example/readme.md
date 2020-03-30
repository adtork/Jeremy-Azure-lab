## 1. Microsoft Peering Routing Example

Microsoft peering [Microsoft Peering](https://docs.microsoft.com/en-us/azure/expressroute/expressroute-circuit-peerings) over Expressroute (ER) provides bi-direcitonal connectivity to Microsoft PAAS/SAAS public IPs. 
Microsoft public IPs will be advertised to you via BGP and it's up to the customer to choose where those routes get injected (internal, DMZ etc). A common design is to have Microsoft peering routes land into an isolated DMZ VRF/routing domain. The goal of this guide is to provide a high level overview of routing behaviors before and after ER and potential gotchas associated with Microsoft peering. Configurations are done on virtual devices so IPs/ASNs etc are simulated. The lab shows traffic initiated from on prem to Microsoft only. Routing shown is purely an example and can be solved a number of ways. Understanding the symmetric flows is key to a successful Microsoft Peering. 

Notes:
- You can deploy private peering and Microsoft peering over the same ER circuit. They are diffrent VRFs and requires seperate BGP sessions/VCs per VRF. This guide focuses on Microsoft peering only.
- Max 200 prefixes allowed to send from on prem to Microsoft peering
- Requires 2x publicly routable /30s that are owned by the customer or your provider. Azure support will need to validate (via opening a support case) that you own the prefixes you are setting up peering with as well as the prefixes you are advertising via BGP. Peering will not come up until verification is complete.
- Private and public ASNs are supported. Microsoft will strip any private ASNs in the AS path. The only potential downside of using private ASNs is when you have mutiple ER circuits with Microsoft peering (outside scope of this document).
- IPv4 and IPv6 addresses are supported
- Microsoft peering does not accept private IPs. You must NAT the private IPs to your public prefixes. This can be accomplished through PAT on the Microsoft peering interfaces. When using NAT pools or PAT, it's important to plan for and understand ephemeral port exhaustion. In general, NAT pools are recommended. The public NAT pool or PAT prefixes must be advertised into BGP towards Micrsoft. By default, Micrsoft will not inject the point to point /30s into the Microsoft routing domain. If you are using PAT, you must advertise the /30s into BGP from the PCE.
- After peering is established, you will not receive any Microsoft prefixes by default. In order to receive prefixes, you must attach route filters to the circuit. Filters identify certain services by name or region + BGP communities. https://docs.microsoft.com/en-us/azure/expressroute/how-to-routefilter-portal
- Office 365 over Microsoft peering is not allowed by default. You must contact your Microsoft account team to go through a "certification" process to enable the service. Office 365 over ER https://docs.microsoft.com/en-us/azure/expressroute/expressroute-prerequisites
- Do not send the entire public prefix you own over Microsoft peering as it could result in asymmetric traffic. 


## Lab topology without Microsoft peering:
![alt text](https://github.com/jwrightazure/lab/blob/master/images/msfrpeeringbasetopo.PNG)

The topology above shows the basic IP scheme layout. Core-r1 represents the on prem internal network in ASN 65001. There are 2 different VRFs (internal, internet) applied to CPE-r2 which could be the on prem router/fw. CPE-r2 owns public ASN 200, prefix 200.200/16 and is peering with Core-r1 via the local-as feature. CPE-r2 is also peering with Internet-r4 in ASN 400. R4 is advertising a default route to CPE-r2 and Microsoft as well as other routes learned vai BGP. R4 is also sending in aggregate/summary route for the 6x public /32 being learned from PAAS-SAAS-r7 which is the simulated Microsoft edge. Traffic initiated from on prem towards the Microsoft prefixes will follow the default route to r2, r2 will follow the aggregate or default, and r4 will route traffic to r7. R7 will see SIP from the NAT pool on r2 (200.200.50.10-.20). Important- r7 only sees the aggregate 200.200/16 to reach r2 (or it would follow the default). 
