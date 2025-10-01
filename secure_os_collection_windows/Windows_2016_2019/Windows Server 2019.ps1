# Windows Server 2019 보안 강화 스크립트 (실행 로그 출력 및 에러 처리 포함)

# W-01: Administrator 계정 이름 변경
Write-Host "W-01: Administrator 계정 이름 변경 시도" -ForegroundColor Cyan
try {
    $adminSID = (Get-WmiObject Win32_UserAccount | Where-Object { $_.SID -like "*-500" }).SID
    $admin = Get-LocalUser | Where-Object { $_.SID -eq $adminSID }
    $newName = "iteasy_admin"
    if ($admin.Name -ne $newName) {
        Rename-LocalUser -Name $admin.Name -NewName $newName
        Write-Host " > Administrator 계정명을 $newName(으)로 변경 완료" -ForegroundColor Green
    } else {
        Write-Host " > 이미 변경된 상태임" -ForegroundColor Yellow
    }
} catch {
    Write-Host " > [오류] Administrator 계정명 변경 실패: $_" -ForegroundColor Red
}

# W-02: Guest 계정 비활성화
Write-Host "W-02: Guest 계정 비활성화 시도" -ForegroundColor Cyan
try {
    $guest = Get-LocalUser | Where-Object { $_.SID -like '*-501' }
    if ($guest -and $guest.Enabled) {
        Disable-LocalUser -Name $guest.Name
        Write-Host " > Guest 계정 비활성화 완료" -ForegroundColor Green
    } else {
        Write-Host " > Guest 계정 없음 또는 이미 비활성화" -ForegroundColor Yellow
    }
} catch {
    Write-Host " > [오류] Guest 계정 비활성화 실패: $_" -ForegroundColor Red
}

# W-03: 불필요한 계정 제거
Write-Host "W-03: 불필요한 계정 비활성화 시도" -ForegroundColor Cyan
try {
    $except = @("iteasy_admin", "Guest", "WDAGUtilityAccount", "DefaultAccount")
    $removed = 0
    Get-LocalUser | Where-Object { $except -notcontains $_.Name } | ForEach-Object {
        try {
            Disable-LocalUser -Name $_.Name
            Write-Host " > $_.Name 계정 비활성화 완료" -ForegroundColor Green
            $removed++
        } catch {
            Write-Host " > $_.Name 계정 비활성화 실패: $_" -ForegroundColor Red
        }
    }
    if ($removed -eq 0) { Write-Host " > 비활성화 할 계정 없음" -ForegroundColor Yellow }
} catch {
    Write-Host " > [오류] 불필요한 계정 비활성화 작업 실패: $_" -ForegroundColor Red
}

# W-04: 계정 잠금 임계값 설정 (5회 실패 시)
Write-Host "W-04: 계정 잠금 임계값 설정(5회)" -ForegroundColor Cyan
try {
    net accounts /lockoutthreshold:5
    Write-Host " > 계정 잠금 임계값(5회) 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 계정 잠금 임계값 설정 실패: $_" -ForegroundColor Red
}

# W-05: 해독 가능한 암호화를 사용하여 암호 저장 해제
Write-Host "W-05: 암호 저장 정책 변경(해독 가능 암호 저장 해제)" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "ClearTextPassword" -Value 0
    Write-Host " > 암호 저장 정책 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 암호 저장 정책 설정 실패: $_" -ForegroundColor Red
}

