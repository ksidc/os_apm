# KISA 2026 Windows Server Hardening

Windows Server(2016/2019/2022/2025) 출고 전 기본 보안 설정을 자동 적용하는 스크립트 모음입니다.

## 목적
- 신규/재설치 서버에 보안 베이스라인을 빠르게 적용
- 적용 전 백업 자동 수행
- 항목 단위/섹션 단위로 튜닝 가능한 운영형 구조 제공

## 구성 파일
- `run.bat`: 백업 + `hardening.ps1` 실행 + 완료 후 10초 뒤 자동 재부팅
- `hardening.ps1`: 파라미터/모듈 로드/실행 오케스트레이션
- `modules/Common.ps1`: 공통 함수, 항목 실행 래퍼, UTF-8 로그 기록 함수
- `modules/Account.ps1`: 계정 관리 항목
- `modules/Service.ps1`: 서비스/네트워크 서비스 항목
- `modules/Log.ps1`: 감사/이벤트 로그 항목
- `modules/Security.ps1`: 보안 정책/권한/방화벽 항목
- `modules/Extra.ps1`: 운영 편의/추가 튜닝 항목
- `modules/Safety.ps1`: 안전장치 항목

## 실행 방법
1. 관리자 권한으로 CMD 실행
2. 프로젝트 폴더에서 `run.bat` 실행
3. 백업 생성 확인 후 적용 완료 메시지 확인
4. 10초 후 자동 재부팅 진행

## 실행 흐름
1. 로컬 보안 정책 백업
2. 레지스트리(HKLM/HKCU) 백업
3. 감사 정책 백업
4. 사용자/관리자 그룹 정보 백업
5. 방화벽 규칙 백업
6. `hardening.ps1` 실행 (모듈 순서 적용)
7. 완료 후 10초 뒤 자동 재부팅
8. 실행 경로 하위 `logs` 디렉터리에 로그 파일 저장
9. 하드닝 단계 로그는 `Write-*` 함수가 UTF-8로 직접 기록 (한글 깨짐 최소화)

## 커스터마이징 포인트 (`hardening.ps1` 상단)
- `$NewAdminName`: 기본 관리자 계정명 변경값
- `$Lockout`: 잠금 임계값/기간/관찰기간
- `$AccountWhite`: 비활성화 제외 계정 목록
- `$BlockServices`: 중지/비활성화 대상 서비스 목록
- `$RdpPort`: 커스텀 RDP 포트
- `$SkipItems`: 특정 항목 ID 제외 (예: `@('W-18','X-01')`)
- `$SectionEnabled`: 섹션 실행 ON/OFF

예시:
```powershell
$SkipItems = @('W-18', 'X-01')
$SectionEnabled['Extra'] = $false
$RdpPort = 3389
```

## 최근 업데이트 (2026-03-31)
- 스크립트 모듈화: 단일 `hardening.ps1` 구조를 섹션별 파일로 분리
- 항목 설명 강화: 각 항목에 `내용` + `적용 시 영향` 주석 추가
- 운영 튜닝 강화: `SkipItems`, `SectionEnabled` 파라미터 추가
- ICMPv4 개선: 외부 포함 Inbound Echo 허용 규칙(`KISA-Allow-External-ICMPv4-In`) 적용 로직으로 변경
- RDP 보강: `X-03A` 항목 추가(원격 접속 허용 + `TermService` 자동 시작/기동)
- 실행 흐름 변경: 재부팅 확인 프롬프트 제거, 완료 후 10초 자동 재부팅으로 통일
- 로그 보강: 실행 경로 기준 `logs` 디렉터리 생성 및 실행 로그 파일 자동 기록
- 로그 안정화: CMD 리다이렉션 기반 PowerShell 캡처 제거, 모듈 공통 로거(UTF-8)로 한글 깨짐 완화

## 주의 사항
- 계정/그룹/서비스/방화벽 설정을 실제로 변경합니다.
- 운영 정책과 다른 항목은 `SkipItems` 또는 `SectionEnabled`로 제외 후 적용하세요.
- 적용 전 `backup` 폴더 백업 파일 생성 여부를 확인하세요.
