# Expressroute 802.1Q Tunneling (Q-in-Q)- draft
Some Expressroute service providers require customers to use 802.1Q tunneling (aka Q-in-Q) for circuit termination. Other Expressroute Service Providers have the ability to terminate Q-in-Q for the customer and provide Q trunks, VLAN tagged, or untagged packets to the customer. Expressroute details are outside the scope of this document. Other important items to consider when terminating Q-in-Q for Expressroute:

- Ethertype must be 0x8100
- A single Expressroute circuit is made up of 2 physical paths. Each physical path requires BGP peering to the Micrsoft Edge Routers (MSEEs).
- It's highly recommended that customers work with their provider to determine if the customer will receive 1 or 2 physical hand offs and the impact on path redundancy.
- Expressroute requires EBGP and does not support multihop.
- C-tags (inner tags) is a customer configurable VLAN you assign to your Expressroute circuit. Both paths for your circuit will be assigned the same VLAN (ex VLAN 100)
- S-tags (outer tags) are not customer configurable in Expressroute. S-tags are handled by your provider and Azure to ensure they are unique throughout their network. EX: customer defines VLAN 100 (C-tag) for the circuit. Azure will insert an outer S-tag (ex 1000) to encapsulate VLAN 100 and transport to the correct provider edge. The customer edge gear will receive S-tag 1000, strip the outer tag and will be presented the inner tag 100. It's CRITICAL to understand the physcal handoffs you receive from the provider, the hardware/software you are using for termination and if you will also be terminating BGP on the same gear (not all hardware/software supports that combination). You can acquire the S-tag from your provider if you are terminating Q-in-Q on customer equipment. 


This guide will show Q-in-Q basic configs as well as more advanced configurations specific to Expressroute topologies. All configurations are done using simulation software so syntax may be slightly different. 

![alt text](https://github.com/jwrightazure/lab/blob/master/Expressroute-Q-in-Q/q-in-q-topo.PNG)
