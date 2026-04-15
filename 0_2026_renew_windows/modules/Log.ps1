# Auto-split module: Log.ps1

function Invoke-LogHardening {
    if (-not (Test-SectionEnabled -Name 'Log')) {
        Write-Warn "로그 관리 섹션 비활성화"
        return
    }

    Write-Info "`n[섹션] 로그 관리"

    # W-40
    # 내용: 고급 감사 정책을 auditpol로 세부 설정합니다.
    # 적용 시: 보안 이벤트 추적 범위가 확대되며, 로캘(한국어 subcategory명) 의존성이 있습니다.
    Invoke-HardeningItem -Id 'W-40' -Title '감사 정책 설정' -Action {
        try {
            auditpol /set /subcategory:"사용자 계정 관리" /failure:enable 2>$null | Out-Null
            auditpol /set /subcategory:"보안 그룹 관리" /success:enable /failure:enable 2>$null | Out-Null

            auditpol /set /subcategory:"자격 증명 유효성 검사" /success:enable /failure:enable 2>$null | Out-Null
            auditpol /set /subcategory:"Kerberos 인증 서비스" /success:enable /failure:enable 2>$null | Out-Null
            auditpol /set /subcategory:"Kerberos 서비스 티켓 작업" /success:enable /failure:enable 2>$null | Out-Null

            auditpol /set /subcategory:"로그온" /success:enable /failure:enable 2>$null | Out-Null
            auditpol /set /subcategory:"특수 로그온" /success:enable /failure:enable 2>$null | Out-Null
            auditpol /set /subcategory:"계정 잠금" /success:enable /failure:enable 2>$null | Out-Null

            auditpol /set /subcategory:"감사 정책 변경" /success:enable /failure:enable 2>$null | Out-Null
            auditpol /set /subcategory:"권한 부여 정책 변경" /success:enable /failure:enable 2>$null | Out-Null
            auditpol /set /subcategory:"인증 정책 변경" /success:enable /failure:enable 2>$null | Out-Null

            auditpol /set /subcategory:"중요한 권한 사용" /failure:enable 2>$null | Out-Null
            auditpol /set /subcategory:"프로세스 만들기" /success:enable 2>$null | Out-Null
            auditpol /set /subcategory:"디렉터리 서비스 액세스" /failure:enable 2>$null | Out-Null

            Write-OK "W-40: 감사 정책 설정 완료 (auditpol 한국어)"
            Write-Warn "W-40: [참고] 고급 감사 정책 적용 시 점검(secedit 기반)에서 취약으로 표시될 수 있으나 실제로는 정상입니다"
        } catch { Write-Err "W-40: 실패 - $_" }
    }

    # W-41
    # 내용: W32Time 서비스 활성화 후 NTP(pool.ntp.org) 동기화를 설정합니다.
    # 적용 시: 시스템 시각 일관성 확보에 도움이 되며, 도메인 구조에서는 별도 시간정책과 충돌할 수 있습니다.
    Invoke-HardeningItem -Id 'W-41' -Title 'NTP 시각 동기화' -Action {
        try {
            Set-Service -Name "W32Time" -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name "W32Time" -ErrorAction SilentlyContinue
            w32tm /config /manualpeerlist:"pool.ntp.org" /syncfromflags:manual /reliable:yes /update 2>$null | Out-Null
            w32tm /resync 2>$null | Out-Null
            Write-OK "W-41: NTP 시각 동기화 설정 (pool.ntp.org)"
        } catch { Write-Err "W-41: 실패 - $_" }
    }

    # W-42
    # 내용: Security/Application/System 이벤트 로그 최대 크기를 지정합니다.
    # 적용 시: 로그 보존량이 고정되어, 과도한 로그 회전/유실 가능성을 줄일 수 있습니다.
    Invoke-HardeningItem -Id 'W-42' -Title '이벤트 로그 크기 설정' -Action {
        try {
            wevtutil sl Security /ms:41943040
            wevtutil sl Application /ms:20971520
            wevtutil sl System /ms:20971520
            Write-OK "W-42: 이벤트 로그 크기 설정 (보안40MB, 응용20MB, 시스템20MB)"
        } catch { Write-Err "W-42: 실패 - $_" }
    }

    # W-43
    # 내용: 주요 로그 경로 ACL에서 Everyone 권한을 제거합니다.
    # 적용 시: 로그 파일 접근 통제가 강화되지만, 특정 도구의 로그 수집 권한이 영향을 받을 수 있습니다.
    Invoke-HardeningItem -Id 'W-43' -Title '이벤트 로그 파일 접근 통제' -Action {
        try {
            $logPaths = @("$env:SystemRoot\System32\winevt\Logs", "$env:SystemRoot\System32\config")
            foreach ($p in $logPaths) {
                if (Test-Path $p) {
                    $acl = Get-Acl $p
                    $acl.Access | Where-Object { $_.IdentityReference -like "*Everyone*" } | ForEach-Object {
                        $acl.RemoveAccessRule($_) | Out-Null
                    }
                    Set-Acl $p $acl -ErrorAction SilentlyContinue
                    Write-OK "W-43: $p Everyone 제거"
                }
            }
        } catch { Write-Err "W-43: 실패 - $_" }
    }
}

