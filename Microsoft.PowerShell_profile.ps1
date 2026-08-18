### PowerShell Profile Refactor
### Version 1.09 - Optimized iCloud Profile

# ---------------------------------------------------------------------------
# Profile startup diagnostics
# ---------------------------------------------------------------------------
# Ideiglenesen hagyd $true értéken. Ha befejeztük a mérést, állítsd $false-ra.
$EnableProfileTiming = $false
$ProfileStartupTimer = [System.Diagnostics.Stopwatch]::StartNew()
$ProfileLastCheckpoint = [double]0

function Show-ProfileTiming {
    param([Parameter(Mandatory)][string]$Name)

    if (-not $EnableProfileTiming) {
        return
    }

    $total = $ProfileStartupTimer.Elapsed.TotalMilliseconds
    $block = $total - $ProfileLastCheckpoint

    Write-Host ("[PROFILE] {0,-30} block: {1,8:N1} ms   total: {2,8:N1} ms" -f $Name, $block, $total) -ForegroundColor DarkGray
    $script:ProfileLastCheckpoint = $total
}

$debug = $false

#################################################################################################################################
############                                                                                                         ############
############                                          !!!   WARNING:   !!!                                           ############
############                                                                                                         ############
############                PERSONAL POWERSHELL PROFILE - OPTIMIZED FOR FAST STARTUP.                  ############
############                    UPDATES CAN BE PULLED MANUALLY WITH Update-Profile FROM                      ############
############                       https://github.com/mereszpingvin/powershell-profile-icloud.git.                         ############
############                                                                                                         ############
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!#
############                                                                                                         ############
############                      TO ADD YOUR OWN CODE OR IF YOU WANT TO OVERRIDE ANY OF THESE VARIABLES             ############
############                      OR FUNCTIONS. USE THE Edit-Profile FUNCTION TO CREATE YOUR OWN profile.ps1 FILE.   ############
############                      TO OVERRIDE IN YOUR NEW profile.ps1 FILE, REWRITE THE VARIABLE                     ############
############                      OR FUNCTION, ADDING "_Override" TO THE NAME.                                       ############
############                                                                                                         ############
############                      THE FOLLOWING VARIABLES RESPECT _Override:                                         ############
############                      $EDITOR_Override                                                                   ############
############                      $debug_Override                                                                    ############
############                      $repo_root_Override  [To point to a fork, for example]                             ############
############                                                                                                         ############
############                      THE FOLLOWING FUNCTIONS RESPECT _Override:                                         ############
############                      Debug-Message_Override                                                             ############
############                      Update-PowerShell_Override                                                         ############
############                      Clear-Cache_Override                                                               ############
#################################################################################################################################

if ($debug_Override){
    # If variable debug_Override is defined in profile.ps1 file
    # then use it instead
    $debug = $debug_Override
} else {
    $debug = $false
}

# Saját GitHub profil/repository.
# A repo legyen publikus, ha a raw.githubusercontent.com URL-t használod.
$ProfileRepoOwner  = "mereszpingvin"
$ProfileRepoName   = "powershell-profile-icloud"
$ProfileRepoBranch = "main"
$ProfileRepoFile   = "Microsoft.PowerShell_profile.ps1"

if ($repo_root_Override) {
    $repo_root = $repo_root_Override
} else {
    $repo_root = "https://raw.githubusercontent.com/$ProfileRepoOwner/$ProfileRepoName/$ProfileRepoBranch"
}

# Helper function for cross-edition compatibility
function Get-ProfileDir {
    if ($PSVersionTable.PSEdition -eq "Core") {
        return [Environment]::GetFolderPath("MyDocuments") + "\PowerShell"
    } elseif ($PSVersionTable.PSEdition -eq "Desktop") {
        return [Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell"
    } else {
        Write-Error "Unsupported PowerShell edition: $($PSVersionTable.PSEdition)"
        return $null
    }
}

function Debug-Message{
    # If function "Debug-Message_Override" is defined in profile.ps1 file
    # then call it instead.
    if (Get-Command -Name "Debug-Message_Override" -ErrorAction SilentlyContinue) {
        Debug-Message_Override
    } else {
        Write-Host "#######################################" -ForegroundColor Red
        Write-Host "#           Debug mode enabled        #" -ForegroundColor Red
        Write-Host "#          ONLY FOR DEVELOPMENT       #" -ForegroundColor Red
        Write-Host "#                                     #" -ForegroundColor Red
        Write-Host "#       IF YOU ARE NOT DEVELOPING     #" -ForegroundColor Red
        Write-Host "#       JUST RUN \`Update-Profile\`     #" -ForegroundColor Red
        Write-Host "#        to discard all changes       #" -ForegroundColor Red
        Write-Host "#   and update to the latest profile  #" -ForegroundColor Red
        Write-Host "#               version               #" -ForegroundColor Red
        Write-Host "#######################################" -ForegroundColor Red
    }
}

if ($debug) {
    Debug-Message
}

Show-ProfileTiming "Initial configuration"

# Opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# Nincs induláskori GitHub ping. A hálózatot csak a kézzel indított
# Update-Profile / Update-PowerShell funkciók használják.

# Startup feature switches
$EnableTerminalIcons   = $true
$LoadChocolateyProfile = $false
$EnableOhMyPosh        = $true
$EnableZoxide          = $true

# Import Modules and External Profiles
# Telepítést soha ne végezzünk profilbetöltés közben.
if ($EnableTerminalIcons) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
}
Show-ProfileTiming "Terminal-Icons"

