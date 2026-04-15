# Changelog

## 2026-03-31
### Added
- `README.md` 추가
- `modules/` 디렉터리 기반 모듈 구조 문서화
- 항목/섹션 단위 커스터마이징 가이드 문서화

### Changed
- `hardening.ps1`를 오케스트레이터 역할로 단순화
- 하드닝 로직을 `modules/*.ps1`로 분리
  - `Common.ps1`
  - `Account.ps1`
  - `Service.ps1`
  - `Log.ps1`
  - `Security.ps1`
  - `Extra.ps1`
  - `Safety.ps1`
- 각 하드닝 항목에 "내용"/"적용 시" 주석 설명 추가
- ICMPv4 허용 로직을 외부 포함 Inbound Echo 규칙(`KISA-Allow-External-ICMPv4-In`) 기준으로 변경
- RDP 활성화 보강 항목(`X-03A`) 추가: `fDenyTSConnections=0`, `TermService` 자동 시작/기동, RDP 방화벽 그룹 활성화
- `run.bat` 재부팅 동작 변경: 사용자 선택 프롬프트 제거, 완료 후 10초 자동 재부팅으로 변경
- 로그 기능 추가: 실행 경로 하위 `logs` 디렉터리 생성, `hardening_YYYYMMDD_HHMMSS.log` 파일에 배치/PowerShell 실행 로그 기록
- 로그 인코딩 개선:
  - `run.bat`에서 `hardening.ps1` stdout/stderr 직접 리다이렉션 제거
  - `modules/Common.ps1`의 `Write-Info/OK/Warn/Err`가 UTF-8 로그 파일에 직접 기록
  - `hardening.ps1` Transcript 의존 제거 및 치명적 오류 로그 추가
- Windows Server 2025 호환성 보강:
  - `W-64`에서 NetSecurity cmdlet 실행 시 간헐적으로 발생하는 `ERROR_NONE_MAPPED(1332)` 대응
  - `Set-NetFirewallProfile`/`New-NetFirewallRule` 실패 시 `netsh advfirewall` fallback으로 동일 정책 적용
  - OS 분기 적용:
    - Windows Server 2025: `netsh advfirewall` 경로를 기본 적용(안정성 우선)
    - Windows Server 2016/2019/2022: 기존 `NetSecurity` 경로 유지 + 실패 시에만 fallback
  - 2025 감지 로직 강화:
    - `Win32_OperatingSystem.Caption` + `HKLM\...\CurrentVersion\ProductName/CurrentBuildNumber` 동시 판별
    - Server + Build 26000 이상도 2025 경로로 인식

### Notes
- 동작 의도(출고 전 보안 베이스라인 적용)는 유지
- 적용 대상/운영 정책에 따라 `SkipItems`, `SectionEnabled`로 선택 적용 권장
