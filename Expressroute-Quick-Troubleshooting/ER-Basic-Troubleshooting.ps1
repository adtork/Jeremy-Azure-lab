Start-Transcript -Path "C:\transcripts\transcript0.txt"
# Variables
$SubID = 'XYZ'
$cktname = 'Circuit_Name'
$RG = 'Resource_Group'

Get-AzSubscription -SubscriptionId $SubID | Out-Null
Set-AzContext -SubscriptionId $SubID | Out-Null
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

Write-Host "Validate circuit Name, Resource Group it is in, provisioning state and circuit provisioning state" -ForegroundColor Cyan
Write-Host "Get-AzExpressRouteCircuit -Name $cktname -ResourceGroupName $RG | Select-Object Name,ResourceGroupName,ProvisioningState,CircuitProvisioningState | Format-Table" -ForegroundColor Green
Get-AzExpressRouteCircuit -Name $cktname -ResourceGroupName $RG | Select-Object Name,ResourceGroupName,ProvisioningState,CircuitProvisioningState | Format-Table

Write-Host "Verify primary path ARP. MAC addresses listed should match on prem interfaces" -ForegroundColor Cyan
Write-Host "Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -PeeringType AzurePrivatePeering -DevicePath Primary | Format-Table" -ForegroundColor Green
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -PeeringType AzurePrivatePeering -DevicePath Primary | Format-Table

Write-Host "Verify secondary path ARP. MAC addresses listed should match on prem interfaces" -ForegroundColor Cyan
Write-Host "Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -PeeringType AzurePrivatePeering -DevicePath Secondary | Format-Table" -ForegroundColor Green
Get-AzExpressRouteCircuitARPTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -PeeringType AzurePrivatePeering -DevicePath Secondary | Format-Table

Write-Host "Get Azure ASN, defined on prem ASN and peering info" -ForegroundColor Cyan
Write-Host "Get-AzexpressRouteCircuitPeeringConfig -Name "AzurePrivatePeering" -ExpressRouteCircuit $ckt | Select-Object AzureASN,PeerASN,PrimaryPeerAddressPrefix,SecondaryPeerAddressPrefix | Format-Table" -ForegroundColor Green
$ckt = Get-AzExpressRouteCircuit -Name $cktname -ResourceGroupName $RG
Get-AzexpressRouteCircuitPeeringConfig -Name "AzurePrivatePeering" -ExpressRouteCircuit $ckt | Select-Object AzureASN,PeerASN,PrimaryPeerAddressPrefix,SecondaryPeerAddressPrefix | Format-Table

Write-Host "Validate peer on primary path in AS 65100(on prem), BGP uptime and the number of prefixes on prem is advertising" -ForegroundColor Cyan
Write-Host "Get-AzExpressRouteCircuitRouteTableSummary -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Primary' -PeeringType AzurePrivatePeering | where-object {$_.AsProperty -eq “65100”} | Format-Table" -ForegroundColor Green
Get-AzExpressRouteCircuitRouteTableSummary -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Primary' -PeeringType AzurePrivatePeering | where-object {$_.AsProperty -eq “65100”} | Format-Table

Write-Host "Validate peer on secondary path in AS 65100(on prem), BGP uptime and the number of prefixes on prem is advertising" -ForegroundColor Cyan
Write-Host "Get-AzExpressRouteCircuitRouteTableSummary -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Secondary' -PeeringType AzurePrivatePeering | where-object {$_.AsProperty -eq “65100”} | Format-Table" -ForegroundColor Green
Get-AzExpressRouteCircuitRouteTableSummary -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Secondary' -PeeringType AzurePrivatePeering | where-object {$_.AsProperty -eq “65100”} | Format-Table

Write-Host "Validate what routes Azure is receiving from on prem on the Primary path" -ForegroundColor Cyan
Write-Host "Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Primary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65100”} | Format-Table" -ForegroundColor Green
Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Primary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65100”} | Format-Table

Write-Host "Validate what routes Azure is receiving from on prem on the Secondary path" -ForegroundColor Cyan
Write-Host "Get-AzexpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Secondary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65100”} | Format-Table" -ForegroundColor Green
Get-AzexpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Secondary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65100”} | Format-Table

Write-Host "Validate what VNET address spaces are seen on the Primary path(router)" -ForegroundColor Cyan
Write-Host "Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Primary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65515”} | Format-Table" -ForegroundColor Green
Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Primary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65515”} | Format-Table

Write-Host "Validate what VNET address spaces are seen on the Secondary path(router)" -ForegroundColor Cyan
Write-Host "Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Secondary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65515”} | Format-Table" -ForegroundColor Green
Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -DevicePath 'Secondary' -PeeringType AzurePrivatePeering| where-object {$_.Path -eq “65515”} | Format-Table

Write-Host "Validate paths are sending/receiving traffic" -ForegroundColor Cyan
Write-Host "Get-AzExpressRouteCircuitStats -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -PeeringType 'AzurePrivatePeering'" -ForegroundColor Green
Get-AzExpressRouteCircuitStats -ResourceGroupName $RG -ExpressRouteCircuitName $cktname -PeeringType 'AzurePrivatePeering'
Stop-Transcript