# A Chocolatey profil főleg tab-completiont ad, ezért gyors indulásnál
# alapértelmezetten nincs betöltve.
if ($LoadChocolateyProfile -and $env:ChocolateyInstall) {
    $ChocolateyProfile = Join-Path $env:ChocolateyInstall 'helpers\chocolateyProfile.psm1'
    if (Test-Path -LiteralPath $ChocolateyProfile) {
        Import-Module $ChocolateyProfile -ErrorAction SilentlyContinue
    }
}
Show-ProfileTiming "Chocolatey profile"

# ---------------------------------------------------------------------------
# Profile update
# ---------------------------------------------------------------------------
# A gyors indulás érdekében alapértelmezetten nincs hálózati ellenőrzés.
# Frissítés kézzel: Update-Profile
$EnableAutomaticProfileUpdateCheck = $false
$ProfileUpdateCheckIntervalDays = 7
$ProfileUpdateStamp = Join-Path (Get-ProfileDir) 'LastProfileUpdateCheck.txt'

function Test-ProfileUpdateDue {
    if (-not (Test-Path -LiteralPath $ProfileUpdateStamp)) {
        return $true
    }

    $raw = Get-Content -LiteralPath $ProfileUpdateStamp -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $true
    }

    [datetime]$stamp = [datetime]::MinValue
    if (-not [datetime]::TryParseExact(
        $raw.Trim(),
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None,
        [ref]$stamp
    )) {
        return $true
    }

    return (((Get-Date).Date - $stamp.Date).TotalDays -ge $ProfileUpdateCheckIntervalDays)
}

function Update-Profile {
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    $url = "$repo_root/$ProfileRepoFile"
    $tempFile = Join-Path $env:TEMP "Microsoft.PowerShell_profile.$PID.ps1"
    $backupFile = "$PROFILE.bak"

    try {
        if (-not $Quiet) {
            Write-Host "Profil frissítés ellenőrzése: $ProfileRepoOwner/$ProfileRepoName ($ProfileRepoBranch)" -ForegroundColor Cyan
        }

        Invoke-WebRequest -Uri $url -OutFile $tempFile -TimeoutSec 10 -ErrorAction Stop

        $downloadedText = Get-Content -LiteralPath $tempFile -Raw -ErrorAction Stop
        [void][scriptblock]::Create($downloadedText)

        $oldHash = (Get-FileHash -LiteralPath $PROFILE -Algorithm SHA256).Hash
        $newHash = (Get-FileHash -LiteralPath $tempFile -Algorithm SHA256).Hash

        if ($oldHash -eq $newHash) {
            if (-not $Quiet) {
                Write-Host "A PowerShell profil naprakész." -ForegroundColor Green
            }
            return
        }

        Copy-Item -LiteralPath $PROFILE -Destination $backupFile -Force
        Copy-Item -LiteralPath $tempFile -Destination $PROFILE -Force

        Write-Host "A PowerShell profil frissítve lett." -ForegroundColor Green
        Write-Host "Biztonsági másolat: $backupFile" -ForegroundColor DarkGray
        Write-Host "Indíts új PowerShell munkamenetet a módosítások betöltéséhez." -ForegroundColor Yellow
    }
    catch {
        Write-Warning "A profil frissítése sikertelen: $($_.Exception.Message)"
    }
    finally {
        Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    }
}

if ($EnableAutomaticProfileUpdateCheck -and (Test-ProfileUpdateDue)) {
    Update-Profile -Quiet
    (Get-Date -Format 'yyyy-MM-dd') | Set-Content -LiteralPath $ProfileUpdateStamp -Encoding ASCII
}

