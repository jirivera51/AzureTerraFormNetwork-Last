param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName
)

try {
    Connect-AzAccount -Identity
    Write-Output "${action}ing all VMs in Resource Group: $ResourceGroupName"
    
    $vms = Get-AzVM -ResourceGroupName $ResourceGroupName
    foreach ($vm in $vms) {
        Write-Output "${action}ing VM: $($vm.Name)"
        Start-AzVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -NoWait
    }
    
    Write-Output "All VM ${action} commands issued successfully"
}
catch {
    Write-Error "Failed to ${action} VMs: $_"
    throw
}