param(
    [Parameter(Mandatory=$true)]
    [string]$Wsl2VmName,

    [Parameter(Mandatory=$true)]
    [int]$Port = 2375

    [Parameter()]
    [bool]$SetDefault = $true
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

function Write-VerboseLog {
    param([string]$Message)
    Write-Verbose $Message
}

try {
    $contextName = "wsl2-$Wsl2VmName"

    # Get the IP address of the WSL2 VM
    Write-VerboseLog "Retrieving IP address for WSL2 VM '$Wsl2VmName'..."
    $ipOutput = wsl -d $Wsl2VmName hostname -I 2>$null
    if (-not $ipOutput) {
        throw "Could not retrieve IP address for WSL2 VM '$Wsl2VmName'."
    }
    $Wsl2Ip = ($ipOutput -split '\s+' | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' })[0]
    if (-not $Wsl2Ip) {
        throw "Could not parse IPv4 address from WSL2 VM '$Wsl2VmName'."
    }
    Write-VerboseLog "WSL2 VM IP address: $Wsl2Ip"

    $Wsl2Ip = $Wsl2Ip.Trim()
    $dockerHost = "tcp://$($Wsl2Ip):$Port"

    Write-VerboseLog "Checking for existing Docker context '$contextName'..."

    # Remove existing context if it exists
    $existingContext = docker context ls --format '{{.Name}}' | Where-Object { $_ -eq $contextName }
    if ($existingContext) {
        Write-VerboseLog "Context '$contextName' already exists. Removing it first."
        $null = docker context rm $contextName -f
    }

    Write-VerboseLog "Creating Docker context '$contextName' for WSL2 VM '$Wsl2VmName' on $dockerHost..."

    # Create the new context
    $output = docker context create $contextName --docker "host=$dockerHost"
    Write-VerboseLog $output

    # Optionally set as default
    if ($SetDefault) {
        Write-VerboseLog "Setting '$contextName' as the default Docker context..."
        $null = docker context use $contextName
        Write-Host "Docker context '$contextName' is now set as default." -ForegroundColor Yellow
    }

    # List contexts for verification
    Write-VerboseLog "Listing all Docker contexts:"
    docker context ls | Write-VerboseLog

    # Test the new context
    Write-VerboseLog "Testing Docker context '$contextName'..."
    docker --context $contextName info | Write-VerboseLog

    Write-Host "Docker context '$contextName' created and tested successfully." -ForegroundColor Green
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}