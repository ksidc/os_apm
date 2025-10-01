# Windows Server 2019 ���� ��ȭ ��ũ��Ʈ (���� �α� ��� �� ���� ó�� ����)

# W-01: Administrator ���� �̸� ����
Write-Host "W-01: Administrator ���� �̸� ���� �õ�" -ForegroundColor Cyan
try {
    $adminSID = (Get-WmiObject Win32_UserAccount | Where-Object { $_.SID -like "*-500" }).SID
    $admin = Get-LocalUser | Where-Object { $_.SID -eq $adminSID }
    $newName = "iteasy_admin"
    if ($admin.Name -ne $newName) {
        Rename-LocalUser -Name $admin.Name -NewName $newName
        Write-Host " > Administrator �������� $newName(��)�� ���� �Ϸ�" -ForegroundColor Green
    } else {
        Write-Host " > �̹� ����� ������" -ForegroundColor Yellow
    }
} catch {
    Write-Host " > [����] Administrator ������ ���� ����: $_" -ForegroundColor Red
}

# W-02: Guest ���� ��Ȱ��ȭ
Write-Host "W-02: Guest ���� ��Ȱ��ȭ �õ�" -ForegroundColor Cyan
try {
    $guest = Get-LocalUser | Where-Object { $_.SID -like '*-501' }
    if ($guest -and $guest.Enabled) {
        Disable-LocalUser -Name $guest.Name
        Write-Host " > Guest ���� ��Ȱ��ȭ �Ϸ�" -ForegroundColor Green
    } else {
        Write-Host " > Guest ���� ���� �Ǵ� �̹� ��Ȱ��ȭ" -ForegroundColor Yellow
    }
} catch {
    Write-Host " > [����] Guest ���� ��Ȱ��ȭ ����: $_" -ForegroundColor Red
}

# W-03: ���ʿ��� ���� ����
Write-Host "W-03: ���ʿ��� ���� ��Ȱ��ȭ �õ�" -ForegroundColor Cyan
try {
    $except = @("iteasy_admin", "Guest", "WDAGUtilityAccount", "DefaultAccount")
    $removed = 0
    Get-LocalUser | Where-Object { $except -notcontains $_.Name } | ForEach-Object {
        try {
            Disable-LocalUser -Name $_.Name
            Write-Host " > $_.Name ���� ��Ȱ��ȭ �Ϸ�" -ForegroundColor Green
            $removed++
        } catch {
            Write-Host " > $_.Name ���� ��Ȱ��ȭ ����: $_" -ForegroundColor Red
        }
    }
    if ($removed -eq 0) { Write-Host " > ��Ȱ��ȭ �� ���� ����" -ForegroundColor Yellow }
} catch {
    Write-Host " > [����] ���ʿ��� ���� ��Ȱ��ȭ �۾� ����: $_" -ForegroundColor Red
}

# W-04: ���� ��� �Ӱ谪 ���� (5ȸ ���� ��)
Write-Host "W-04: ���� ��� �Ӱ谪 ����(5ȸ)" -ForegroundColor Cyan
try {
    net accounts /lockoutthreshold:5
    Write-Host " > ���� ��� �Ӱ谪(5ȸ) ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ���� ��� �Ӱ谪 ���� ����: $_" -ForegroundColor Red
}

# W-05: �ص� ������ ��ȣȭ�� ����Ͽ� ��ȣ ���� ����
Write-Host "W-05: ��ȣ ���� ��å ����(�ص� ���� ��ȣ ���� ����)" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "ClearTextPassword" -Value 0
    Write-Host " > ��ȣ ���� ��å ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ��ȣ ���� ��å ���� ����: $_" -ForegroundColor Red
}

