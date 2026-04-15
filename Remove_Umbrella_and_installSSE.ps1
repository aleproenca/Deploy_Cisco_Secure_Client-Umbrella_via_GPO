# ==================================================
# Configuracoes e caminhos
# ==================================================
$programData      = [System.Environment]::GetFolderPath('CommonApplicationData')
$secureClientPath = Join-Path $programData "Cisco\Cisco Secure Client\Umbrella\OrgInfo.json"
$umbrellaPath     = Join-Path $programData "Cisco\Cisco Secure Client\Umbrella\data\OrgInfo.json"
$dataFolderPath   = Join-Path $programData "Cisco\Cisco Secure Client\Umbrella\data"

# ==================================================
# Validacao OrgInfo
# ==================================================
$ValidateOnlyOrgId = $true

$expected = [PSCustomObject]@{
    organizationId = "5605000"
    region         = "global"
    userId         = "11189436"
}

$fixedContent = @'
{
  "organizationId": "5605000",
  "region": "global",
  "userId": "11189436"
}
'@

# ==================================================
# Instalador – Cisco Secure Client Deployment Tool
# ==================================================
$InstallerPath   = "C:\Temp\csc-deploy-full-CASTROLANDA-Default-CSA.exe"
$ProductNameLike = "Cisco Secure Client"

$ExeInstallArgs = @(
    "-q",
    "-c"
)

# ==================================================
# Marcador de instalacao (Registro)
# ==================================================
$InstallRegPath  = "HKLM:\Software\Castrolanda\CiscoSecureClient"
$InstallRegFlag  = "UmbrellaInstalled"
$InstallRegValue = 1

# ==================================================
# Funcoes utilitarias
# ==================================================
function Get-JsonSafe {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try { Get-Content -Raw $Path | ConvertFrom-Json } catch { return $null }
}

function Is-OrgInfoValid {
    param($Json, $Expected, [bool]$OnlyOrgId)

    if ($null -eq $Json) { return $false }

    if ($OnlyOrgId) {
        return ([string]$Json.organizationId -eq [string]$Expected.organizationId)
    }

    foreach ($prop in $Expected.PSObject.Properties.Name) {
        if ($Json.PSObject.Properties.Name -notcontains $prop) { return $false }
        if ([string]$Json.$prop -ne [string]$Expected.$prop) { return $false }
    }
    return $true
}

function Test-InstallationRegistry {
    try {
        if (Test-Path $InstallRegPath) {
            $v = Get-ItemProperty -Path $InstallRegPath -Name $InstallRegFlag -ErrorAction Stop
            return ($v.$InstallRegFlag -eq $InstallRegValue)
        }
    } catch {}
    return $false
}

function Set-InstallationRegistry {
    if (-not (Test-Path $InstallRegPath)) {
        New-Item -Path $InstallRegPath -Force | Out-Null
    }

    New-ItemProperty -Path $InstallRegPath -Name $InstallRegFlag -Value $InstallRegValue -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $InstallRegPath -Name "InstalledAt" -Value (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $InstallRegPath -Name "OrgId" -Value $expected.organizationId -PropertyType String -Force | Out-Null
}

function Try-StopServices {
    param([string[]]$Names)
    foreach ($n in $Names) {
        if (Get-Service -Name $n -ErrorAction SilentlyContinue) {
            Stop-Service -Name $n -Force
        }
    }
}

function Try-StartServices {
    param([string[]]$Names)
    foreach ($n in $Names) {
        if (Get-Service -Name $n -ErrorAction SilentlyContinue) {
            Start-Service -Name $n
        }
    }
}

function Remove-OldCiscoSecureClient {
    $apps = Get-ItemProperty `
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", `
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*$ProductNameLike*" }

    foreach ($app in $apps) {
        if ($app.UninstallString -match "MsiExec") {
            $cmd = $app.UninstallString -replace "/I", "/X"
            Start-Process cmd.exe "/c $cmd /qn /norestart" -Wait
        } elseif ($app.UninstallString) {
            Start-Process cmd.exe "/c `"$($app.UninstallString)`"" -Wait
        }
    }
}

function Install-NewCiscoSecureClient {
    if (-not (Test-Path $InstallerPath)) {
        throw "Instalador nao encontrado: $InstallerPath"
    }

    $p = Start-Process -FilePath $InstallerPath -ArgumentList $ExeInstallArgs -Wait -PassThru
    if ($p.ExitCode -ne 0) {
        throw "Falha na instalacao. ExitCode: $($p.ExitCode)"
    }
}

# ==================================================
# 1) Validacao inicial (Registro + OrgInfo)
# ==================================================
$secureJson   = Get-JsonSafe $secureClientPath
$umbrellaJson = Get-JsonSafe $umbrellaPath

if (
    (Test-InstallationRegistry) -and
    (
        (Is-OrgInfoValid $secureJson   $expected $ValidateOnlyOrgId) -or
        (Is-OrgInfoValid $umbrellaJson $expected $ValidateOnlyOrgId)
    )
) {
    Write-Host "Instalacao ja realizada e validada. Nada a fazer."
    exit 0
}

# ==================================================
# 2) Reinstalacao completa
# ==================================================
Remove-OldCiscoSecureClient
Install-NewCiscoSecureClient

Try-StopServices @("csc_umbrellaagent", "csc_swgagent")

if (Test-Path $dataFolderPath) {
    Remove-Item $dataFolderPath -Recurse -Force
}

$fixedContent | Set-Content -Path $secureClientPath -Force -Encoding utf8

if (-not (Test-Path (Split-Path $umbrellaPath))) {
    New-Item -ItemType Directory -Path (Split-Path $umbrellaPath) -Force | Out-Null
}

Copy-Item $secureClientPath $umbrellaPath -Force

Try-StartServices @("csc_umbrellaagent", "csc_swgagent")

# ==================================================
# 3) Validacao final + grava Registro
# ==================================================
$finalSecure   = Get-JsonSafe $secureClientPath
$finalUmbrella = Get-JsonSafe $umbrellaPath

if (
    (Is-OrgInfoValid $finalSecure   $expected $ValidateOnlyOrgId) -or
    (Is-OrgInfoValid $finalUmbrella $expected $ValidateOnlyOrgId)
) {
    Set-InstallationRegistry
    Write-Host "Instalacao concluida e registrada com sucesso."
    exit 0
}

Write-Warning "Falha na validacao final."
exit 1
``