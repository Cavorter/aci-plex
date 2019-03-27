[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]    
    [ValidateNotNullOrEmpty()]    
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [SecureString]$Claim
)
$InformationPreference = "Continue"

$rgParams = @{
    Name     = "plex-cavort"
    Location = "centralus"
}
$rg = Get-AzResourceGroup @rgParams -ErrorAction SilentlyContinue
if ( $rg ) {
    Write-Information "Found existing resource group..."
}
else {
    Write-Information "Creating new resource group..."
    $rg = New-AzResourceGroup @rgParams
}

$deployParams = @{
    ResourceGroupName = $rg.ResourceGroupName
    Mode = "Incremental"
    TemplateParameterObject = @{
        instanceName = $Name
        plexClaim    = $Claim
    }
    TemplateFile ="$PSScriptRoot\template.json"
}

Write-Information "Testing deployment template with given parameters..."
Test-AzResourceGroupDeployment @deployParams

Write-Information "Executing deployment..."
$result = New-AzResourceGroupDeployment @deployParams

Write-Output $result
# Download a sample MP3 to post
# https://archive.org/download/Betty_Roche-Trouble_Trouble/Betty_Roche-Trouble_Trouble.mp3