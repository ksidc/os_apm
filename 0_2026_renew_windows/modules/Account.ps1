# Auto-split module: Account.ps1

function Invoke-AccountHardening {
    if (-not (Test-SectionEnabled -Name 'Account')) {
        Write-Warn "계정 관리 섹션 비활성화"
        return
    }

    Write-Info "`n[섹션] 계정 관리"

    # W-01
    # 내용: 기본 Administrator(SID -500) 계정 이름을 지정한 관리자 계정명으로 변경합니다.
    # 적용 시: 기본 계정명 노출을 줄일 수 있으나, 이후 로그인 시 새 계정명을 사용해야 합니다.
    Invoke-HardeningItem -Id 'W-01' -Title 'Administrator 계정 이름 변경' -Action {
        try {
            $admin = Get-LocalUser | Where-Object { $_.SID -like "*-500" }
            if ($admin -and $admin.Name -ne $NewAdminName) {
                Rename-LocalUser -Name $admin.Name -NewName $NewAdminName
                Write-OK "W-01: Administrator → $NewAdminName 변경 완료"
                Need-Reboot
            } else { Write-Warn "W-01: 이미 $NewAdminName" }
        } catch { Write-Err "W-01: 실패 - $_" }
    }

    # W-02
    # 내용: Guest(SID -501) 계정을 비활성화합니다.
    # 적용 시: 익명/저신뢰 계정의 직접 로그인 위험을 줄일 수 있습니다.
    Invoke-HardeningItem -Id 'W-02' -Title 'Guest 계정 비활성화' -Action {
        try {
            $guest = Get-LocalUser | Where-Object { $_.SID -like "*-501" }
            if ($guest -and $guest.Enabled) {
                Disable-LocalUser -Name $guest.Name
                Write-OK "W-02: Guest 비활성화 완료"
            } else { Write-Warn "W-02: Guest 이미 비활성화" }
        } catch { Write-Err "W-02: 실패 - $_" }
    }

    # W-03
    # 내용: 화이트리스트($AccountWhite)에 없는 로컬 계정을 비활성화합니다.
    # 적용 시: 불필요한 계정 노출을 줄이지만, 운영 계정을 화이트리스트에 넣지 않으면 접속 장애가 발생할 수 있습니다.
    Invoke-HardeningItem -Id 'W-03' -Title '불필요한 계정 비활성화' -Action {
        foreach ($u in Get-LocalUser) {
            if ($AccountWhite -notcontains $u.Name -and $u.Enabled) {
                try {
                    Disable-LocalUser -Name $u.Name -ErrorAction Stop
                    Write-OK "W-03: [$($u.Name)] 비활성화"
                } catch { Write-Err "W-03: [$($u.Name)] 실패 - $_" }
            }
        }
    }

    # W-04/W-08
    # 내용: 로그인 실패 잠금 임계값/잠금기간/관찰기간을 설정합니다.
    # 적용 시: 무차별 대입 공격 억제 효과가 있으나, 오입력 반복 시 정상 사용자도 일시 잠금됩니다.
    Invoke-HardeningItem -Id 'W-04-W-08' -Title '계정 잠금 정책 설정' -Action {
        try {
            net accounts /lockoutthreshold:$($Lockout.Threshold) `
                         /lockoutduration:$($Lockout.Duration) `
                         /lockoutwindow:$($Lockout.Window) | Out-Null
            Write-OK "W-04/W-08: 잠금 임계값 $($Lockout.Threshold)회, 잠금 기간 $($Lockout.Duration)분"
        } catch { Write-Err "W-04/W-08: 실패 - $_" }
    }

    # W-05
    # 내용: 가역적(해독 가능한) 암호 저장 정책을 비활성화합니다.
    # 적용 시: 암호 보관 강도가 올라가며, 일부 레거시 인증 호환성이 영향을 받을 수 있습니다.
    Invoke-HardeningItem -Id 'W-05' -Title '가역적 암호 저장 해제' -Action {
        try {
            $cfg = "$env:TEMP\w05_$(Get-Random).inf"
            secedit /export /cfg $cfg | Out-Null
            (Get-Content $cfg) `
                -replace 'ClearTextPassword\s*=.*', 'ClearTextPassword = 0' `
                -replace 'MaximumPasswordAge\s*=.*', 'MaximumPasswordAge = 0' |
                Set-Content $cfg -Encoding Unicode
            secedit /configure /db secedit.sdb /cfg $cfg /areas SECURITYPOLICY | Out-Null
            Remove-Item $cfg -Force
            Write-OK "W-05: 가역적 암호 저장 해제 완료"
        } catch { Write-Err "W-05: 실패 - $_" }
    }

    # W-06
    # 내용: Administrators 그룹에서 유지 대상 외 멤버를 제거합니다.
    # 적용 시: 관리자 권한 계정을 최소화할 수 있으나, 필요한 계정까지 제거되면 운영 중 권한 이슈가 발생할 수 있습니다.
    Invoke-HardeningItem -Id 'W-06' -Title '관리자 그룹 정리' -Action {
        try {
            $keep = @($NewAdminName, 'SYSTEM', 'Administrator')
            $members = Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop
            $members | Where-Object {
                $shortName = $_.Name -replace '^.*\\', ''
                $shortName -notin $keep
            } | ForEach-Object {
                try {
                    Remove-LocalGroupMember -Group 'Administrators' -Member $_.Name -ErrorAction Stop
                    Write-OK "W-06: Administrators에서 [$($_.Name)] 제거"
                } catch { Write-Err "W-06: [$($_.Name)] 제거 실패 - $($_.Exception.Message)" }
            }
        } catch { Write-Err "W-06: 실패 - $_" }
    }

    # W-07
    # 내용: Everyone 권한을 익명 사용자에 포함하지 않도록 설정합니다.
    # 적용 시: 익명 컨텍스트에서의 과도한 접근 범위를 줄입니다.
    Invoke-HardeningItem -Id 'W-07' -Title 'Everyone 익명 적용 해제' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "everyoneincludesanonymous" -Value 0 -Type DWord
            Write-OK "W-07: Everyone 익명 사용자 적용 해제"
        } catch { Write-Err "W-07: 실패 - $_" }
    }

    # W-09
    # 내용: 비밀번호 길이/이력/복잡성/빈 암호 제한 정책을 설정합니다.
    # 적용 시: 계정 보안 강도가 올라가며, 최대 사용기간은 무제한으로 유지됩니다.
    Invoke-HardeningItem -Id 'W-09' -Title '비밀번호 정책 설정' -Action {
        try {
            net accounts /minpwlen:8 /minpwage:1 /maxpwage:unlimited /uniquepw:12 | Out-Null
            $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
            Set-ItemProperty -Path $lsa -Name "PasswordComplexity" -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $lsa -Name "LimitBlankPasswordUse" -Value 1 -Type DWord -Force
            Write-OK "W-09: 복잡성=사용, 최소길이=8, 최소사용기간=1일, 최대사용기간=무제한(의도적), 이력=12개"
        } catch { Write-Err "W-09: 실패 - $_" }
    }

    # W-10
    # 내용: 로그인 화면에 마지막 사용자 이름 표시를 비활성화합니다.
    # 적용 시: 계정명 추측 단서를 줄일 수 있습니다.
    Invoke-HardeningItem -Id 'W-10' -Title '마지막 사용자 이름 표시 안 함' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "DontDisplayLastUserName" -Value 1 -Type DWord
            Write-OK "W-10: 마지막 사용자 이름 표시 안 함"
        } catch { Write-Err "W-10: 실패 - $_" }
    }

    # W-11
    # 내용: 로컬 로그온 권한을 Administrators, IIS_IUSRS SID로 설정합니다.
    # 적용 시: 인터랙티브 로그온 가능한 그룹을 제한합니다.
    Invoke-HardeningItem -Id 'W-11' -Title '로컬 로그온 권한 제한' -Action {
        try {
            Set-SecPol 'Privilege Rights' 'SeInteractiveLogonRight' '*S-1-5-32-544,*S-1-5-32-568'
            Write-OK "W-11: 로컬 로그온 Administrators, IIS_IUSRS로 제한"
            Write-Warn "W-11: [참고] 취약으로 표시되어도 운영상 문제없음"
        } catch { Write-Err "W-11: 실패 - $_" }
    }

    # W-12
    # 내용: 익명 SID/이름 조회를 금지합니다.
    # 적용 시: 익명 열람 기반 정보 수집 가능성을 줄입니다.
    Invoke-HardeningItem -Id 'W-12' -Title '익명 SID/이름 변환 해제' -Action {
        try {
            Set-SecPol 'System Access' 'LSAAnonymousNameLookup' '0'
            Write-OK "W-12: 익명 SID/이름 변환 해제"
        } catch { Write-Err "W-12: 실패 - $_" }
    }

    # W-13
    # 내용: 빈 암호 계정의 콘솔 로그온을 제한합니다.
    # 적용 시: 무암호 계정 오남용 가능성을 낮춥니다.
    Invoke-HardeningItem -Id 'W-13' -Title '빈 암호 사용 제한' -Action {
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LimitBlankPasswordUse" -Value 1 -Type DWord
            Write-OK "W-13: 빈 암호 사용 제한"
        } catch { Write-Err "W-13: 실패 - $_" }
    }

    # W-14
    # 내용: Remote Desktop Users 그룹 멤버를 지정 관리자 계정 중심으로 정리합니다.
    # 적용 시: RDP 진입 계정을 최소화할 수 있으나, 필요한 계정을 제외하면 원격 접속이 제한됩니다.
    Invoke-HardeningItem -Id 'W-14' -Title '원격터미널 접속 사용자 그룹 제한' -Action {
        try {
            $rdpGroup = Get-LocalGroup -Name "Remote Desktop Users" -ErrorAction Stop
            $rdpMembers = Get-LocalGroupMember -Group "Remote Desktop Users" -ErrorAction SilentlyContinue
            $rdpMembers | ForEach-Object {
                $shortName = $_.Name -replace '^.*\\', ''
                if ($shortName -notin @($NewAdminName)) {
                    Remove-LocalGroupMember -Group "Remote Desktop Users" -Member $_.Name -ErrorAction SilentlyContinue
                    Write-OK "W-14: Remote Desktop Users에서 [$($_.Name)] 제거"
                }
            }
            Write-OK "W-14: RDP 접근 그룹 정리 완료"
        } catch { Write-Err "W-14: 실패 - $_" }
    }
}

