# Expressroute 802.1ad (Q-in-Q)- draft
Some Expressroute service providers require customers to use 802.ad tunneling (aka Q-in-Q) for circuit termination. Other Expressroute Service Providers have the ability to terminate Q-in-Q for the customer and provide Q trunks, VLAN tagged, or untagged packets to the customer. This guide is intended to provide a high level overview of Q-in-Q functionality as well as example configurations for common Expressroute topologies. Expressroute details are outside the scope of this document. 

**Important items to consider when terminating Q-in-Q for Expressroute**

- Ethertype must be 0x8100 (any reference to 0x9100 is specific to my lab only)
- A single Expressroute circuit is made up of 2 physical paths. Each physical path requires BGP peering to the Micrsoft Edge Routers (MSEEs).
- It's highly recommended that customers work with their provider to determine if the customer will receive 1 or 2 physical hand offs and the impact on path redundancy.
- Expressroute requires EBGP and does not support multihop.
- C-tags (inner tags) is a customer configurable VLAN you assign to your Expressroute circuit. Both paths for your circuit will be assigned the same VLAN (ex VLAN 100). More on that later.
- S-tags (outer tags) are not customer configurable in Expressroute. S-tags are handled by your provider and Azure to ensure they are unique throughout their network. (ex VLAN 1000). There are 2 Micrsoft edge routers (MSEEs) that provide connectivity for a single Expressroute circuit. MSEE1/2 will send out the same S-tag for both paths.
- If the provider terminates Q-in-Q on behalf of the customer, Azure and the provider will take care of adding/removing the S-tag.
- If the customer is terminating Q-in-Q, the customer edge gear will receive S-tag 1000, strip the outer tag and will be presented the inner tag 100. It's CRITICAL to understand the physcal handoffs you receive from the provider, the hardware/software you are using for termination and if you will also be terminating BGP on the same gear (not all hardware/software supports that combination). 
- You can acquire the S-tag from your provider if you are terminating Q-in-Q on customer equipment. The S-tag between Azure and the provider can't be changed. Some providers will allow you to change the S-tag between the provider edge and customer edge if the customer needs a specific S-tag.


This guide will show Q-in-Q basic configs as well as more advanced configurations specific to Expressroute topologies. All configurations are done using simulation software so syntax may be slightly different. 

# Basic Q-in-Q topology, configuration and order of operations. This is not an Expressroute topology.
![alt text](https://github.com/jwrightazure/lab/blob/master/Expressroute-Q-in-Q/basics.png)

In the above topology, R1 and R2 interfaces are on the same subnet seperated by the service provider Q-in-Q network. R1 and R2 interfaces will tag packets as VLAN 100. The service provider switches will tunnel any tagged packets it receives from the customer with S-tag 1000. The service provider network knows nothing about customer VLAN 100 (C-tag) and simply switches VLAN 1000 (S-tag) throughout their network. In this topology, the service provider switches facing the customer are responsible for stripping the S-tag.

# Back to back Q-in-Q 
![alt text](https://github.com/jwrightazure/lab/blob/master/Expressroute-Q-in-Q/b2b.png)

In the back to back example, you can see that you can have multiple S-tags (1000,2000) arrive on different logical interfaces and present the same C-tag (100).  When a customer terminates Q-in-Q on a single physical interface (2 logical interfaces), the S-tag must be unique. If the customer terminates Q-in-Q on seperate physical interfaces on the same device, the S-tag can be the same. Please check your hardware/software to validate.

# Lab 1 - Expressroute with single CE, single handoff from provider
![alt text](https://github.com/jwrightazure/lab/blob/master/Expressroute-Q-in-Q/Lab1-configs/lab1-topo.png)

Lab 1 shows a basic L2 Expressroute topology where the provider is only giving 1 physical handoff to the CE. As previously mentioned, each Microsoft Edge router (MSEE) will send the SAME S-tag to the provider switch(es). Most, if not all providers will have the ability to rewrite outer tags. For simplicity purposes, I've configured each MSEE to send a unique S-tag instead of rewriting S-tag at the switch level. The CE is terminating Q-in-Q on a single interface. Remember, depending on your edge HW/SW, you probably cannot terminate the same S-tag on 2 different subinterfaces belonging to the same single physical interface. For any Q-in-Q deployment, it's IMPORTANT to understand how many handoffs you will be receiving from the provider and your edge HW/SW capabilities as well as provider options for S-tag rewrites. Each subinterface is configured to receive a unique S-tag (1000,2000), and the same C-tag (100). C-tag 100 is what the customer configures as the VLAN associated to the Expressroute circuit. The CE is BGP peering with both MSEEs, sending a summary route of 10/8. The simulated VNET is 10.10.10/24. The provider switch only knows about VLAN 1000 and 2000 (S-tags) but doesn't know about customer VLAN 100 (C-tag). Device configurations are provided in the Lab1-configs folder.

# Lab 2 - Expressroute with single CE, multiple handoffs from provider
![alt text](https://github.com/jwrightazure/lab/blob/master/Expressroute-Q-in-Q/Lab2-configs/sr-mi.png)

