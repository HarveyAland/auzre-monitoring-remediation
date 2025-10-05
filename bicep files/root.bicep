param location string = resourceGroup().location
param deployNetworking bool = false

@secure()
param win1AdminPassword string
@secure()
param win2AdminPassword string
@secure()
param linAdminPassword string

// These only get used if NOT deploying networking
param windowsSubnetId string = ''
param windowsSubnet2Id string = ''
param linuxSubnetId string = ''


// Resolve subnet IDs from either module outputs (day-0) or passed-in IDs (day-n)
var subnetIdWindows  = deployNetworking ? networking.outputs.windowsSubnetId  : windowsSubnetId
var subnetIdWindows2 = deployNetworking ? networking.outputs.windowsSubnet2Id : windowsSubnet2Id
var subnetIdLinux    = deployNetworking ? networking.outputs.linuxSubnetId    : linuxSubnetId

module networking 'networking.bicep' = if (deployNetworking) {
  name: 'networkingDeploy'
  params: {
    location: location
  }
}


module vm 'vm.bicep' = {
  name: 'vmDeploy'
  params: {
    location: location
    windowsSubnetId:  subnetIdWindows
    windowsSubnet2Id: subnetIdWindows2
    linuxSubnetId:    subnetIdLinux

    win1AdminPassword: win1AdminPassword
    win2AdminPassword: win2AdminPassword
    linAdminPassword:  linAdminPassword
  }
}

// Only output if networking deployed
output vnetId string = deployNetworking ? networking.outputs.vnetId : ''

