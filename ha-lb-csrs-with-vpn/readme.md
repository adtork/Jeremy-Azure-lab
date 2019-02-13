#placeholder
##You may have to accept the NVA agreement if you;ve never deployed this image before. This is just an example:##
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept

##Create CSR VNET and subnets##
az group create --name CSR --location "EastUS"
az network vnet create --name CSR --resource-group CSR --address-prefix 10.0.0.0/16
az network vnet subnet create --address-prefix 10.0.1.0/24 --name InsideSubnet --resource-group CSR --vnet-name CSR 
az network vnet subnet create --address-prefix 10.0.0.0/24 --name OutsideSubnet --resource-group CSR --vnet-name CSR
az network vnet subnet create --address-prefix 10.0.2.0/24 --name lbSubnet --resource-group CSR --vnet-name CSR
az network vnet subnet create --address-prefix 10.0.10.0/24 --name testVMSubnet --resource-group CSR --vnet-name CSR
az vm availability-set create --resource-group CSR --name myAvailabilitySet --platform-fault-domain-count 2 --platform-update-domain-count 2

##Create internal standard load balancer, probe and rule
az network lb create --name csr-lb --resource-group CSR --sku Standard --private-ip-address 10.0.2.100 --subnet lbsubnet --vnet-name CSR
az network lb address-pool create -g CSR --lb-name csr-lb -n csr-backendpool
az network lb probe create --resource-group CSR --lb-name csr-lb --name myHealthProbe --protocol tcp --port 22
az network lb rule create -g CSR --lb-name csr-lb -n MyHAPortsRule  --protocol All --frontend-port 0 --backend-port 0 --backend-pool-name csr-backendpool --floating-ip true --probe-name myHealthProbe

##Create NSG for CSR1##
az network nsg create --resource-group CSR --name Azure-CSR-NSG --location EastUS
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"
az network nsg rule create --resource-group CSR --nsg-name Azure-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"

##Create CSR1##
az network public-ip create --name CSR1PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR1OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR1PublicIP --private-ip-address 10.0.0.4 --ip-forwarding true --network-security-group Azure-CSR-NSG
az network nic create --name CSR1InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.4 --network-security-group Azure-CSR-NSG --lb-name csr-lb --lb-address-pools csr-backendpool
az vm create --resource-group CSR --location EastUS --name CSR1 --size Standard_D2_v2 --nics CSR1OutsideInterface CSR1InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108 --admin-username azureuser --admin-password Msft123Msft123 --availability-set myAvailabilitySet --no-wait

##Create CSR2##
####Create CSR2
az network public-ip create --name CSR2PublicIP --resource-group CSR --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR2OutsideInterface -g CSR --subnet OutsideSubnet --vnet CSR --public-ip-address CSR2PublicIP --private-ip-address 10.0.0.5 --ip-forwarding true --network-security-group Azure-CSR-NSG
az network nic create --name CSR2InsideInterface -g CSR --subnet InsideSubnet --vnet CSR --ip-forwarding true --private-ip-address 10.0.1.5 --network-security-group Azure-CSR-NSG --lb-name csr-lb --lb-address-pools csr-backendpool
az vm create --resource-group CSR --location EastUS --name CSR2 --size Standard_D2_v2 --nics CSR2OutsideInterface CSR2InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108 --admin-username azureuser --admin-password Msft123Msft123 --availability-set myAvailabilitySet --no-wait

##Create onprem VNET and subnets##
az group create --name onprem --location "East US2"
az network vnet create --name onprem --resource-group onprem --address-prefix 10.100.0.0/16
az network vnet subnet create --address-prefix 10.100.1.0/24 --name InsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.0.0/24 --name OutsideSubnet --resource-group onprem --vnet-name onprem
az network vnet subnet create --address-prefix 10.100.10.0/24 --name testVMSubnet --resource-group onprem --vnet-name onprem

##Create NSG for CSR3##
az network nsg create --resource-group onprem --name onprem-CSR-NSG --location EastUS2
az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC1 --access Allow --protocol Udp --direction Inbound --priority 100 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 500

az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name CSR-IPSEC2 --access Allow --protocol Udp --direction Inbound --priority 110 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range 4500

az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22

az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"

az network nsg rule create --resource-group onprem --nsg-name onprem-CSR-NSG --name Allow-Out --access Allow --protocol "*" --direction Outbound --priority 140 --source-address-prefix "*" --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"