# W-06: 관리자 그룹에서 불필요한 계정 제거
Write-Host "W-06: 관리자 그룹에서 불필요한 계정 제거 시도" -ForegroundColor Cyan
try {
    $except = @("iteasy_admin", "SYSTEM")
    Get-LocalGroupMember -Group "Administrators" | Where-Object { $except -notcontains $_.Name } | ForEach-Object {
        try {
            Remove-LocalGroupMember -Group "Administrators" -Member $_.Name
            Write-Host " > 관리자 그룹에서 $_.Name 제거 완료" -ForegroundColor Green
        } catch {
            Write-Host " > 관리자 그룹에서 $_.Name 제거 실패: $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host " > [오류] 관리자 그룹 관리 실패: $_" -ForegroundColor Red
}

# W-07: 기본 공유 자동 생성 비활성화(레지스트리)
Write-Host "W-07: 기본 공유 자동 생성 비활성화(레지스트리)" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareServer" -Value 0
    Write-Host " > 기본 공유 자동 생성 비활성화 설정 완료 (재부팅 필요)" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 기본 공유 자동 생성 비활성화 설정 실패: $_" -ForegroundColor Red
}

# W-08: 하드디스크 기본 공유(C$, D$ 등) 제거 (레지스트리)
Write-Host "W-08: 하드디스크 기본 공유(C$, D$ 등) 제거(레지스트리 방식)" -ForegroundColor Cyan
try {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
    # AutoShareServer 값을 0으로 설정
    Set-ItemProperty -Path $regPath -Name "AutoShareServer" -Value 0
    Write-Host " > 기본 공유 자동 생성 비활성화(레지스트리) 설정 완료 (재부팅 필요)" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 기본 공유 자동 생성 비활성화(레지스트리) 설정 실패: $_" -ForegroundColor Red
}

# W-09: 불필요한 서비스 일괄 비활성화
Write-Host "W-09: 불필요 서비스 비활성화 시도" -ForegroundColor Cyan
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
            Write-Host " > $svc 서비스 중지 및 비활성화 완료" -ForegroundColor Green
        }
    } catch {
        Write-Host " > [오류] $svc 서비스 비활성화 실패: $_" -ForegroundColor Red
    }
}

# W-24: NetBIOS 바인딩 서비스 구동 점검
Write-Host "W-24: NetBIOS 바인딩 해제" -ForegroundColor Cyan
try {
    Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object {
        try {
            $_.SetTcpipNetbios(2) | Out-Null
            Write-Host " > NIC $($_.Description) NetBIOS 해제 완료" -ForegroundColor Green
        } catch {
            Write-Host " > NIC $($_.Description) NetBIOS 해제 실패: $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host " > [오류] NetBIOS 바인딩 해제 실패: $_" -ForegroundColor Red
}

# W-35: 원격으로 액세스 할 수 있는 레지스트리 경로 서비스 중지
Write-Host "W-35: RemoteRegistry 서비스 비활성화" -ForegroundColor Cyan
try {
    Stop-Service -Name RemoteRegistry -Force -ErrorAction SilentlyContinue
    Set-Service -Name RemoteRegistry -StartupType Disabled
    Write-Host " > RemoteRegistry 서비스 비활성화 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] RemoteRegistry 비활성화 실패: $_" -ForegroundColor Red
}

# W-38: 화면보호기 설정
Write-Host "W-38: 화면보호기 정책 설정" -ForegroundColor Cyan
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop"
try {
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "ScreenSaveActive" -Value "1"
    Set-ItemProperty -Path $regPath -Name "ScreenSaverIsSecure" -Value "1"
    Set-ItemProperty -Path $regPath -Name "ScreenSaveTimeOut" -Value "600"
    Write-Host " > 화면보호기 정책 적용 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 화면보호기 정책 적용 실패: $_" -ForegroundColor Red
}

# W-39: 로그온 하지 않고 시스템 종료 허용
Write-Host "W-39: 로그온 없이 시스템 종료 허용 해제" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Value 0
    Write-Host " > 시스템 종료 허용 해제 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 시스템 종료 허용 해제 실패: $_" -ForegroundColor Red
}

# W-40: 원격 시스템에서 강제로 시스템 종료
Write-Host "W-40: 원격 시스템 강제 종료 권한 관리자만 부여" -ForegroundColor Cyan
try {
    $cfg = "$env:TEMP\secpol.cfg"
    secedit /export /cfg $cfg
    (Get-Content $cfg) -replace 'SeRemoteShutdownPrivilege\s*=.*', 'SeRemoteShutdownPrivilege = *S-1-5-32-544' | Set-Content $cfg
    secedit /configure /db secedit.sdb /cfg $cfg /areas USER_RIGHTS
    Remove-Item $cfg
    Write-Host " > 원격 시스템 종료 권한 제한 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 원격 시스템 종료 권한 제한 실패: $_" -ForegroundColor Red
}

# W-41. 보안 감사를 로그할 수 없는 경우 즉시 시스템 종료
Write-Host "W-41: 감사 불가시 시스템 종료 설정" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "CrashOnAuditFail" -Value 0
    Write-Host " > 감사 불가시 시스템 종료 해제 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 감사 불가시 시스템 종료 해제 실패: $_" -ForegroundColor Red
}

