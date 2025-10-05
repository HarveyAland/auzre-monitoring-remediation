// ==========================
// Parameters
// ==========================


@description('Location for all resources')
param location string = resourceGroup().location

@description('Virtual network name')
param vnetName string = 'infra-monitoring-vnet'

@description('VNet address space')
param vnetAddressSpace string = '10.0.0.0/16'

@description('Windows subnet address prefix')
param windowsSubnetPrefix string = '10.0.1.0/24'

@description('Windows subnet address prefix2')
param windowsSubnetPrefix2 string = '10.0.4.0/24'

@description('Linux subnet address prefix')
param linuxSubnetPrefix string = '10.0.2.0/24'

@description('Bastion subnet prefix (must be named AzureBastionSubnet)')
param bastionSubnetPrefix string = '10.0.3.0/26'

@description('Base name for resources')
param namePrefix string = 'aim-dev'

@description('NSG rule priority base (smaller = higher precedence)')
param nsgPriorityBase int = 200

// ==========================
// Variables - Common Tags
// ==========================
var commonTags = {
  env: 'lab'
  owner: 'yourname'
  costCenter: 'infra'
}

// ==========================
// Network Security Groups
// ==========================
resource nsgWindows 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${namePrefix}-nsg-windows'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-From-Bastion'
        properties: {
          priority: nsgPriorityBase
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefixes: [
            windowsSubnetPrefix
            windowsSubnetPrefix2
          ]
        }
      }
    ]
  }
}

resource nsgLinux 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${namePrefix}-nsg-linux'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH-From-Bastion'
        properties: {
          priority: nsgPriorityBase
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: bastionSubnetPrefix
          destinationAddressPrefix: linuxSubnetPrefix
        }
      }
    ]
  }
}

// ==========================
// Virtual Network (no inline subnets)
// ==========================
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: commonTags
  properties: {
    addressSpace: { addressPrefixes: [ vnetAddressSpace ] }
  }
}

// ==========================
// Subnets as child resources (addressable)
// ==========================
resource subnetWindows 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  name: '${vnet.name}/subnet-windows'
  properties: {
    addressPrefix: windowsSubnetPrefix
    networkSecurityGroup: { id: nsgWindows.id }
  }
}

resource subnetWindows2 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  name: '${vnet.name}/subnet-windows2'
  properties: {
    addressPrefix: windowsSubnetPrefix2
    networkSecurityGroup: { id: nsgWindows.id }
  }
}

resource subnetLinux 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  name: '${vnet.name}/subnet-linux'
  properties: {
    addressPrefix: linuxSubnetPrefix
    networkSecurityGroup: { id: nsgLinux.id }
  }
}
resource subnetBastion 'Microsoft.Network/virtualNetworks/subnets@2023-09-01' = {
  name: '${vnet.name}/AzureBastionSubnet' // exact name required
  properties: {
    addressPrefix: bastionSubnetPrefix
  }
}




// ==========================
// Bastion Public IP
// ==========================
resource bastionPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: '${namePrefix}-bastion-pip'
  location: location
  tags: commonTags
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

// ==========================
// Bastion Host
// ==========================
resource bastion 'Microsoft.Network/bastionHosts@2023-09-01' = {
  name: '${namePrefix}-bastion'
  location: location
  tags: commonTags
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          subnet: {
            id: subnetBastion.id
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

// ==========================
// Outputs
// ==========================
output vnetId string = vnet.id
output windowsSubnetId string = subnetWindows.id
output linuxSubnetId string = subnetLinux.id
output windowsSubnet2Id string = subnetWindows2.id
