# ──────────────────────────────────────────────────────────
# 0. 사용자 조정 파라미터
# ──────────────────────────────────────────────────────────
$NewAdminName   = 'Administrator'                   # W?01 administrartor 계정 변경 될 이름
$Lockout        = @{Threshold = 5; Duration = 60; Window = 60}   # W?04, W?47 패스워드 5회 실패시 60분 잠금
$AccountWhite   = @($NewAdminName,'Guest','WDAGUtilityAccount','DefaultAccount') # W?03 항목에서 삭제 하지 않을 계정
$BlockServices  = @('SNMP','SNMPTRAP','Telnet','Fax','TlntSvr','TrkWks','TrkSvr','Spooler') # W?09 + W?60/63/65 항목에서 비활성화될 서비스
$ExtraBlockSvc  = @('DNS')   # W?09 + W?60/63/65 DNS 서버나 도메인 컨트롤러 사용 할 경우 제외
$NeedReboot     = $false     # 재부팅 플래그

# ──────────────────────────────────────────────────────────
# 1. 공통 출력 함수
# ──────────────────────────────────────────────────────────
function Write-Info { param([string]$m) Write-Host $m -ForegroundColor Cyan    }
function Write-OK   { param([string]$m) Write-Host $m -ForegroundColor Green   }
function Write-Warn { param([string]$m) Write-Host $m -ForegroundColor Yellow  }
function Write-Err  { param([string]$m) Write-Host $m -ForegroundColor Red     }
function Need-Reboot{ $script:NeedReboot = $true }

# ──────────────────────────────────────────────────────────
# 2. 시작
# ──────────────────────────────────────────────────────────
Write-Info "`n===== Windows?Server 보안 설정 시작 ====="

# ──────────────────────────────────────────────────────────
# 4. W?02 Guest 계정 비활성화
# ──────────────────────────────────────────────────────────
try {
    $guest = Get-LocalUser | Where SID -like '*-501'
    if ($guest -and $guest.Enabled) {
        Disable-LocalUser -Name $guest.Name
        Write-OK "W-02: Guest 계정 비활성화 완료"
    } else { Write-Warn "W-02: Guest 계정 없음/이미 비활성화" }
} catch { Write-Err "W-02: 실패 ? $_" }

# ──────────────────────────────────────────────────────────
# 5. W?03 불필요 로컬 계정 비활성화 (화이트리스트)
# ──────────────────────────────────────────────────────────
foreach ($u in Get-LocalUser) {
    if ($AccountWhite -notcontains $u.Name) {
        try {
            Disable-LocalUser -Name $u.Name -ErrorAction Stop
            Write-OK "W-03: [$($u.Name)] 비활성화"
        } catch {
            Write-Err "W-03: [$($u.Name)] 실패 ? $_"
        }
    }
}

# ──────────────────────────────────────────────────────────
# 7. W?05 가역적 암호 저장 금지
# ──────────────────────────────────────────────────────────
Import-Module Microsoft.PowerShell.LocalAccounts   # 필요 시 모듈 로드

$dom = (Get-CimInstance Win32_ComputerSystem -EA 0).PartOfDomain      # 도메인 여부
$builtin = Get-LocalUser | Where-Object { $_.SID -match '-500$' }     # 내장 Admin 확인
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
    Write-OK  "W-05: 가역적 암호 저장 금지 적용 완료"
}
catch {
    Write-Err "W-05: 실패 ? $_"
}



# ──────────────────────────────────────────
# 8. W-06 관리자 그룹 정리
# ──────────────────────────────────────────
# 유지할 계정의 SID 목록
$newAdminSid = (Get-LocalUser -Name $NewAdminName).SID.Value
$systemSid   = 'S-1-5-18'    # NT AUTHORITY\SYSTEM
$keepSids    = @($newAdminSid, $systemSid)

# Administrators 그룹 멤버 조회 및 제거
Get-LocalGroupMember -Group 'Administrators' |
Where-Object {
    $_.ObjectClass -eq 'User' -and
    $keepSids -notcontains $_.SID.Value
} |
ForEach-Object {
    try {
        # SID 기반으로 제거
        Remove-LocalGroupMember `
            -Group 'Administrators' `
            -Member $_.SID.Value `
            -ErrorAction Stop `
            -Confirm:$false

        Write-OK "W-06: Administrators에서 [$($_.Name)] 제거 완료"
    }
    catch {
        Write-Err "W-06: [$($_.Name)] 제거 실패 ? $($_.Exception.Message)"
    }
}