# W-42. SAM 계정과 공유의 익명 열거 허용 안 함
Write-Host "W-42: SAM 계정 및 공유 익명 열거 제한" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -Value 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymousSAM" -Value 1
    Write-Host " > 익명 열거 제한 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 익명 열거 제한 설정 실패: $_" -ForegroundColor Red
}

# W-43. Autologon 기능 제어
Write-Host "W-43: 자동 로그온 기능 해제" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "0"
    Write-Host " > 자동 로그온 해제 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 자동 로그온 해제 실패: $_" -ForegroundColor Red
}

# W-44. 이동식 미디어 포맷 및 꺼내기 허용 제어
Write-Host "W-44: 이동식 미디어 포맷/꺼내기 권한 관리자 제한" -ForegroundColor Cyan
try {
    $cfg = "$env:TEMP\secpol.cfg"
    secedit /export /cfg $cfg
    (Get-Content $cfg) -replace 'AllocateDASD\s*=.*', 'AllocateDASD = *S-1-5-32-544' | Set-Content $cfg
    secedit /configure /db secedit.sdb /cfg $cfg /areas USER_RIGHTS
    Remove-Item $cfg
    Write-Host " > 이동식 미디어 포맷/꺼내기 권한 제한 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 이동식 미디어 포맷/꺼내기 권한 제한 실패: $_" -ForegroundColor Red
}

# W-46: Everyone 사용 권한을 익명 사용자에 적용 해제
Write-Host "W-46: Everyone 권한에 익명 사용자 제외" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "EveryoneIncludesAnonymous" -Value 0
    Write-Host " > Everyone에 익명 사용자 제외 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] Everyone에 익명 사용자 제외 실패: $_" -ForegroundColor Red
}

# W-47: 계정 잠금 기간 설정
Write-Host "W-47: 계정 잠금 기간/윈도우 설정" -ForegroundColor Cyan
try {
    net accounts /lockoutduration:60 /lockoutwindow:60
    Write-Host " > 계정 잠금 기간 및 윈도우 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 계정 잠금 기간 설정 실패: $_" -ForegroundColor Red
}

# W-48: 패스워드 복잡성 설정
Write-Host "W-48: 패스워드 복잡성 정책 설정" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "PasswordComplexity" -Value 1
    Write-Host " > 패스워드 복잡성 정책 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 패스워드 복잡성 정책 설정 실패: $_" -ForegroundColor Red
}

# W-49: 패스워드 최소 암호 길이
Write-Host "W-49: 패스워드 최소 길이 설정" -ForegroundColor Cyan
try {
    net accounts /minpwlen:8
    Write-Host " > 패스워드 최소 길이 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 패스워드 최소 길이 설정 실패: $_" -ForegroundColor Red
}

# W-50: 패스워드 최대 사용 기간
Write-Host "W-50: 패스워드 최대 사용 기간 설정" -ForegroundColor Cyan
try {
    net accounts /maxpwage:90
    Write-Host " > 패스워드 최대 사용 기간 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 패스워드 최대 사용 기간 설정 실패: $_" -ForegroundColor Red
}

# W-51: 패스워드 최소 사용 기간
Write-Host "W-51: 패스워드 최소 사용 기간 설정" -ForegroundColor Cyan
try {
    net accounts /minpwage:1
    Write-Host " > 패스워드 최소 사용 기간 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 패스워드 최소 사용 기간 설정 실패: $_" -ForegroundColor Red
}

# W-52: 마지막 사용자 이름 표시 안함
Write-Host "W-52: 마지막 사용자 이름 미표시 설정" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DontDisplayLastUserName" -Value 1
    Write-Host " > 마지막 사용자 이름 미표시 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 마지막 사용자 이름 미표시 설정 실패: $_" -ForegroundColor Red
}

# W-54: 익명 SID/이름 변환 허용 해제
Write-Host "W-54: 익명 SID/이름 변환 허용 해제" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LSAAnonymousNameLookup" -Value 0
    Write-Host " > 익명 SID/이름 변환 허용 해제 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 익명 SID/이름 변환 해제 실패: $_" -ForegroundColor Red
}

