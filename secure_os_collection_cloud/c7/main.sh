#!/bin/bash
# c7/main.sh : CentOS 7 보안 강화 메인 (불필요 모듈 호출 제거 + 리부팅 기능 유지)

set -u

# 경로 및 로그 설정
BACKUP_DIR="/usr/local/src/scripts_org"
LOG_DIR="/usr/local/src/secure_os_collection/logs"
mkdir -p "$LOG_DIR" && chmod 700 "$LOG_DIR" || { echo "[ERROR] 로그 디렉토리 생성 실패"; exit 1; }

LOG_FILE="$LOG_DIR/go_$(date +%Y%m%d_%H%M%S).log"
RESULT_FILE="$LOG_DIR/result_$(date +%Y%m%d_%H%M%S).log"

# 요약용 변수
SUMMARY=""
DELETED_USERS=""
SERVICES_DISABLED=""
RESTARTED_SERVICES=""
declare -A restarts_needed

# 공통 함수 로드
source /usr/local/src/secure_os_collection/c7/common.sh
check_root
log_info "main.sh 시작"

# 1. 시스템 설정
log_info "system.sh 실행"
source /usr/local/src/secure_os_collection/c7/system.sh || { log_error "main" "system.sh 실패"; exit 1; }

# 2. 계정 관련 설정
log_info "accounts.sh 실행"
source /usr/local/src/secure_os_collection/c7/accounts.sh || { log_error "main" "accounts.sh 실패"; exit 1; }

# 3. 서비스 설정
log_info "services.sh 실행"
source /usr/local/src/secure_os_collection/c7/services.sh || { log_error "main" "services.sh 실패"; exit 1; }

# 4. 시스템 패키지 업데이트
log_info "yum update 시작"
yum -y update || { log_error "main" "yum update 실패"; exit 1; }
log_info "yum update 완료"
SUMMARY+="패키지 업데이트: 적용됨\n"

# 5. 재시작이 필요한 서비스 처리
for svc in "${!restarts_needed[@]}"; do
    if [ "${restarts_needed[$svc]}" -eq 1 ]; then
        systemctl restart "$svc" && log_info "$svc 재시작" || { log_error "main" "$svc 재시작 실패"; exit 1; }
        RESTARTED_SERVICES+="$svc "
    fi
done
SUMMARY+="서비스 재시작: 적용됨 (대상: ${RESTARTED_SERVICES:-없음})\n"

# 6. 요약 정보 출력
SUMMARY+="불필요 사용자 삭제: 적용됨 (대상: ${DELETED_USERS:-없음})\n"
SUMMARY+="핵심 파일 권한/배너: 적용됨\n"
SUMMARY+="서비스 비활성화: 적용됨 (대상: ${SERVICES_DISABLED:-없음})\n"
SUMMARY+="백업 위치: $BACKUP_DIR\n"

echo -e "\n=== 실행 결과 요약 ===\n$SUMMARY"
echo -e "$SUMMARY" > "$RESULT_FILE"
log_info "결과 요약 저장: $RESULT_FILE"

# 7. ✅ 리부팅 여부 질의
echo ""
echo "====================================================================="
echo " 📌 시스템 재부팅이 필요할 수 있습니다."
echo "     - 패키지 업데이트 및 주요 설정이 적용되었습니다."
echo "     - 즉시 재부팅하지 않으면 일부 설정이 반영되지 않을 수 있습니다."
echo "====================================================================="
read -p "지금 즉시 재부팅하시겠습니까? (y/n): " reboot_choice
case "$reboot_choice" in
    y|Y)
        log_info "사용자 요청에 따라 즉시 재부팅 수행"
        echo "서버를 즉시 재부팅합니다..."
        sleep 2
        reboot
        ;;
    n|N)
        log_info "사용자가 재부팅을 보류함"
        echo "재부팅을 건너뜁니다. 필요 시 수동으로 reboot 명령을 실행하세요."
        ;;
    *)
        echo "잘못된 입력입니다. 재부팅을 건너뜁니다."
        ;;
esac

log_info "main.sh 종료"
exit 0