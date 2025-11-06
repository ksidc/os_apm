# 튜닝 프로필 & 점검 가이드

`iteasy_tuning` 스크립트가 생성·적용하는 Apache 및 MySQL(MariaDB) 설정의 기본 원칙과 확인 방법을 정리했습니다.  
r8, r9에서 공통으로 사용합니다.

---

## 1. 서비스 프로필별 메모리 배분

| 프로필 | 구성 | Apache | DB | 비고 |
| --- | --- | --- | --- | --- |
| `web` | Apache 단독 | 70% | 0% | 나머지 30%는 OS/기타용 |
| `web_was` | Apache + WAS | 55% | 0% | WAS JVM이 별도로 메모리를 사용 |
| `web_db` | Apache + DB | 35% | 55% | 10%는 OS/기타용 |
| `web_was_db` | Apache + WAS + DB | 25% | 50% | 세 구성요소를 균형 있게 분배 |
| `was_db` | WAS + DB | 15% | 65% | Apache 없이 WAS/DB 중심 |
| `db` | DB 전용 | 0% | 80% | 나머지는 OS/백업용 |

> Apache 비중이 0%면 `calculate_mpm_config.sh`는 자동으로 건너뜁니다.

---

## 2. Apache 설정 산출 규칙

추천 설정은 `tmp_conf/apache_tuning.conf`로 생성되며 `apply_apache.sh`가 `/etc/httpd/conf.d/zz-iteasy_tuning.conf`에 반영합니다.

### Prefork MPM
- 메모리 60MB당 1 프로세스 기준으로 `MaxRequestWorkers`를 계산하고 50~8000 범위로 제한.  
- `StartServers`, `MinSpareServers`, `MaxSpareServers`는 CPU 코어 수와 경험적 하한/상한으로 보정.  
- `MaxConnectionsPerChild`는 10000 고정.

### Worker/Event MPM
- 메모리 4MB당 1 스레드 기준으로 `MaxRequestWorkers`를 계산하고 300~10000 범위로 제한.  
- `ThreadsPerChild = cores × 4` 값을 16~64 범위로 보정.  
- `ServerLimit = ceil(MaxRequestWorkers / ThreadsPerChild)`.  
- `MinSpareThreads = ThreadsPerChild / 2`, `MaxSpareThreads = MinSpareThreads × 2 (최대 256)`  
- `MaxConnectionsPerChild`는 동일하게 10000.

---

## 3. MySQL/MariaDB 설정 산출 규칙

생성 파일은 `tmp_conf/mysql_tuning.cnf`, 적용 대상은 `/etc/my.cnf.d/zz-iteasy_tuning.cnf`입니다.

### 공통 항목
- `max_connections = clamp(cores × 60, 200, 1200)`  
- `thread_cache_size = clamp(cores × 8, 32, 256)`  
- `table_open_cache = clamp(cores × 200, 800, 4000)`  
- `tmp_table_size`와 `max_heap_table_size`는 기본 64MB, 총 메모리 8GB 이상이면 128MB  
- `wait_timeout = 300`  
- `innodb_log_file_size = clamp(innodb_buffer_pool_size / 4, 256, 2048)` (MB)  
- `innodb_flush_log_at_trx_commit = 2`, `innodb_flush_method = O_DIRECT`, `innodb_file_per_table = 1`

### 엔진별 메모리 배분
- **InnoDB 전용 (`innodb`)**: `innodb_buffer_pool_size = target_memory × 70%`, `key_buffer_size = 64MB`  
- **MyISAM 전용 (`myisam`)**: `innodb_buffer_pool_size = 30%`, `key_buffer_size = 50%`  
- **혼합 (`mixed`)**: `innodb_buffer_pool_size = 60%`, `key_buffer_size = 20%`

버퍼 풀은 최소 256MB, 최대는 전체 메모리에서 256MB를 뺀 값으로 묶으며,  
`innodb_buffer_pool_instances = clamp(innodb_buffer_pool_size / 1024, 1, 8)`로 계산합니다.

---

## 4. 실행 흐름 요약

1. **`main.sh`**  
   - 서비스 프로필과 DB 엔진을 입력받아 환경 변수를 설정합니다.  
   - `log_section_start`로 파이프라인 시작을 기록합니다.
2. **`steps.sh`**  
   - `get_server_specs.sh`, `find_services.sh`, `check_service_versions.sh`를 순차 실행해 `logs/artifacts`에 정보를 저장합니다.  
   - `determine_target_services`가 실제 튜닝 대상 목록을 확정합니다.  
   - `run_calculation_steps`가 Apache/DB 설정 파일을 생성합니다.
3. **`backup.sh`**  
   - 감지된 서비스의 주요 설정 파일을 `backups/`에 보관합니다.
4. **`apply/*.sh`**  
   - 사용자가 선택한 서비스에 대해 추천 설정을 복사하고, 가능하면 서비스 재시작/재적용을 수행합니다.
5. **`verify_tuning.sh` (선택)**  
   - 백업, 추천 설정, 로그 상태를 검사해 `[OK]/[경고]/[오류]` 형태로 보고합니다.
6. **`rollback/rollback.sh` (선택)**  
   - 백업 파일을 지정 경로에 복원하고, 기존 파일은 `.rollback.<timestamp>` 이름으로 보존합니다.

---

## 5. 확인 및 권장 사항

- **로그 확인**:  
  - 진행 상황은 `logs/runtime/tuning_status.log`, 상세 오류는 `logs/debug/pipeline-debug.log`에서 확인합니다.
- **문구 일관성 유지**:  
  - 사용자 안내는 `tty_echo`, 내부 기록은 `log_*` 계열 함수로 구분합니다.
- **테스트 팁**:  
  - `SERVICE_LOG`, `SYSTEM_LOG`에 감지 정보가 올바르게 기록되었는지, `tmp_conf`에 생성된 파일이 기대값을 반영했는지 확인한 뒤 적용을 진행합니다.
- **확장 시 주의**:  
  - 프로필이나 배분 전략을 변경할 때는 `modules/calculate_mpm_config.sh`와 `modules/calculate_mysql_config.sh`의 배분 상수만 조정하면 됩니다.

이 가이드를 토대로 작업하면 설정 생성·적용·검증 과정이 일관되게 유지되어 향후 운영과 문제 분석이 훨씬 수월해집니다.