##Create CSR3##
az network public-ip create --name CSR3PublicIP --resource-group onprem --idle-timeout 30 --allocation-method Static --sku standard
az network nic create --name CSR3OutsideInterface -g onprem --subnet OutsideSubnet --vnet onprem --public-ip-address CSR3PublicIP --private-ip-address 10.100.0.4 --ip-forwarding true --network-security-group onprem-CSR-NSG
az network nic create --name CSR3InsideInterface -g onprem --subnet InsideSubnet --vnet onprem --ip-forwarding true --private-ip-address 10.100.1.4 --network-security-group onprem-CSR-NSG

az vm create --resource-group onprem --location EastUS2 --name CSR3 --size Standard_D2_v2 --nics CSR3OutsideInterface CSR3InsideInterface  --image cisco:cisco-csr-1000v:16_10-byol:16.10.120190108  --admin-username azureuser --admin-password Msft123Msft123 --no-wait

##Create NSG for Azure side test VM##
az network nsg create --resource-group CSR --name Azure-VM-NSG --location EastUS

az network nsg rule create --resource-group CSR --nsg-name Azure-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22

az network nsg rule create --resource-group CSR --nsg-name Azure-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"

##Create Azure side VM##
az network public-ip create --name AzureVMPubIP --resource-group CSR --location EastUS --allocation-method Dynamic
az network nic create --resource-group CSR -n AzureVMNIC --location EastUS --subnet testVMSubnet --private-ip-address 10.0.10.10 --vnet-name CSR --public-ip-address AzureVMPubIP --network-security-group Azure-VM-NSG --ip-forwarding true
az vm create -n AzureVM -g CSR --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics AzureVMNIC --no-wait

##Create NSG for onprem side test VM##
az network nsg create --resource-group onprem --name onprem-VM-NSG --location EastUS2

az network nsg rule create --resource-group onprem --nsg-name onprem-VM-NSG --name Allow-SSH-All --access Allow --protocol Tcp --direction Inbound --priority 120 --source-address-prefix Internet --source-port-range "*" --destination-address-prefix "*" --destination-port-range 22

az network nsg rule create --resource-group onprem --nsg-name onprem-VM-NSG --name Allow-Tens --access Allow --protocol "*" --direction Inbound --priority 130 --source-address-prefix 10.0.0.0/8 --source-port-range "*" --destination-address-prefix "*" --destination-port-range "*"


##Create  onprem side VM##
az network public-ip create --name onpremVMPubIP --resource-group onprem --location EastUS2 --allocation-method Dynamic
az network nic create --resource-group onprem -n onpremVMNIC --location EastUS2 --subnet testVMSubnet --private-ip-address 10.100.10.10 --vnet-name onprem --public-ip-address onpremVMPubIP --network-security-group onprem-VM-NSG --ip-forwarding true
az vm create -n onpremVM -g onprem --image UbuntuLTS --admin-username azureuser --admin-password Msft123Msft123 --nics onpremVMNIC --no-wait

##Create a route table for the onprem side VM subnet. Routes include VTIs of both CSRs as well as the loopbacks for CSRs##

az network route-table create --name vm-rt --resource-group onprem
az network route-table route create --name vm-rt --resource-group onprem --route-table-name vm-rt --address-prefix 10.0.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4

az network route-table route create --name csr1-loopback --resource-group onprem --route-table-name vm-rt --address-prefix 1.1.1.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4

az network route-table route create --name csr1-vti --resource-group onprem --route-table-name vm-rt --address-prefix 192.168.1.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4

az network route-table route create --name csr3-loopback --resource-group onprem --route-table-name vm-rt --address-prefix 3.3.3.3/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4

az network route-table route create --name csr3-vti --resource-group onprem --route-table-name vm-rt --address-prefix 192.168.1.3/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.100.1.4

az network vnet subnet update --name testVMSubnet --vnet-name onprem --resource-group onprem --route-table vm-rt

##Create a route table for the CSR side VM subnet. Routes include VTIs of both CSRs as well as the loopbacks for CSRs##

az network route-table create --name vm-rt --resource-group CSR
az network route-table route create --name vm-rt --resource-group CSR --route-table-name vm-rt --address-prefix 10.100.0.0/16 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.2.100

