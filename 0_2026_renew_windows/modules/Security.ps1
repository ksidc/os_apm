# Auto-split module: Security.ps1

function Invoke-SecurityHardening {
    if (-not (Test-SectionEnabled -Name 'Security')) {
        Write-Warn "보안 관리 섹션 비활성화"
        return
    }

    Write-Info "`n[섹션] 보안 관리"

    # W-47
    # 내용: 화면보호기 활성, 10분 타임아웃, 해제 시 암호 입력을 설정합니다.
    # 적용 시: 자리 비움 상태에서 콘솔 무단 사용을 억제합니다.
    Invoke-HardeningItem -Id 'W-47' -Title '화면보호기 보안 설정' -Action {
        try {
            $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop"
            if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
            Set-ItemProperty -Path $regPath -Name "ScreenSaveActive" -Value "1"
            Set-ItemProperty -Path $regPath -Name "ScreenSaverIsSecure" -Value "1"
            Set-ItemProperty -Path $regPath -Name "ScreenSaveTimeOut" -Value "600"
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveActive" -Value "1"
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaverIsSecure" -Value "1"
            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveTimeOut" -Value "600"
            Write-OK "W-47: 화면보호기 10분, 암호 복귀"
        } catch { Write-Err "W-47: 실패 - $_" }
    }

    # W-48
    # 내용: 로그인 전 시스템 종료 옵션을 비활성화합니다.
    # 적용 시: 비인증 상태에서의 임의 종료 가능성을 줄입니다.
    Invoke-HardeningItem -Id 'W-48' -Title '비로그온 시스템 종료 해제' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ShutdownWithoutLogon" -Value 0 -Type DWord
            Write-OK "W-48: 비로그온 시스템 종료 해제"
        } catch { Write-Err "W-48: 실패 - $_" }
    }

    # W-49
    # 내용: 원격 강제 종료 권한을 Administrators 그룹으로 제한합니다.
    # 적용 시: 원격 종료 권한 오남용 범위를 줄일 수 있습니다.
    Invoke-HardeningItem -Id 'W-49' -Title '원격 강제 종료 권한 제한' -Action {
        try {
            Set-SecPol 'Privilege Rights' 'SeRemoteShutdownPrivilege' '*S-1-5-32-544'
            Write-OK "W-49: 원격 강제 종료 Administrators만"
        } catch { Write-Err "W-49: 실패 - $_" }
    }

    # W-50
    # 내용: 감사 로그 기록 불가 시 시스템 종료 정책을 해제합니다.
    # 적용 시: 로그 장애로 서버가 중단되는 상황을 방지할 수 있습니다.
    Invoke-HardeningItem -Id 'W-50' -Title '감사 실패 시 시스템 종료 해제' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "CrashOnAuditFail" -Value 0 -Type DWord
            Write-OK "W-50: 감사 실패 시 종료 해제"
        } catch { Write-Err "W-50: 실패 - $_" }
    }

    # W-51
    # 내용: SAM/공유의 익명 열거를 제한합니다.
    # 적용 시: 익명 사용자의 계정/공유 정보 수집을 차단합니다.
    Invoke-HardeningItem -Id 'W-51' -Title 'SAM 익명 열거 차단' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -Value 1 -Type DWord
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymousSAM" -Value 1 -Type DWord
            Write-OK "W-51: SAM 익명 열거 차단"
        } catch { Write-Err "W-51: 실패 - $_" }
    }

    # W-52
    # 내용: 자동 로그인(AutoAdminLogon) 및 저장된 기본 암호를 제거합니다.
    # 적용 시: 시스템 재부팅 후 자동 계정 노출/로그인 위험을 줄입니다.
    Invoke-HardeningItem -Id 'W-52' -Title 'Autologon 해제' -Action {
        try {
            $winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
            Set-ItemProperty -Path $winlogon -Name "AutoAdminLogon" -Value "0"
            Remove-ItemProperty -Path $winlogon -Name "DefaultPassword" -ErrorAction SilentlyContinue
            Write-OK "W-52: Autologon 해제"
        } catch { Write-Err "W-52: 실패 - $_" }
    }

    # W-53
    # 내용: 이동식 미디어 포맷/꺼내기 권한을 Administrators로 제한합니다.
    # 적용 시: 일반 사용자에 의한 저장장치 조작 권한을 낮춥니다.
    Invoke-HardeningItem -Id 'W-53' -Title '이동식 미디어 권한 제한' -Action {
        try {
            Set-SecPol 'Privilege Rights' 'AllocateDASD' '*S-1-5-32-544'
            Write-OK "W-53: 이동식 미디어 Administrators만"
        } catch { Write-Err "W-53: 실패 - $_" }
    }

    # W-55
    # 내용: 사용자 프린터 드라이버 설치를 제한합니다.
    # 적용 시: 프린트 드라이버 기반 권한 상승 공격면을 줄일 수 있습니다.
    Invoke-HardeningItem -Id 'W-55' -Title '프린터 드라이버 설치 금지' -Action {
        try {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Providers\LanMan Print Services\Servers"
            if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
            Set-ItemProperty -Path $regPath -Name "AddPrinterDrivers" -Value 1 -Type DWord
            Write-OK "W-55: 프린터 드라이버 설치 금지"
        } catch { Write-Err "W-55: 실패 - $_" }
    }

    # W-56
    # 내용: SMB 유휴 세션 종료(15분)와 시간 만료 시 강제 로그오프를 설정합니다.
    # 적용 시: 방치된 SMB 세션 지속 시간을 줄여 세션 오남용 위험을 낮춥니다.
    Invoke-HardeningItem -Id 'W-56' -Title 'SMB 세션 제어' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoDisconnect" -Value 15 -Type DWord
            Set-SecPol 'System Access' 'ForceLogoffWhenHourExpire' '1'
            Write-OK "W-56: SMB 세션 유휴 15분 종료 + 만료 시 끊기"
        } catch { Write-Err "W-56: 실패 - $_" }
    }

    # W-57
    # 내용: 로그인 시 법적 고지(배너) 문구를 표시합니다.
    # 적용 시: 무단 접근 경고를 명시하여 정책 고지 효과를 제공합니다.
    Invoke-HardeningItem -Id 'W-57' -Title '로그온 경고 메시지 설정' -Action {
        try {
            $sysPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            Set-ItemProperty -Path $sysPath -Name "LegalNoticeCaption" -Value "경고"
            Set-ItemProperty -Path $sysPath -Name "LegalNoticeText" -Value "이 시스템은 허가된 사용자만 접근할 수 있습니다. 무단 접근 시 관련 법률에 의해 처벌될 수 있습니다."
            Write-OK "W-57: 경고 메시지 설정"
        } catch { Write-Err "W-57: 실패 - $_" }
    }

    # W-58
    # 내용: 사용자 홈 디렉터리 ACL에서 Everyone 권한 제거 후 지정 관리자 권한을 부여합니다.
    # 적용 시: 사용자 프로필 접근 통제가 강화되나, 기존 ACL 의존 프로그램은 영향이 있을 수 있습니다.
    Invoke-HardeningItem -Id 'W-58' -Title '홈 디렉터리 ACL 정리' -Action {
        try {
            Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notin @("Public", "Default", "Default User", "All Users") } |
                ForEach-Object {
                    $acl = Get-Acl $_.FullName
                    $removed = $false
                    $acl.Access | Where-Object { $_.IdentityReference -like "*Everyone*" } | ForEach-Object {
                        $acl.RemoveAccessRule($_) | Out-Null
                        $removed = $true
                    }
                    if ($removed) {
                        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($NewAdminName, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                        $acl.AddAccessRule($rule)
                        Set-Acl $_.FullName $acl
                        Write-OK "W-58: [$($_.Name)] Everyone 제거, $NewAdminName 권한 부여"
                    }
                }
        } catch { Write-Err "W-58: 실패 - $_" }
    }

    # W-59
    # 내용: LAN Manager 인증 수준을 3(NTLMv2)으로 설정합니다.
    # 적용 시: 구형 인증 방식 사용을 줄여 인증 보안을 강화합니다.
    Invoke-HardeningItem -Id 'W-59' -Title 'LAN Manager 인증 수준 강화' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LmCompatibilityLevel" -Value 3 -Type DWord
            Write-OK "W-59: LAN Manager 인증 수준 3 (NTLMv2)"
        } catch { Write-Err "W-59: 실패 - $_" }
    }

    # W-60
    # 내용: Netlogon 보안 채널에 서명/암호화를 강제합니다.
    # 적용 시: 보안 채널 무결성과 기밀성이 강화됩니다.
    Invoke-HardeningItem -Id 'W-60' -Title '보안 채널 서명/암호화 설정' -Action {
        try {
            $netlogon = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
            Set-ItemProperty -Path $netlogon -Name "RequireSignOrSeal" -Value 1 -Type DWord
            Set-ItemProperty -Path $netlogon -Name "SealSecureChannel" -Value 1 -Type DWord
            Set-ItemProperty -Path $netlogon -Name "SignSecureChannel" -Value 1 -Type DWord
            Write-OK "W-60: 보안 채널 암호화/서명 설정"
        } catch { Write-Err "W-60: 실패 - $_" }
    }

    # W-64
    # 내용: Windows 방화벽 전 프로필 활성화 후 외부 포함 ICMPv4 Echo(Inbound) 허용 규칙을 생성합니다.
    # 적용 시: 기본 인바운드 차단 정책은 유지하면서 ping(IPv4) 응답을 허용할 수 있습니다.
    Invoke-HardeningItem -Id 'W-64' -Title '방화벽 활성화 + ICMPv4 허용' -Action {
        $sidMapPattern = 'No mapping between account names and security IDs was done|ERROR_NONE_MAPPED|0x534|1332'
        $icmpRuleName = "KISA-Allow-External-ICMPv4-In"
        $osCaption = ""
        $productName = ""
        $buildNumber = 0

        try {
            $osCaption = [string](Get-CimInstance Win32_OperatingSystem -ErrorAction Stop | Select-Object -ExpandProperty Caption)
        } catch {}

        try {
            $cv = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
            $productName = [string]$cv.ProductName
            $buildNumber = [int]([string]$cv.CurrentBuildNumber)
        } catch {}

        $isServer2025 =
            ($osCaption -match 'Windows Server 2025') -or
            ($productName -match 'Windows Server 2025') -or
            (($productName -match 'Windows Server') -and ($buildNumber -ge 26000))

        if ($isServer2025) {
            # 2025: NetSecurity cmdlet에서 SID 매핑 오류(1332) 사례가 있어 netsh를 기본 경로로 사용
            try {
                netsh advfirewall set allprofiles state on | Out-Null
                Write-OK "W-64: 방화벽 전 프로필 활성화 (Windows Server 2025 전용 경로)"
            } catch {
                Write-Err "W-64: 실패 - $($_.Exception.Message)"
            }

            try {
                netsh advfirewall firewall delete rule name="$icmpRuleName" | Out-Null
                netsh advfirewall firewall add rule name="$icmpRuleName" dir=in action=allow protocol=icmpv4:8,any remoteip=any profile=any | Out-Null
                Write-OK "W-64: ICMPv4 Inbound(Echo, External 포함) 허용 규칙 적용 (Windows Server 2025 전용 경로)"
            } catch {
                Write-Err "W-64: ICMP 허용 실패 - $($_.Exception.Message)"
            }
        } else {
            # 2016/2019/2022: 기존 NetSecurity 경로 유지
            try {
                Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True -ErrorAction Stop
                Write-OK "W-64: 방화벽 전 프로필 활성화"
            } catch {
                $msg = $_.Exception.Message
                if ($msg -match $sidMapPattern) {
                    Write-Warn "W-64: NetSecurity SID 매핑 오류 감지, netsh fallback 적용"
                } else {
                    Write-Warn "W-64: Set-NetFirewallProfile 실패, netsh fallback 시도 - $msg"
                }

                try {
                    netsh advfirewall set allprofiles state on | Out-Null
                    Write-OK "W-64: 방화벽 전 프로필 활성화 (netsh fallback)"
                } catch {
                    Write-Err "W-64: 실패 - $($_.Exception.Message)"
                }
            }

            try {
                Get-NetFirewallRule -DisplayName $icmpRuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
                New-NetFirewallRule -DisplayName $icmpRuleName -Direction Inbound -Action Allow -Protocol ICMPv4 -IcmpType 8 -Profile Any -RemoteAddress Any -ErrorAction Stop | Out-Null
                Write-OK "W-64: ICMPv4 Inbound(Echo, External 포함) 허용 규칙 적용"
            } catch {
                $msg = $_.Exception.Message
                if ($msg -match $sidMapPattern) {
                    Write-Warn "W-64: NetSecurity SID 매핑 오류 감지, ICMP 규칙 netsh fallback 적용"
                } else {
                    Write-Warn "W-64: New-NetFirewallRule 실패, netsh fallback 시도 - $msg"
                }

                try {
                    netsh advfirewall firewall delete rule name="$icmpRuleName" | Out-Null
                    netsh advfirewall firewall add rule name="$icmpRuleName" dir=in action=allow protocol=icmpv4:8,any remoteip=any profile=any | Out-Null
                    Write-OK "W-64: ICMPv4 Inbound(Echo, External 포함) 허용 규칙 적용 (netsh fallback)"
                } catch {
                    Write-Err "W-64: ICMP 허용 실패 - $($_.Exception.Message)"
                }
            }
        }
    }
}