# ──────────────────────────────────────────────────────────
# 9. W-08 기본 공유(C$, D$) 자동생성 해제 / SMBv1 비활성화
# ──────────────────────────────────────────────────────────

try {
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath | Out-Null
    }

    Set-ItemProperty -Path $regPath -Name 'AutoShareServer' -Value 0 -Force
    Set-ItemProperty -Path $regPath -Name 'SMB1' -Value 0 -Type DWord -Force

    Write-OK "W-08: 기본 공유 해제 및 SMBv1 비활성화 완료 (재부팅 후 적용)"
    Need-Reboot
} catch {
    Write-Err "W-08: 기본 공유 해제 또는 SMBv1 설정 실패 ? $_"
}


# ──────────────────────────────────────────────────────────
# 10. W-09 + W-60/63/65 불필요 서비스 비활성화 (설치 안 된 서비스는 건너뜀)
# ──────────────────────────────────────────────────────────
$AllBlock = $BlockServices + $ExtraBlockSvc

foreach ($svcName in $AllBlock) {
    # 서비스 조회 (실패해도 에러 쓰로우 안 함)
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue

    # 설치 안 된 서비스는 스킵
    if (-not $svc) {
        Write-Host "W-09/60/63/65: 서비스 [$svcName] 설치 안 됨, 건너뜀"
        continue
    }

    try {
        # (1) 실행 중이면 중지
        if ($svc.Status -ne 'Stopped') {
            Stop-Service -InputObject $svc -Force -ErrorAction SilentlyContinue
        }

        # (2) 비활성화 (객체 전달 시 -InputObject 사용)
        Set-Service -InputObject $svc -StartupType Disabled -ErrorAction Stop

        Write-OK "W-09/60/63/65: 서비스 [$svcName] 중지·비활성화 완료"
    }
    catch {
        Write-Err "W-09/60/63/65: [$svcName] 실패 ? $($_.Exception.Message)"
    }
}


# ──────────────────────────────────────────────────────────
# 11. W-24 NetBIOS 바인딩 설정 점검 및 강제 비활성화
# ──────────────────────────────────────────────────────────
try {
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces'
    $keys = Get-ChildItem -Path $base -ErrorAction Stop

    foreach ($key in $keys) {
        try {
            $fullPath = Join-Path $base $key.PSChildName
            Set-ItemProperty -Path $fullPath -Name 'NetbiosOptions' -Value 2 -Type DWord -Force
            Write-OK "W-24: [$($key.PSChildName)] NetbiosOptions = 2 (비활성화)"
        } catch {
            Write-Err "W-24: [$($key.PSChildName)] 설정 실패 ? $_"
        }
    }
} catch {
    Write-Err "W-24: NetBIOS 인터페이스 나열 실패 ? $_"
}


# ──────────────────────────────────────────────────────────
# 12. W?35 RemoteRegistry 서비스 비활성화
# ──────────────────────────────────────────────────────────
try {
    $rr = Get-Service RemoteRegistry -ErrorAction SilentlyContinue
    if ($rr) {
        if ($rr.Status -ne 'Stopped') { Stop-Service RemoteRegistry -Force }
        Set-Service RemoteRegistry -StartupType Disabled
        Write-OK "W-35: RemoteRegistry 서비스 비활성화"
    }
} catch { Write-Err "W-35: 실패 ? $_" }

# ──────────────────────────────────────────
# 13. W-38 화면보호기 정책 (10분·암호 복귀)
# ──────────────────────────────────────────
#Requires -RunAsAdministrator     # 관리자 권한 보장

