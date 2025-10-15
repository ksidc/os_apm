#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 최소 공통 유틸만 사용 (로그/백업 없음)
source "$SCRIPT_DIR/common.sh"

check_root

# 모듈 실행 (iptables 미사용)
source "$SCRIPT_DIR/system.sh"
source "$SCRIPT_DIR/accounts.sh"
source "$SCRIPT_DIR/services.sh"

# 완료 즉시 재부팅 (질문 없음)
systemctl reboot