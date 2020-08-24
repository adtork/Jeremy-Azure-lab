## Microsoft BGP Peering Quick Reference
This is a quick reference to find basic information on Microsoft BGP Peering prefix and community information. All commands are done in Powershell. The examples shown are using shell.azure.com. Outputs can be piped to a file.

**Show all Microsoft Peering BGP community names, values and prefixes. Output not included.**
<pre lang="...">
Get-AzureRmBgpServiceCommunity
</pre>

**Show total amount of BGP communities.**
<pre lang="...">
$BGPCommunityCount = Get-AzureRmBgpServiceCommunity
$BGPCommunityCount.name
$BGPCommunityCount.Name.Count
</pre>
![alt text](https://github.com/jwrightazure/lab/blob/master/images/bgp%20count.PNG)

**Show only the names of all BGP communities. Output not included.**
<pre lang="...">
$BGPName = Get-AzureRmBgpServiceCommunity
$BGPName.name
</pre>

**Show only information for the "AzureStorageEastUS" community. Output truncated.**
<pre lang="...">
Get-AzureRmBgpServiceCommunity | Where-Object { $_.Name -eq "AzureStorageEastUS" }
</pre>
![alt text](https://github.com/jwrightazure/lab/blob/master/images/bgpstoragecommunity.PNG)

**Show prefix count for the "AzureStorageEastUS" community.**
<pre lang="...">
$BGPstoragecount = Get-AzureRmBgpServiceCommunity | Where-Object { $_.Name -eq "AzureStorageEastUS" }
$BGPstoragecount.BgpCommunities.CommunityPrefixes.Count
</pre>
![alt text](https://github.com/jwrightazure/lab/blob/master/images/bgpstorageprefixcount.PNG)

**Show community value only for "AzureStorageEastUS".**
<pre lang="...">
$BGPStorageCommunity = Get-AzureRmBgpServiceCommunity | Where-Object { $_.Name -eq "AzureStorageEastUS" }
$BGPStorageCommunity.BgpCommunities.CommunityValue
</pre>
![alt text](https://github.com/jwrightazure/lab/blob/master/images/bgpstoragecommunityvalue.PNG)

Get-AzureRmBgpServiceCommunity | Where-Object { $_.Name -eq "AzureEastUS" }
