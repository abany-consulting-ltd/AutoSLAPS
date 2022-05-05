

Function Create-HttpTriggerFunction {

    Param(
      [Parameter (Mandatory=$True)]
      [String] $funRG,
      [String] $funName,
      [String] $funLocation
    )

    $fnName = "Set-KeyVaultSecret"
    $FileContent = "$(Get-Content $PSScriptRoot/Set-KeyVaultSecret.ps1 -Raw)"

    $props = @{
        name = "Set-KeyVaultSecret"
        script_root_path_href = "https://$funName.azurewebsites.net/admin/vfs/site/wwwroot/Set-KeyVaultSecret/"
        script_href = "https://$funName.azurewebsites.net/admin/vfs/site/wwwroot/Set-KeyVaultSecret/run.ps1"
        config_href = "https://$funName.azurewebsites.net/admin/vfs/site/wwwroot/Set-KeyVaultSecret/function.json"
        test_data_href = "https://$funName.azurewebsites.net/admin/vfs/data/Functions/sampledata/Set-KeyVaultSecret.dat"
        href = "https://$funName.azurewebsites.net/admin/functions/Set-KeyVaultSecret"
            config = @{
                bindings = @(
                    @{
                    authLevel = "function"
                    type = "httpTrigger"
                    direction = "in"
                    webHookType = ""
                    name = "Request"
                    methods = "get,post"
                    }
                    @{
                    type = "http"
                    direction = "out"
                    name = "Response"
                    }
                )
        }
        files = @{
            "run.ps1" = $FileContent
        }
        test_data = $null
        invoke_url_template = "https://$funName.azurewebsites.net/api/set-keyvaultsecret"
        language = "powershell"
        isDisabled = false
    }

    New-AzResource -ResourceGroupName $funRG -ResourceType Microsoft.Web/sites/functions -ResourceName $funName/$fnName -Location $funLocation -PropertyObject $props -Force
}



$null = Start-Transcript -Path "$env:SystemRoot\TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))"

# == IMPORT VARIABLES =================================================================================================================
# -- Variabes to be set to suit your requirements within the variables.json file
$JSON = Get-Content -Raw -Path $PSScriptRoot/variables.json
$var = @{}
(ConvertFrom-Json $JSON).psobject.properties | Foreach-object { $var[$_.Name] = $_.Value }

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

if ($azTen) {} else {
    Write-Error "Unable to get values from variables.json"
    $null = Stop-Transcript
    exit
}

if (Get-AzContext) {} else {
    Connect-AzAccount -Tenant $azTen -SubscriptionId $azSub
}



if (Get-AzContext) {} else {
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

Start-Sleep 10

Create-HttpTriggerFunction -funRG $funRG -funName $funName -funLocation $funLocation


$null = Stop-Transcript