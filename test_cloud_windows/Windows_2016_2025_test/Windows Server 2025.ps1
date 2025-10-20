# ��������������������������������������������������������������������������������������������������������������������
# 0. ����� ���� �Ķ����
# ��������������������������������������������������������������������������������������������������������������������
$NewAdminName   = 'Administrator'                   # W?01 administrartor ���� ���� �� �̸�
$Lockout        = @{Threshold = 5; Duration = 60; Window = 60}   # W?04, W?47 �н����� 5ȸ ���н� 60�� ���
$AccountWhite   = @($NewAdminName,'Guest','WDAGUtilityAccount','DefaultAccount') # W?03 �׸񿡼� ���� ���� ���� ����
$BlockServices  = @('SNMP','SNMPTRAP','Telnet','Fax','TlntSvr','TrkWks','TrkSvr','Spooler') # W?09 + W?60/63/65 �׸񿡼� ��Ȱ��ȭ�� ����
$ExtraBlockSvc  = @('DNS')   # W?09 + W?60/63/65 DNS ������ ������ ��Ʈ�ѷ� ��� �� ��� ����
$NeedReboot     = $false     # ����� �÷���

# ��������������������������������������������������������������������������������������������������������������������
# 1. ���� ��� �Լ�
# ��������������������������������������������������������������������������������������������������������������������
function Write-Info { param([string]$m) Write-Host $m -ForegroundColor Cyan    }
function Write-OK   { param([string]$m) Write-Host $m -ForegroundColor Green   }
function Write-Warn { param([string]$m) Write-Host $m -ForegroundColor Yellow  }
function Write-Err  { param([string]$m) Write-Host $m -ForegroundColor Red     }
function Need-Reboot{ $script:NeedReboot = $true }

# ��������������������������������������������������������������������������������������������������������������������
# 2. ����
# ��������������������������������������������������������������������������������������������������������������������
Write-Info "`n===== Windows?Server ���� ���� ���� ====="

# ��������������������������������������������������������������������������������������������������������������������
# 4. W?02 Guest ���� ��Ȱ��ȭ
# ��������������������������������������������������������������������������������������������������������������������
try {
    $guest = Get-LocalUser | Where SID -like '*-501'
    if ($guest -and $guest.Enabled) {
        Disable-LocalUser -Name $guest.Name
        Write-OK "W-02: Guest ���� ��Ȱ��ȭ �Ϸ�"
    } else { Write-Warn "W-02: Guest ���� ����/�̹� ��Ȱ��ȭ" }
} catch { Write-Err "W-02: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 5. W?03 ���ʿ� ���� ���� ��Ȱ��ȭ (ȭ��Ʈ����Ʈ)
# ��������������������������������������������������������������������������������������������������������������������
foreach ($u in Get-LocalUser) {
    if ($AccountWhite -notcontains $u.Name) {
        try {
            Disable-LocalUser -Name $u.Name -ErrorAction Stop
            Write-OK "W-03: [$($u.Name)] ��Ȱ��ȭ"
        } catch {
            Write-Err "W-03: [$($u.Name)] ���� ? $_"
        }
    }
}

# ��������������������������������������������������������������������������������������������������������������������
# 7. W?05 ������ ��ȣ ���� ����
# ��������������������������������������������������������������������������������������������������������������������
Import-Module Microsoft.PowerShell.LocalAccounts   # �ʿ� �� ��� �ε�

$dom = (Get-CimInstance Win32_ComputerSystem -EA 0).PartOfDomain      # ������ ����
$builtin = Get-LocalUser | Where-Object { $_.SID -match '-500$' }     # ���� Admin Ȯ��
if (-not $builtin) {
    Remove-LocalGroupMember Administrators "$env:COMPUTERNAME\Administrator" -EA 0
}

try {
    $cfg = "$env:TEMP\w05_$(Get-Random).inf"
    secedit /export /cfg $cfg | Out-Null
    (Get-Content $cfg) -replace 'PasswordStoreCleartext\s*=.*','PasswordStoreCleartext = 0' |
        Set-Content $cfg -Encoding Unicode
    secedit /configure /db secedit.sdb /cfg $cfg /areas SECURITYPOLICY | Out-Null
    Remove-Item $cfg -Force
    Write-OK  "W-05: ������ ��ȣ ���� ���� ���� �Ϸ�"
}
catch {
    Write-Err "W-05: ���� ? $_"
}



# ������������������������������������������������������������������������������������
# 8. W-06 ������ �׷� ����
# ������������������������������������������������������������������������������������
# ������ ������ SID ���
$newAdminSid = (Get-LocalUser -Name $NewAdminName).SID.Value
$systemSid   = 'S-1-5-18'    # NT AUTHORITY\SYSTEM
$keepSids    = @($newAdminSid, $systemSid)

# Administrators �׷� ��� ��ȸ �� ����
Get-LocalGroupMember -Group 'Administrators' |
Where-Object {
    $_.ObjectClass -eq 'User' -and
    $keepSids -notcontains $_.SID.Value
} |
ForEach-Object {
    try {
        # SID ������� ����
        Remove-LocalGroupMember `
            -Group 'Administrators' `
            -Member $_.SID.Value `
            -ErrorAction Stop `
            -Confirm:$false

        Write-OK "W-06: Administrators���� [$($_.Name)] ���� �Ϸ�"
    }
    catch {
        Write-Err "W-06: [$($_.Name)] ���� ���� ? $($_.Exception.Message)"
    }
}

# ��������������������������������������������������������������������������������������������������������������������
# 9. W-08 �⺻ ����(C$, D$) �ڵ����� ���� / SMBv1 ��Ȱ��ȭ
# ��������������������������������������������������������������������������������������������������������������������

try {
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath | Out-Null
    }

    Set-ItemProperty -Path $regPath -Name 'AutoShareServer' -Value 0 -Force
    Set-ItemProperty -Path $regPath -Name 'SMB1' -Value 0 -Type DWord -Force

    Write-OK "W-08: �⺻ ���� ���� �� SMBv1 ��Ȱ��ȭ �Ϸ� (����� �� ����)"
    Need-Reboot
} catch {
    Write-Err "W-08: �⺻ ���� ���� �Ǵ� SMBv1 ���� ���� ? $_"
}


