# 메시지·로그 작성 가이드

`iteasy_tuning` 스크립트에서 사용하는 안내 문구와 로그 출력 방식을 통일하기 위한 지침입니다.  
r8, r9 공통으로 적용됩니다.

---

## 1. 메시지 톤과 표현

| 상황 | 표현 규칙 | 예시 |
| --- | --- | --- |
| 안내/진행 | 간결한 평서문 | `Apache 설정 계산을 시작합니다.` |
| 입력 요청 | 괄호로 선택지 명시 | `설정을 적용하시겠습니까? (A: 전체, S: 선택, N: 취소)` |
| 경고 | `경고:` 접두사 + 원인 설명 | `경고: MySQL 서비스가 실행 중이 아닙니다.` |
| 오류 | `오류:` 접두사 + 조치 안내 | `오류: 로그 디렉터리를 생성할 수 없습니다. (경로: /var/log/iteasy_tuning)` |
| 완료 | 결과 요약 + 로그 위치 | `모든 작업이 완료되었습니다. 로그는 logs/runtime/tuning_status.log에서 확인하세요.` |

> **표현 원칙**
> - 존댓말과 반말이 섞이지 않도록 하고, 과도한 감탄 표현은 피합니다.  
> - 한글은 UTF-8로 직접 입력하며, 자동화가 필요한 경우에만 `\uXXXX` 표기법을 사용합니다.

---

## 2. 로그 디렉터리 구조

```
logs/
 ├─ runtime/      # 사람이 바로 읽는 진행 로그
 │   └─ tuning_status.log
 ├─ debug/        # JSON 한 줄 로그 (상세 진단용)
 │   └─ pipeline-debug.log
 └─ artifacts/    # 스크립트가 남기는 참조 데이터
     ├─ service_paths.log
     ├─ system_specs.log
     ├─ service_versions.log
     └─ tuning_context.log
```

### 2.1 runtime 로그
```
=== [튜닝 파이프라인 시작] ===
시간 = 2025-10-30 11:24:02
결과 = 진행 중
```
- `log_section_start`, `log_section_end`로 구간을 표시합니다.  
- 사람이 직접 확인할 때를 고려해 문장을 자연어로 작성합니다.

### 2.2 debug 로그
```
{"ts":"2025-10-30T11:24:05+0900","level":"INFO","module":"calculate_mpm","msg":"Apache 설정을 생성했습니다","detail":{"mpm":"event","output":"/usr/local/src/iteasy_tuning/tmp_conf/apache_tuning.conf"}}
```
- `log_info`, `log_warn`, `log_error`는 JSON 형식의 한 줄 로그를 남깁니다.  
- `detail` 값은 `json_kv`, `json_two` 헬퍼를 활용해 key-value 구조로 작성합니다.

### 2.3 artifacts 로그
- 서비스 감지 결과나 시스템 정보처럼 재활용 가능한 데이터를 Key=Value 형식으로 저장합니다.  
- 예시:
  ```
  APACHE_RUNNING=1
  APACHE_CONFIG=/etc/httpd/conf/httpd.conf
  ```

---

## 3. 공통 헬퍼 요약

| 함수 | 설명 | 로그 위치 |
| --- | --- | --- |
| `log_section_start "제목"` | runtime 로그에 섹션 시작 기록 | `logs/runtime/tuning_status.log` |
| `log_section_end "결과"` | runtime 로그에 섹션 종료 기록 | `logs/runtime/tuning_status.log` |
| `log_info "메시지" "모듈" [세부]` | 정보 레벨 JSON 로그 | `logs/debug/pipeline-debug.log` |
| `log_warn "메시지" "모듈" [세부]` | 경고 레벨 JSON 로그 | `logs/debug/pipeline-debug.log` |
| `log_error "메시지" "모듈" [세부]` | 오류 레벨 JSON 로그 | `logs/debug/pipeline-debug.log` |
| `runtime_log "문장"` | runtime 로그에 임의 문장 추가 | `logs/runtime/tuning_status.log` |
| `tty_echo "문장"` | TTY에 사용자 안내 출력 | 사용자 화면 |

세부 정보는 `scripts/common.sh`에 정의된 `json_kv`, `json_two` 헬퍼를 사용해 일관되게 작성합니다.

---

## 4. 메시지 작성 체크리스트

1. **문맥 파악**  
   - 작업 시작/종료에 `log_section_start`·`log_section_end`가 있는지 확인합니다.  
   - 사용자에게 보여야 하는 문구는 `tty_echo`, 내부 기록은 `log_*`로 구분합니다.

2. **한국어 표현 통일**  
   - 명령형은 `~하세요`, 설명은 평서문으로 작성합니다.  
   - 불필요한 슬래시(`/`)나 영문 혼용을 줄이고 한글로 명확히 표기합니다.

3. **세부 정보 포함**  
   - 오류/경고에는 대상 경로·서비스명을 `json_kv` 등으로 첨부합니다.  
   - 추가 조치가 필요한 경우 `hint`, `file`, `service` 등 키로 안내합니다.

4. **인코딩 유지**  
   - 모든 파일은 UTF-8(BOM 없음)과 LF 줄바꿈을 사용합니다.  
   - 외부 도구 사용 시에도 동일한 인코딩을 유지하고, 저장 전 diff로 내용을 다시 확인합니다.

---

## 5. 적용 순서 제안

1. `rg 'log_'` 등을 이용해 기존 스크립트에서 로그/메시지 호출 지점을 점검합니다.  
2. 본 가이드에 맞지 않는 표현을 수정하고, 누락된 구간에는 `log_*` 호출을 추가합니다.  
3. 실제 실행을 통해 `logs/runtime`, `logs/debug`, `logs/artifacts`에 결과가 올바르게 쌓이는지 확인합니다.  
4. 문구가 변경되면 `docs/` 아래 문서와 릴리스 노트를 함께 업데이트합니다.  
5. 새 메시지가 추가될 경우, 다른 버전(r8 등)에도 동일한 표현을 적용해 일관성을 유지합니다.

위 지침을 따르면 CLI 출력과 로그 파일이 자연스럽게 정리되어 추후 운영 및 문제 파악이 훨씬 수월해집니다.
