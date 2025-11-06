#!/bin/bash

# ui.sh
# 사용자 입력과 선택을 처리합니다.

tty_echo() {
    local message="$1"
    if [ -t 1 ]; then
        printf "%s\n" "$message"
    fi
    if [ ! -t 1 ] && [ -w /dev/tty ]; then
        printf "%s\n" "$message" > /dev/tty
    fi
}

tty_read_line() {
    local prompt="${1:-}"
    local input=""

    if [ -t 0 ]; then
        [ -n "$prompt" ] && printf "%s" "$prompt"
        if ! read -r input; then
            input=""
        fi
    elif [ -r /dev/tty ]; then
        [ -n "$prompt" ] && printf "%s" "$prompt" > /dev/tty
        if ! read -r input < /dev/tty; then
            input=""
        fi
    else
        echo "[경고] 입력 TTY를 찾을 수 없습니다." >&2
        exit 1
    fi

    printf '%s\n' "$input"
}

normalize_choice() {
    local value="$1"
    value="${value//$'\r'/}"
    value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$value" ]]; then
        echo ""
        return
    fi
    if [[ $value == $'\e['* ]]; then
        echo ""
        return
    fi
    value=$(printf '%s' "$value" | sed 's/^[^[:alnum:]]*//')
    value=$(printf '%s' "$value" | tr 'A-Z' 'a-z')
    if [[ $value =~ ^([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi
    value=${value%%\)*}
    value=$(printf '%s' "$value" | sed 's/[[:space:]].*$//')
    echo "$value"
}

prompt_service_profile() {
    local selection=""
    while true; do
        tty_echo ""
        tty_echo "필요한 서비스 구성을 선택하세요."
        tty_echo "  1) web          - Apache 단독"
        tty_echo "  2) web_was      - Apache + WAS"
        tty_echo "  3) web_db       - Apache + DB"
        tty_echo "  4) web_was_db   - Apache + WAS + DB"
        tty_echo "  5) was_db       - WAS + DB"
        tty_echo "  6) db           - DB 전용"
        tty_echo "  c) 취소"
        local raw_input
        raw_input=$(tty_read_line "> ")
        selection=$(normalize_choice "$raw_input")
        log_info "서비스 프로필 입력" "ui" "$(json_two raw "$raw_input" normalized "$selection")"
        case "$selection" in
            web_was_db*|4*) echo "web_was_db"; return 0 ;;
            web_db*|3*) echo "web_db"; return 0 ;;
            web_was*|2*) echo "web_was"; return 0 ;;
            was_db*|5*) echo "was_db"; return 0 ;;
            db*|6*) echo "db"; return 0 ;;
            web*|1*) echo "web"; return 0 ;;
            c*|cancel*|q*|quit*|exit*|"")
                echo ""
                return 0
                ;;
            *) tty_echo "잘못 입력하셨습니다. 다시 선택해 주세요." ;;
        esac
    done
}

prompt_db_engine() {
    local selection=""
    while true; do
        tty_echo ""
        tty_echo "사용할 데이터베이스 엔진을 선택하세요."
        tty_echo "  1) innodb"
        tty_echo "  2) myisam"
        tty_echo "  3) mixed (innodb + myisam)"
        tty_echo "  c) 취소"
        local raw_input
        raw_input=$(tty_read_line "> ")
        selection=$(normalize_choice "$raw_input")
        log_info "DB 엔진 입력" "ui" "$(json_two raw "$raw_input" normalized "$selection")"
        case "$selection" in
            mixed*|3*) echo "mixed"; return 0 ;;
            myisam*|2*) echo "myisam"; return 0 ;;
            innodb*|1*) echo "innodb"; return 0 ;;
            c*|cancel*|q*|quit*|exit*|"") echo "none"; return 0 ;;
            *) tty_echo "잘못 입력하셨습니다. 다시 선택해 주세요." ;;
        esac
    done
}