# ��������������������������������������������������������������������������������������������������������������������
# 10. W-09 + W-60/63/65 ���ʿ� ���� ��Ȱ��ȭ (��ġ �� �� ���񽺴� �ǳʶ�)
# ��������������������������������������������������������������������������������������������������������������������
$AllBlock = $BlockServices + $ExtraBlockSvc

foreach ($svcName in $AllBlock) {
    # ���� ��ȸ (�����ص� ���� ���ο� �� ��)
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue

    # ��ġ �� �� ���񽺴� ��ŵ
    if (-not $svc) {
        Write-Host "W-09/60/63/65: ���� [$svcName] ��ġ �� ��, �ǳʶ�"
        continue
    }

    try {
        # (1) ���� ���̸� ����
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -InputObject $svc -Force -ErrorAction SilentlyContinue
        }

        # (2) ��Ȱ��ȭ (��ü ���� �� -InputObject ���)
        Set-Service -InputObject $svc -StartupType Disabled -ErrorAction Stop

        Write-OK "W-09/60/63/65: ���� [$svcName] ��������Ȱ��ȭ �Ϸ�"
    }
    catch {
        Write-Err "W-09/60/63/65: [$svcName] ���� ? $($_.Exception.Message)"
    }
}


# ��������������������������������������������������������������������������������������������������������������������
# 11. W-24 NetBIOS ���ε� ���� ���� �� ���� ��Ȱ��ȭ
# ��������������������������������������������������������������������������������������������������������������������
try {
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
    $keys = Get-ChildItem -Path $base -ErrorAction Stop

    foreach ($key in $keys) {
        try {
            $fullPath = Join-Path $base $key.PSChildName
            Set-ItemProperty -Path $fullPath -Name 'NetbiosOptions' -Value 2 -Type DWord -Force
            Write-OK "W-24: [$($key.PSChildName)] NetbiosOptions = 2 (��Ȱ��ȭ)"
        } catch {
            Write-Err "W-24: [$($key.PSChildName)] ���� ���� ? $_"
        }
    }
} catch {
    Write-Err "W-24: NetBIOS �������̽� ���� ���� ? $_"
}


