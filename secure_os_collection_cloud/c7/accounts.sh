#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# [제거됨]
# - root 원격접속 차단(PermitRootLogin no) 미적용
# - SSH 포트 변경/검증 전체 제거
# - 패스워드 만료 정책(chage, login.defs) 제거
# - 계정 잠금 임계값(PAM tally/FAILLock) 제거
# - /etc/pwquality.conf 유지 여부는 '현상 유지' 원칙으로 미변경(생성/수정 안 함)

remove_unneeded_users() {
  # 존재 시만 제거 (현상 유지)
  local users=(lp games sync shutdown halt)
  for u in "${users[@]}"; do
    id "$u" >/dev/null 2>&1 && userdel -r "$u" || true
  done
}

# root 비밀번호 변경(옵션) — 사용자 입력 없애고 '미수행'
# 필요 시 별도 명령으로 진행하도록 본 모듈에서는 수행하지 않음.

# 관리자 대체 계정 생성 절차는 사용자 입력이 필요하므로 본 모듈에서는 미수행.
# (현상 유지: 자동 생성/권한변경/SSH 설정 변경 없음)

# 실행
remove_unneeded_users