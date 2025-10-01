# ��������������������������������������������������������������������������������������������������������������������
# ������ ���� �ڵ� �°�
# ��������������������������������������������������������������������������������������������������������������������
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "������ �������� �ٽ� �����մϴ�..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# �α� ���� ���
$log = "C:\Windows\SecurityScript_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ��������������������������������������������������������������������������������������������������������������������
# 0. ����� ���� �Ķ����
# ��������������������������������������������������������������������������������������������������������������������
$NewAdminName   = 'iteasy'
$Lockout        = @{Threshold = 5; Duration = 60; Window = 60}
$AccountWhite   = @($NewAdminName,'Guest','WDAGUtilityAccount','DefaultAccount')
$BlockServices  = @('SNMP','SNMPTRAP','Telnet','Fax','TlntSvr','TrkWks','TrkSvr','Spooler')
$ExtraBlockSvc  = @('DNS')
$NeedReboot     = $false

# ��������������������������������������������������������������������������������������������������������������������
# 1. ���� ��� �Լ�
# ��������������������������������������������������������������������������������������������������������������������
function Log-Info { param($m) Add-Content -Path $log -Value "[INFO] $m" }
function Log-OK   { param($m) Add-Content -Path $log -Value "[ OK ] $m" }
function Log-Warn { param($m) Add-Content -Path $log -Value "[WARN] $m" }
function Log-Err  { param($m) Add-Content -Path $log -Value "[ERR ] $m" }
function Need-Reboot{ $script:NeedReboot = $true }

# ��������������������������������������������������������������������������������������������������������������������
# 2. ����
# ��������������������������������������������������������������������������������������������������������������������
Log-Info "`n===== Windows?Server?2012 ���� ���� ���� ====="

# ��������������������������������������������������������������������������������������������������������������������
# 3. W?01 Administrator ���� �̸� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $admin = Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount=True AND SID LIKE '%-500'"
    if ($admin) {
        if ($admin.Name -ne $NewAdminName) {
            wmic useraccount where "name='$($admin.Name)'" rename $NewAdminName
            Log-OK  "W-01: Administrator �� $NewAdminName ���� �Ϸ�"
            Need-Reboot
        } else {
            Log-Warn "W-01: �̹� $NewAdminName ���� �����"
        }
    } else {
        Log-Warn "W-01: ���� Administrator ������ �������� ����"
    }
} catch { Log-Err "W-01: ���� ? $_" }