# ��������������������������������������������������������������������������������������������������������������������
# 12. W?35 RemoteRegistry ���� ��Ȱ��ȭ
# ��������������������������������������������������������������������������������������������������������������������
try {
    $rr = Get-Service RemoteRegistry -ErrorAction SilentlyContinue
    if ($rr) {
        if ($rr.Status -ne 'Stopped') { Stop-Service RemoteRegistry -Force }
        Set-Service RemoteRegistry -StartupType Disabled
        Write-OK "W-35: RemoteRegistry ���� ��Ȱ��ȭ"
    }
} catch { Write-Err "W-35: ���� ? $_" }

# ������������������������������������������������������������������������������������
# 13. W-38 ȭ�麸ȣ�� ��å (10�С���ȣ ����)
# ������������������������������������������������������������������������������������
#Requires -RunAsAdministrator     # ������ ���� ����

try {
    $desk = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop'

    # �ʿ��� ��θ� ����
    if (-not (Test-Path $desk)) {
        New-Item -Path $desk -Force -ErrorAction Stop | Out-Null
    }

    # ��å �� ����
    Set-ItemProperty -Path $desk -Name 'ScreenSaveActive'    -Value 1   -Type String -Force
    Set-ItemProperty -Path $desk -Name 'ScreenSaverIsSecure' -Value 1   -Type String -Force
    Set-ItemProperty -Path $desk -Name 'ScreenSaveTimeOut'   -Value 600 -Type String -Force
    Set-ItemProperty -Path $desk -Name 'SCRNSAVE.EXE'        -Value 'scrnsave.scr' -Type String -Force

    Write-OK 'W-38: ȭ�麸ȣ�� ��å ���� �Ϸ�'
}
catch {
    Write-Err "W-38: ���� ? $_"
}


# ������������������������������������������������������������������������������������
# 14. W-39 �α׿����� �ʰ� �ý��� ���� ��� ����
# ������������������������������������������������������������������������������������
#Requires -RunAsAdministrator

try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'

    # Lsa Ű�� �⺻������ ����������, ������ ���� Ȯ��
    if (-not (Test-Path $lsa)) {
        New-Item -Path $lsa -ErrorAction Stop | Out-Null
    }

    # 0 = ��� �� ��, 1 = ���
    Set-ItemProperty -Path $lsa -Name 'ShutdownWithoutLogon' -Value 0 -Type DWord -Force

    Write-OK 'W-39: �α׿� ���� �ý��� ���� ��� ���� �Ϸ�'
}
catch {
    Write-Err "W-39: ���� ? $_"
}



# ������������������������������������������������������������������������������������
# 15. W-41 ���� ���縦 �α��� �� ���� ��� ��� �ý��� ���� 
#     W-52 ������ ����� �̸� ����
# ������������������������������������������������������������������������������������
try {
    # ������Ʈ�� ��� ����
    $sysPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'

    # ������ Ű ����
    if (-not (Test-Path -Path $sysPath)) {
        New-Item -Path $sysPath -Force | Out-Null
    }
    if (-not (Test-Path -Path $lsaPath)) {
        New-Item -Path $lsaPath -Force | Out-Null
    }

    # W-52: ������ ����� �̸� ����
    Set-ItemProperty `
        -Path $sysPath `
        -Name 'DontDisplayLastUserName' `
        -Value 1 `
        -Type DWord `
        -Force

    # W-41: ���� ���縦 �α��� �� ���� �� �ý��� ���� ��Ȱ��ȭ (0 = ��Ȱ��ȭ)
    Set-ItemProperty `
        -Path $lsaPath `
        -Name 'CrashOnAuditFail' `
        -Value 0 `
        -Type DWord `
        -Force

    Write-OK "W-41/W-52: ���� ���� �Ϸ� (������ ����� �̸� ����, CrashOnAuditFail ����)"
}
catch {
    Write-Err "W-41/W-52: ���� ? $($_.Exception.Message)"
}


# ��������������������������������������������������������������������������������������������������������������������
# 16. W-40 / W-44 ����� ���� ���� (secedit)
# ��������������������������������������������������������������������������������������������������������������������

function Set-SecPol {             # (�� ������ �̹� �ִٸ� �� �Լ� �κ��� ����)
    param($Area,$Key,$Val)
    $cfg="$env:TEMP\secpol.inf"
    secedit /export /cfg $cfg /areas $Area | Out-Null
    if ((Get-Content $cfg) -notmatch "^\s*$Key\s*=") {
        Add-Content $cfg "$Key = $Val"
    } else {
        (Get-Content $cfg) -replace "^\s*$Key\s*=.*","$Key = $Val" |
            Set-Content $cfg
    }
    secedit /configure /db secedit.sdb /cfg $cfg /areas $Area | Out-Null
    Remove-Item $cfg -Force
}