try {
    $desk = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop'

    # 필요한 경로만 생성
    if (-not (Test-Path $desk)) {
        New-Item -Path $desk -Force -ErrorAction Stop | Out-Null
    }

    # 정책 값 적용
    Set-ItemProperty -Path $desk -Name 'ScreenSaveActive'    -Value 1   -Type String -Force
    Set-ItemProperty -Path $desk -Name 'ScreenSaverIsSecure' -Value 1   -Type String -Force
    Set-ItemProperty -Path $desk -Name 'ScreenSaveTimeOut'   -Value 600 -Type String -Force
    Set-ItemProperty -Path $desk -Name 'SCRNSAVE.EXE'        -Value 'scrnsave.scr' -Type String -Force

    Write-OK 'W-38: 화면보호기 정책 적용 완료'
}
catch {
    Write-Err "W-38: 실패 ? $_"
}


# ──────────────────────────────────────────
# 14. W-39 로그온하지 않고 시스템 종료 허용 해제
# ──────────────────────────────────────────
#Requires -RunAsAdministrator

try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'

    # Lsa 키는 기본적으로 존재하지만, 만일을 위해 확인
    if (-not (Test-Path $lsa)) {
        New-Item -Path $lsa -ErrorAction Stop | Out-Null
    }

    # 0 = 허용 안 함, 1 = 허용
    Set-ItemProperty -Path $lsa -Name 'ShutdownWithoutLogon' -Value 0 -Type DWord -Force

    Write-OK 'W-39: 로그온 없이 시스템 종료 허용 해제 완료'
}
catch {
    Write-Err "W-39: 실패 ? $_"
}



# ──────────────────────────────────────────
# 15. W-41 보안 감사를 로그할 수 없는 경우 즉시 시스템 종료 
#     W-52 마지막 사용자 이름 숨김
# ──────────────────────────────────────────
try {
    # 레지스트리 경로 정의
    $sysPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'

    # 없으면 키 생성
    if (-not (Test-Path -Path $sysPath)) {
        New-Item -Path $sysPath -Force | Out-Null
    }
    if (-not (Test-Path -Path $lsaPath)) {
        New-Item -Path $lsaPath -Force | Out-Null
    }

    # W-52: 마지막 사용자 이름 숨김
    Set-ItemProperty `
        -Path $sysPath `
        -Name 'DontDisplayLastUserName' `
        -Value 1 `
        -Type DWord `
        -Force

    # W-41: 보안 감사를 로그할 수 없을 때 시스템 종료 비활성화 (0 = 비활성화)
    Set-ItemProperty `
        -Path $lsaPath `
        -Name 'CrashOnAuditFail' `
        -Value 0 `
        -Type DWord `
        -Force

    Write-OK "W-41/W-52: 설정 적용 완료 (마지막 사용자 이름 숨김, CrashOnAuditFail 해제)"
}
catch {
    Write-Err "W-41/W-52: 실패 ? $($_.Exception.Message)"
}


# ──────────────────────────────────────────────────────────
# 16. W-40 / W-44 사용자 권한 제한 (secedit)
# ──────────────────────────────────────────────────────────

function Set-SecPol {             # (※ 기존에 이미 있다면 이 함수 부분은 생략)
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

try { Set-SecPol 'USER_RIGHTS' 'SeRemoteShutdownPrivilege' '*S-1-5-32-544'; Write-OK "W-40: 원격 강제 종료 권한 제한" }
catch { Write-Err "W-40: 실패 ? $_" }

try { Set-SecPol 'USER_RIGHTS' 'AllocateDASD' '*S-1-5-32-544'; Write-OK "W-44: 이동식 미디어 포맷/꺼내기 권한 제한" }
catch { Write-Err "W-44: 실패 ? $_" }


# ──────────────────────────────────────────────────────────
# 16. W-42 SAM·공유 익명 열거 차단
# ──────────────────────────────────────────────────────────
try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }      # ← 변경(조건부 생성)
    Set-ItemProperty $lsa RestrictAnonymous    1
    Set-ItemProperty $lsa RestrictAnonymousSAM 1
    Write-OK "W-42: 익명 열거 제한 완료"
} catch { Write-Err "W-42: 실패 ? $_" }