az network route-table route create --name csr1-loopback --resource-group CSR --route-table-name vm-rt --address-prefix 1.1.1.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.2.100

az network route-table route create --name csr1-vti --resource-group CSR --route-table-name vm-rt --address-prefix 192.168.1.1/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.2.100

az network route-table route create --name csr3-loopback --resource-group CSR --route-table-name vm-rt --address-prefix 3.3.3.3/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.2.100

az network route-table route create --name csr3-vti --resource-group CSR --route-table-name vm-rt --address-prefix 192.168.1.3/32 --next-hop-type VirtualAppliance --next-hop-ip-address 10.0.2.100

az network vnet subnet update --name testVMSubnet --vnet-name CSR --resource-group CSR --route-table vm-rt

##Get public IPs for CSR1 and CSR3##
az network public-ip show -g CSR -n CSR1PublicIP --query "{address: ipAddress}"
az network public-ip show -g onprem -n CSR3PublicIP --query "{address: ipAddress}"

####
CSR1: 52.157.21.98
CSR3: 40.91.118.215
CSR1 config:

int gi1
no ip nat outside

int gi2
no ip nat inside

ip route 10.0.10.0 255.255.255.0 10.0.1.1
ip route 168.63.129.16 255.255.255.255 10.0.1.1

crypto ikev2 proposal to-csr3-proposal
  encryption aes-cbc-256
  integrity sha1
  group 2
  exit

crypto ikev2 policy to-csr3-policy
  proposal to-csr3-proposal
  match address local 10.0.0.4
  exit
  
crypto ikev2 keyring to-csr3-keyring
  peer 40.91.118.215
    address 40.91.118.215
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-csr3-profile
  match address local 10.0.0.4
  match identity remote address 10.100.0.4
  authentication remote pre-share
  authentication local  pre-share
  lifetime 3600
  dpd 10 5 on-demand
  keyring local to-csr3-keyring
  exit

crypto ipsec transform-set to-csr3-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-csr3-IPsecProfile
  set transform-set to-csr3-TransformSet
  set ikev2-profile to-csr3-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.1 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.0.0.4
  tunnel destination 40.91.118.215
  tunnel protection ipsec profile to-csr3-IPsecProfile
  exit 

int lo1
ip address 1.1.1.1 255.255.255.255

router bgp 65001
  bgp log-neighbor-changes
  neighbor 192.168.1.3 remote-as 65003
  neighbor 192.168.1.3 ebgp-multihop 255
  neighbor 192.168.1.3 update-source tunnel 11

  address-family ipv4
    network 10.0.0.0 mask 255.255.0.0
    network 1.1.1.1 mask 255.255.255.255
    network 192.168.1.1 mask 255.255.255.255
    neighbor 192.168.1.3 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 192.168.1.3 255.255.255.255 Tunnel 11
ip route 10.0.0.0 255.255.0.0 null0


###CSR3 config###
int gi1
no ip nat outside

int gi2
no ip nat inside

ip route 10.100.10.0 255.255.255.0 10.100.1.1

crypto ikev2 proposal to-csr1-proposal
  encryption aes-cbc-256
  integrity sha1
  group 2
  exit

crypto ikev2 policy to-csr1-policy
  proposal to-csr1-proposal
  match address local 10.100.0.4
  exit
  
crypto ikev2 keyring to-csr1-keyring
  peer 52.157.21.98
    address 52.157.21.98
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-csr1-profile
  match address local 10.100.0.4
  match identity remote address 10.0.0.4
  authentication remote pre-share
  authentication local  pre-share
  lifetime 3600
  dpd 10 5 on-demand
  keyring local to-csr1-keyring
  exit

crypto ipsec transform-set to-csr1-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-csr1-IPsecProfile
  set transform-set to-csr1-TransformSet
  set ikev2-profile to-csr1-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.3 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.100.0.4
  tunnel destination 52.157.21.98
  tunnel protection ipsec profile to-csr1-IPsecProfile
  exit

int lo1
ip address 3.3.3.3 255.255.255.255

router bgp 65003
  bgp log-neighbor-changes
  neighbor 192.168.1.1 remote-as 65001
  neighbor 192.168.1.1 ebgp-multihop 255
  neighbor 192.168.1.1 update-source tunnel 11

  address-family ipv4
    network 10.100.0.0 mask 255.255.0.0
    network 3.3.3.3 mask 255.255.255.255

    network 192.168.1.3 mask 255.255.255.255
    neighbor 192.168.1.1 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 192.168.1.1 255.255.255.255 Tunnel 11
