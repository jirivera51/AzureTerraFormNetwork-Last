param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName
)

try {
    Connect-AzAccount -Identity
    Write-Output "${action}ing all VMs in Resource Group: $ResourceGroupName"
    
    $vms = Get-AzVM -ResourceGroupName $ResourceGroupName -Status | Where-Object {$_.PowerState -eq 'VM running'}
    foreach ($vm in $vms) {
        Write-Output "${action}ing VM: $($vm.Name)"
        Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -Force -NoWait
    }
    
    Write-Output "All VM ${action} commands issued successfully"
}
catch {
    Write-Error "Failed to ${action} VMs: $_"
    throw
}