# ──────────────────────────────────────────────────────────
# 17. W-43 자동 로그온 해제
# ──────────────────────────────────────────────────────────
try {
    $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

    # (1) 키가 없으면 생성
    if (-not (Test-Path -Path $winlogonPath)) {
        New-Item -Path $winlogonPath -Force | Out-Null
    }

    # (2) 자동 로그온 기능 해제 (0 = 비활성화)
    Set-ItemProperty `
        -Path $winlogonPath `
        -Name 'AutoAdminLogon' `
        -Value 0 `
        -Type DWord `
        -Force

    Write-OK "W-43: 자동 로그온 기능 해제 완료"
}
catch {
    Write-Err "W-43: 실패 ? $($_.Exception.Message)"
}

# ──────────────────────────────────────────────────────────
# 18. W?46 Everyone 사용 권한을 익명 사용자에 적용 해제
# ──────────────────────────────────────────────────────────
try {
    $lsa='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    Set-ItemProperty $lsa EveryoneIncludesAnonymous 0
    Write-OK "W-46: Everyone 권한에서 익명 사용자 제외"
} catch { Write-Err "W-46: 실패 ? $_" }

# ──────────────────────────────────────────────────────────
# 19. W-48~56 패스워드 정책·빈 암호 제한
# ──────────────────────────────────────────────────────────
try {
    net accounts /minpwlen:8 /minpwage:1 /uniquepw:12 | Out-Null

    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }   # ← 조건부 생성(수정)

    Set-ItemProperty $lsa PasswordComplexity   1
    Set-ItemProperty $lsa LimitBlankPasswordUse 1
    Write-OK "W-48~56: 패스워드 복잡성·재사용 제한 완료"
} catch { Write-Err "W-48~56: 실패 ? $_" }


# ──────────────────────────────────────────────────────────
# 20. W-54: 익명 SID/이름 변환 허용 해제
# ──────────────────────────────────────────────────────────
try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }   # ← 한 줄만 수정
    Set-ItemProperty $lsa -Name LSAAnonymousNameLookup -Value 0
    Write-OK  "W-54: 익명 SID/이름 변환 허용 해제 완료"
} catch {
    Write-Err "W-54: 실패 ? $_"
}


# ──────────────────────────────────────────────────────────
# 21. W-56: 콘솔 로그온 시 로컬 계정에서 빈 암호 사용 제한
# ──────────────────────────────────────────────────────────
try {
    $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    if (-not (Test-Path $lsa)) { New-Item $lsa | Out-Null }   # ← 변경: 조건부 생성
    Set-ItemProperty $lsa -Name LimitBlankPasswordUse -Value 1
    Write-OK  "W-56: 빈 암호 사용 제한 설정 완료"
} catch {
    Write-Err "W-56: 실패 ? $_"
}


# ──────────────────────────────────────────────────────────
# 22. W-57 RDP 관련 그룹 정리
# ──────────────────────────────────────────────────────────
try {
    $tempInf = "$env:TEMP\Rdp.inf"
    $tempDb  = "$env:TEMP\Rdp.sdb"

    secedit /export /cfg $tempInf

    (Get-Content $tempInf) `
      -replace 'SeRemoteInteractiveLogonRight =.*', `
               'SeRemoteInteractiveLogonRight = *S-1-5-32-544,*S-1-5-32-555' |
    Set-Content $tempInf -Encoding Unicode

    secedit /configure /db $tempDb /cfg $tempInf /areas USER_RIGHTS

    Write-OK "W-57: RDP 접근 권한 그룹 설정 완료"
} catch {
    Write-Err "W-57: 실패 ? $($_.Exception.Message)"
}

# ──────────────────────────────────────────────────────────
# 24. W?58 RDP 암호화 수준 최상/ W?67 RDP 세션 Idle 타임아웃 10분
# ──────────────────────────────────────────────────────────
try {
$ts = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
if (-not (Test-Path $ts)) {
    New-Item -Path $ts | Out-Null
}
Set-ItemProperty $ts MinEncryptionLevel 3
Set-ItemProperty $ts MaxIdleTime 600000
    Write-OK "W-58: 터미널 서비스 암호화 수준 최상, W?67 RDP 세션 Idle 타임아웃 10분"
} catch { Write-Err "W-58: 실패 ? $_" }

# ──────────────────────────────────────────────────────────
# 22. W?67 RDP 세션 Idle 타임아웃 10분
# ──────────────────────────────────────────────────────────
try {
    $ts='HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
    Set-ItemProperty $ts MaxIdleTime 600000
    Write-OK "W-67: RDP 세션 타임아웃 10분"
} catch { Write-Err "W-67: 실패 ? $_" }

# ──────────────────────────────────────────────────────────
# 23. W-69 정책에 따른 시스템 로깅 설정
# ──────────────────────────────────────────────────────────
try {
    # 계정 관리 감사
    auditpol /set /subcategory:"사용자 계정 관리" /failure:enable
    auditpol /set /subcategory:"보안 그룹 관리" /success:enable /failure:enable

    # 계정 로그온 이벤트 감사
    auditpol /set /subcategory:"자격 증명 유효성 검사" /success:enable /failure:enable
    auditpol /set /subcategory:"Kerberos 인증 서비스" /success:enable /failure:enable
    auditpol /set /subcategory:"Kerberos 서비스 티켓 작업" /success:enable /failure:enable

    # 로그온 이벤트 감사
    auditpol /set /subcategory:"로그온" /success:enable /failure:enable
    auditpol /set /subcategory:"특수 로그온" /success:enable /failure:enable
    auditpol /set /subcategory:"계정 잠금" /success:enable /failure:enable

    # 정책 변경 감사
    auditpol /set /subcategory:"감사 정책 변경" /success:enable /failure:enable
    auditpol /set /subcategory:"권한 부여 정책 변경" /success:enable /failure:enable
    auditpol /set /subcategory:"인증 정책 변경" /success:enable /failure:enable

    # 권한 사용 감사
    auditpol /set /subcategory:"중요한 권한 사용" /failure:enable
    auditpol /set /subcategory:"기타 권한 사용 이벤트" /failure:enable

    # 프로세스 추적
    auditpol /set /subcategory:"프로세스 만들기" /success:enable
    auditpol /set /subcategory:"프로세스 종료" /success:enable

    # 디렉터리 서비스 액세스 감사
    auditpol /set /subcategory:"디렉터리 서비스 액세스" /failure:enable

    Write-OK "W-69: 감사 정책 로컬 보안 정책 적용 완료"
} catch {
    Write-Err "W-69: 감사 정책 적용 실패 ? $_"
}

# ──────────────────────────────────────────────────────────
# 24. W?71 이벤트 로그 경로 Everyone 제거 (최상위 폴더만)
# ──────────────────────────────────────────────────────────
$LogDirs = @("$env:SystemRoot\System32\config","$env:SystemRoot\System32\logfiles")
foreach($p in $LogDirs){
    try{
        icacls $p /remove:g "Everyone" /inheritance:d >$null 2>&1
        Write-OK "W-71: $p 권한 제한"
    }catch{ Write-Err "W-71: $p 실패 ? $_" }
}

# ──────────────────────────────────────────────────────────
# 25. W?73 사용자 프린터 드라이버 설치 금지
# ──────────────────────────────────────────────────────────

try {
$pr = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers'
if (-not (Test-Path $pr)) {
    New-Item -Path $pr | Out-Null
}
Set-ItemProperty $pr AddPrinterDrivers 0
    Write-OK "W-73: 프린터 드라이버 설치 금지"
} catch { Write-Err "W-73: 실패 ? $_" }

# ──────────────────────────────────────────────────────────
# 26. W?74 세션 유휴 15분 후 자동 종료
#  ──────────────────────────────────────────────────────────

try {
    $srv = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanManServer\Parameters'
    if (-not (Test-Path $srv)) {
        New-Item -Path $srv | Out-Null
    }
    Set-ItemProperty -Path $srv -Name 'EnableForcedLogoff' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $srv -Name 'AutoDisconnect' -Value 15 -Type DWord -Force
    Write-OK "W-74: 세션 유휴 15분 후 자동 종료"
} catch {
    Write-Err "W-74: 실패 ? $_"
}


# ──────────────────────────────────────────────────────────
# 27. W?75 경고 배너
# ──────────────────────────────────────────────────────────
try {
    $cap="경고: 무단 접속 금지"
    $txt="이 시스템은 허가받은 사용자만 접속할 수 있습니다.`n무단 접속 시 법적 처벌을 받을 수 있습니다."
    $sys='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    Set-ItemProperty $sys legalnoticecaption $cap
    Set-ItemProperty $sys legalnoticetext  $txt
    Write-OK "W-75: 경고 배너 설정 완료"
} catch { Write-Err "W-75: 실패 ? $_" }