# W-06: ������ �׷쿡�� ���ʿ��� ���� ����
Write-Host "W-06: ������ �׷쿡�� ���ʿ��� ���� ���� �õ�" -ForegroundColor Cyan
try {
    $except = @("iteasy_admin", "SYSTEM")
    Get-LocalGroupMember -Group "Administrators" | Where-Object { $except -notcontains $_.Name } | ForEach-Object {
        try {
            Remove-LocalGroupMember -Group "Administrators" -Member $_.Name
            Write-Host " > ������ �׷쿡�� $_.Name ���� �Ϸ�" -ForegroundColor Green
        } catch {
            Write-Host " > ������ �׷쿡�� $_.Name ���� ����: $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host " > [����] ������ �׷� ���� ����: $_" -ForegroundColor Red
}

# W-07: �⺻ ���� �ڵ� ���� ��Ȱ��ȭ(������Ʈ��)
Write-Host "W-07: �⺻ ���� �ڵ� ���� ��Ȱ��ȭ(������Ʈ��)" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareServer" -Value 0
    Write-Host " > �⺻ ���� �ڵ� ���� ��Ȱ��ȭ ���� �Ϸ� (����� �ʿ�)" -ForegroundColor Green
} catch {
    Write-Host " > [����] �⺻ ���� �ڵ� ���� ��Ȱ��ȭ ���� ����: $_" -ForegroundColor Red
}

# W-08: �ϵ��ũ �⺻ ����(C$, D$ ��) ���� (������Ʈ��)
Write-Host "W-08: �ϵ��ũ �⺻ ����(C$, D$ ��) ����(������Ʈ�� ���)" -ForegroundColor Cyan
try {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
    # AutoShareServer ���� 0���� ����
    Set-ItemProperty -Path $regPath -Name "AutoShareServer" -Value 0
    Write-Host " > �⺻ ���� �ڵ� ���� ��Ȱ��ȭ(������Ʈ��) ���� �Ϸ� (����� �ʿ�)" -ForegroundColor Green
} catch {
    Write-Host " > [����] �⺻ ���� �ڵ� ���� ��Ȱ��ȭ(������Ʈ��) ���� ����: $_" -ForegroundColor Red
}

# W-09: ���ʿ��� ���� �ϰ� ��Ȱ��ȭ
Write-Host "W-09: ���ʿ� ���� ��Ȱ��ȭ �õ�" -ForegroundColor Cyan
$serviceList = @(
    "Alerter",
    "ClipSrv",
    "Messenger",
    "SimpTcp",
    "TrkWks",
    "TrkSrv"
)
foreach ($svc in $serviceList) {
    try {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($service) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host " > $svc ���� ���� �� ��Ȱ��ȭ �Ϸ�" -ForegroundColor Green
        }
    } catch {
        Write-Host " > [����] $svc ���� ��Ȱ��ȭ ����: $_" -ForegroundColor Red
    }
}

# W-24: NetBIOS ���ε� ���� ���� ����
Write-Host "W-24: NetBIOS ���ε� ����" -ForegroundColor Cyan
try {
    Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object {
        try {
            $_.SetTcpipNetbios(2) | Out-Null
            Write-Host " > NIC $($_.Description) NetBIOS ���� �Ϸ�" -ForegroundColor Green
        } catch {
            Write-Host " > NIC $($_.Description) NetBIOS ���� ����: $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host " > [����] NetBIOS ���ε� ���� ����: $_" -ForegroundColor Red
}

# W-35: �������� �׼��� �� �� �ִ� ������Ʈ�� ��� ���� ����
Write-Host "W-35: RemoteRegistry ���� ��Ȱ��ȭ" -ForegroundColor Cyan
try {
    Stop-Service -Name RemoteRegistry -Force -ErrorAction SilentlyContinue
    Set-Service -Name RemoteRegistry -StartupType Disabled
    Write-Host " > RemoteRegistry ���� ��Ȱ��ȭ �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] RemoteRegistry ��Ȱ��ȭ ����: $_" -ForegroundColor Red
}

# W-38: ȭ�麸ȣ�� ����
Write-Host "W-38: ȭ�麸ȣ�� ��å ����" -ForegroundColor Cyan
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop"
try {
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "ScreenSaveActive" -Value "1"
    Set-ItemProperty -Path $regPath -Name "ScreenSaverIsSecure" -Value "1"
    Set-ItemProperty -Path $regPath -Name "ScreenSaveTimeOut" -Value "600"
    Write-Host " > ȭ�麸ȣ�� ��å ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ȭ�麸ȣ�� ��å ���� ����: $_" -ForegroundColor Red
}

# W-39: �α׿� ���� �ʰ� �ý��� ���� ���
Write-Host "W-39: �α׿� ���� �ý��� ���� ��� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Value 0
    Write-Host " > �ý��� ���� ��� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �ý��� ���� ��� ���� ����: $_" -ForegroundColor Red
}

# W-40: ���� �ý��ۿ��� ������ �ý��� ����
Write-Host "W-40: ���� �ý��� ���� ���� ���� �����ڸ� �ο�" -ForegroundColor Cyan
try {
    $cfg = "$env:TEMP\secpol.cfg"
    secedit /export /cfg $cfg
    (Get-Content $cfg) -replace 'SeRemoteShutdownPrivilege\s*=.*', 'SeRemoteShutdownPrivilege = *S-1-5-32-544' | Set-Content $cfg
    secedit /configure /db secedit.sdb /cfg $cfg /areas USER_RIGHTS
    Remove-Item $cfg
    Write-Host " > ���� �ý��� ���� ���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ���� �ý��� ���� ���� ���� ����: $_" -ForegroundColor Red
}

# W-41. ���� ���縦 �α��� �� ���� ��� ��� �ý��� ����
Write-Host "W-41: ���� �Ұ��� �ý��� ���� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "CrashOnAuditFail" -Value 0
    Write-Host " > ���� �Ұ��� �ý��� ���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ���� �Ұ��� �ý��� ���� ���� ����: $_" -ForegroundColor Red
}

