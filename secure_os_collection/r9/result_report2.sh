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
공격 표면 축소: 불필요 서비스 비활성화 및 방화벽 기본정책 적용으로 외부 노출 감소
계정 탈취 위험 완화: root 원격 로그인 차단, pwquality/lockout 적용
구성 무결성 유지: 핵심 설정 변경 전 백업 및 표준 롤백 경로 제공
운영 가시성 향상: rsyslog 원격 전송, 히스토리 타임스템프, motd 고지
성능·안정성 기본치 확보: 합리적 sysctl/limits 기본 프로파일
EOF

# HTML 템플릿 함수
generate_html() {
  cat << 'HTML_TEMPLATE'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>보안 강화 결과 리포트</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #2c3e50 0%, #34495e 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            font-weight: 300;
        }
        
        .header .subtitle {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .content {
            padding: 40px;
        }
        
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .info-card {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 25px;
            border-left: 5px solid #667eea;
        }
        
        .info-card h3 {
            color: #2c3e50;
            margin-bottom: 15px;
            font-size: 1.2em;
        }
        
        .info-item {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            padding: 8px 0;
            border-bottom: 1px solid #e9ecef;
        }
        
        .info-item:last-child {
            border-bottom: none;
        }
        
        .info-label {
            font-weight: 600;
            color: #6c757d;
        }
        
        .info-value {
            color: #2c3e50;
            font-family: 'Courier New', monospace;
        }
        
        .section {
            margin-bottom: 40px;
        }
        
        .section-title {
            font-size: 1.8em;
            color: #2c3e50;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
        }
        
        .summary-box {
            background: #f1f3f4;
            border-radius: 10px;
            padding: 25px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            line-height: 1.5;
            white-space: pre-wrap;
            border-left: 4px solid #28a745;
        }
        
        .applied-items {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
        }
        
        .applied-item {
            background: linear-gradient(135deg, #e8f5e8 0%, #f0f8f0 100%);
            border-radius: 10px;
            padding: 15px;
            border-left: 4px solid #28a745;
            transition: transform 0.3s ease;
        }
        
        .applied-item:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        
        .applied-item::before {
            content: "✓";
            color: #28a745;
            font-weight: bold;
            margin-right: 10px;
        }
        
        .impact-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        
        .impact-item {
            background: linear-gradient(135deg, #fff3cd 0%, #fefefe 100%);
            border-radius: 10px;
            padding: 20px;
            border-left: 4px solid #ffc107;
        }
        
        .impact-item::before {
            content: "🛡️";
            margin-right: 10px;
        }
        
        .log-section {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 25px;
        }
        
        .log-item {
            background: white;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 10px;
            border-left: 4px solid #6c757d;
        }
        
        .log-item:last-child {
            margin-bottom: 0;
        }
        
        .backup-section {
            background: linear-gradient(135deg, #e3f2fd 0%, #f5f5f5 100%);
            border-radius: 10px;
            padding: 25px;
            border-left: 4px solid #2196f3;
        }
        
        .backup-command {
            background: #263238;
            color: #00e676;
            padding: 15px;
            border-radius: 8px;
            font-family: 'Courier New', monospace;
            margin: 10px 0;
        }
        
        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #6c757d;
            border-top: 1px solid #e9ecef;
        }
        
        .status-badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
            background: #28a745;
            color: white;
        }
        
        @media (max-width: 768px) {
            .container {
                margin: 10px;
                border-radius: 10px;
            }
            
            .header {
                padding: 20px;
            }
            
            .header h1 {
                font-size: 2em;
            }
            
            .content {
                padding: 20px;
            }
            
            .info-grid {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 보안 강화 결과 리포트</h1>
            <div class="subtitle">Security Hardening Report</div>
            <div class="status-badge">완료</div>
        </div>
        
        <div class="content">
            <!-- 시스템 정보 -->
            <div class="info-grid">
                <div class="info-card">
                    <h3>📊 시스템 정보</h3>
                    <div class="info-item">
                        <span class="info-label">생성 시각:</span>
                        <span class="info-value">REPORT_TIME</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">호스트명:</span>
                        <span class="info-value">HOST_NAME</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">운영체제:</span>
                        <span class="info-value">OS_INFO</span>
                    </div>
                </div>
                
                <div class="info-card">
                    <h3>🌐 네트워크 정보</h3>
                    <div class="info-item">
                        <span class="info-label">커널:</span>
                        <span class="info-value">KERNEL_INFO</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">IP 주소:</span>
                        <span class="info-value">IP_ADDRESSES</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">SSH 포트:</span>
                        <span class="info-value">SSH_PORT</span>
                    </div>
                </div>
            </div>
            
            <!-- 실행 요약 -->
            <div class="section">
                <h2 class="section-title">📋 실행 요약</h2>
                <div class="summary-box">SUMMARY_CONTENT</div>
            </div>
            
            <!-- 적용 항목 -->
            <div class="section">
                <h2 class="section-title">✅ 적용 항목</h2>
                <div class="applied-items">
                    APPLIED_ITEMS_CONTENT
                </div>
            </div>
            
            <!-- 보완 효과 -->
            <div class="section">
                <h2 class="section-title">🛡️ 보완 효과</h2>
                <div class="impact-list">
                    IMPACT_CONTENT
                </div>
            </div>
            
            <!-- 참고 로그 -->
            <div class="section">
                <h2 class="section-title">📁 참고 로그</h2>
                <div class="log-section">
                    <div class="log-item">
                        <strong>Result Log:</strong> <code>RESULT_LOG_PATH</code>
                    </div>
                    <div class="log-item">
                        <strong>Execution Log:</strong> <code>GO_LOG_PATH</code>
                    </div>
                </div>
            </div>
            
            <!-- 롤백 및 백업 -->
            <div class="section">
                <h2 class="section-title">🔄 롤백 및 백업</h2>
                <div class="backup-section">
                    <p><strong>백업 경로:</strong></p>
                    <div class="backup-command">/usr/local/src/scripts_org</div>
                    
                    <p><strong>롤백 명령:</strong></p>
                    <div class="backup-command">sudo bash /usr/local/src/secure_os_collection/r9/rollback.sh</div>
                </div>
            </div>
        </div>
        
        <div class="footer">
            <p>본 보고서는 하드닝 스크립트 결과를 자동 요약하여 생성되었습니다.</p>
        </div>
    </div>
</body>
</html>
HTML_TEMPLATE
}

# Markdown 본문 생성 (기존 유지)
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
  echo "- 본 보고서는 보안 스크립트 결과를 자동 요약하여 생성되었습니다."
} > "$REPORT_MD"

echo "[INFO] Markdown 보고서 생성: $REPORT_MD"

# 향상된 HTML 생성
html_content="$(generate_html)"

# 데이터 치환
html_content="${html_content//REPORT_TIME/$(date '+%Y-%m-%d %H:%M:%S')}"
html_content="${html_content//HOST_NAME/$hostname}"
html_content="${html_content//OS_INFO/${os_pretty:-unknown}}"
html_content="${html_content//KERNEL_INFO/$kernel}"
html_content="${html_content//IP_ADDRESSES/${ip_addrs:-N/A}}"
html_content="${html_content//SSH_PORT/$ssh_port}"

# 요약 내용 치환
if [[ -n "$summary_block" ]]; then
  # HTML 특수문자 이스케이프
  escaped_summary="$(echo "$summary_block" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
  html_content="${html_content//SUMMARY_CONTENT/$escaped_summary}"
else
  html_content="${html_content//SUMMARY_CONTENT/(참고할 result_*.log가 없어 기본 정보만 표기합니다.)}"
fi

# 적용 항목 HTML 생성
applied_html=""
[[ -n "$applied_ntp"      ]] && applied_html+="<div class=\"applied-item\">$applied_ntp</div>"
[[ -n "$applied_users"    ]] && applied_html+="<div class=\"applied-item\">$applied_users</div>"
[[ -n "$applied_ssh"      ]] && applied_html+="<div class=\"applied-item\">$applied_ssh</div>"
[[ -n "$applied_pw"       ]] && applied_html+="<div class=\"applied-item\">$applied_pw</div>"
[[ -n "$applied_selinux"  ]] && applied_html+="<div class=\"applied-item\">$applied_selinux</div>"
[[ -n "$applied_sysctl"   ]] && applied_html+="<div class=\"applied-item\">$applied_sysctl</div>"
[[ -n "$applied_services" ]] && applied_html+="<div class=\"applied-item\">$applied_services</div>"
[[ -n "$applied_backup"   ]] && applied_html+="<div class=\"applied-item\">$applied_backup</div>"

[[ -z "$applied_html" ]] && applied_html="<div class=\"applied-item\">적용된 항목이 없습니다.</div>"
html_content="${html_content//APPLIED_ITEMS_CONTENT/$applied_html}"

# 개선 효과 HTML 생성
impact_html=""
while IFS= read -r line; do
  [[ -n "$line" ]] && impact_html+="<div class=\"impact-item\">$line</div>"
done <<< "$IMPACT"
html_content="${html_content//IMPACT_CONTENT/$impact_html}"

# 로그 경로 치환
html_content="${html_content//RESULT_LOG_PATH/${latest_result:-없음}}"
html_content="${html_content//GO_LOG_PATH/${latest_go:-없음}}"

# HTML 파일 저장
echo "$html_content" > "$REPORT_HTML"
echo "[INFO] 향상된 HTML 보고서 생성: $REPORT_HTML"

# PDF 생성 (선택적)
if command -v wkhtmltopdf >/dev/null 2>&1; then
  wkhtmltopdf --page-size A4 --margin-top 0.75in --margin-right 0.75in --margin-bottom 0.75in --margin-left 0.75in "$REPORT_HTML" "$REPORT_PDF"
  echo "[INFO] PDF 생성: $REPORT_PDF"
else
  echo "[WARN] wkhtmltopdf 미탑재 → PDF 생략(HTML/MD 제공)"
fi