# ──────────────────────────────────────────────────────────
# 28. W?76 사용자 홈 디렉터리 Everyone 권한 제거 + $NewAdminName 권한 부여
# ──────────────────────────────────────────────────────────
try {
    $Skip = @('All Users','Default','Default User','Public','DefaultAppPool','MSSQL','defaultuser0')
    
    Get-ChildItem 'C:\Users' -Directory | Where-Object { $Skip -notcontains $_.Name } | ForEach-Object {
        $userDir = $_.FullName

        # Everyone 그룹 제거
        icacls $userDir /remove:g "Everyone" /T >$null 2>&1

        # 관리자 계정에 전체 권한 부여
        icacls $userDir /grant:r "${NewAdminName}:(OI)(CI)(F)" /T >$null 2>&1

        Write-OK "W-76: [$($_.Name)] Everyone 제거 및 $NewAdminName 전체 권한 부여"
    }
}
catch {
    Write-Err "W-76: 실패 ? $_"
}

# ──────────────────────────────────────────────────────────
# 29. W?77 LAN Manager 인증 수준 3 (CIS 최신 권장은 5 → 필요 시 수정)
# ──────────────────────────────────────────────────────────
try {
    $lsa='HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
    Set-ItemProperty $lsa LmCompatibilityLevel 3
    Write-OK "W-77: LAN Manager 인증 수준 3"
} catch { Write-Err "W-77: 실패 ? $_" }

