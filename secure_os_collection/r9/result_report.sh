#!/bin/bash
# result_report.sh : 실행 결과를 Markdown/HTML/PDF 보고서로 생성
# 사용: sudo bash /usr/local/src/secure_os_collection/r9/result_report.sh

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$BASE_DIR/logs"
OUT_TS="$(date +%Y%m%d_%H%M%S)"
REPORT_MD="$LOG_DIR/report_${OUT_TS}.md"
REPORT_HTML="${REPORT_MD%.md}.html"
REPORT_PDF="${REPORT_MD%.md}.pdf"

# 최신 파일 찾기
latest_result="$(ls -1t "$LOG_DIR"/result_*.log 2>/dev/null | head -n1 || true)"
latest_go="$(ls -1t "$LOG_DIR"/go_*.log 2>/dev/null | head -n1 || true)"

hostname="$(hostname)"
os_pretty=""; [[ -f /etc/os-release ]] && . /etc/os-release && os_pretty="${PRETTY_NAME:-$ID $VERSION_ID}"
kernel="$(uname -r 2>/dev/null || echo unknown)"
ip_addrs="$(ip -4 addr show 2>/dev/null | awk '/inet /{print $2}' | paste -sd', ' -)"

# SSH 실제 포트(설정 파일 기준)
ssh_port="$(grep -iE '^[# ]*Port[[:space:]]+[0-9]+' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tail -n1)"
ssh_port="${ssh_port:-22}"

# 안전한 grep
safe_grep() { grep -iE "$1" "$2" 2>/dev/null || true; }

# 결과 요약 파싱(없으면 빈 값)
summary_block=""
if [[ -n "$latest_result" && -f "$latest_result" ]]; then
  summary_block="$(cat "$latest_result")"
fi

# 적용 항목 추출(있을 때만)
applied_ntp="$(safe_grep '^NTP 설정' "$latest_result")"
applied_users="$(safe_grep '^불필요 사용자 삭제' "$latest_result")"
applied_ssh="$(safe_grep '^SSH 포트 변경' "$latest_result")"
applied_pw="$(safe_grep '^패스워드 정책' "$latest_result")"
applied_selinux="$(safe_grep '^SELinux' "$latest_result")"
applied_sysctl="$(safe_grep '^sysctl/limits' "$latest_result")"
applied_services="$(safe_grep '^서비스 비활성화' "$latest_result")"
applied_backup="$(safe_grep '^백업 위치' "$latest_result")"

# 개선 효과 서술(템플릿)
read -r -d '' IMPACT <<'EOF' || true
- **공격 표면 축소**: 불필요 서비스 비활성화 및 방화벽 기본정책 적용으로 외부 노출 감소
- **계정 탈취 위험 완화**: root 원격 로그인 차단, pwquality/lockout 적용
- **구성 무결성 유지**: 핵심 설정 변경 전 백업 및 표준 롤백 경로 제공
- **운영 가시성 향상**: rsyslog 원격 전송, 히스토리 타임스템프, motd 고지
- **성능·안정성 기본치 확보**: 합리적 sysctl/limits 기본 프로파일
EOF

# Markdown 본문 생성
{
  echo "# 보안 강화 결과 리포트"
  echo ""
  echo "- **생성 시각**: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- **대상 호스트**: $hostname"
  echo "- **운영체제**: ${os_pretty:-unknown}"
  echo "- **커널**: $kernel"
  echo "- **IP(v4)**: ${ip_addrs:-N/A}"
  echo "- **SSH 포트**: $ssh_port"
  echo ""
  echo "## 1. 실행 요약(Summary)"
  if [[ -n "$summary_block" ]]; then
    echo '```'
    echo "$summary_block"
    echo '```'
  else
    echo "- (참고할 result_*.log가 없어 기본 정보만 표기합니다.)"
  fi
  echo ""
  echo "## 2. 적용 항목(What was applied)"
  [[ -n "$applied_ntp"      ]] && echo "- $applied_ntp"
  [[ -n "$applied_users"    ]] && echo "- $applied_users"
  [[ -n "$applied_ssh"      ]] && echo "- $applied_ssh"
  [[ -n "$applied_pw"       ]] && echo "- $applied_pw"
  [[ -n "$applied_selinux"  ]] && echo "- $applied_selinux"
  [[ -n "$applied_sysctl"   ]] && echo "- $applied_sysctl"
  [[ -n "$applied_services" ]] && echo "- $applied_services"
  [[ -n "$applied_backup"   ]] && echo "- $applied_backup"
  echo ""
  echo "## 3. 보완 효과(So-What / Improvement)"
  echo "$IMPACT"
  echo ""
  echo "## 4. 참고 로그(최근 실행 로그 경로)"
  echo "- result: ${latest_result:-없음}"
  echo "- go: ${latest_go:-없음}"
  echo ""
  echo "## 5. 롤백 및 백업"
  echo "- 백업 경로: \`/usr/local/src/scripts_org\`"
  echo "- 롤백 명령: \`sudo bash /usr/local/src/secure_os_collection/r9/rollback.sh\`"
  echo ""
  echo "## 6. 부록(Appendix)"
  echo "- 본 보고서는 하드닝 스크립트 결과를 자동 요약하여 생성되었습니다."
} > "$REPORT_MD"

echo "[INFO] Markdown 보고서 생성: $REPORT_MD"

# 변환: HTML/PDF (선택적)
if command -v pandoc >/dev/null 2>&1; then
  pandoc "$REPORT_MD" -o "$REPORT_HTML"
  echo "[INFO] HTML 생성: $REPORT_HTML"
  if command -v wkhtmltopdf >/dev/null 2>&1; then
    pandoc "$REPORT_MD" -o "$REPORT_PDF" --pdf-engine=wkhtmltopdf
    echo "[INFO] PDF 생성: $REPORT_PDF"
  else
    echo "[WARN] wkhtmltopdf 미탑재 → PDF 생략(HTML/MD 제공)"
  fi
else
  echo "[WARN] pandoc 미탑재 → MD만 제공"
fi