param($aksName, $acrName, $rgName)

az aks get-credentials --resource-group $aksName --name $rgName --overwrite-existing

# Associate ACR with AKS
az aks update -n $aksName -g $rgName --attach-acr $acrName