# ��������������������������������������������������������������������������������������������������������������������
# 4. W?02 Guest ���� ��Ȱ��ȭ
# ��������������������������������������������������������������������������������������������������������������������
try {
    net user Guest /active:no
    Log-OK "W-02: Guest ���� ��Ȱ��ȭ �Ϸ�"
} catch { Log-Err "W-02: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 5. W?03 ���ʿ� ���� ���� ��Ȱ��ȭ (ȭ��Ʈ����Ʈ)
# ��������������������������������������������������������������������������������������������������������������������
$allUsers = (Get-WmiObject Win32_UserAccount | Where-Object { $_.LocalAccount -eq $true })
foreach ($u in $allUsers) {
    if ($AccountWhite -notcontains $u.Name) {
        try {
            net user "$($u.Name)" /active:no
            Log-OK "W-03: [$($u.Name)] ��Ȱ��ȭ"
        } catch {
            Log-Err "W-03: [$($u.Name)] ���� ? $_"
        }
    }
}

# ��������������������������������������������������������������������������������������������������������������������
# 6. W?04��47 ���� ��� ��å ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    net accounts /lockoutthreshold:$($Lockout.Threshold) `
                 /lockoutduration:$($Lockout.Duration) `
                 /lockoutwindow:$($Lockout.Window) | Out-Null
    Log-OK "W-04/47: ���� ��� �Ӱ谪���Ⱓ ���� �Ϸ� ($($Lockout.Threshold)ȸ / $($Lockout.Duration)��)"
} catch { Log-Err "W-04/47: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 7. W?05 ������ ��ȣ ���� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $cfg = "$env:TEMP\w05_$(Get-Random).inf"
    secedit /export /cfg $cfg /areas SECURITYPOLICY | Out-Null
    (Get-Content $cfg) -replace 'PasswordStoreCleartext\s*=.*','PasswordStoreCleartext = 0' |
        Set-Content $cfg -Encoding Unicode
    secedit /configure /db secedit.sdb /cfg $cfg /areas SECURITYPOLICY | Out-Null
    Remove-Item $cfg -Force
    Log-OK "W-05: ������ ��ȣ ���� ���� ���� �Ϸ�"
} catch {
    Log-Err "W-05: ���� ? $_"
}



# ������������������������������������������������������������������������������������
# 8. W-06 ������ �׷� ����
# ������������������������������������������������������������������������������������
$members = net localgroup Administrators | Select-String -Pattern '^\s\S+' | ForEach-Object { $_.ToString().Trim() }
foreach ($m in $members) {
    if ($AccountWhite -notcontains $m) {
        try {
            net localgroup Administrators "$m" /delete
            Log-OK "W-06: Administrators���� [$m] ���� �Ϸ�"
        } catch {
            Log-Err "W-06: [$m] ���� ����"
        }
    }
}


# ��������������������������������������������������������������������������������������������������������������������
# 9. W-08 �⺻ ����(C$, D$) �ڵ����� ���� / SMBv1 ��Ȱ��ȭ
# ��������������������������������������������������������������������������������������������������������������������
try {
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath | Out-Null }
    Set-ItemProperty -Path $regPath -Name 'AutoShareServer' -Value 0 -Force
    Set-ItemProperty -Path $regPath -Name 'SMB1' -Value 0 -Force
    Log-OK "W-08: �⺻ ���� ���� �� SMBv1 ��Ȱ��ȭ �Ϸ� (����� �ʿ�)"
    Need-Reboot
} catch { Log-Err "W-08: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 10. W-09 + W-60/63/65 ���ʿ� ���� ��Ȱ��ȭ (��ġ �� �� ���񽺴� �ǳʶ�)
# ��������������������������������������������������������������������������������������������������������������������
$AllBlock = $BlockServices + $ExtraBlockSvc
foreach ($svcName in $AllBlock) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if (-not $svc) {
        Log-Warn "W-09/60/63/65: [$svcName] ��ġ �� ��"
        continue
    }
    try {
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -InputObject $svc -Force
        }
        Set-Service -InputObject $svc -StartupType Disabled
        Log-OK "W-09/60/63/65: [$svcName] ���� �� ��Ȱ��ȭ �Ϸ�"
    } catch { Log-Err "W-09/60/63/65: [$svcName] ���� ? $_" }
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
            Log-OK "W-24: [$($key.PSChildName)] NetbiosOptions = 2 (��Ȱ��ȭ)"
        } catch {
            Log-Err "W-24: [$($key.PSChildName)] ���� ���� ? $_"
        }
    }
} catch {
    Log-Err "W-24: NetBIOS �������̽� ���� ���� ? $_"
}


# ��������������������������������������������������������������������������������������������������������������������
# 12. W?35 RemoteRegistry ���� ��Ȱ��ȭ
# ��������������������������������������������������������������������������������������������������������������������
try {
    $rr = Get-Service RemoteRegistry -ErrorAction SilentlyContinue
    if ($rr) {
        if ($rr.Status -ne 'Stopped') { Stop-Service RemoteRegistry -Force }
        Set-Service RemoteRegistry -StartupType Disabled
        Log-OK "W-35: RemoteRegistry ���� ��Ȱ��ȭ"
    }
} catch { Log-Err "W-35: ���� ? $_" }

# ������������������������������������������������������������������������������������
# 13. W-38 ȭ�麸ȣ�� ��å (10�С���ȣ ����)
# ������������������������������������������������������������������������������������

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

    Log-OK 'W-38: ȭ�麸ȣ�� ��å ���� �Ϸ�'
}
catch {
    Log-Err "W-38: ���� ? $_"
}


# ������������������������������������������������������������������������������������
# 14. W-39 �α׿����� �ʰ� �ý��� ���� ��� ����
# ������������������������������������������������������������������������������������

try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'

    # Lsa Ű�� �⺻������ ����������, ������ ���� Ȯ��
    if (-not (Test-Path $lsa)) {
        New-Item -Path $lsa -ErrorAction Stop | Out-Null
    }

    # 0 = ��� �� ��, 1 = ���
    Set-ItemProperty -Path $lsa -Name 'ShutdownWithoutLogon' -Value 0 -Type DWord -Force

    Log-OK 'W-39: �α׿� ���� �ý��� ���� ��� ���� �Ϸ�'
}
catch {
    Log-Err "W-39: ���� ? $_"
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

    Log-OK "W-41/W-52: ���� ���� �Ϸ� (������ ����� �̸� ����, CrashOnAuditFail ����)"
}
catch {
    Log-Err "W-41/W-52: ���� ? $($_.Exception.Message)"
}


# ��������������������������������������������������������������������������������������������������������������������
# 16. W-40 / W-44 ����� ���� ���� (secedit)
# ��������������������������������������������������������������������������������������������������������������������

function Set-SecPol {
    param($Area,$Key,$Val)
    $cfg="$env:TEMP\secpol.inf"
    secedit /export /cfg $cfg /areas $Area | Out-Null
    if ((Get-Content $cfg) -notmatch "^\s*$Key\s*=") {
        Add-Content $cfg "$Key = $Val"
    } else {
        (Get-Content $cfg) -replace "^\s*$Key\s*=.*","$Key = $Val" |
            Set-Content $cfg
    }

    Start-Process -FilePath "secedit.exe" -ArgumentList "/configure /db secedit.sdb /cfg `"$cfg`" /areas $Area" -Wait -WindowStyle Hidden

    Remove-Item $cfg -Force
}