# W-55: 최근 암호 기억
Write-Host "W-55: 최근 암호 기억 설정" -ForegroundColor Cyan
try {
    net accounts /uniquepw:12
    Write-Host " > 최근 암호 기억 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 최근 암호 기억 설정 실패: $_" -ForegroundColor Red
}

# W-56: 콘솔 로그온 시 로컬 계정에서 빈 암호 사용 제한
Write-Host "W-56: 빈 암호 사용 제한" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -Value 1
    Write-Host " > 빈 암호 사용 제한 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 빈 암호 사용 제한 설정 실패: $_" -ForegroundColor Red
}

# W-57: 원격터미널 접속 가능한 사용자 그룹 제한
Write-Host "W-57: 원격터미널 접속 사용자 그룹 제한" -ForegroundColor Cyan
try {
    $groups = @("Administrators", "Remote Desktop Users")
    foreach ($group in $groups) {
        Get-LocalGroupMember -Group $group | Where-Object {
            $_.Name -notmatch "Administrators|Remote Desktop Users"
        } | ForEach-Object {
            try {
                Remove-LocalGroupMember -Group $group -Member $_.Name -ErrorAction SilentlyContinue
                Write-Host " > $group 그룹에서 $_.Name 제거 완료" -ForegroundColor Green
            } catch {
                Write-Host " > $group 그룹에서 $_.Name 제거 실패: $_" -ForegroundColor Red
            }
        }
    }
} catch {
    Write-Host " > [오류] 원격터미널 사용자 그룹 제한 실패: $_" -ForegroundColor Red
}

# W-58. 터미널 서비스 암호화 수준 설정
Write-Host "W-58: 터미널 서비스 암호화 수준(최상) 설정" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "MinEncryptionLevel" -Value 3
    Write-Host " > 터미널 서비스 암호화 수준(최상) 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 터미널 서비스 암호화 수준 설정 실패: $_" -ForegroundColor Red
}

# W-60/63/65: SNMP, DNS, Telnet 서비스 구동 점검(존재시만 처리)
Write-Host "W-60/63/65: SNMP, DNS, Telnet 서비스 비활성화" -ForegroundColor Cyan
foreach ($svc in @("SNMP", "DNS", "Telnet")) {
    try {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            Stop-Service -Name $svc -Force
            Set-Service -Name $svc -StartupType Disabled
            Write-Host " > $svc 서비스 비활성화 완료" -ForegroundColor Green
        }
    } catch {
        Write-Host " > [오류] $svc 서비스 비활성화 실패: $_" -ForegroundColor Red
    }
}

# W-67: 원격터미널 접속 타임아웃 설정 (10분)
Write-Host "W-67: 원격터미널 타임아웃(10분) 설정" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "MaxIdleTime" -Value 600000
    Write-Host " > 원격터미널 타임아웃 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 원격터미널 타임아웃 설정 실패: $_" -ForegroundColor Red
}

# W-69: 정책에 따른 시스템 로깅설정
Write-Host "W-69: 감사 정책(로깅) 설정" -ForegroundColor Cyan
try {
    auditpol /set /subcategory:"User Account Management" /failure:enable
    auditpol /set /subcategory:"Logon" /success:enable /failure:enable
    auditpol /set /subcategory:"Sensitive Privilege Use" /failure:enable
    auditpol /set /subcategory:"Directory Service Access" /failure:enable
    auditpol /set /subcategory:"Audit Policy Change" /success:enable /failure:enable
    Write-Host " > 감사 정책(로깅) 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 감사 정책 설정 실패: $_" -ForegroundColor Red
}

# W-71: 원격에서 이벤트 로그파일 접근 차단
Write-Host "W-71: 원격 이벤트 로그파일 접근 권한 제한" -ForegroundColor Cyan
$paths = @("$env:SystemRoot\System32\config", "$env:SystemRoot\System32\logfiles")
foreach ($path in $paths) {
    try {
        icacls $path /remove:g "Everyone" /T > $null 2>&1
        Write-Host " > $path 권한 제한 완료" -ForegroundColor Green
    } catch {
        Write-Host " > [오류] $path 권한 제한 실패: $_" -ForegroundColor Red
    }
}

