
# Objectives and Initial Setup
This lab guide shows how to configure highly available load balanced Cisco CSRs. Each CSR in Azure utilizes BGP over IKEv2 tunnel to a CSR located in a VNET that simulates an on prem environment. The test VM subnet on the Azure side will have UDRs pointed to an Azure Standard Load Balancer with a backend pool of the inside interfaces of CSR1 and CSR2. Traffic is load balanced across the 2 CSRs with the health probe monitoring the inside interfaces. In the event of a failure on CSR1 or CSR2, the load balancer will only steer traffic to the healthy CSR. BGP is also enabled between CSR1 and CSR2 providing tunnel redundancy if one of the tunnels goes down
The main goal of this lab is to quickly stand up a sandbox environment for functionality testing. The test VMs will be able to ping each other, all CSR interfaces including VTIs/loopbacks. Basic BGP prefix filters are in place to control route advertisement. Other methods could be used to filter routes. The entire environment is built on Azure and does not require any hardware. 

**Requirements:**
- A valid Azure subscription account. If you don’t have one, you can create your free azure account (https://azure.microsoft.com/en-us/free/) today.
- If you are using Windows 10, you can install Bash shell on Ubuntu on Windows (http://www.windowscentral.com/how-install-bash-shell-command-line-windows-10).
- Azure CLI 2.0, follow these instructions to install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
- Basic knowledge of Azure networking.

**Notes:**
This is for functionality testing purposes only and should not be considered production configurations. There are a number of configuration options (security policies/NSG/timers/CLI etc) and designs you can use, this is just an example to use as a baseline. Azure CLI is used to show the building blocks and order of operations to make the environment work. All CLI is provided so you can fit to your environment. Azure Cloud Shell is an option if you cannot install Azure CLI on your machine. A loopback address is added to each CSR for troubleshooting and validation purposes only. The lab uses CSR IOS-XE 16.10, syntax could very based on code levels. You may need to accept the legal agreement for the CSR BYOL demo image. Below is a Powershell example that you can run in Cloud Shell (in portal) to accept the agreement:
<pre lang="...">
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol"
Get-AzureRmMarketplaceTerms -Publisher "Cisco" -Product "cisco-csr-1000v" -Name "16_10-byol" | Set-AzureRmMarketplaceTerms -Accept
</pre>

