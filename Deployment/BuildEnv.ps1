param(
    [string]$NETWORKING_PREFIX, 
    [string]$BUILD_ENV, 
    [string]$RESOURCE_GROUP, 
    [string]$PREFIX,
    [string]$GITHUB_REF,
    [string]$CLIENT_ID,
    [string]$CLIENT_SECRET,
    [string]$SSH_PUBLIC_KEY,
    [string]$MANAGED_USER_ID,
    [string]$RUN_NUMBER)

$ErrorActionPreference = "Stop"

$deploymentName = "aksdeploy" + (Get-Date).ToString("yyyyMMddHHmmss")
$platformRes = (az resource list --tag stack-name=$NETWORKING_PREFIX | ConvertFrom-Json)
if (!$platformRes) {
    throw "Unable to find eligible Virtual Network resource!"
}
if ($platformRes.Length -eq 0) {
    throw "Unable to find 'ANY' eligible Virtual Network resource!"
}
$vnet = ($platformRes | Where-Object { $_.type -eq "Microsoft.Network/virtualNetworks" -and $_.name.Contains("-pri-") -and $_.resourceGroup.EndsWith("-$BUILD_ENV") })
if (!$vnet) {
    throw "Unable to find Virtual Network resource!"
}
$vnetRg = $vnet.resourceGroup
$vnetName = $vnet.name
$location = $vnet.location
$subnets = (az network vnet subnet list -g $vnetRg --vnet-name $vnetName | ConvertFrom-Json)
if (!$subnets) {
    throw "Unable to find eligible Subnets from Virtual Network $vnetName!"
}          
$subnetId = ($subnets | Where-Object { $_.name -eq "aks" }).id
if (!$subnetId) {
    throw "Unable to find Subnet resource!"
}

$rgName = "$RESOURCE_GROUP-$BUILD_ENV"
$deployOutputText = (az deployment group create --name $deploymentName --resource-group $rgName --template-file Deployment/deploy.bicep --parameters `
        location=$location `
        prefix=$PREFIX `
        environment=$BUILD_ENV `
        branch=$GITHUB_REF `
        clientId=$CLIENT_ID `
        clientSecret=$CLIENT_SECRET `
        sshPublicKey="$SSH_PUBLIC_KEY" `
        managedUserId=$MANAGED_USER_ID `
        subnetId=$subnetId)

$deployOutput = $deployOutputText | ConvertFrom-Json
$acrName = $deployOutput.properties.outputs.acrName.value

if (!$acrName) {
    $deployOutputText
    return
}

$appName = "ContosoWeb"
dotnet new webapp -f net5.0 -n $appName
$content = Get-Content .\Deployment\Dockerfile
$content = $content.Replace("%WEB_APP_NAME%", $appName)
Set-Content -Path ./Dockerfile -Value $content
Push-Location $appName

# We will be using acr to build out the image.
# All container names MUST Be lowercase
$version = $RUN_NUMBER
$imageName = $appName.ToLower() + ":$version"
az acr build --image $imageName -r $acrName --file ./Dockerfile .
Pop-Location

$content = Get-Content .\Deployment\app.yaml
$content = $content.Replace("%ACR_NAME%", $acrName)
$content = $content.Replace("%VERSION%", $version)
Set-Content -Path myapp.yaml -Value $content

az aks install-cli
az aks get-credentials --resource-group $rgName --name $deployOutput.properties.outputs.aksName.value
kubectl create namespace contoso
kubectl apply -f myapp.yaml --namespace contoso