# W-73: 사용자가 프린터 드라이버를 설치할 수 없게 함
Write-Host "W-73: 사용자 프린터 드라이버 설치 금지" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers" -Name "AddPrinterDrivers" -Value 0
    Write-Host " > 사용자 프린터 드라이버 설치 금지 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 사용자 프린터 드라이버 설치 금지 실패: $_" -ForegroundColor Red
}

# W-74: 세션 연결을 중단하기 전에 필요한 유휴시간
Write-Host "W-74: 세션 유휴시간(15분) 후 자동 종료 설정" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters" -Name "EnableForcedLogoff" -Value 1
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters" -Name "AutoDisconnect" -Value 15
    Write-Host " > 세션 유휴시간(15분) 후 자동 종료 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 세션 유휴시간 자동 종료 설정 실패: $_" -ForegroundColor Red
}

# W-75: 경고 메시지 설정
Write-Host "W-75: 경고 메시지(배너) 설정" -ForegroundColor Cyan
try {
    $caption = "경고: 무단 접속 금지"
    $text = @"
이 시스템은 허가받은 사용자만 접속할 수 있습니다.
무단 접속 시 법적 처벌을 받을 수 있습니다.
"@
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "legalnoticecaption" -Value $caption
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "legalnoticetext" -Value $text
    Write-Host " > 경고 메시지(배너) 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 경고 메시지 설정 실패: $_" -ForegroundColor Red
}

# W-76: 사용자별 홈 디렉터리 권한 설정
Write-Host "W-76: 사용자 홈 디렉터리 Everyone 권한 제거" -ForegroundColor Cyan
try {
    $exclude = @("All Users", "Default", "Default User", "Public", "DefaultAppPool", "MSSQL", "defaultuser0")
    Get-ChildItem 'C:\Users' -Directory | Where-Object { $exclude -notcontains $_.Name } | ForEach-Object {
        try {
            icacls $_.FullName /remove:g "Everyone" /T > $null 2>&1
            Write-Host " > $_.FullName 권한 제거 완료" -ForegroundColor Green
        } catch {
            Write-Host " > $_.FullName 권한 제거 실패: $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host " > [오류] 사용자 홈 디렉터리 권한 제거 실패: $_" -ForegroundColor Red
}

# W-77: LAN Manager 인증 수준
Write-Host "W-77: LAN Manager 인증 수준 설정" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 3
    Write-Host " > LAN Manager 인증 수준 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] LAN Manager 인증 수준 설정 실패: $_" -ForegroundColor Red
}

# W-78: 보안 채널 데이터 디지털 암호화/서명
Write-Host "W-78: 보안 채널 데이터 암호화/서명 설정" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "RequireSignOrSeal" -Value 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "SealSecureChannel" -Value 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "SignSecureChannel" -Value 1
    Write-Host " > 보안 채널 암호화/서명 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 보안 채널 암호화/서명 설정 실패: $_" -ForegroundColor Red
}

# W-80: 컴퓨터 계정 암호 최대 사용 기간
Write-Host "W-80: 컴퓨터 계정 암호 최대 사용 기간(90일) 설정" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "MaximumPasswordAge" -Value 90
    Write-Host " > 컴퓨터 계정 암호 최대 사용 기간 설정 완료" -ForegroundColor Green
} catch {
    Write-Host " > [오류] 컴퓨터 계정 암호 최대 사용 기간 설정 실패: $_" -ForegroundColor Red
}

# [스크립트 맨 마지막에 경고 메시지 출력]
$warningMsg = @"
────────────────────────────────────────────
? [주의] 일부 보안 설정은 서버의 실제 용도에 따라
   서비스 운영에 영향을 줄 수 있습니다.

[W-74] 세션 유휴시간 후 자동 종료(AutoDisconnect) 설정이 적용됨
   - 현재 값: 15분
   - 파일 공유, 장시간 세션 유지가 필요한 서버에서는
     접속 끊김, 파일 저장 오류가 발생할 수 있습니다.
   - 세션 유지가 필요하면 아래 명령으로 설정 복원이 가능합니다.
     Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name 'AutoDisconnect' -Value -1
────────────────────────────────────────────
"@

Write-Host $warningMsg -ForegroundColor Yellow
Write-Host ""
Write-Host "계속하려면 [Enter] 키를 누르세요." -ForegroundColor Cyan
[void][System.Console]::ReadLine()