# W-42. SAM ������ ������ �͸� ���� ��� �� ��
Write-Host "W-42: SAM ���� �� ���� �͸� ���� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -Value 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymousSAM" -Value 1
    Write-Host " > �͸� ���� ���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �͸� ���� ���� ���� ����: $_" -ForegroundColor Red
}

# W-43. Autologon ��� ����
Write-Host "W-43: �ڵ� �α׿� ��� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "0"
    Write-Host " > �ڵ� �α׿� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �ڵ� �α׿� ���� ����: $_" -ForegroundColor Red
}

# W-44. �̵��� �̵�� ���� �� ������ ��� ����
Write-Host "W-44: �̵��� �̵�� ����/������ ���� ������ ����" -ForegroundColor Cyan
try {
    $cfg = "$env:TEMP\secpol.cfg"
    secedit /export /cfg $cfg
    (Get-Content $cfg) -replace 'AllocateDASD\s*=.*', 'AllocateDASD = *S-1-5-32-544' | Set-Content $cfg
    secedit /configure /db secedit.sdb /cfg $cfg /areas USER_RIGHTS
    Remove-Item $cfg
    Write-Host " > �̵��� �̵�� ����/������ ���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �̵��� �̵�� ����/������ ���� ���� ����: $_" -ForegroundColor Red
}

# W-46: Everyone ��� ������ �͸� ����ڿ� ���� ����
Write-Host "W-46: Everyone ���ѿ� �͸� ����� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "EveryoneIncludesAnonymous" -Value 0
    Write-Host " > Everyone�� �͸� ����� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] Everyone�� �͸� ����� ���� ����: $_" -ForegroundColor Red
}

# W-47: ���� ��� �Ⱓ ����
Write-Host "W-47: ���� ��� �Ⱓ/������ ����" -ForegroundColor Cyan
try {
    net accounts /lockoutduration:60 /lockoutwindow:60
    Write-Host " > ���� ��� �Ⱓ �� ������ ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ���� ��� �Ⱓ ���� ����: $_" -ForegroundColor Red
}

# W-48: �н����� ���⼺ ����
Write-Host "W-48: �н����� ���⼺ ��å ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "PasswordComplexity" -Value 1
    Write-Host " > �н����� ���⼺ ��å ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �н����� ���⼺ ��å ���� ����: $_" -ForegroundColor Red
}

# W-49: �н����� �ּ� ��ȣ ����
Write-Host "W-49: �н����� �ּ� ���� ����" -ForegroundColor Cyan
try {
    net accounts /minpwlen:8
    Write-Host " > �н����� �ּ� ���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �н����� �ּ� ���� ���� ����: $_" -ForegroundColor Red
}

# W-50: �н����� �ִ� ��� �Ⱓ
Write-Host "W-50: �н����� �ִ� ��� �Ⱓ ����" -ForegroundColor Cyan
try {
    net accounts /maxpwage:90
    Write-Host " > �н����� �ִ� ��� �Ⱓ ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �н����� �ִ� ��� �Ⱓ ���� ����: $_" -ForegroundColor Red
}

# W-51: �н����� �ּ� ��� �Ⱓ
Write-Host "W-51: �н����� �ּ� ��� �Ⱓ ����" -ForegroundColor Cyan
try {
    net accounts /minpwage:1
    Write-Host " > �н����� �ּ� ��� �Ⱓ ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �н����� �ּ� ��� �Ⱓ ���� ����: $_" -ForegroundColor Red
}

# W-52: ������ ����� �̸� ǥ�� ����
Write-Host "W-52: ������ ����� �̸� ��ǥ�� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DontDisplayLastUserName" -Value 1
    Write-Host " > ������ ����� �̸� ��ǥ�� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ������ ����� �̸� ��ǥ�� ���� ����: $_" -ForegroundColor Red
}

