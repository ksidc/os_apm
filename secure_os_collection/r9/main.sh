#!/bin/bash

# Rocky Linux 9 보안 강화 메인 스크립트
# 실행: go.sh에서 호출됨

set -u  # undefined 변수 에러 시 중단

# 환경 설정 (고정값)
NTP_SERVER=${NTP_SERVER:-"kr.pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
BACKUP_DIR="/usr/local/src/scripts_org"
LOG_DIR="/usr/local/src/secure_os_collection/logs"
LOG_FILE="$LOG_DIR/go_$(date +%Y%m%d_%H%M%S).log"
RESULT_FILE="$LOG_DIR/result_$(date +%Y%m%d_%H%M%S).log"

# 요약 변수 초기화
SUMMARY=""
NEW_SSH_PORT="미변경 (기본 22)"
PASSWORD_POLICY_SUMMARY="미적용"
CREATED_USER="미생성"
DELETED_USERS=""
SERVICES_DISABLED=""
RESTARTED_SERVICES=""

declare -A restarts_needed

# 로그 디렉토리 생성
mkdir -p "$LOG_DIR" && chmod 700 "$LOG_DIR" || { 
    echo "[ERROR] 로그 디렉토리 $LOG_DIR 생성 실패" >&2
    exit 1
}
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] 로그 디렉토리 $LOG_DIR 생성 성공" | tee -a "$LOG_FILE"

# 공통 함수 로드
source /usr/local/src/secure_os_collection/r9/common.sh || { 
    echo "[ERROR] common.sh 로드 실패" >&2
    log_error "main" "common.sh 로드 실패"
    exit 1
}

# 하위 스크립트 실행
log_info "main 시작"
check_root

log_info "system.sh 실행 시작"
source /usr/local/src/secure_os_collection/r9/system.sh || { 
    log_error "main" "system.sh 실행 실패"
    exit 1
}
log_info "system.sh 실행 완료"

 log_info "iptables.sh 실행 시작"
 source /usr/local/src/secure_os_collection/r9/iptables.sh || { 
     log_error "main" "iptables.sh 실행 실패"
     exit 1
 }
 log_info "iptables.sh 실행 완료"

log_info "accounts.sh 실행 시작"
source /usr/local/src/secure_os_collection/r9/accounts.sh || { 
     log_error "main" "accounts.sh 실행 실패"
     exit 1
}
log_info "accounts.sh 실행 완료"

log_info "services.sh 실행 시작"
source /usr/local/src/secure_os_collection/r9/services.sh || { 
    log_error "main" "services.sh 실행 실패"
    exit 1
}
log_info "services.sh 실행 완료"

# 패키지 업데이트
log_info "dnf update 시작"
dnf -y update || { 
    log_error "main" "dnf update 실패"
    exit 1
}
log_info "dnf update 완료"
SUMMARY+="패키지 업데이트: 적용됨\n"

# 서비스 재시작
log_info "서비스 재시작 시작"
for svc in "${!restarts_needed[@]}"; do
    if [ "${restarts_needed[$svc]}" -eq 1 ]; then
        systemctl restart "$svc" && log_info "$svc 재시작 성공" || { 
            log_error "main" "$svc 재시작 실패"
            exit 1
        }
        RESTARTED_SERVICES+="$svc "
    fi
done
log_info "서비스 재시작 완료"
SUMMARY+="서비스 재시작: 적용됨 (대상: ${RESTARTED_SERVICES:-없음})\n"

# 요약 생성
SUMMARY+="NTP 설정: 적용됨 (서버: $NTP_SERVER)\n"
SUMMARY+="불필요 사용자 삭제: 적용됨 (대상: ${DELETED_USERS:-없음})\n"
SUMMARY+="SSH 포트 변경: $NEW_SSH_PORT\n"
SUMMARY+="패스워드 정책: $PASSWORD_POLICY_SUMMARY\n"
SUMMARY+="새 계정 생성: $CREATED_USER\n"
SUMMARY+="방화벽 설정: 적용됨"
SUMMARY+="SELinux 비활성화: 적용됨\n"
SUMMARY+="sysctl/limits 튜닝: 적용됨\n"
SUMMARY+="서비스 비활성화: 적용됨 (대상: ${SERVICES_DISABLED:-없음})\n"
SUMMARY+="백업 위치: $BACKUP_DIR (롤백: bash /usr/local/src/secure_os_collection/r9/rollback.sh 실행)\n"
SUMMARY+="주의: 고객 데이터 보호를 위해 /etc/ 백업 확인 ($BACKUP_DIR). 다운타임 최소화 위해 off-peak 시간 리부팅 권장.\n"

# 요약 출력 및 저장
echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"
echo -e "$SUMMARY" > "$RESULT_FILE"
log_info "결과 요약 저장: $RESULT_FILE"

# 리부팅 확인
log_info "리부팅 확인 시작"
read -r -p "시스템을 지금 리부팅하시겠습니까? (Y/N): " reboot < /dev/tty
if [[ "$reboot" =~ ^[Yy]$ ]]; then
    log_info "사용자 선택: 리부팅"
    systemctl reboot
else
    log_info "사용자 선택: 리부팅 생략"
    echo "설정 적용을 위해 시스템 리부팅을 권장합니다."
fi