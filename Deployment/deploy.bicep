param prefix string
param environment string
param branch string
param location string
param subnetId string
param clientId string
@secure()
param clientSecret string
@secure()
param sshPublicKey string

var tags = {
  'stack-name': prefix
  'environment': environment
  'branch': branch
}

resource aks 'Microsoft.ContainerService/managedClusters@2021-05-01' = {
  name: prefix
  location: location
  tags: tags
  properties: {
    dnsPrefix: prefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        osDiskSizeGB: 60
        count: 1
        minCount: 1
        maxCount: 3
        enableAutoScaling: true
        vmSize: 'Standard_B2ms'
        osType: 'Linux'
        osDiskType: 'Managed'
        vnetSubnetID: subnetId
        tags: tags
      }
    ]
    servicePrincipalProfile: {
      clientId: clientId
      secret: clientSecret
    }
    linuxProfile: {
      adminUsername: 'appadmin'
      ssh: {
        publicKeys: [
          {
            keyData: sshPublicKey
          }
        ]
      }
    }
  }
}