# W-54: �͸� SID/�̸� ��ȯ ��� ����
Write-Host "W-54: �͸� SID/�̸� ��ȯ ��� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LSAAnonymousNameLookup" -Value 0
    Write-Host " > �͸� SID/�̸� ��ȯ ��� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �͸� SID/�̸� ��ȯ ���� ����: $_" -ForegroundColor Red
}

# W-55: �ֱ� ��ȣ ���
Write-Host "W-55: �ֱ� ��ȣ ��� ����" -ForegroundColor Cyan
try {
    net accounts /uniquepw:12
    Write-Host " > �ֱ� ��ȣ ��� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �ֱ� ��ȣ ��� ���� ����: $_" -ForegroundColor Red
}

# W-56: �ܼ� �α׿� �� ���� �������� �� ��ȣ ��� ����
Write-Host "W-56: �� ��ȣ ��� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -Value 1
    Write-Host " > �� ��ȣ ��� ���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �� ��ȣ ��� ���� ���� ����: $_" -ForegroundColor Red
}

# W-57: �����͹̳� ���� ������ ����� �׷� ����
Write-Host "W-57: �����͹̳� ���� ����� �׷� ����" -ForegroundColor Cyan
try {
    $groups = @("Administrators", "Remote Desktop Users")
    foreach ($group in $groups) {
        Get-LocalGroupMember -Group $group | Where-Object {
            $_.Name -notmatch "Administrators|Remote Desktop Users"
        } | ForEach-Object {
            try {
                Remove-LocalGroupMember -Group $group -Member $_.Name -ErrorAction SilentlyContinue
                Write-Host " > $group �׷쿡�� $_.Name ���� �Ϸ�" -ForegroundColor Green
            } catch {
                Write-Host " > $group �׷쿡�� $_.Name ���� ����: $_" -ForegroundColor Red
            }
        }
    }
} catch {
    Write-Host " > [����] �����͹̳� ����� �׷� ���� ����: $_" -ForegroundColor Red
}

# W-58. �͹̳� ���� ��ȣȭ ���� ����
Write-Host "W-58: �͹̳� ���� ��ȣȭ ����(�ֻ�) ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "MinEncryptionLevel" -Value 3
    Write-Host " > �͹̳� ���� ��ȣȭ ����(�ֻ�) ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �͹̳� ���� ��ȣȭ ���� ���� ����: $_" -ForegroundColor Red
}

# W-60/63/65: SNMP, DNS, Telnet ���� ���� ����(����ø� ó��)
Write-Host "W-60/63/65: SNMP, DNS, Telnet ���� ��Ȱ��ȭ" -ForegroundColor Cyan
foreach ($svc in @("SNMP", "DNS", "Telnet")) {
    try {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Stop-Service -Name $svc -Force
            Set-Service -Name $svc -StartupType Disabled
            Write-Host " > $svc ���� ��Ȱ��ȭ �Ϸ�" -ForegroundColor Green
        }
    } catch {
        Write-Host " > [����] $svc ���� ��Ȱ��ȭ ����: $_" -ForegroundColor Red
    }
}

# W-67: �����͹̳� ���� Ÿ�Ӿƿ� ���� (10��)
Write-Host "W-67: �����͹̳� Ÿ�Ӿƿ�(10��) ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "MaxIdleTime" -Value 600000
    Write-Host " > �����͹̳� Ÿ�Ӿƿ� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] �����͹̳� Ÿ�Ӿƿ� ���� ����: $_" -ForegroundColor Red
}

# W-69: ��å�� ���� �ý��� �α뼳��
Write-Host "W-69: ���� ��å(�α�) ����" -ForegroundColor Cyan
try {
    auditpol /set /subcategory:"User Account Management" /failure:enable
    auditpol /set /subcategory:"Logon" /success:enable /failure:enable
    auditpol /set /subcategory:"Sensitive Privilege Use" /failure:enable
    auditpol /set /subcategory:"Directory Service Access" /failure:enable
    auditpol /set /subcategory:"Audit Policy Change" /success:enable /failure:enable
    Write-Host " > ���� ��å(�α�) ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ���� ��å ���� ����: $_" -ForegroundColor Red
}

# W-71: ���ݿ��� �̺�Ʈ �α����� ���� ����
Write-Host "W-71: ���� �̺�Ʈ �α����� ���� ���� ����" -ForegroundColor Cyan
$paths = @("$env:SystemRoot\System32\config", "$env:SystemRoot\System32\logfiles")
foreach ($path in $paths) {
    try {
        icacls $path /remove:g "Everyone" /T > $null 2>&1
        Write-Host " > $path ���� ���� �Ϸ�" -ForegroundColor Green
    } catch {
        Write-Host " > [����] $path ���� ���� ����: $_" -ForegroundColor Red
    }
}