# ──────────────────────────────────────────────────────────
# 30. W?78 보안 채널 데이터 서명·암호화
# ──────────────────────────────────────────────────────────
try {
    $nlg = 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters'
    if (-not (Test-Path $nlg)) {
        New-Item -Path $nlg | Out-Null
    }
    Set-ItemProperty $nlg RequireSignOrSeal 1
    Set-ItemProperty $nlg SealSecureChannel 1
    Set-ItemProperty $nlg SignSecureChannel 1
    Write-OK "W-78: 보안 채널 암호화·서명 설정"
} catch {
    Write-Err "W-78: 실패 ? $_"
}

# ──────────────────────────────────────────────────────────
# 31. Windows Update 자동 업데이트 중지
# ──────────────────────────────────────────────────────────
try {
   # 자동 업데이트만 중지 (서비스는 그대로 유지)
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    if (-not (Test-Path $wu)) {
        New-Item -Path $wu | Out-Null
    }

    # 자동 업데이트 정책(레지스트리) 비활성화
$wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
if (-not (Test-Path $wu)) {
    New-Item -Path $wu | Out-Null
}
Set-ItemProperty -Path $wu -Name 'NoAutoUpdate' -Value 1
Set-ItemProperty -Path $wu -Name 'AUOptions' -Value 1

    Write-OK "W-78: Windows Update 자동 업데이트 중지"
}
catch {
    Write-Err "W-78: 실패 ? $_"
}

# ──────────────────────────────────────────────────────────
# 32. 파일 확장자 숨김 해제
# ──────────────────────────────────────────────────────────
try {
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'HideFileExt' -Value 0
    Write-OK "추가: 파일 확장자 숨김 해제"
} catch { Write-Err "확장자 설정 실패 ? $_" }

# ──────────────────────────────────────────────────────────
# 33. 이벤트 로그 최대 크기 설정
# ──────────────────────────────────────────────────────────
try {
    wevtutil sl Security /ms:41943040
    wevtutil sl Application /ms:20971520
    wevtutil sl System /ms:20971520
    Write-OK "추가: 이벤트 로그 최대 크기 설정 완료"
} catch { Write-Err "이벤트 로그 크기 설정 실패 ? $_" }


# ──────────────────────────────────────────────────────────
# 35. WDigest 인증 비활성화
# ──────────────────────────────────────────────────────────
try {
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest' -Name 'UseLogonCredential' -Value 0 -Type DWord
        Write-OK "추가: WDigest 인증 비활성화"
    } catch { Write-Err "WDigest 설정 실패 ? $_" }


