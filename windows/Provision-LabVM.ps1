# =============================================================================
# Ansible Course Lab — Windows VM Provisioning Script
# Run this script on the Windows Server 2022 VM as a local Administrator
# BEFORE the course starts. It configures WinRM, creates lab accounts,
# installs Chocolatey, and sets up the directory structure for exercises.
#
# Usage (run from an elevated PowerShell prompt):
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\Provision-LabVM.ps1
#
# After running, verify with:
#   winrm enumerate winrm/config/listener
# =============================================================================

param(
    [string]$DomainName      = "LAB.COURSE.LOCAL",
    [string]$LocalAdminPass  = "LabAdmin2024!",
    [string]$SvcAccountPass  = "SvcAnsible2024!",
    [string]$ParticipantCIDR = "0.0.0.0/0"   # Restrict to participant subnet in production
)

$ErrorActionPreference = "Stop"

Write-Host "=== Ansible Course Lab — Windows VM Provisioning ===" -ForegroundColor Cyan
Write-Host "Domain:           $DomainName"
Write-Host "Participant CIDR: $ParticipantCIDR"
Write-Host ""

# ── 1. WINRM CONFIGURATION ────────────────────────────────────────────────────
Write-Host "[1/7] Configuring WinRM..." -ForegroundColor Yellow

# Enable WinRM with default settings first
winrm quickconfig -quiet

# Enable HTTP listener (port 5985) — used in Module 12 for initial NTLM testing
$httpListener = Get-WSManInstance -ResourceURI winrm/config/listener `
    -SelectorSet @{Address="*"; Transport="HTTP"} -ErrorAction SilentlyContinue
if (-not $httpListener) {
    New-WSManInstance -ResourceURI winrm/config/listener `
        -SelectorSet @{Address="*"; Transport="HTTP"} | Out-Null
    Write-Host "  HTTP listener created (port 5985)"
} else {
    Write-Host "  HTTP listener already exists"
}

# Enable HTTPS listener (port 5986) — used in production discussion
# Creates a self-signed cert for the lab
$cert = New-SelfSignedCertificate `
    -DnsName $env:COMPUTERNAME, "$env:COMPUTERNAME.$DomainName" `
    -CertStoreLocation Cert:\LocalMachine\My `
    -NotAfter (Get-Date).AddYears(2)

$httpsListener = Get-WSManInstance -ResourceURI winrm/config/listener `
    -SelectorSet @{Address="*"; Transport="HTTPS"} -ErrorAction SilentlyContinue
if (-not $httpsListener) {
    New-WSManInstance -ResourceURI winrm/config/listener `
        -SelectorSet @{Address="*"; Transport="HTTPS"} `
        -ValueSet @{Hostname=$env:COMPUTERNAME; CertificateThumbprint=$cert.Thumbprint} | Out-Null
    Write-Host "  HTTPS listener created (port 5986), cert thumbprint: $($cert.Thumbprint)"
} else {
    Write-Host "  HTTPS listener already exists"
}

# Allow WinRM Basic auth (for NTLM; Kerberos does not require this)
Set-Item WSMan:\localhost\Service\Auth\Basic $true
Set-Item WSMan:\localhost\Service\Auth\Kerberos $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted $true  # HTTP only — lab use only

# Increase max shell memory and timeout for larger playbook runs
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1024
Set-Item WSMan:\localhost\Shell\MaxShellsPerUser 30

Write-Host "  WinRM configured." -ForegroundColor Green

# ── 2. FIREWALL RULES ─────────────────────────────────────────────────────────
Write-Host "[2/7] Configuring firewall rules..." -ForegroundColor Yellow

$fwRules = @(
    @{ Name="WinRM-HTTP-Lab";  Port=5985; Protocol="TCP" },
    @{ Name="WinRM-HTTPS-Lab"; Port=5986; Protocol="TCP" }
)

foreach ($rule in $fwRules) {
    $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule `
            -DisplayName $rule.Name `
            -Direction Inbound `
            -Protocol $rule.Protocol `
            -LocalPort $rule.Port `
            -Action Allow `
            -Profile Any | Out-Null
        Write-Host "  Firewall rule created: $($rule.Name) (port $($rule.Port))"
    } else {
        Write-Host "  Firewall rule already exists: $($rule.Name)"
    }
}

Write-Host "  Firewall rules configured." -ForegroundColor Green

# ── 3. LOCAL ADMIN ACCOUNT (for Module 12 NTLM testing) ──────────────────────
Write-Host "[3/7] Creating local labadmin account..." -ForegroundColor Yellow

