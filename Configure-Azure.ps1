


$null = Start-Transcript -Path "$env:SystemRoot\TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))"

# == IMPORT VARIABLES =================================================================================================================
# -- Variabes to be set to suit your requirements within the variables.json file
$JSON = Get-Content -Raw -Path $PSScriptRoot/variables.json
$var = @{}
(ConvertFrom-Json $varImport).psobject.properties | Foreach-object { $var[$_.Name] = $_.Value }

$azTen = $var.Azure_Tenent_ID
$azSub = $var.Azure_Subscription_ID

# AZURE VAULT
$vaultName = $var.Azure_Vault_Name
$vaultRG = $var.Azure_Vault_ResourceGroup
$vaultLocation = $var.Azure_Vault_Location

# AZURE FUNCTION
$funName = $var.Azure_Function_Name
$funRG = $var.Azure_Function_ResourceGroup
$funLocation = $var.Azure_Function_Location
$funStorage = $var.Azure_Storage_Name

# ------------------------------------------------------------------------------------------------------------------------------------

$AzSession = Connect-AzAccount -Tenant $azTen -SubscriptionId $azSub

if ($AzSession) {} else {
    Write-Error "Unable to establish session to AzureCloud"
    $null = Stop-Transcript
    exit
}


# Create the vault
try {
    $NewKeyVault = New-AzKeyVault -Name $vaultName -ResourceGroupName $vaultRG -Location $vaultLocation
}
catch {
    Write-Error $_
    $null = Stop-Transcript
    exit
}




# Create the function
try {
    $NewFunctionApp = New-AzFunctionApp -Name $funName -ResourceGroupName $funRG -Location $funLocation -StorageAccountName $funStorage -Runtime PowerShell
}
catch {
    Write-Error $_
    $null = Stop-Transcript
    exit
}

# Assign a managed service identity
Update-AzFunctionApp -Name $funName -ResourceGroupName $funRG -IdentityType SystemAssigned -Force

# Get the ObjectID of function
$funObj = (Get-AzADServicePrincipal -SearchString $funName).Id

# Configure access policy
Set-AzKeyVaultAccessPolicy -VaultName $vaultName -ObjectId $funObj -PermissionsToSecrets Get,Set


$null = Stop-Transcript