# W-73: ����ڰ� ������ ����̹��� ��ġ�� �� ���� ��
Write-Host "W-73: ����� ������ ����̹� ��ġ ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers" -Name "AddPrinterDrivers" -Value 0
    Write-Host " > ����� ������ ����̹� ��ġ ���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ����� ������ ����̹� ��ġ ���� ����: $_" -ForegroundColor Red
}

# W-74: ���� ������ �ߴ��ϱ� ���� �ʿ��� ���޽ð�
Write-Host "W-74: ���� ���޽ð�(15��) �� �ڵ� ���� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters" -Name "EnableForcedLogoff" -Value 1
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters" -Name "AutoDisconnect" -Value 15
    Write-Host " > ���� ���޽ð�(15��) �� �ڵ� ���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ���� ���޽ð� �ڵ� ���� ���� ����: $_" -ForegroundColor Red
}

# W-75: ��� �޽��� ����
Write-Host "W-75: ��� �޽���(���) ����" -ForegroundColor Cyan
try {
    $caption = "���: ���� ���� ����"
    $text = @"
�� �ý����� �㰡���� ����ڸ� ������ �� �ֽ��ϴ�.
���� ���� �� ���� ó���� ���� �� �ֽ��ϴ�.
"@
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "legalnoticecaption" -Value $caption
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "legalnoticetext" -Value $text
    Write-Host " > ��� �޽���(���) ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ��� �޽��� ���� ����: $_" -ForegroundColor Red
}

# W-76: ����ں� Ȩ ���͸� ���� ����
Write-Host "W-76: ����� Ȩ ���͸� Everyone ���� ����" -ForegroundColor Cyan
try {
    $exclude = @("All Users", "Default", "Default User", "Public", "DefaultAppPool", "MSSQL", "defaultuser0")
    Get-ChildItem 'C:\Users' -Directory | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
        try {
            icacls $_.FullName /remove:g "Everyone" /T > $null 2>&1
            Write-Host " > $_.FullName ���� ���� �Ϸ�" -ForegroundColor Green
        } catch {
            Write-Host " > $_.FullName ���� ���� ����: $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host " > [����] ����� Ȩ ���͸� ���� ���� ����: $_" -ForegroundColor Red
}

# W-77: LAN Manager ���� ����
Write-Host "W-77: LAN Manager ���� ���� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 3
    Write-Host " > LAN Manager ���� ���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] LAN Manager ���� ���� ���� ����: $_" -ForegroundColor Red
}

# W-78: ���� ä�� ������ ������ ��ȣȭ/����
Write-Host "W-78: ���� ä�� ������ ��ȣȭ/���� ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "RequireSignOrSeal" -Value 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "SealSecureChannel" -Value 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "SignSecureChannel" -Value 1
    Write-Host " > ���� ä�� ��ȣȭ/���� ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ���� ä�� ��ȣȭ/���� ���� ����: $_" -ForegroundColor Red
}

# W-80: ��ǻ�� ���� ��ȣ �ִ� ��� �Ⱓ
Write-Host "W-80: ��ǻ�� ���� ��ȣ �ִ� ��� �Ⱓ(90��) ����" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "MaximumPasswordAge" -Value 90
    Write-Host " > ��ǻ�� ���� ��ȣ �ִ� ��� �Ⱓ ���� �Ϸ�" -ForegroundColor Green
} catch {
    Write-Host " > [����] ��ǻ�� ���� ��ȣ �ִ� ��� �Ⱓ ���� ����: $_" -ForegroundColor Red
}

# [��ũ��Ʈ �� �������� ��� �޽��� ���]
$warningMsg = @"
����������������������������������������������������������������������������������������
? [����] �Ϻ� ���� ������ ������ ���� �뵵�� ����
   ���� ��� ������ �� �� �ֽ��ϴ�.

[W-74] ���� ���޽ð� �� �ڵ� ����(AutoDisconnect) ������ �����
   - ���� ��: 15��
   - ���� ����, ��ð� ���� ������ �ʿ��� ����������
     ���� ����, ���� ���� ������ �߻��� �� �ֽ��ϴ�.
   - ���� ������ �ʿ��ϸ� �Ʒ� ������� ���� ������ �����մϴ�.
     Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name 'AutoDisconnect' -Value -1
����������������������������������������������������������������������������������������
"@

Write-Host $warningMsg -ForegroundColor Yellow
Write-Host ""
Write-Host "����Ϸ��� [Enter] Ű�� ��������." -ForegroundColor Cyan
[void][System.Console]::ReadLine()
