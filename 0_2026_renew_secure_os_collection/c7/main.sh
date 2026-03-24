#!/bin/bash

# CentOS 7 보안 강화 메인 스크립트
# 실행: go.sh에서 호출됨

set -u  # undefined 변수 에러 시 중단

# 환경 설정 (고정값)
NTP_SERVER=${NTP_SERVER:-"kr.pool.ntp.org"}
RSYSLOG_SERVER=${RSYSLOG_SERVER:-"1.224.163.4"}
MIN_PASSWORD_LENGTH=${MIN_PASSWORD_LENGTH:-8}
SSH_PORT=${SSH_PORT:-38371}
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
source /usr/local/src/secure_os_collection/c7/common.sh || {
    echo "[ERROR] common.sh 로드 실패" >&2
    log_error "main" "common.sh 로드 실패"
    exit 1
}

# 하위 스크립트 실행
log_info "main 시작"
check_root

log_info "system.sh 실행 시작"
source /usr/local/src/secure_os_collection/c7/system.sh || {
    log_error "main" "system.sh 실행 실패"
    exit 1
}
log_info "system.sh 실행 완료"

while true; do
    echo "방화벽 시스템을 선택하세요:"
    echo "  1) iptables 설정"
    echo "  2) firewalld 설정"
    echo "  3) 방화벽 미사용 (모두 비활성화)"
    read -r -p "선택 (1/2/3): " FIREWALL_CHOICE < /dev/tty
    case "$FIREWALL_CHOICE" in
        1|2|3) break ;;
        *) echo "잘못된 입력입니다. 1, 2, 3 중 하나를 선택해주세요." ;;
    esac
done

if [ "$FIREWALL_CHOICE" -eq 1 ]; then
    log_info "iptables.sh 실행 시작 (iptables 선택)"
    source /usr/local/src/secure_os_collection/c7/iptables.sh || {
        log_error "main" "iptables.sh 실행 실패"
        exit 1
    }
    log_info "iptables.sh 실행 완료"
elif [ "$FIREWALL_CHOICE" -eq 2 ]; then
    log_info "firewalld.sh 실행 시작 (firewalld 선택)"
    source /usr/local/src/secure_os_collection/c7/firewalld.sh || {
        log_error "main" "firewalld.sh 실행 실패"
        exit 1
    }
    log_info "firewalld.sh 실행 완료"
else
    log_info "방화벽 미사용 설정 시작"
    systemctl stop firewalld iptables 2>/dev/null || true
    systemctl disable firewalld iptables 2>/dev/null || true
    systemctl mask firewalld iptables 2>/dev/null || true
    log_info "방화벽 미사용 설정 완료"
fi

log_info "accounts.sh 실행 시작"
source /usr/local/src/secure_os_collection/c7/accounts.sh || {
    log_error "main" "accounts.sh 실행 실패"
    exit 1
}
log_info "accounts.sh 실행 완료"

log_info "services.sh 실행 시작"
source /usr/local/src/secure_os_collection/c7/services.sh || {
    log_error "main" "services.sh 실행 실패"
    exit 1
}
log_info "services.sh 실행 완료"

# 패키지 업데이트
log_info "yum update 시작"
yum -y update || {
    log_error "main" "yum update 실패"
    exit 1
}
log_info "yum update 완료"
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
SUMMARY+="방화벽 설정: 적용됨\n"
SUMMARY+="SELinux 비활성화: 적용됨\n"
SUMMARY+="sysctl/limits 튜닝: 적용됨\n"
SUMMARY+="서비스 비활성화: 적용됨 (대상: ${SERVICES_DISABLED:-없음})\n"

# 요약 출력 및 저장
echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"
echo -e "$SUMMARY" > "$RESULT_FILE"
log_info "결과 요약 저장: $RESULT_FILE"

# 리부팅 확인
log_info "모든 작업 완료. 정리 및 재부팅 대기."

echo ""
echo "============================================================================"
echo " [경고] 'Y' 선택 시 설치 파일(/usr/local/src/secure_os_collection)과"
echo "        로그 파일이 모두 삭제되며, 즉시 시스템이 재부팅됩니다."
echo "============================================================================"

while true; do
    read -r -p "설치 파일을 삭제하고 시스템을 재부팅하시겠습니까? (Y/N): " confirm_finish < /dev/tty
    
    case "$confirm_finish" in
        [Yy]*)
            log_info "사용자 요청에 의한 파일 삭제 및 재부팅 시작"
            echo "  → 설치 파일 및 로그 삭제 중..."
            
            # 디렉토리 변수 (하드코딩 방지용 로컬 선언)
            SCRIPT_DIR="/usr/local/src/secure_os_collection"
            ZIP_FILE="/usr/local/src/secure_os_collection.zip"
            
            # 1. zip 파일 및 스크립트 디렉토리 삭제
            [ -d "$SCRIPT_DIR" ] && rm -rf "$SCRIPT_DIR"
            [ -f "$ZIP_FILE" ] && rm -f "$ZIP_FILE"
            
            # 2. 임시 파일 정리
            rm -f /tmp/script_* /tmp/*.tmp 2>/dev/null || true
            
            echo "  → 시스템을 재부팅합니다..."
            sleep 1
            # 파일이 삭제되었어도 셸 메모리에 로드된 명령은 실행됨
            init 6
            break
            ;;
        [Nn]*)
            log_info "사용자 요청에 의해 정리 및 재부팅 취소됨."
            echo "  → 파일 삭제 및 재부팅을 취소했습니다."
            echo "  → 로그 및 스크립트가 유지됩니다."
            exit 0
            ;;
        *)
            echo "잘못된 입력입니다. 'Y' 또는 'N'을 입력해주세요."
            ;;
    esac
done
