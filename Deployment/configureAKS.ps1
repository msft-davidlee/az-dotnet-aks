param($aksName, $acrName, $rgName)

Install-AzAksKubectl -Version latest
Import-AzAksCredential -ResourceGroupName $rgName -Name $aksName

# Associate ACR with AKS
Set-AzAksCluster -ResourceGroupName $rgName -Name $aksName -AcrNameToAttach $acrName