try { Set-SecPol 'USER_RIGHTS' 'SeRemoteShutdownPrivilege' '*S-1-5-32-544'; Log-OK "W-40: ���� ���� ���� ���� ����" }
catch { Log-Err "W-40: ���� ? $_" }

try { Set-SecPol 'USER_RIGHTS' 'AllocateDASD' '*S-1-5-32-544'; Log-OK "W-44: �̵��� �̵�� ����/������ ���� ����" }
catch { Log-Err "W-44: ���� ? $_" }


# ��������������������������������������������������������������������������������������������������������������������
# 16. W-42 SAM������ �͸� ���� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }      # �� ����(���Ǻ� ����)
    Set-ItemProperty $lsa RestrictAnonymous    1
    Set-ItemProperty $lsa RestrictAnonymousSAM 1
    Log-OK "W-42: �͸� ���� ���� �Ϸ�"
} catch { Log-Err "W-42: ���� ? $_" }

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

    Log-OK "W-43: �ڵ� �α׿� ��� ���� �Ϸ�"
}
catch {
    Log-Err "W-43: ���� ? $($_.Exception.Message)"
}

# ��������������������������������������������������������������������������������������������������������������������
# 18. W?46 Everyone ��� ������ �͸� ����ڿ� ���� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    Set-ItemProperty $lsa EveryoneIncludesAnonymous 0
    Log-OK "W-46: Everyone ���ѿ��� �͸� ����� ����"
} catch { Log-Err "W-46: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 19. W-48~56 �н����� ��å���� ��ȣ ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    net accounts /minpwlen:8 /minpwage:1 /uniquepw:12 | Out-Null

    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }   # �� ���Ǻ� ����(����)

    Set-ItemProperty $lsa PasswordComplexity   1
    Set-ItemProperty $lsa LimitBlankPasswordUse 1
    Log-OK "W-48~56: �н����� ���⼺������ ���� �Ϸ�"
} catch { Log-Err "W-48~56: ���� ? $_" }


# ��������������������������������������������������������������������������������������������������������������������
# 20. W-54: �͸� SID/�̸� ��ȯ ��� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }   # �� �� �ٸ� ����
    Set-ItemProperty $lsa -Name LSAAnonymousNameLookup -Value 0
    Log-OK  "W-54: �͸� SID/�̸� ��ȯ ��� ���� �Ϸ�"
} catch {
    Log-Err "W-54: ���� ? $_"
}


# ��������������������������������������������������������������������������������������������������������������������
# 21. W-56: �ܼ� �α׿� �� ���� �������� �� ��ȣ ��� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }   # �� ����: ���Ǻ� ����
    Set-ItemProperty $lsa -Name LimitBlankPasswordUse -Value 1
    Log-OK  "W-56: �� ��ȣ ��� ���� ���� �Ϸ�"
} catch {
    Log-Err "W-56: ���� ? $_"
}


