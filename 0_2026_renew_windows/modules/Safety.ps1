# Auto-split module: Safety.ps1

function Invoke-SafetyGuards {
    if (-not (Test-SectionEnabled -Name 'Safety')) {
        Write-Warn "안전장치 섹션 비활성화"
        return
    }

    Write-Info "`n[섹션] 안전장치"

    # SAFETY-01
    # 내용: 최대 암호 사용기간을 무제한으로 다시 강제합니다.
    # 적용 시: 출고 후 관리자 계정의 주기적 암호 변경 강제를 방지합니다.
    Invoke-HardeningItem -Id 'SAFETY-01' -Title 'PW 만료 정책 무제한 재강제' -Action {
        try {
            net accounts /maxpwage:unlimited | Out-Null
            Write-OK "안전장치: PW 최대사용기간 무제한 확인/재설정"
        } catch { Write-Err "안전장치: 실패 - $_" }
    }
}