$localAdminSecure = ConvertTo-SecureString $LocalAdminPass -AsPlainText -Force
$labAdmin = Get-LocalUser -Name "labadmin" -ErrorAction SilentlyContinue
if (-not $labAdmin) {
    New-LocalUser `
        -Name "labadmin" `
        -Password $localAdminSecure `
        -FullName "Lab Administrator" `
        -Description "Ansible course lab local admin — Module 12 NTLM testing" `
        -PasswordNeverExpires | Out-Null
    Add-LocalGroupMember -Group "Administrators" -Member "labadmin"
    Write-Host "  labadmin created and added to Administrators"
} else {
    Set-LocalUser -Name "labadmin" -Password $localAdminSecure
    Write-Host "  labadmin already exists — password updated"
}

Write-Host "  Local admin account ready." -ForegroundColor Green

# ── 4. DOMAIN SERVICE ACCOUNT (for Module 14 Kerberos) ───────────────────────
# This section runs only if the machine is domain-joined.
Write-Host "[4/7] Checking domain membership for service account creation..." -ForegroundColor Yellow

$domainJoined = (Get-WmiObject Win32_ComputerSystem).PartOfDomain
if ($domainJoined) {
    Write-Host "  Machine is domain-joined. Creating svc-ansible domain account..."
    try {
        $svcPass = ConvertTo-SecureString $SvcAccountPass -AsPlainText -Force
        $domainNetbios = (Get-WmiObject Win32_ComputerSystem).Domain.Split(".")[0].ToUpper()

        # Create domain user (requires Domain Admin or Account Operator rights)
        $existingUser = Get-ADUser -Filter {SamAccountName -eq "svc-ansible"} -ErrorAction SilentlyContinue
        if (-not $existingUser) {
            New-ADUser `
                -Name "svc-ansible" `
                -SamAccountName "svc-ansible" `
                -UserPrincipalName "svc-ansible@$DomainName" `
                -Description "Ansible automation service account — course lab" `
                -AccountPassword $svcPass `
                -Enabled $true `
                -PasswordNeverExpires $true `
                -CannotChangePassword $true
            Write-Host "  Domain account svc-ansible@$DomainName created"
        } else {
            Set-ADAccountPassword -Identity "svc-ansible" -NewPassword $svcPass -Reset
            Write-Host "  Domain account svc-ansible already exists — password updated"
        }

        # Add svc-ansible to local Administrators on this machine
        # (In production, this would be done via GPO or a dedicated OU)
        Add-LocalGroupMember -Group "Administrators" -Member "$domainNetbios\svc-ansible" -ErrorAction SilentlyContinue
        Write-Host "  svc-ansible added to local Administrators"

    } catch {
        Write-Warning "  Could not create domain account: $($_.Exception.Message)"
        Write-Warning "  Run this step manually as Domain Admin or use an existing domain service account."
    }
} else {
    Write-Host "  Machine is NOT domain-joined. Skipping domain account creation." -ForegroundColor Yellow
    Write-Host "  NOTE: Module 14 (Kerberos auth) requires domain membership." -ForegroundColor Yellow
    Write-Host "  Join this machine to $DomainName before the course begins." -ForegroundColor Yellow
}

Write-Host "  Domain account step complete." -ForegroundColor Green

# ── 5. CHOCOLATEY ─────────────────────────────────────────────────────────────
Write-Host "[5/7] Installing Chocolatey..." -ForegroundColor Yellow

$chocoInstalled = Get-Command choco -ErrorAction SilentlyContinue
if (-not $chocoInstalled) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Host "  Chocolatey installed."
} else {
    Write-Host "  Chocolatey already installed: $(choco --version)"
}

Write-Host "  Chocolatey ready." -ForegroundColor Green

# ── 6. DIRECTORY STRUCTURE ────────────────────────────────────────────────────
Write-Host "[6/7] Creating deployment directory structure..." -ForegroundColor Yellow

$dirs = @(
    "C:\deploy",
    "C:\deploy\config",
    "C:\deploy\logs",
    "C:\deploy\bin"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-Host "  Created: $dir"
    } else {
        Write-Host "  Already exists: $dir"
    }
}

# Set permissions on deploy dir so svc-ansible (if domain account exists) can write
if ($domainJoined) {
    try {
        $domainNetbios = (Get-WmiObject Win32_ComputerSystem).Domain.Split(".")[0].ToUpper()
        $acl = Get-Acl "C:\deploy"
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "$domainNetbios\svc-ansible", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl.SetAccessRule($rule)
        Set-Acl "C:\deploy" $acl
        Write-Host "  Permissions set on C:\deploy for svc-ansible"
    } catch {
        Write-Warning "  Could not set ACL for svc-ansible: $($_.Exception.Message)"
    }
}

Write-Host "  Directories ready." -ForegroundColor Green

# ── 7. VERIFY ─────────────────────────────────────────────────────────────────
Write-Host "[7/7] Verification..." -ForegroundColor Yellow

Write-Host ""
Write-Host "=== WinRM Listener Status ===" -ForegroundColor Cyan
winrm enumerate winrm/config/listener

Write-Host ""
Write-Host "=== Local Users ===" -ForegroundColor Cyan
Get-LocalUser | Select-Object Name, Enabled, Description | Format-Table -AutoSize

Write-Host ""
Write-Host "=== Firewall Rules (WinRM) ===" -ForegroundColor Cyan
Get-NetFirewallRule -DisplayName "WinRM*" | Select-Object DisplayName, Enabled, Direction | Format-Table -AutoSize

Write-Host ""
Write-Host "=== Provisioning Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "VM is ready for Ansible course Day 3." -ForegroundColor Green
Write-Host ""
Write-Host "Participant connection details:" -ForegroundColor Cyan
Write-Host "  WinRM HTTP:   $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike '*Loopback*'} | Select-Object -First 1).IPAddress):5985"
Write-Host "  Local admin:  labadmin / $LocalAdminPass"
if ($domainJoined) {
    Write-Host "  Domain svc:   svc-ansible@$DomainName / $SvcAccountPass"
}
Write-Host ""
Write-Host "IMPORTANT: Change these passwords before distributing to participants" -ForegroundColor Red
Write-Host "if this is a production training environment." -ForegroundColor Red