function Update-PowerShell {
    # If function "Update-PowerShell_Override" is defined in profile.ps1 file
    # then call it instead.
    if (Get-Command -Name "Update-PowerShell_Override" -ErrorAction SilentlyContinue) {
        Update-PowerShell_Override
    } else {
        try {
            Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
            $updateNeeded = $false
            [version]$currentVersion = $PSVersionTable.PSVersion
            $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
            $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl -TimeoutSec 10 -ErrorAction Stop
            [version]$latestVersion = $latestReleaseInfo.tag_name.TrimStart('v')
            if ($currentVersion -lt $latestVersion) {
                $updateNeeded = $true
            }

            if ($updateNeeded) {
                Write-Host "Updating PowerShell..." -ForegroundColor Yellow
                Start-Process winget.exe -ArgumentList @(
                    'upgrade',
                    '--id', 'Microsoft.PowerShell',
                    '--exact',
                    '--accept-source-agreements',
                    '--accept-package-agreements'
                ) -Wait -NoNewWindow
                Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
            } else {
                Write-Host "Your PowerShell is up to date." -ForegroundColor Green
            }
        } catch {
            Write-Error "Failed to update PowerShell. Error: $_"
        }
    }
}

# A PowerShell verzió ellenőrzése is kézi művelet.
# Futtasd szükség esetén: Update-PowerShell

function Clear-Cache {
    # If function "Clear-Cache_Override" is defined in profile.ps1 file
    # then call it instead.
    # -----------------------------------------------------------------
    # If you do override this function, you should should probably duplicate
    # the following calls in your override function, just don't call this
    # function from your override function, otherwise you'll be in an infinate loop.
    if (Get-Command -Name "Clear-Cache_Override" -ErrorAction SilentlyContinue) {
        Clear-Cache_Override
    } else {
        # add clear cache logic here
        Write-Host "Clearing cache..." -ForegroundColor Cyan

        # Clear Windows Prefetch
        Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
        Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

        # Clear Windows Temp
        Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
        Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Clear User Temp
        Write-Host "Clearing User Temp..." -ForegroundColor Yellow
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Clear Internet Explorer Cache
        Write-Host "Clearing Internet Explorer Cache..." -ForegroundColor Yellow
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "Cache clearing completed." -ForegroundColor Green
    }
}

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

Show-ProfileTiming "Update/admin definitions"

# Editor Configuration
# Ezen a gépen a VS Code az elsődleges editor. Ha valamiért nem érhető el,
# Notepad++ a második, végül a Windows Notepad a fallback.
if ($EDITOR_Override) {
    $EDITOR = $EDITOR_Override
} elseif (Get-Command code -CommandType Application -ErrorAction SilentlyContinue) {
    $EDITOR = 'code'
} elseif (Get-Command 'notepad++' -CommandType Application -ErrorAction SilentlyContinue) {
    $EDITOR = 'notepad++'
} else {
    $EDITOR = 'notepad'
}

Set-Alias -Name vim -Value $EDITOR -Force

Show-ProfileTiming "Editor detection"

# Quick Access to Editing the Profile
function Edit-Profile {
    & $EDITOR $PROFILE.CurrentUserCurrentHost
}
Set-Alias -Name ep -Value Edit-Profile

# Opens the local-only notes file that is intentionally not committed to Git.
$LocalProfileNotesPath = Join-Path (Get-ProfileDir) 'profile.local.ps1'
function Edit-LocalProfile {
    if (-not (Test-Path -LiteralPath $LocalProfileNotesPath)) {
        New-Item -ItemType File -Path $LocalProfileNotesPath -Force | Out-Null
    }
    & $EDITOR $LocalProfileNotesPath
}
Set-Alias -Name eplocal -Value Edit-LocalProfile

function Invoke-Profile {
    if ($PSVersionTable.PSEdition -eq "Desktop") {
        Write-Host "Note: Some Oh My Posh/PSReadLine errors are expected in PowerShell 5. The profile still works fine." -ForegroundColor Yellow
    }
    . $PROFILE
}

function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

# Network Utilities
function pubip {
    try { $ipv4 = Invoke-RestMethod 'https://api.ipify.org' -NoProxy -TimeoutSec 10 } catch { $ipv4 = 'N/A' }
    try { $ipv6 = Invoke-RestMethod 'https://api6.ipify.org' -NoProxy -TimeoutSec 10 } catch { $ipv6 = 'N/A' }

    "IPv4: $ipv4 | IPv6: $ipv6"
}

# System Utilities
function admin {
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}

# Set UNIX-like aliases for the admin command, so sudo <command> will run the command with elevated rights.
Set-Alias -Name su -Value admin

