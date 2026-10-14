# MacBookPro11,4 (Intel Iris Pro, PCI\VEN_8086&DEV_0D26) Boot Camp black-screen fix.
# Run as Administrator. Run it twice:
#   1st time in Safe Mode  -> removes the Windows Update Intel driver, blocks WU drivers
#   2nd time in normal boot -> once Apple's 10.18.x driver is active, locks the device
param([switch]$Unlock)

$ErrorActionPreference = 'Continue'
$GoodVer = '10.18.15.4240'           # Apple Boot Camp driver (oem5.inf)
$DevId   = 'PCI\VEN_8086&DEV_0D26'

function Set-Reg($path, $name, $value) {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    New-ItemProperty -Path $path -Name $name -Value $value -PropertyType DWord -Force | Out-Null
}

$restr = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
if ($Unlock) {
    Remove-Item -Path $restr -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Device lock removed.' -ForegroundColor Yellow
    exit
}

# 1. Delete every Intel igdlh64 driver package except Apple's version
Get-ChildItem "$env:WINDIR\INF\oem*.inf" | ForEach-Object {
    $txt = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
    if ($txt -match 'igdlh64' -and $txt -match 'DriverVer\s*=\s*[^,]+,\s*([\d\.]+)') {
        $ver = $Matches[1]
        if ($ver -ne $GoodVer) {
            Write-Host "Removing $($_.Name) (Intel $ver)" -ForegroundColor Red
            pnputil /delete-driver $_.Name /uninstall /force
        } else {
            Write-Host "Keeping  $($_.Name) (Apple $ver)" -ForegroundColor Green
            $script:GoodInf = $_.Name
        }
    }
}

# 2. Stop Windows Update from shipping drivers at all
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' 'SearchOrderConfig' 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata' 'PreventDeviceMetadataFromNetwork' 1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork' 1
Write-Host 'Windows Update driver delivery disabled.' -ForegroundColor Green

# 3. Disable Fast Startup/hibernation so macOS can safely access BOOTCAMP
powercfg /h off

# 4. If Apple's driver is the active one, forbid any further driver install on the GPU
$gpu = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceID -like "$DevId*" } | Select-Object -First 1
Write-Host "Active GPU driver: $($gpu.DriverVersion) ($($gpu.InfName))"
if ($gpu.DriverVersion -eq $GoodVer) {
    Set-Reg $restr 'DenyDeviceIDs' 1
    Set-Reg $restr 'DenyDeviceIDsRetroactive' 0
    $list = "$restr\DenyDeviceIDs"
    if (-not (Test-Path $list)) { New-Item -Path $list -Force | Out-Null }
    New-ItemProperty -Path $list -Name '1' -Value $DevId -PropertyType String -Force | Out-Null
    Write-Host 'GPU driver LOCKED. Nothing can replace it now. (undo: run with -Unlock)' -ForegroundColor Green
} else {
    if ($script:GoodInf -and -not (Get-CimInstance Win32_ComputerSystem).BootupState.Contains('Fail-safe')) {
        Write-Host "Installing Apple driver $script:GoodInf ..." -ForegroundColor Yellow
        pnputil /add-driver "$env:WINDIR\INF\$script:GoodInf" /install
    }
    Write-Host 'Apple driver not active yet -> reboot normally, then run this script again to lock.' -ForegroundColor Yellow
}
Read-Host 'Done. Press Enter'
