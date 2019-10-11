# Azure Networking Lab- Basic BGP route control
This lab guide illustrates how to control basic BGP prefix control in/out of Azure. The lab is built on simulation software 
and is not using a live Azure VNET/Expressroute. The goal of the lab is to show default behavior of BGP route propagation. 
Some customers are sending numerous prefixes into Azure when a summary addres may be more efficient as well as controlling 
what is leaked into their infrastructure. There are a number of ways to address this challenge with BGP with this lab focusing 
on summary address behavior and outbound prefix control. This is for lab testing purposes only. 

# Base Topology
![alt text](https://github.com/jwrightazure/lab/blob/master/images/bgp-summary-lab.PNG)