try { Set-SecPol 'USER_RIGHTS' 'SeRemoteShutdownPrivilege' '*S-1-5-32-544'; Write-OK "W-40: ���� ���� ���� ���� ����" }
catch { Write-Err "W-40: ���� ? $_" }

try { Set-SecPol 'USER_RIGHTS' 'AllocateDASD' '*S-1-5-32-544'; Write-OK "W-44: �̵��� �̵�� ����/������ ���� ����" }
catch { Write-Err "W-44: ���� ? $_" }


# ��������������������������������������������������������������������������������������������������������������������
# 16. W-42 SAM������ �͸� ���� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }      # �� ����(���Ǻ� ����)
    Set-ItemProperty $lsa RestrictAnonymous    1
    Set-ItemProperty $lsa RestrictAnonymousSAM 1
    Write-OK "W-42: �͸� ���� ���� �Ϸ�"
} catch { Write-Err "W-42: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 17. W-43 �ڵ� �α׿� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

    # (1) Ű�� ������ ����
    if (-not (Test-Path -Path $winlogonPath)) {
        New-Item -Path $winlogonPath -Force | Out-Null
    }

    # (2) �ڵ� �α׿� ��� ���� (0 = ��Ȱ��ȭ)
    Set-ItemProperty `
        -Path $winlogonPath `
        -Name 'AutoAdminLogon' `
        -Value 0 `
        -Type DWord `
        -Force

    Write-OK "W-43: �ڵ� �α׿� ��� ���� �Ϸ�"
}
catch {
    Write-Err "W-43: ���� ? $($_.Exception.Message)"
}

# ��������������������������������������������������������������������������������������������������������������������
# 18. W?46 Everyone ��� ������ �͸� ����ڿ� ���� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    Set-ItemProperty $lsa EveryoneIncludesAnonymous 0
    Write-OK "W-46: Everyone ���ѿ��� �͸� ����� ����"
} catch { Write-Err "W-46: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 19. W-48~56 �н����� ��å���� ��ȣ ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    net accounts /minpwlen:8 /minpwage:1 /uniquepw:12 | Out-Null

    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }   # �� ���Ǻ� ����(����)

    Set-ItemProperty $lsa PasswordComplexity   1
    Set-ItemProperty $lsa LimitBlankPasswordUse 1
    Write-OK "W-48~56: �н����� ���⼺������ ���� �Ϸ�"
} catch { Write-Err "W-48~56: ���� ? $_" }


# ��������������������������������������������������������������������������������������������������������������������
# 20. W-54: �͸� SID/�̸� ��ȯ ��� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }   # �� �� �ٸ� ����
    Set-ItemProperty $lsa -Name LSAAnonymousNameLookup -Value 0
    Write-OK  "W-54: �͸� SID/�̸� ��ȯ ��� ���� �Ϸ�"
} catch {
    Write-Err "W-54: ���� ? $_"
}


# ��������������������������������������������������������������������������������������������������������������������
# 21. W-56: �ܼ� �α׿� �� ���� �������� �� ��ȣ ��� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }   # �� ����: ���Ǻ� ����
    Set-ItemProperty $lsa -Name LimitBlankPasswordUse -Value 1
    Write-OK  "W-56: �� ��ȣ ��� ���� ���� �Ϸ�"
} catch {
    Write-Err "W-56: ���� ? $_"
}


# ��������������������������������������������������������������������������������������������������������������������
# 22. W-57 RDP ���� �׷� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $tempInf = "$env:TEMP\Rdp.inf"
    $tempDb  = "$env:TEMP\Rdp.sdb"

    secedit /export /cfg $tempInf

    (Get-Content $tempInf) `
      -replace 'SeRemoteInteractiveLogonRight =.*', `
               'SeRemoteInteractiveLogonRight = *S-1-5-32-544,*S-1-5-32-555' |
    Set-Content $tempInf -Encoding Unicode

    secedit /configure /db $tempDb /cfg $tempInf /areas USER_RIGHTS

    Write-OK "W-57: RDP ���� ���� �׷� ���� �Ϸ�"
} catch {
    Write-Err "W-57: ���� ? $($_.Exception.Message)"
}

# ��������������������������������������������������������������������������������������������������������������������
# 24. W?58 RDP ��ȣȭ ���� �ֻ�/ W?67 RDP ���� Idle Ÿ�Ӿƿ� 10��
# ��������������������������������������������������������������������������������������������������������������������
try {
$ts = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
if (-not (Test-Path $ts)) {
    New-Item -Path $ts | Out-Null
}
Set-ItemProperty $ts MinEncryptionLevel 3
Set-ItemProperty $ts MaxIdleTime 600000
    Write-OK "W-58: �͹̳� ���� ��ȣȭ ���� �ֻ�, W?67 RDP ���� Idle Ÿ�Ӿƿ� 10��"
} catch { Write-Err "W-58: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 22. W?67 RDP ���� Idle Ÿ�Ӿƿ� 10��
# ��������������������������������������������������������������������������������������������������������������������
try {
    $ts='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
    Set-ItemProperty $ts MaxIdleTime 600000
    Write-OK "W-67: RDP ���� Ÿ�Ӿƿ� 10��"
} catch { Write-Err "W-67: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 23. W-69 ��å�� ���� �ý��� �α� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    # ���� ���� ����
    auditpol /set /subcategory:"����� ���� ����" /failure:enable
    auditpol /set /subcategory:"���� �׷� ����" /success:enable /failure:enable

    # ���� �α׿� �̺�Ʈ ����
    auditpol /set /subcategory:"�ڰ� ���� ��ȿ�� �˻�" /success:enable /failure:enable
    auditpol /set /subcategory:"Kerberos ���� ����" /success:enable /failure:enable
    auditpol /set /subcategory:"Kerberos ���� Ƽ�� �۾�" /success:enable /failure:enable

    # �α׿� �̺�Ʈ ����
    auditpol /set /subcategory:"�α׿�" /success:enable /failure:enable
    auditpol /set /subcategory:"Ư�� �α׿�" /success:enable /failure:enable
    auditpol /set /subcategory:"���� ���" /success:enable /failure:enable

    # ��å ���� ����
    auditpol /set /subcategory:"���� ��å ����" /success:enable /failure:enable
    auditpol /set /subcategory:"���� �ο� ��å ����" /success:enable /failure:enable
    auditpol /set /subcategory:"���� ��å ����" /success:enable /failure:enable

    # ���� ��� ����
    auditpol /set /subcategory:"�߿��� ���� ���" /failure:enable
    auditpol /set /subcategory:"��Ÿ ���� ��� �̺�Ʈ" /failure:enable

    # ���μ��� ����
    auditpol /set /subcategory:"���μ��� �����" /success:enable
    auditpol /set /subcategory:"���μ��� ����" /success:enable

    # ���͸� ���� �׼��� ����
    auditpol /set /subcategory:"���͸� ���� �׼���" /failure:enable

    Write-OK "W-69: ���� ��å ���� ���� ��å ���� �Ϸ�"
} catch {
    Write-Err "W-69: ���� ��å ���� ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 24. W?71 �̺�Ʈ �α� ��� Everyone ���� (�ֻ��� ������)
# ��������������������������������������������������������������������������������������������������������������������
$LogDirs = @("$env:SystemRoot\System32\config","$env:SystemRoot\System32\logfiles")
foreach($p in $LogDirs){
    try{
        icacls $p /remove:g "Everyone" /inheritance:d >$null 2>&1
        Write-OK "W-71: $p ���� ����"
    }catch{ Write-Err "W-71: $p ���� ? $_" }
}

# ��������������������������������������������������������������������������������������������������������������������
# 25. W?73 ����� ������ ����̹� ��ġ ����
# ��������������������������������������������������������������������������������������������������������������������

try {
$pr = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers'
if (-not (Test-Path $pr)) {
    New-Item -Path $pr | Out-Null
}
Set-ItemProperty $pr AddPrinterDrivers 0
    Write-OK "W-73: ������ ����̹� ��ġ ����"
} catch { Write-Err "W-73: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 26. W?74 ���� ���� 15�� �� �ڵ� ����
#  ��������������������������������������������������������������������������������������������������������������������

try {
    $srv = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters'
    if (-not (Test-Path $srv)) {
        New-Item -Path $srv | Out-Null
    }
    Set-ItemProperty -Path $srv -Name 'EnableForcedLogoff' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $srv -Name 'AutoDisconnect' -Value 15 -Type DWord -Force
    Write-OK "W-74: ���� ���� 15�� �� �ڵ� ����"
} catch {
    Write-Err "W-74: ���� ? $_"
}


# ��������������������������������������������������������������������������������������������������������������������
# 27. W?75 ��� ���
# ��������������������������������������������������������������������������������������������������������������������
try {
    $cap="���: ���� ���� ����"
    $txt="�� �ý����� �㰡���� ����ڸ� ������ �� �ֽ��ϴ�.`n���� ���� �� ���� ó���� ���� �� �ֽ��ϴ�."
    $sys='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    Set-ItemProperty $sys legalnoticecaption $cap
    Set-ItemProperty $sys legalnoticetext  $txt
    Write-OK "W-75: ��� ��� ���� �Ϸ�"
} catch { Write-Err "W-75: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 28. W?76 ����� Ȩ ���͸� Everyone ���� ���� + $NewAdminName ���� �ο�
# ��������������������������������������������������������������������������������������������������������������������
try {
    $Skip = @('All Users','Default','Default User','Public','DefaultAppPool','MSSQL','defaultuser0')
    
    Get-ChildItem 'C:\Users' -Directory | Where-Object { $Skip -notcontains $_.Name } | ForEach-Object {
        $userDir = $_.FullName

        # Everyone �׷� ����
        icacls $userDir /remove:g "Everyone" /T >$null 2>&1

        # ������ ������ ��ü ���� �ο�
        icacls $userDir /grant:r "${NewAdminName}:(OI)(CI)(F)" /T >$null 2>&1

        Write-OK "W-76: [$($_.Name)] Everyone ���� �� $NewAdminName ��ü ���� �ο�"
    }
}
catch {
    Write-Err "W-76: ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 29. W?77 LAN Manager ���� ���� 3 (CIS �ֽ� ������ 5 �� �ʿ� �� ����)
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    Set-ItemProperty $lsa LmCompatibilityLevel 3
    Write-OK "W-77: LAN Manager ���� ���� 3"
} catch { Write-Err "W-77: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 30. W?78 ���� ä�� ������ ������ȣȭ
# ��������������������������������������������������������������������������������������������������������������������
try {
    $nlg = 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters'
    if (-not (Test-Path $nlg)) {
        New-Item -Path $nlg | Out-Null
    }
    Set-ItemProperty $nlg RequireSignOrSeal 1
    Set-ItemProperty $nlg SealSecureChannel 1
    Set-ItemProperty $nlg SignSecureChannel 1
    Write-OK "W-78: ���� ä�� ��ȣȭ������ ����"
} catch {
    Write-Err "W-78: ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 31. Windows Update �ڵ� ������Ʈ ����
# ��������������������������������������������������������������������������������������������������������������������
try {
   # �ڵ� ������Ʈ�� ���� (���񽺴� �״�� ����)
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    if (-not (Test-Path $wu)) {
        New-Item -Path $wu | Out-Null
    }

    # �ڵ� ������Ʈ ��å(������Ʈ��) ��Ȱ��ȭ
$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
if (-not (Test-Path $wu)) {
    New-Item -Path $wu | Out-Null
}
Set-ItemProperty -Path $wu -Name 'NoAutoUpdate' -Value 1
Set-ItemProperty -Path $wu -Name 'AUOptions' -Value 1

    Write-OK "W-78: Windows Update �ڵ� ������Ʈ ����"
}
catch {
    Write-Err "W-78: ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 32. ���� Ȯ���� ���� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0
    Write-OK "�߰�: ���� Ȯ���� ���� ����"
} catch { Write-Err "Ȯ���� ���� ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 33. �̺�Ʈ �α� �ִ� ũ�� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    wevtutil sl Security /ms:41943040
    wevtutil sl Application /ms:20971520
    wevtutil sl System /ms:20971520
    Write-OK "�߰�: �̺�Ʈ �α� �ִ� ũ�� ���� �Ϸ�"
} catch { Write-Err "�̺�Ʈ �α� ũ�� ���� ���� ? $_" }


# ��������������������������������������������������������������������������������������������������������������������
# 35. WDigest ���� ��Ȱ��ȭ
# ��������������������������������������������������������������������������������������������������������������������
try {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name 'UseLogonCredential' -Value 0 -Type DWord
        Write-OK "�߰�: WDigest ���� ��Ȱ��ȭ"
    } catch { Write-Err "WDigest ���� ���� ? $_" }


# ��������������������������������������������������������������������������������������������������������������������
# 37. TCP ���� Ʃ�� �� RDP ���� ����
# ��������������������������������������������������������������������������������������������������������������������

try {
    $tcpip = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    if (-not (Test-Path $tcpip)) { New-Item -Path $tcpip | Out-Null }

    Set-ItemProperty -Path $tcpip -Name 'TcpTimedWaitDelay' -Value 30 -Type DWord
    Set-ItemProperty -Path $tcpip -Name 'MaxUserPort' -Value 65534 -Type DWord

    Write-OK "�߰�: TCP TimeWaitDelay(30��) �� MaxUserPort(65534) ���� �Ϸ�"
} catch {
    Write-Err "TCP ���� Ʃ�� ���� ? $_"
}

try {
    $tsRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    if (-not (Test-Path $tsRoot)) { New-Item -Path $tsRoot | Out-Null }

    Set-ItemProperty -Path $tsRoot -Name 'fDenyTSConnections' -Value 0 -Type DWord
    Set-ItemProperty -Path $tsRoot -Name 'fSingleSessionPerUser' -Value 0 -Type DWord

    Write-OK "�߰�: RDP Ȱ��ȭ �� ��Ƽ ���� ��� ���� �Ϸ�"
} catch {
    Write-Err "RDP �⺻ ���� ���� ? $_"
}

try {
    $rdpTcp = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
    if (-not (Test-Path $rdpTcp)) { New-Item -Path $rdpTcp | Out-Null }

    Set-ItemProperty -Path $rdpTcp -Name 'MaxInstanceCount' -Value 2 -Type DWord

    Write-OK "�߰�: RDP ���� ���� �ִ� 2�� ���� �Ϸ�"
} catch {
    Write-Err "RDP ���� ���� �� ���� ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 36. W-53 ���� �α׿� ��� ���� ���� (Administrators, IIS_IUSRS �׷�)
# ��������������������������������������������������������������������������������������������������������������������
try {
    $cfgPath = "$env:TEMP\W53.inf"
    $dbPath  = "$env:TEMP\W53.sdb"

    # SID: *S-1-5-32-544 = Administrators
    # SID: *S-1-5-32-568 = IIS_IUSRS �׷�
    $sids = '*S-1-5-32-544,*S-1-5-32-568'

    secedit /export /cfg $cfgPath /areas USER_RIGHTS | Out-Null

    # SeInteractiveLogonRight ���� ������ ������ SID�� ����
    (Get-Content $cfgPath) `
        -replace '^SeInteractiveLogonRight\s*=.*', "SeInteractiveLogonRight = $sids" |
    Set-Content $cfgPath -Encoding Unicode

    # ��å ����
    secedit /configure /db $dbPath /cfg $cfgPath /areas USER_RIGHTS | Out-Null

    Remove-Item $cfgPath,$dbPath -Force
    Write-OK "W-53: ���� �α׿� ����� Administrators, IIS_IUSRS�� ������"
}
catch {
    Write-Err "W-53: ���� ? $_"
}


# ��������������������������������������������������������������������������������������������������������������������
# 38 . ������
# ��������������������������������������������������������������������������������������������������������������������
$warningMsg = @"
����������������������������������������������������������������������������������������
? [����] �Ϻ� ���� ������ ������ ���� �뵵�� ����
   ���� ��� ������ �� �� �ֽ��ϴ�.

 01. W?01 Administrator ���� �̸� ����
   - �⺻ ������ ���� �̸��� [$NewAdminName] ���� ����Ǿ����ϴ�.
   - ���� �α��� �Ǵ� ��ũ��Ʈ ���� �� �������� �� �̸����� ����ϼ���.

 26. W?74 ���� ���� 15�� �� �ڵ� ����
   - ���� ��: 15��
   - ���� ����, ��ð� ���� ������ �ʿ��� ����������
     ���� ����, ���� ���� ������ �߻��� �� �ֽ��ϴ�.
   - ���� ������ �ʿ��ϸ� �Ʒ� ������� ���� ������ �����մϴ�.
     Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name 'AutoDisconnect' -Value -1
����������������������������������������������������������������������������������������
"@

Write-Warn $warningMsg          # ����� ��� ���
Write-Info ""                  # �� �� (�ϰ��� ��� �Լ� ���)