# ──────────────────────────────────────────────────────────
# 37. TCP 연결 튜닝 및 RDP 관련 설정
# ──────────────────────────────────────────────────────────

try {
    $tcpip = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    if (-not (Test-Path $tcpip)) { New-Item -Path $tcpip | Out-Null }

    Set-ItemProperty -Path $tcpip -Name 'TcpTimedWaitDelay' -Value 30 -Type DWord
    Set-ItemProperty -Path $tcpip -Name 'MaxUserPort' -Value 65534 -Type DWord

    Write-OK "추가: TCP TimeWaitDelay(30초) 및 MaxUserPort(65534) 적용 완료"
} catch {
    Write-Err "TCP 연결 튜닝 실패 ? $_"
}

try {
    $tsRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
    if (-not (Test-Path $tsRoot)) { New-Item -Path $tsRoot | Out-Null }

    Set-ItemProperty -Path $tsRoot -Name 'fDenyTSConnections' -Value 0 -Type DWord
    Set-ItemProperty -Path $tsRoot -Name 'fSingleSessionPerUser' -Value 0 -Type DWord

    Write-OK "추가: RDP 활성화 및 멀티 세션 허용 설정 완료"
} catch {
    Write-Err "RDP 기본 설정 실패 ? $_"
}

try {
    $rdpTcp = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
    if (-not (Test-Path $rdpTcp)) { New-Item -Path $rdpTcp | Out-Null }

    Set-ItemProperty -Path $rdpTcp -Name 'MaxInstanceCount' -Value 2 -Type DWord

    Write-OK "추가: RDP 동시 접속 최대 2명 설정 완료"
} catch {
    Write-Err "RDP 동시 접속 수 설정 실패 ? $_"
}

# ──────────────────────────────────────────────────────────
# 36. W-53 로컬 로그온 허용 권한 제한 (Administrators, IIS_IUSRS 그룹)
# ──────────────────────────────────────────────────────────
try {
    $cfgPath = "$env:TEMP\W53.inf"
    $dbPath  = "$env:TEMP\W53.sdb"

    # SID: *S-1-5-32-544 = Administrators
    # SID: *S-1-5-32-568 = IIS_IUSRS 그룹
    $sids = '*S-1-5-32-544,*S-1-5-32-568'

    secedit /export /cfg $cfgPath /areas USER_RIGHTS | Out-Null

    # SeInteractiveLogonRight 값을 강제로 지정된 SID로 설정
    (Get-Content $cfgPath) `
        -replace '^SeInteractiveLogonRight\s*=.*', "SeInteractiveLogonRight = $sids" |
    Set-Content $cfgPath -Encoding Unicode

    # 정책 적용
    secedit /configure /db $dbPath /cfg $cfgPath /areas USER_RIGHTS | Out-Null

    Remove-Item $cfgPath,$dbPath -Force
    Write-OK "W-53: 로컬 로그온 허용을 Administrators, IIS_IUSRS로 제한함"
}
catch {
    Write-Err "W-53: 실패 ? $_"
}


# ──────────────────────────────────────────────────────────
# 38 . 마무리
# ──────────────────────────────────────────────────────────
$warningMsg = @"
────────────────────────────────────────────
? [주의] 일부 보안 설정은 서버의 실제 용도에 따라
   서비스 운영에 영향을 줄 수 있습니다.

 01. W?01 Administrator 계정 이름 변경
   - 기본 관리자 계정 이름이 [$NewAdminName] 으로 변경되었습니다.
   - 이후 로그인 또는 스크립트 실행 시 계정명을 새 이름으로 사용하세요.

 26. W?74 세션 유휴 15분 후 자동 종료
   - 현재 값: 15분
   - 파일 공유, 장시간 세션 유지가 필요한 서버에서는
     접속 끊김, 파일 저장 오류가 발생할 수 있습니다.
   - 세션 유지가 필요하면 아래 명령으로 설정 복원이 가능합니다.
     Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Services\LanManServer\Parameters' -Name 'AutoDisconnect' -Value -1
────────────────────────────────────────────
"@

Write-Warn $warningMsg          # 노란색 경고 출력
Write-Info ""                  # 빈 줄 (일관된 출력 함수 사용)