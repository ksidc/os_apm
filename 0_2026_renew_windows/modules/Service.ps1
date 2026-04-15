# Auto-split module: Service.ps1

function Invoke-ServiceHardening {
    if (-not (Test-SectionEnabled -Name 'Service')) {
        Write-Warn "서비스 관리 섹션 비활성화"
        return
    }

    Write-Info "`n[섹션] 서비스 관리"

    # W-15
    # 내용: 개인키 사용 시 강한 보호(암호 입력)를 요구합니다.
    # 적용 시: 개인키 오남용 난이도가 높아지며, 인증서 사용 UX가 강화됩니다.
    Invoke-HardeningItem -Id 'W-15' -Title '개인키 보호 강제' -Action {
        try {
            $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Cryptography"
            if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
            Set-ItemProperty -Path $regPath -Name "ForceKeyProtection" -Value 2 -Type DWord
            Write-OK "W-15: 개인키 사용 시 암호 입력 강제"
        } catch { Write-Err "W-15: 실패 - $_" }
    }

    # W-17
    # 내용: 기본 공유(AutoShareServer)를 끄고 SMBv1을 비활성화합니다.
    # 적용 시: 레거시/취약 SMB 노출을 낮추며, 일부 구형 장비 호환성에 영향이 있을 수 있습니다.
    Invoke-HardeningItem -Id 'W-17' -Title '기본 공유 제거 + SMBv1 비활성화' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareServer" -Value 0 -Type DWord
            Write-OK "W-17: 기본 공유(AutoShareServer) 해제"
        } catch { Write-Err "W-17: 기본 공유 해제 실패 - $_" }

        try {
            Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop
            Write-OK "W-17: SMBv1 비활성화 완료"
        } catch {
            try {
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0 -Type DWord
                Write-OK "W-17: SMBv1 비활성화 (레지스트리)"
            } catch { Write-Err "W-17: SMBv1 비활성화 실패 - $_" }
        }
        Need-Reboot
    }

    # W-18
    # 내용: 지정된 불필요 서비스($BlockServices + RemoteRegistry)를 중지/비활성화합니다.
    # 적용 시: 공격면이 줄어들지만, 실제 사용 중인 역할 서비스가 목록에 있으면 기능 장애가 생길 수 있습니다.
    Invoke-HardeningItem -Id 'W-18' -Title '불필요 서비스 비활성화' -Action {
        foreach ($svcName in ($BlockServices + @('RemoteRegistry'))) {
            try {
                $svc = Get-Service -Name $svcName -ErrorAction Stop
                if ($svc.Status -eq 'Running') { Stop-Service -Name $svcName -Force -ErrorAction Stop }
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
                Write-OK "W-18: [$svcName] 중지/비활성화"
            } catch {
                if ($_.Exception.Message -match 'Cannot find') {
                    Write-Warn "W-18: [$svcName] 미설치, 건너뜀"
                } else { Write-Err "W-18: [$svcName] 실패 - $($_.Exception.Message)" }
            }
        }
    }

    # W-20
    # 내용: 각 네트워크 인터페이스의 NetBIOS over TCP/IP를 비활성화합니다.
    # 적용 시: NetBIOS 기반 정보 노출과 브로드캐스트 트래픽을 줄일 수 있습니다.
    Invoke-HardeningItem -Id 'W-20' -Title 'NetBIOS over TCP/IP 비활성화' -Action {
        try {
            $regBase = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"
            Get-ChildItem $regBase -ErrorAction Stop | ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name "NetbiosOptions" -Value 2 -Type DWord
                Write-OK "W-20: [$($_.PSChildName)] NetBIOS 비활성화"
            }
        } catch { Write-Err "W-20: 실패 - $_" }
    }

    # W-28
    # 내용: RDP 최소 암호화 수준을 높음(3)으로 설정합니다.
    # 적용 시: 원격 세션 암호화 강도가 강화됩니다.
    Invoke-HardeningItem -Id 'W-28' -Title 'RDP 암호화 수준 강화' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MinEncryptionLevel" -Value 3 -Type DWord
            Write-OK "W-28: RDP 암호화 수준 = 높음(3)"
        } catch { Write-Err "W-28: 실패 - $_" }
    }

    # W-36
    # 내용: RDP 유휴/연결해제 세션 타임아웃을 10분으로 설정합니다.
    # 적용 시: 방치된 세션이 자동 정리되어 세션 하이재킹 위험을 줄일 수 있습니다.
    Invoke-HardeningItem -Id 'W-36' -Title 'RDP 세션 타임아웃 설정' -Action {
        try {
            $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
            if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
            Set-ItemProperty -Path $regPath -Name "MaxIdleTime" -Value 600000 -Type DWord
            Set-ItemProperty -Path $regPath -Name "MaxDisconnectionTime" -Value 600000 -Type DWord
            Write-OK "W-36: RDP 유휴 타임아웃 10분"
        } catch { Write-Err "W-36: 실패 - $_" }
    }
}

