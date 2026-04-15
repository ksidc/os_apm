# Auto-split module: Extra.ps1

function Invoke-ExtraSettings {
    if (-not (Test-SectionEnabled -Name 'Extra')) {
        Write-Warn "추가 설정 섹션 비활성화"
        return
    }

    Write-Info "`n[섹션] 추가 설정 (KISA 항목 외)"

    # X-01
    # 내용: 자동 업데이트를 비활성화(NoAutoUpdate=1)합니다.
    # 적용 시: 계획되지 않은 재부팅/패치 변동을 줄일 수 있으나, 패치 누락 리스크가 생길 수 있습니다.
    Invoke-HardeningItem -Id 'X-01' -Title 'Windows Update 자동 업데이트 중지' -Action {
        try {
            $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            if (!(Test-Path $wuPath)) { New-Item -Path $wuPath -Force | Out-Null }
            Set-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -Value 1 -Type DWord
            Write-OK "추가: Windows Update 자동 업데이트 중지"
        } catch { Write-Err "추가: WU 실패 - $_" }
    }

    # X-02
    # 내용: 파일 확장자 숨김을 해제합니다.
    # 적용 시: 파일 위장(이중 확장자) 식별이 쉬워집니다.
    Invoke-HardeningItem -Id 'X-02' -Title '파일 확장자 표시' -Action {
        try {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Type DWord
            Write-OK "추가: 파일 확장자 표시"
        } catch { Write-Err "추가: 확장자 실패 - $_" }
    }

    # X-03
    # 내용: WDigest 인증에서 평문 자격증명 캐시를 비활성화합니다.
    # 적용 시: 메모리 기반 자격증명 탈취 위험을 줄일 수 있습니다.
    Invoke-HardeningItem -Id 'X-03' -Title 'WDigest 인증 비활성화' -Action {
        try {
            $wdPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"
            if (!(Test-Path $wdPath)) { New-Item -Path $wdPath -Force | Out-Null }
            Set-ItemProperty -Path $wdPath -Name "UseLogonCredential" -Value 0 -Type DWord
            Write-OK "추가: WDigest 인증 비활성화"
        } catch { Write-Err "추가: WDigest 실패 - $_" }
    }

    # X-03A
    # 내용: RDP를 사용 가능 상태로 강제합니다(원격 접속 허용 + TermService 자동 시작/기동).
    # 적용 시: OS 기본값이 비활성화여도 원격 데스크톱 접속이 가능해집니다.
    Invoke-HardeningItem -Id 'X-03A' -Title 'RDP 활성화 + 서비스 자동 시작' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Type DWord
            Set-Service -Name "TermService" -StartupType Automatic -ErrorAction Stop
            Start-Service -Name "TermService" -ErrorAction SilentlyContinue
            netsh advfirewall firewall set rule group="원격 데스크톱" new enable=Yes 2>$null | Out-Null
            netsh advfirewall firewall set rule group="remote desktop" new enable=Yes 2>$null | Out-Null
            Write-OK "추가: RDP 활성화 + TermService 자동 시작 적용"
        } catch { Write-Err "추가: RDP 활성화 실패 - $_" }
    }

    # X-04
    # 내용: RDP 포트를 커스텀 포트($RdpPort)로 변경하고 해당 포트 인바운드 허용 규칙을 추가합니다.
    # 적용 시: 기본 3389 스캔 노출을 줄일 수 있으나, 재부팅 후 새 포트로 접속해야 합니다.
    Invoke-HardeningItem -Id 'X-04' -Title 'RDP 포트 변경 + 방화벽 허용' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "PortNumber" -Value $RdpPort -Type DWord
            netsh advfirewall firewall add rule name="RDP-Custom-$RdpPort" dir=in action=allow protocol=tcp localport=$RdpPort | Out-Null
            netsh advfirewall firewall set rule name="원격 데스크톱 - 사용자 모드(TCP-In)" new enable=no 2>$null | Out-Null
            netsh advfirewall firewall set rule name="Remote Desktop - User Mode (TCP-In)" new enable=no 2>$null | Out-Null
            Write-OK "추가: RDP 포트 $RdpPort 변경 + 방화벽 허용"
            Need-Reboot
        } catch { Write-Err "추가: RDP 포트 실패 - $_" }
    }

    # X-05
    # 내용: TCP TimeWaitDelay, MaxUserPort 레지스트리 값을 튜닝합니다.
    # 적용 시: 연결 처리 특성이 변경되므로 고트래픽 서버에서만 신중히 사용해야 합니다.
    Invoke-HardeningItem -Id 'X-05' -Title 'TCP 연결 튜닝' -Action {
        try {
            $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            Set-ItemProperty -Path $tcpPath -Name "TcpTimedWaitDelay" -Value 30 -Type DWord
            Set-ItemProperty -Path $tcpPath -Name "MaxUserPort" -Value 65534 -Type DWord
            Write-OK "추가: TCP 튜닝 (TimeWaitDelay=30, MaxUserPort=65534)"
        } catch { Write-Err "추가: TCP 튜닝 실패 - $_" }
    }

    # X-06
    # 내용: RDP 동시 세션 수를 2로 제한하고, 사용자당 단일 세션 강제를 끕니다.
    # 적용 시: 세션 운영 기준이 바뀌므로 운영 정책과 맞는지 확인이 필요합니다.
    Invoke-HardeningItem -Id 'X-06' -Title 'RDP 동시 세션 제한' -Action {
        try {
            $tsPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
            if (!(Test-Path $tsPath)) { New-Item -Path $tsPath -Force | Out-Null }
            Set-ItemProperty -Path $tsPath -Name "MaxInstanceCount" -Value 2 -Type DWord
            Set-ItemProperty -Path $tsPath -Name "fSingleSessionPerUser" -Value 0 -Type DWord
            Write-OK "추가: RDP 최대 2세션"
        } catch { Write-Err "추가: RDP 세션 실패 - $_" }
    }
}

