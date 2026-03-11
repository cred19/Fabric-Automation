param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CapacityResourceId,

    [Parameter(Mandatory = $true)]
    [ValidateSet("resume", "suspend")]
    [string]$Action
)

$apiVersion = "2023-11-01"

# Normalize Resource ID (remove trailing slash if present)
$normalizedResourceId = $CapacityResourceId.TrimEnd('/')

# Build URI correctly
$uriBuilder = [System.UriBuilder]::new("https://management.azure.com$normalizedResourceId/$Action")
$uriBuilder.Query = "api-version=$apiVersion"
$uri = $uriBuilder.Uri.AbsoluteUri

Write-Output "Fabric Capacity Resource ID: $normalizedResourceId"
Write-Output "Action: $Action"
Write-Output "Final REST URI: $uri"

# Authenticate using system-assigned managed identity
Write-Output "Authenticating using System-Assigned Managed Identity..."
Connect-AzAccount -Identity -ErrorAction Stop | Out-Null

# Acquire ARM access token
$token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com/").Token
if (-not $token) {
    throw "Failed to acquire ARM access token"
}

$headers = @{
    Authorization = "Bearer $token"
}

# Invoke Fabric capacity action (NO BODY)
try {
    Write-Output "Sending $Action request to Microsoft Fabric capacity..."
    Invoke-RestMethod `
        -Method POST `
        -Uri $uri `
        -Headers $headers `
        -ErrorAction Stop

    Write-Output "SUCCESS: $Action request accepted (202 expected)."
}
catch {
    Write-Error "FAILED: Unable to $Action Fabric capacity"

    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Error $reader.ReadToEnd()
    } else {
        Write-Error $_.Exception.Message
    }

    throw
}