function uptime {
    try {
        # find date/time format
        $dateFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.ShortDatePattern
        $timeFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.LongTimePattern

        # check powershell version
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            $lastBoot = (Get-WmiObject win32_operatingsystem).LastBootUpTime
            $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)

            # reformat lastBoot
            $lastBoot = $bootTime.ToString("$dateFormat $timeFormat")
        } else {
            # the Get-Uptime cmdlet was introduced in PowerShell 6.0
            $lastBoot = (Get-Uptime -Since).ToString("$dateFormat $timeFormat")
            $bootTime = [System.DateTime]::ParseExact($lastBoot, "$dateFormat $timeFormat", [System.Globalization.CultureInfo]::InvariantCulture)
        }

        # Format the start time
        $formattedBootTime = $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) + " [$lastBoot]"
        Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray

        # calculate uptime
        $uptime = (Get-Date) - $bootTime

        # Uptime in days, hours, minutes, and seconds
        $days = $uptime.Days
        $hours = $uptime.Hours
        $minutes = $uptime.Minutes
        $seconds = $uptime.Seconds

        # Uptime output
        Write-Host ("Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $days, $hours, $minutes, $seconds) -ForegroundColor Blue

    } catch {
        Write-Error "An error occurred while retrieving system uptime."
    }
}

function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
    param($Path, $n = 10)
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10, [switch]$f = $false)
    Get-Content $Path -Tail $n -Wait:$f
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

function trash($path) {
    $fullPath = (Resolve-Path -Path $path).Path

    if (Test-Path $fullPath) {
        $item = Get-Item $fullPath

        if ($item.PSIsContainer) {
            # Handle directory
            $parentPath = $item.Parent.FullName
        } else {
            # Handle file
            $parentPath = $item.DirectoryName
        }

        $shell = New-Object -ComObject 'Shell.Application'
        $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)

        if ($item) {
            $shellItem.InvokeVerb('delete')
            Write-Host "Item '$fullPath' has been moved to the Recycle Bin."
        } else {
            Write-Host "Error: Could not find the item '$fullPath' to trash."
        }
    } else {
        Write-Host "Error: Item '$fullPath' does not exist."
    }
}

### Quality of Life Aliases

# Navigation Shortcuts
function docs {
    $docs = if(([Environment]::GetFolderPath("MyDocuments"))) {([Environment]::GetFolderPath("MyDocuments"))} else {$HOME + "\Documents"}
    Set-Location -Path $docs
}

function dtop {
    $dtop = if ([Environment]::GetFolderPath("Desktop")) {[Environment]::GetFolderPath("Desktop")} else {$HOME + "\Documents"}
    Set-Location -Path $dtop
}

# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing
function la { Get-ChildItem | Format-Table -AutoSize }
function ll { Get-ChildItem -Force | Format-Table -AutoSize }

# Git Shortcuts
function gs { git status }

function ga { git add . }

function gcommit { param($m) git commit -m "$m" }

function gpush { git push }

function gpull { git pull }

function g { __zoxide_z github }

function gcl { git clone @args }

function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS has been flushed"
}

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

Show-ProfileTiming "Utility definitions"

function Get-AppUpdates {
    winget list --upgrade-available --source winget
}

# ============================================================
# Winget alkalmazásfrissítés
# ============================================================

