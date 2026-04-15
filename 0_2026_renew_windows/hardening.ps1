# ──────────────────────────────────────────────────────────
# KISA 2026 Windows Server 보안 설정 자동화
# 대상: Windows Server 2016 / 2019 / 2022 / 2025
# 용도: 신규/재설치 서버 초기 보안 베이스라인 선적용
# ──────────────────────────────────────────────────────────

# ── 운영자 커스터마이징 가이드 ──
# 1) 관리자 계정명 변경:
#    $NewAdminName = 'iteasy_admin'
#
# 2) 잠금 정책 튜닝:
#    $Lockout = @{ Threshold = 5; Duration = 60; Window = 60 }
#
# 3) 계정/서비스 정책 튜닝:
#    $AccountWhite = @($NewAdminName, 'Guest', 'WDAGUtilityAccount', 'DefaultAccount')
#    $BlockServices = @('SNMP','SNMPTRAP','Telnet','Fax','TlntSvr','TrkWks','TrkSvr','Spooler','DNS')
#
# 4) 항목 단위 제외(기본값: 없음)
#    예) W-18, X-01을 건너뛰려면:
#    $SkipItems = @('W-18', 'X-01')
#
# 5) 섹션 단위 비활성화(기본값: 전부 활성)
#    예) 추가 설정 섹션 전체 비활성화:
#    $SectionEnabled['Extra'] = $false
#
# 6) RDP 포트 튜닝:
#    $RdpPort = 48321

# ── 0. 사용자 조정 파라미터 ──
$NewAdminName   = 'iteasy_admin'
$Lockout        = @{ Threshold = 5; Duration = 60; Window = 60 }
$AccountWhite   = @($NewAdminName, 'Guest', 'WDAGUtilityAccount', 'DefaultAccount')
$BlockServices  = @('SNMP', 'SNMPTRAP', 'Telnet', 'Fax', 'TlntSvr', 'TrkWks', 'TrkSvr', 'Spooler', 'DNS')
$RdpPort        = 48321

# 비활성화할 항목 ID 목록 (기본: 없음)
$SkipItems      = @()

# 섹션별 실행 여부
$SectionEnabled = @{
    Account  = $true
    Service  = $true
    Log      = $true
    Security = $true
    Extra    = $true
    Safety   = $true
}

$NeedReboot     = $false
# ── 모듈 로드 ──
# run.bat에서 현재 디렉터리를 스크립트 경로로 이동하므로,
# ScriptBlock 실행 환경에서도 Get-Location 기반 로딩이 가능합니다.
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ModuleDir = Join-Path $ScriptRoot 'modules'
$ModuleList = @('Common.ps1', 'Account.ps1', 'Service.ps1', 'Log.ps1', 'Security.ps1', 'Extra.ps1', 'Safety.ps1')
$LogDir = Join-Path $ScriptRoot 'logs'
if (-not (Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
$LogFile = if ($env:KISA_LOG_FILE -and $env:KISA_LOG_FILE.Trim()) { $env:KISA_LOG_FILE } else { Join-Path $LogDir ("hardening_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss")) }
$Global:KisaLogFile = $LogFile
try {
    Add-Content -Path $LogFile -Value ("[INFO] PowerShell hardening start: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
} catch {}

try {
    foreach ($module in $ModuleList) {
        $modulePath = Join-Path $ModuleDir $module
        if (-not (Test-Path $modulePath)) {
            throw "모듈 파일을 찾을 수 없습니다: $modulePath"
        }
        . $modulePath
    }

    # ── 실행 ──
    Write-Info "`n===== KISA 2026 Windows Server 보안 설정 시작 ====="
    Write-Info "대상: $env:COMPUTERNAME / $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)"
    Write-Info "실행 로그: $LogFile"
    Write-Info ""

    Invoke-AccountHardening
    Invoke-ServiceHardening
    Invoke-LogHardening
    Invoke-SecurityHardening
    Invoke-ExtraSettings
    Invoke-SafetyGuards

    Write-Info "`n===== 보안 설정 적용 완료 ====="
    if ($NeedReboot) {
        Write-Warn "재부팅이 필요한 설정이 포함되어 있습니다."
        Write-Warn "RDP 포트가 $RdpPort 로 변경되었습니다. 재부팅 후 해당 포트로 접속하십시오."
    }
    Write-Info ""
} catch {
    $err = "치명적 오류: $($_.Exception.Message)"
    Write-Host $err -ForegroundColor Red
    try {
        Add-Content -Path $LogFile -Value ("{0}`t[ERROR] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $err) -Encoding UTF8
    } catch {}
    throw
} finally {
    $Global:KisaLogFile = $null
}