ip route 10.100.0.0 255.255.0.0 null0




#Get CSR public IP
az network public-ip show -g CSR -n CSR2PublicIP --query "{address: ipAddress}"


##CSR2 (13.64.28.124)

int gi1
no ip nat outside

int gi2
no ip nat inside

ip route 10.0.10.0 255.255.255.0 10.0.1.1
ip route 168.63.129.16 255.255.255.255 10.0.1.1

crypto ikev2 proposal to-csr3-proposal
  encryption aes-cbc-256
  integrity sha1
  group 2
  exit

crypto ikev2 policy to-csr3-policy
  proposal to-csr3-proposal
  match address local 10.0.0.5
  exit
  
crypto ikev2 keyring to-csr3-keyring
  peer 40.91.118.215
    address 40.91.118.215
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-csr3-profile
  match address local 10.0.0.5
  match identity remote address 10.100.0.4
  authentication remote pre-share
  authentication local  pre-share
  lifetime 3600
  dpd 10 5 on-demand
  keyring local to-csr3-keyring
  exit

crypto ipsec transform-set to-csr3-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-csr3-IPsecProfile
  set transform-set to-csr3-TransformSet
  set ikev2-profile to-csr3-profile
  set security-association lifetime seconds 3600
  exit

int tunnel 11
  ip address 192.168.1.2 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.0.0.5
  tunnel destination 40.91.118.215
  tunnel protection ipsec profile to-csr3-IPsecProfile
  exit 

int lo1
ip address 2.2.2.2 255.255.255.255

router bgp 65002
  bgp log-neighbor-changes
  neighbor 192.168.1.33 remote-as 65003
  neighbor 192.168.1.33 ebgp-multihop 255
  neighbor 192.168.1.33 update-source tunnel 11

  address-family ipv4
    network 10.0.0.0 mask 255.255.0.0
    network 2.2.2.2 mask 255.255.255.255
    network 192.168.1.2 mask 255.255.255.255
    neighbor 192.168.1.33 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 192.168.1.3 255.255.255.255 Tunnel 11
ip route 10.0.0.0 255.255.0.0 null0

####CSR3 update#########################################
crypto ikev2 proposal to-csr2-proposal
  encryption aes-cbc-256
  integrity sha1
  group 2
  exit

crypto ikev2 policy to-csr2-policy
  proposal to-csr2-proposal
  match address local 10.100.0.4
  exit
  
crypto ikev2 keyring to-csr2-keyring
  peer 13.64.28.124
    address 13.64.28.124
    pre-shared-key Msft123Msft123
    exit
  exit

crypto ikev2 profile to-csr2-profile
  match address local 10.100.0.4
  match identity remote address 10.0.0.5
  authentication remote pre-share
  authentication local  pre-share
  lifetime 3600
  dpd 10 5 on-demand
  keyring local to-csr1-keyring
  exit

crypto ipsec transform-set to-csr2-TransformSet esp-gcm 256 
  mode tunnel
  exit

crypto ipsec profile to-csr2-IPsecProfile
  set transform-set to-csr2-TransformSet
  set ikev2-profile to-csr2-profile
  set security-association lifetime seconds 3600
  exit



int tunnel12
ip address 192.168.1.33 255.255.255.255
  tunnel mode ipsec ipv4
  ip tcp adjust-mss 1350
  tunnel source 10.100.0.4
  tunnel destination 52.157.21.98
  tunnel protection ipsec profile to-csr2-IPsecProfile
  exit

int lo1
ip address 33.33.33.33 255.255.255.255

router bgp 65003
  bgp log-neighbor-changes
  neighbor 192.168.1.2 remote-as 65002
  neighbor 192.168.1.2 ebgp-multihop 255
  neighbor 192.168.1.2 update-source tunnel 12

  address-family ipv4
    network 33.33.33.33 mask 255.255.255.255
    network 192.168.1.33 mask 255.255.255.255
    neighbor 192.168.1.2 activate    
    exit
  exit

!route BGP peer IP over the tunnel
ip route 192.168.1.2 255.255.255.255 Tunnel 12
