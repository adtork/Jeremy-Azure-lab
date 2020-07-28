# Cisco VPN to Azure using Shared Services VRF
Requirements- R2 provides an Azure DMZ VRF. The Azure DMZ VRF serves as a landing zone for internal customer VRFs and can use the VPN to Azure through the front door VRF Shared. Customer Segment A (R3) and Customer Segment B (R4) can communicate with Azure loopback 1.1.1.1. R3 and R4 cannot talk to each other.
This allows R2 to be a transit point to a shared VPN to Azure but keeps internal traffic segmented. MP-BGP over IPSEC is used for the tunnel between Azure and R2. MP-BGP is used between R2 and R3/4. This problem can be solved multiple ways and this is purely an example.

Notes:
- This is done using router simulation software. Configurations for the VPN to Azure will slightly vary.
- All router configurations are provided in this repo.
- Azure VPN does not allow you to create multiple connections to the same public IP.

# Base topology and VRF layout
![alt text](https://github.com/jwrightazure/lab/blob/master/Cisco-VPN-Azure-Shared-Services/shared-services-topo.PNG)
