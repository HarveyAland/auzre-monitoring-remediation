// ==========================
// Parameters
// ==========================
param location string
param windowsSubnetId string
param windowsSubnet2Id string
param linuxSubnetId string


// ---- VM names & sizes (override if you want) ----
param win1Name string = 'win-iis-01'
param win2Name string = 'win-print-01'
param linName  string = 'lin-nginx-01'
param windowsVmSize string = 'Standard_B2ms'
param linuxVmSize   string = 'Standard_B2s'

@allowed([ '2022-datacenter-azure-edition', '2022-datacenter', '2019-datacenter' ])
param windowsSku string = '2022-datacenter'

// ---- Credentials (secure, one set per VM) ----
param win1AdminUsername string = 'azureuser'
@secure()
param win1AdminPassword string

param win2AdminUsername string = 'azureuser'
@secure()
param win2AdminPassword string

param linAdminUsername string = 'azureuser'
@secure()
param linAdminPassword string

// ==========================
// NICs
// ==========================
resource nicWin1 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${win1Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: windowsSubnetId }
          publicIPAddress: null
        }
      }
    ]
    enableIPForwarding: false
  }
}

resource nicWin2 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${win2Name}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: windowsSubnet2Id }
          publicIPAddress: null
        }
      }
    ]
    enableIPForwarding: false
  }
}

resource nicLin 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: '${linName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Dynamic'
          subnet: { id: linuxSubnetId }
          publicIPAddress: null
        }
      }
    ]
    enableIPForwarding: false
  }
}

// ==========================
// Windows VM #1 (IIS)
// ==========================
resource winVm1 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: win1Name
  location: location
  properties: {
    hardwareProfile: { vmSize: windowsVmSize }
    osProfile: {
      computerName: win1Name
      adminUsername: win1AdminUsername
      adminPassword: win1AdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsSku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        { id: nicWin1.id, properties: { primary: true } }
      ]
    }
    diagnosticsProfile: { bootDiagnostics: { enabled: true } }
  }
}
// IIS Install
resource win1Ext 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: winVm1
  name: 'installIIS'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -Command "Install-WindowsFeature -Name Web-Server -IncludeManagementTools"'
    }
  }
}



// ==========================
// Windows VM #2 (Print Spooler)
// ==========================
resource winVm2 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: win2Name
  location: location
  properties: {
    hardwareProfile: { vmSize: windowsVmSize }
    osProfile: {
      computerName: win2Name
      adminUsername: win2AdminUsername
      adminPassword: win2AdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: windowsSku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        { id: nicWin2.id, properties: { primary: true } }
      ]
    }
    diagnosticsProfile: { bootDiagnostics: { enabled: true } }
  }
}

// Install Print Server role and ensure Spooler running
resource win2Ext 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: winVm2
  name: 'installPrintServer'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Bypass -Command "Install-WindowsFeature Print-Server; Set-Service -Name Spooler -StartupType Automatic; Start-Service -Name Spooler"'
    }
  }
}

// ==========================
// Linux VM (nginx)
// ==========================
resource linVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: linName
  location: location
  properties: {
    hardwareProfile: { vmSize: linuxVmSize }
    osProfile: {
      computerName: linName
      adminUsername: linAdminUsername
      adminPassword: linAdminPassword
      linuxConfiguration: { disablePasswordAuthentication: false }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
      }
      dataDisks: []
    }
    networkProfile: {
      networkInterfaces: [
        { id: nicLin.id, properties: { primary: true } }
      ]
    }
    diagnosticsProfile: { bootDiagnostics: { enabled: true } }
  }
}

// Install nginx
resource linExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: linVm
  name: 'installNginx'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'bash -c "sudo apt-get update && sudo apt-get install -y nginx" '
    }
  }
}

// ==========================
// Outputs
// ==========================
output win1NicId string = nicWin1.id
output win2NicId string = nicWin2.id
output linNicId  string = nicLin.id
output win1VmId  string = winVm1.id
output win2VmId  string = winVm2.id
output linVmId   string = linVm.id