function Update-Apps {
    $isAdmin = (
        [Security.Principal.WindowsPrincipal]
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    # Ha nem rendszergazdai PowerShellből futunk,
    # egyszer kérünk UAC jogosultságot, majd emelt joggal
    # elindítjuk a teljes Winget frissítést.
    if (-not $isAdmin) {
        Write-Host ""
        Write-Host "Winget frissítéshez rendszergazdai jogosultság szükséges." -ForegroundColor Yellow
        Write-Host "UAC jogosultságkérés indítása..." -ForegroundColor Yellow
        Write-Host ""

        # PowerShell 7 használata, ha elérhető
        $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue

        if ($pwsh) {
            Start-Process `
                -FilePath $pwsh.Source `
                -Verb RunAs `
                -ArgumentList @(
                    '-NoProfile',
                    '-NoExit',
                    '-Command',
                    'winget upgrade --all --source winget --accept-source-agreements --accept-package-agreements'
                )
        }
        else {
            # Fallback Windows PowerShellre
            Start-Process `
                -FilePath 'powershell.exe' `
                -Verb RunAs `
                -ArgumentList @(
                    '-NoProfile',
                    '-NoExit',
                    '-Command',
                    'winget upgrade --all --source winget --accept-source-agreements --accept-package-agreements'
                )
        }

        return
    }

    # Ha már eleve rendszergazdai PowerShellben vagyunk
    Write-Host ""
    Write-Host "Winget alkalmazásfrissítés indítása..." -ForegroundColor Cyan
    Write-Host ""

    winget upgrade --all `
        --source winget `
        --accept-source-agreements `
        --accept-package-agreements

    Write-Host ""
    Write-Host "Winget frissítés befejeződött." -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Integrated infrastructure / SSH shortcuts
# ---------------------------------------------------------------------------
# These functions were previously loaded from the separate custom PS1 file.
$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# ---------------------------------------------------------------------------
# Machine-specific SSH shortcuts
# ---------------------------------------------------------------------------
# The functions below were migrated from the previous CurrentUserAllHosts
# profile.ps1 file. Non-secret comments are intentionally preserved.

# SSH connections
# DotRoll Hosting
function webspace {
    ssh richie@richie.loginssl.com @args
}
# VPS
function vps {
    ssh root@vps.richardbuz.de @args
}
# router
function router {
    ssh richard.buz@10.10.42.254 @args
}
# Gyruma
function darthnas {
    ssh root@nas.kantorgyorgy.hu -p 32022 @args
}
# nas in home
function nashome {
    ssh richie@10.10.42.212 @args
}

# nasout
function nasout {
    ssh root@nas.richardbuz.de -p 32022 @args
}
function bethlennas {
    ssh root@bethlen.dvrdns.org -p 32022 @args
}
# backup02.wavesystem.hu
function backup02 {
    ssh root@backup02.wavesystem.hu @args
}
# IMAERP db01 ol
function db01old {
   ssh root@10.36.101.11 @args
}
function signatory {
    ssh buz.richard@10.36.101.15 @args
}
function api01 {
    ssh rbuz@10.36.101.21 @args
}
function api02 {
    ssh rbuz@10.36.101.22 @args
}
function api03 {
    ssh rbuz@10.36.101.23 @args
}
function api04 {
    ssh rbuz@10.36.101.24 @args
}
function api05 {
    ssh rbuz@10.36.101.25 @args
}
function imaarchdb01 {
    ssh rbuz@10.36.101.51 @args
}
function imaarchdb02 {
    ssh rbuz@10.36.101.52 @args
}
function imaarchdb03 {
    ssh rbuz@10.36.101.53 @args
}
function imaarchdb04 {
    ssh rbuz@10.36.101.54 @args
}
function imanav {
    ssh rbuz@10.36.101.58 @args
}
function imabackup01 {
    ssh rbuz@10.36.101.61 @args
}
function db01 {
    ssh rbuz@10.36.101.41 @args
}
function db02 {
    ssh rbuz@10.36.101.42 @args
}
function db03 {
    ssh rbuz@10.36.101.43 @args
}
function db04 {
    ssh rbuz@10.36.101.44 @args
}
function db05 {
    ssh rbuz@10.36.101.45 @args
}
function db06 {
    ssh rbuz@10.36.101.46 @args
}
function db07 {
    ssh rbuz@10.36.101.47 @args
}
function db08 {
    ssh rbuz@10.36.101.48 @args
}
function db09 {
    ssh rbuz@10.36.101.49 @args
}
function db10 {
    ssh rbuz@10.36.101.50 @args
}
function db21 {
    ssh rbuz@10.36.101.71 @args
}
function db22 {
    ssh rbuz@10.36.101.72 @args
}
function imafs01 {
    ssh rbuz@10.36.101.81 @args
}
function imafs02 {
    ssh rbuz@10.36.101.82 @args
}
function imadevel {
    ssh rbuz@10.36.101.59 @args
}
function proxy01 {
    ssh rbuz@10.36.101.31 @args
}
function proxy02 {
    ssh rbuz@10.36.101.32 @args
}
function webproxy01 {
     ssh rbuz@10.36.101.11 @args
}
function webproxy02 {
     ssh rbuz@10.36.101.12 @args
}
function imatask {
    ssh rbuz@10.36.101.57 @args
}
function denton {
    ssh root@217.113.60.2 @args
}
function midland {
    ssh root@217.113.60.3 @args
}
function aurora {
    ssh root@185.33.53.38 @args
}
function wavesystem {
    ssh root@wavesystem.hu @args
}
function kralik {
    ssh root@web.kralikugyvediiroda.hu @args
}
function market {
    ssh root@217.113.60.22 @args
}
function web2 {
    ssh root@217.113.60.50 @args
}
function web3 {
    ssh root@217.113.60.51 @args
}
function web4 {
    ssh root@217.113.60.53 @args
}
function romvandor {
    ssh root@217.113.60.47 @args
}
function budapart {
    ssh root@web.budapart.hu @args
}
function redmine {
    ssh rbuz@217.113.60.57 @args
}
function devprodukt {
    ssh root@alpha.devprodukt.hu @args
}
function patronbolt {
    ssh root@origin.patronbolt.hu @args
}
# cREwraSp8wre
function migrating {
    ssh root@195.56.100.60 @args
}
function csempevarazs {
    ssh root@195.56.100.44 -p 22 @args
}
function syscsempevarazs {
    ssh sysadmin@195.56.100.44 -p 22 @args
}
function dbr {
    ssh root@217.113.60.62 @args
}
function pridentum {
    ssh root@web.pridentumpro.hu @args
}
# web.novelment.hu
function novelment {
    ssh root@novelment.hu @args
}
# doc.babycare.hu
function babycare {
    ssh root@217.113.60.71 @args
}
# gablini
function gablini {
    ssh root@217.113.60.80 @args
}
# budapartbutorpalyazat.market.hu
function butorpalyazat {
    ssh root@217.113.60.49 @args
}
# minecraft.wavesystem.hu
function minecraft {
    ssh root@217.113.60.90 @args
}

# sudo/root credential note is stored locally in profile.local.ps1
function entersys {
    ssh entersys@10.10.109.67 @args
}

# sudo/root credential note is stored locally in profile.local.ps1
function enterportal {
    ssh enterportal@10.10.109.68 @args
}
## market/root credential notes are stored locally in profile.local.ps1
function qr {
    ssh market@10.10.103.158 @args
}
# su/root credential note is stored locally in profile.local.ps1
function alert {
    ssh smtpsu@10.0.0.26 @args
}

# local credential note is stored locally in profile.local.ps1
function shinyproxy {
    ssh datasc2@10.10.103.144 @args
}

# VPS Hatvan
function hatvan {
    ssh root@vps.hatvan.hu @args
}
# Arga
function argatech {
    ssh root@cp.argatech.hu @args
}

# cPanel SSH
function cl([string] $name) { ssh root@cl$name.webspacecontrol.com @args }
# DirectAdmin SSH
function da([string] $name) { ssh root@da$name.dadmin.hu @args }

Show-ProfileTiming "Infrastructure shortcuts"


# Set-PSReadLineOption Compatibility for PowerShell Desktop
function Set-PSReadLineOptionsCompat {
    param([hashtable]$Options)
    if ($PSVersionTable.PSEdition -eq "Core") {
        Set-PSReadLineOption @Options
    } else {
        # Remove unsupported keys for Desktop and silence errors
        $SafeOptions = $Options.Clone()
        $SafeOptions.Remove('PredictionSource')
        $SafeOptions.Remove('PredictionViewStyle')
        Set-PSReadLineOption @SafeOptions
    }
}

# Enhanced PowerShell Experience
# Enhanced PSReadLine Configuration
$PSReadLineOptions = @{
    EditMode = 'Windows'
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    Colors = @{
        Command = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator = '#FFB6C1'  # LightPink (pastel)
        Variable = '#DDA0DD'  # Plum (pastel)
        String = '#FFDAB9'  # PeachPuff (pastel)
        Number = '#B0E0E6'  # PowderBlue (pastel)
        Type = '#F0E68C'  # Khaki (pastel)
        Comment = '#D3D3D3'  # LightGray (pastel)
        Keyword = '#8367c7'  # Violet (pastel)
        Error = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    PredictionSource = 'History'
    PredictionViewStyle = 'ListView'
    BellStyle = 'None'
}
Set-PSReadLineOptionsCompat -Options $PSReadLineOptions

Show-ProfileTiming "PSReadLine options"

# Custom key handlers
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

Show-ProfileTiming "PSReadLine handlers"

# Prediction source is already set to History in $PSReadLineOptions.
# Only set the history size here. Avoid Get-Command / plugin discovery during startup.
Set-PSReadLineOption -MaximumHistoryCount 10000

Show-ProfileTiming "Prediction setup"

# Custom completion for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git' = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'npm' = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

Show-ProfileTiming "Argument completers"

# Oh My Posh initialization
# Nincs téma-letöltés indulás közben. A téma helyben legyen elérhető.
$localThemePath = Join-Path (Get-ProfileDir) 'cobalt2.omp.json'
$ohMyPosh = Get-Command oh-my-posh -CommandType Application -ErrorAction SilentlyContinue
if ($EnableOhMyPosh -and $ohMyPosh -and (Test-Path -LiteralPath $localThemePath)) {
    & $ohMyPosh.Source init pwsh --config $localThemePath | Invoke-Expression
}

Show-ProfileTiming "Oh My Posh"

# zoxide initialization
# Ha nincs telepítve, nem indítunk winget-et a profil betöltése közben.
$zoxide = Get-Command zoxide -CommandType Application -ErrorAction SilentlyContinue
if ($EnableZoxide -and $zoxide) {
    (& $zoxide.Source init --cmd z powershell | Out-String) | Invoke-Expression
}

Show-ProfileTiming "zoxide"

function Install-ProfileDependencies {
    [CmdletBinding()]
    param()

    Write-Host "PowerShell profil függőségeinek ellenőrzése..." -ForegroundColor Cyan

    if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
        Write-Host "Terminal-Icons telepítése..." -ForegroundColor Yellow
        Install-Module Terminal-Icons -Scope CurrentUser -Force
    }

    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        Write-Host "Oh My Posh telepítése..." -ForegroundColor Yellow
        winget install --id JanDeDobbeleer.OhMyPosh --exact --accept-source-agreements --accept-package-agreements
    }

    if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
        Write-Host "zoxide telepítése..." -ForegroundColor Yellow
        winget install --id ajeetdsouza.zoxide --exact --accept-source-agreements --accept-package-agreements
    }

    if (-not (Test-Path -LiteralPath $localThemePath)) {
        Write-Host "cobalt2 Oh My Posh téma letöltése..." -ForegroundColor Yellow
        $themeUrl = 'https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json'
        Invoke-WebRequest -Uri $themeUrl -OutFile $localThemePath -TimeoutSec 10 -ErrorAction Stop
    }

    Write-Host "Kész. Indíts új PowerShell munkamenetet." -ForegroundColor Green
}

# Help Function
function Show-Help {
    $helpText = @"
$($PSStyle.Foreground.Cyan)PowerShell Profile Help$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)Edit-Profile$($PSStyle.Reset) - Opens the current user's profile for editing using the configured editor.
$($PSStyle.Foreground.Green)Update-Profile$($PSStyle.Reset) - Frissíti a profilt a saját GitHub repositoryból.
$($PSStyle.Foreground.Green)Update-PowerShell$($PSStyle.Reset) - Ellenőrzi és szükség esetén frissíti a PowerShellt.
$($PSStyle.Foreground.Green)Install-ProfileDependencies$($PSStyle.Reset) - Telepíti a profilhoz szükséges opcionális komponenseket.

$($PSStyle.Foreground.Cyan)Git Shortcuts$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)g$($PSStyle.Reset) - Changes to the GitHub directory.
$($PSStyle.Foreground.Green)ga$($PSStyle.Reset) - Shortcut for 'git add .'.
$($PSStyle.Foreground.Green)gc$($PSStyle.Reset) <message> - Shortcut for 'git commit -m'.
$($PSStyle.Foreground.Green)gcl$($PSStyle.Reset) <repo> - Shortcut for 'git clone'.
$($PSStyle.Foreground.Green)gcom$($PSStyle.Reset) <message> - Adds all changes and commits with the specified message.
$($PSStyle.Foreground.Green)gp$($PSStyle.Reset) - Shortcut for 'git push'.
$($PSStyle.Foreground.Green)gpull$($PSStyle.Reset) - Shortcut for 'git pull'.
$($PSStyle.Foreground.Green)gpush$($PSStyle.Reset) - Shortcut for 'git push'.
$($PSStyle.Foreground.Green)gs$($PSStyle.Reset) - Shortcut for 'git status'.
$($PSStyle.Foreground.Green)lazyg$($PSStyle.Reset) <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.

$($PSStyle.Foreground.Cyan)Shortcuts$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)cpy$($PSStyle.Reset) <text> - Copies the specified text to the clipboard.
$($PSStyle.Foreground.Green)df$($PSStyle.Reset) - Displays information about volumes.
$($PSStyle.Foreground.Green)docs$($PSStyle.Reset) - Changes the current directory to the user's Documents folder.
$($PSStyle.Foreground.Green)dtop$($PSStyle.Reset) - Changes the current directory to the user's Desktop folder.
$($PSStyle.Foreground.Green)ep$($PSStyle.Reset) - Opens the active Microsoft.PowerShell_profile.ps1 for editing.
$($PSStyle.Foreground.Green)eplocal$($PSStyle.Reset) - Opens local-only notes that are excluded from Git.
$($PSStyle.Foreground.Green)export$($PSStyle.Reset) <name> <value> - Sets an environment variable.
$($PSStyle.Foreground.Green)ff$($PSStyle.Reset) <name> - Finds files recursively with the specified name.
$($PSStyle.Foreground.Green)flushdns$($PSStyle.Reset) - Clears the DNS cache.
$($PSStyle.Foreground.Green)pubip$($PSStyle.Reset) - Displays the current public IPv4 and IPv6 addresses.
$($PSStyle.Foreground.Green)grep$($PSStyle.Reset) <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input.
$($PSStyle.Foreground.Green)head$($PSStyle.Reset) <path> [n] - Displays the first n lines of a file (default 10).
$($PSStyle.Foreground.Green)k9$($PSStyle.Reset) <name> - Kills a process by name.
$($PSStyle.Foreground.Green)la$($PSStyle.Reset) - Lists all files in the current directory with detailed formatting.
$($PSStyle.Foreground.Green)ll$($PSStyle.Reset) - Lists all files, including hidden, in the current directory with detailed formatting.
$($PSStyle.Foreground.Green)mkcd$($PSStyle.Reset) <dir> - Creates and changes to a new directory.
$($PSStyle.Foreground.Green)nf$($PSStyle.Reset) <name> - Creates a new file with the specified name.
$($PSStyle.Foreground.Green)pgrep$($PSStyle.Reset) <name> - Lists processes by name.
$($PSStyle.Foreground.Green)pkill$($PSStyle.Reset) <name> - Kills processes by name.
$($PSStyle.Foreground.Green)pst$($PSStyle.Reset) - Retrieves text from the clipboard.
$($PSStyle.Foreground.Green)sed$($PSStyle.Reset) <file> <find> <replace> - Replaces text in a file.
$($PSStyle.Foreground.Green)sysinfo$($PSStyle.Reset) - Displays detailed system information.
$($PSStyle.Foreground.Green)tail$($PSStyle.Reset) <path> [n] - Displays the last n lines of a file (default 10).
$($PSStyle.Foreground.Green)touch$($PSStyle.Reset) <file> - Creates a new empty file.
$($PSStyle.Foreground.Green)unzip$($PSStyle.Reset) <file> - Extracts a zip file to the current directory.
$($PSStyle.Foreground.Green)uptime$($PSStyle.Reset) - Displays the system uptime.
$($PSStyle.Foreground.Green)which$($PSStyle.Reset) <name> - Shows the path of the command.


$($PSStyle.Foreground.Cyan)Infrastructure / SSH Shortcuts$($PSStyle.Reset)
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)
$($PSStyle.Foreground.Green)cl$($PSStyle.Reset) <nn> - SSH to clNN.webspacecontrol.com as root.
$($PSStyle.Foreground.Green)da$($PSStyle.Reset) <nn> - SSH to daNN.dadmin.hu as root.
$($PSStyle.Foreground.Green)webspace$($PSStyle.Reset) - SSH to richie.loginssl.com.
$($PSStyle.Foreground.Green)router$($PSStyle.Reset) - SSH to the local router.
$($PSStyle.Foreground.Green)nashome / nasout / darthnas$($PSStyle.Reset) - NAS SSH shortcuts.
$($PSStyle.Foreground.Green)api01..api05$($PSStyle.Reset) - IMA API server shortcuts.
$($PSStyle.Foreground.Green)db01..db10, db21..db22$($PSStyle.Reset) - IMA database server shortcuts.
$($PSStyle.Foreground.Green)ima*$($PSStyle.Reset) - IMA archive, backup, filesystem, development, navigation and task shortcuts.
$($PSStyle.Foreground.Green)proxy01 / proxy02 / webproxy01 / webproxy02$($PSStyle.Reset) - Proxy shortcuts.
$($PSStyle.Foreground.Green)Other SSH shortcuts$($PSStyle.Reset) - Wavesystem, customer VPS, development and application server shortcuts are also integrated.
$($PSStyle.Foreground.Yellow)=======================$($PSStyle.Reset)

Use '$($PSStyle.Foreground.Magenta)Show-Help$($PSStyle.Reset)' to display this help message.
"@
    Write-Host $helpText
}

Show-ProfileTiming "Help"

if ($EnableProfileTiming) {
    Write-Host ("[PROFILE] {0,-30} {1,8:N1} ms" -f 'TOTAL PROFILE', $ProfileStartupTimer.Elapsed.TotalMilliseconds) -ForegroundColor Cyan
}

Write-Host "$($PSStyle.Foreground.Yellow)Use 'Show-Help' to display help$($PSStyle.Reset)"