# ��������������������������������������������������������������������������������������������������������������������
# 22. W-57 RDP ���� �׷� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    secedit /export /cfg $tempInf | Out-Null

    (Get-Content $tempInf) `
      -replace 'SeRemoteInteractiveLogonRight =.*',
               'SeRemoteInteractiveLogonRight = *S-1-5-32-544,*S-1-5-32-555' |
    Set-Content $tempInf -Encoding Unicode

    Start-Process -FilePath "secedit.exe" -ArgumentList "/configure /db `"$tempDb`" /cfg `"$tempInf`" /areas USER_RIGHTS" -Wait -WindowStyle Hidden

    Log-OK "W-57: RDP ���� ���� �׷� ���� �Ϸ�"
}
catch {
    Log-Err "W-57: ���� ? $($_.Exception.Message)"
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
    Log-OK "W-58: �͹̳� ���� ��ȣȭ ���� �ֻ�, W?67 RDP ���� Idle Ÿ�Ӿƿ� 10��"
} catch { Log-Err "W-58: ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 22. W?67 RDP ���� Idle Ÿ�Ӿƿ� 10��
# ��������������������������������������������������������������������������������������������������������������������
try {
    $ts='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
    Set-ItemProperty $ts MaxIdleTime 600000
    Log-OK "W-67: RDP ���� Ÿ�Ӿƿ� 10��"
} catch { Log-Err "W-67: ���� ? $_" }

#������������������������������������������������������������������������������������������������������������������
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

    Log-OK "W-69: ���� ��å ���� ���� ��å ���� �Ϸ�"
}
catch {
    Log-Err "W-69: ���� ��å ���� ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 24. W?71 �̺�Ʈ �α� ��� Everyone ���� (�ֻ��� ������)
# ��������������������������������������������������������������������������������������������������������������������
$LogDirs = @("$env:SystemRoot\System32\config","$env:SystemRoot\System32\logfiles")
foreach($p in $LogDirs){
    try{
        icacls $p /remove:g "Everyone" /inheritance:d >$null 2>&1
        Log-OK "W-71: $p ���� ����"
    }catch{ Log-Err "W-71: $p ���� ? $_" }
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
    Log-OK "W-73: ������ ����̹� ��ġ ����"
} catch { Log-Err "W-73: ���� ? $_" }

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
    Log-OK "W-74: ���� ���� 15�� �� �ڵ� ����"
} catch {
    Log-Err "W-74: ���� ? $_"
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
    Log-OK "W-75: ��� ��� ���� �Ϸ�"
} catch { Log-Err "W-75: ���� ? $_" }

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

        Log-OK "W-76: [$($_.Name)] Everyone ���� �� $NewAdminName ��ü ���� �ο�"
    }
}
catch {
    Log-Err "W-76: ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 29. W?77 LAN Manager ���� ���� 3 (CIS �ֽ� ������ 5 �� �ʿ� �� ����)
# ��������������������������������������������������������������������������������������������������������������������
try {
    $lsa='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    Set-ItemProperty $lsa LmCompatibilityLevel 3
    Log-OK "W-77: LAN Manager ���� ���� 3"
} catch { Log-Err "W-77: ���� ? $_" }

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
    Log-OK "W-78: ���� ä�� ��ȣȭ������ ����"
} catch {
    Log-Err "W-78: ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 31. Windows Update �ڵ� ������Ʈ ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    # Windows Update ���� ��������Ȱ��ȭ
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Set-Service  -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue

    # Windows Update Medic Service(��Ȱ��ȭ ����) ��������Ȱ��ȭ
    sc.exe stop WaaSMedicSvc   > $null 2>&1
    sc.exe config WaaSMedicSvc start= disabled  > $null 2>&1

    # ���� �۾� ��Ȱ��ȭ (ǥ ��� ����)
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\WindowsUpdate\Scheduled Start" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "\Microsoft\Windows\UpdateOrchestrator\Scheduled Scan" -ErrorAction SilentlyContinue | Out-Null

    # COM �������̽��� �˸��� ǥ���ϵ��� ����
    $AUSettings = (New-Object -ComObject "Microsoft.Update.AutoUpdate").Settings
    $AUSettings.NotificationLevel = 1
    $AUSettings.Save()

    Log-OK "W-78: Windows Update �ڵ� ������Ʈ ���� (���񽺡������۾����˸���)"
}
catch {
    Log-Err "W-78: ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 32. ���� Ȯ���� ���� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0
    Log-OK "�߰�: ���� Ȯ���� ���� ����"
} catch { Log-Err "Ȯ���� ���� ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 33. �̺�Ʈ �α� �ִ� ũ�� ����
# ��������������������������������������������������������������������������������������������������������������������
try {
    wevtutil sl Security /ms:41943040
    wevtutil sl Application /ms:20971520
    wevtutil sl System /ms:20971520
    Log-OK "�߰�: �̺�Ʈ �α� �ִ� ũ�� ���� �Ϸ�"
} catch { Log-Err "�̺�Ʈ �α� ũ�� ���� ���� ? $_" }


# ��������������������������������������������������������������������������������������������������������������������
# 35. WDigest ���� ��Ȱ��ȭ
# ��������������������������������������������������������������������������������������������������������������������
try {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name 'UseLogonCredential' -Value 0 -Type DWord
        Log-OK "�߰�: WDigest ���� ��Ȱ��ȭ"
    } catch { Log-Err "WDigest ���� ���� ? $_" }

# ��������������������������������������������������������������������������������������������������������������������
# 36. ���� ����ũ�� ��Ʈ ���� �� ��ȭ�� ��� (netsh ���)
# ��������������������������������������������������������������������������������������������������������������������
$NewPort = 48321  # ���ϴ� ��Ʈ�� �����ϼ���

try {
    # RDP ��Ʈ ������Ʈ�� ����
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
                     -Name 'PortNumber' -Value $NewPort -Type DWord
    Log-OK "�߰�: ���� ����ũ�� ��Ʈ�� $NewPort �� ������"
} catch {
    Log-Err "���� ��Ʈ ���� ���� ? $_"
}

try {
    # ���� �⺻ RDP ��ȭ�� ��Ģ ��Ȱ��ȭ
    netsh advfirewall firewall set rule name="���� ����ũ�� - ����� ��� (TCP-In)" new enable=No >$null 2>&1

    # �� ��Ʈ�� ��ȭ�� ��Ģ �߰�
    netsh advfirewall firewall add rule name="Allow RDP Port $NewPort" `
         dir=in action=allow protocol=TCP localport=$NewPort >$null 2>&1

    Log-OK "�߰�: netsh ������� ��Ʈ $NewPort ��� ��Ģ �߰�"
} catch {
    Log-Err "��ȭ�� ��Ģ �߰� ���� ? $_"
}

# ��������������������������������������������������������������������������������������������������������������������
# 37. TCP ���� Ʃ�� �� RDP ���� ����
# ��������������������������������������������������������������������������������������������������������������������

try {
    $tcpip = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    if (-not (Test-Path $tcpip)) { New-Item -Path $tcpip | Out-Null }

    Set-ItemProperty -Path $tcpip -Name 'TcpTimedWaitDelay' -Value 30 -Type DWord
    Set-ItemProperty -Path $tcpip -Name 'MaxUserPort' -Value 65534 -Type DWord

    Log-OK "�߰�: TCP TimeWaitDelay(30��) �� MaxUserPort(65534) ���� �Ϸ�"
} catch {
    Log-Err "TCP ���� Ʃ�� ���� ? $_"
}

try {
    $tsRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    if (-not (Test-Path $tsRoot)) { New-Item -Path $tsRoot | Out-Null }

    Set-ItemProperty -Path $tsRoot -Name 'fDenyTSConnections' -Value 0 -Type DWord
    Set-ItemProperty -Path $tsRoot -Name 'fSingleSessionPerUser' -Value 0 -Type DWord

    Log-OK "�߰�: RDP Ȱ��ȭ �� ��Ƽ ���� ��� ���� �Ϸ�"
} catch {
    Log-Err "RDP �⺻ ���� ���� ? $_"
}

try {
    $rdpTcp = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
    if (-not (Test-Path $rdpTcp)) { New-Item -Path $rdpTcp | Out-Null }

    Set-ItemProperty -Path $rdpTcp -Name 'MaxInstanceCount' -Value 2 -Type DWord

    Log-OK "�߰�: RDP ���� ���� �ִ� 2�� ���� �Ϸ�"
} catch {
    Log-Err "RDP ���� ���� �� ���� ���� ? $_"
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
    Log-OK "W-53: ���� �α׿� ����� Administrators, IUSR_ �� ������"
}
catch {
    Log-Err "W-53: ���� ? $_"
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

Log-Warn $warningMsg          # ����� ��� ���
Log-Info ""                   # �� �� (�ϰ��� ��� �Լ� ���)
Log-Info "����Ϸ��� Enter Ű�� ��������."
Read-Host | Out-Null