#!/bin/bash

source /usr/local/src/secure_os_collection/c6/common.sh

# 설치 기본 계정 중 로그인이나 서비스 운영에 사용하지 않는 계정을 삭제한다.
remove_unneeded_users() {
    local user_name
    for user_name in lp games ftp sync shutdown halt; do
        if id "$user_name" >/dev/null 2>&1; then
            userdel "$user_name" || {
                echo "ERROR: 불필요 계정 삭제 실패: $user_name" >&2
                return 1
            }
            DELETED_USERS="${DELETED_USERS}${user_name} "
        fi
    done
}

# root 비밀번호를 두 번 입력받아 최소 길이와 일치 여부를 확인한 후 변경한다.
change_root_password() {
    local password password_confirm
    while true; do
        read -r -s -p "root 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " password < /dev/tty
        echo
        [ "${#password}" -ge "$MIN_PASSWORD_LENGTH" ] || {
            echo "최소 ${MIN_PASSWORD_LENGTH}자 이상 입력해야 합니다."
            continue
        }
        read -r -s -p "비밀번호 확인: " password_confirm < /dev/tty
        echo
        [ "$password" = "$password_confirm" ] || {
            echo "비밀번호가 일치하지 않습니다."
            continue
        }
        break
    done

    printf 'root:%s\n' "$password" | chpasswd || {
        echo "ERROR: root 비밀번호 변경 실패" >&2
        return 1
    }
    passwd -S root >/dev/null 2>&1 || return 1
}

# 숫자 정책값을 입력받고 잘못된 값이면 다시 입력하게 한다.
read_policy_number() {
    local prompt="$1" default_value="$2" value
    while true; do
        read -r -p "$prompt (기본값: $default_value): " value < /dev/tty
        value="${value:-$default_value}"
        if echo "$value" | grep -Eq '^[0-9]+$'; then
            echo "$value"
            return 0
        fi
        echo "0 이상의 숫자를 입력하세요." >&2
    done
}

# 기존 관리자 계정의 비밀번호가 잠겨 있거나 없으면 새 비밀번호를 설정한다.
ensure_account_password() {
    local user_name="$1" status password password_confirm
    status="$(passwd -S "$user_name" 2>/dev/null | awk '{print $2}')"
    case "$status" in
        P|PS) return 0 ;;
    esac

    echo "계정 '$user_name'의 사용 가능한 비밀번호가 없어 새로 설정합니다."
    while true; do
        read -r -s -p "계정 '$user_name' 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " password < /dev/tty
        echo
        [ "${#password}" -ge "$MIN_PASSWORD_LENGTH" ] || {
            echo "최소 ${MIN_PASSWORD_LENGTH}자 이상 입력해야 합니다."
            continue
        }
        read -r -s -p "비밀번호 확인: " password_confirm < /dev/tty
        echo
        [ "$password" = "$password_confirm" ] || {
            echo "비밀번호가 일치하지 않습니다."
            continue
        }
        break
    done
    printf '%s:%s\n' "$user_name" "$password" | chpasswd || {
        echo "ERROR: 계정 비밀번호 설정 실패: $user_name" >&2
        return 1
    }
}

# 선택 시 login.defs와 현재 일반 계정에 동일한 비밀번호 만료 정책을 적용한다.
configure_password_expiration() {
    local max_days min_len min_days warn_days uid_min user_name
    if ! prompt_yes_no "패스워드 만료 정책을 설정하시겠습니까?"; then
        PASSWORD_POLICY_SUMMARY="not applied"
        return 0
    fi

    max_days="$(read_policy_number '최대 사용일수' 90)"
    min_len="$(read_policy_number '최소 길이' 8)"
    min_days="$(read_policy_number '최소 사용일수' 0)"
    warn_days="$(read_policy_number '경고일수' 7)"
    [ "$min_len" -ge "$MIN_PASSWORD_LENGTH" ] || min_len="$MIN_PASSWORD_LENGTH"
    MIN_PASSWORD_LENGTH="$min_len"
    PASSWORD_MIN_LENGTH="$min_len"

    sed -i '/^[[:space:]]*PASS_MAX_DAYS[[:space:]]/d; /^[[:space:]]*PASS_MIN_LEN[[:space:]]/d; /^[[:space:]]*PASS_MIN_DAYS[[:space:]]/d; /^[[:space:]]*PASS_WARN_AGE[[:space:]]/d' /etc/login.defs || return 1
    cat >> /etc/login.defs <<EOF || return 1
PASS_MAX_DAYS   $max_days
PASS_MIN_LEN    $min_len
PASS_MIN_DAYS   $min_days
PASS_WARN_AGE   $warn_days
EOF

    uid_min="$(awk '/^[[:space:]]*UID_MIN[[:space:]]+/ {print $2; exit}' /etc/login.defs)"
    uid_min="${uid_min:-500}"
    for user_name in $(awk -F: -v min="$uid_min" '$3 >= min && $3 < 60000 {print $1}' /etc/passwd); do
        chage -M "$max_days" -m "$min_days" -W "$warn_days" "$user_name" || return 1
    done
    PASSWORD_POLICY_SUMMARY="applied(max=$max_days min_len=$min_len min_days=$min_days warn=$warn_days)"
}

# 기존 일반 계정을 사용하거나 확인된 이름으로 wheel 운영 계정을 새로 생성한다.
prepare_admin_account() {
    local uid_min existing_users user_name password password_confirm create_user=1
    configure_wheel_sudo || return 1

    uid_min="$(awk '/^[[:space:]]*UID_MIN[[:space:]]+/ {print $2; exit}' /etc/login.defs)"
    uid_min="${uid_min:-500}"
    existing_users="$(awk -F: -v min="$uid_min" '$3 >= min && $3 < 60000 {print $1}' /etc/passwd)"

    if [ -n "$existing_users" ]; then
        echo "기존 일반 계정:"
        echo "$existing_users"
        if prompt_yes_no "새 계정 생성 없이 진행하시겠습니까?"; then
            ensure_admin_access $existing_users || return 1
            CREATED_USER="not created(existing: $existing_users)"
            create_user=0
        fi
    fi

    if [ "$create_user" -eq 1 ]; then
        while true; do
            read -r -p "생성할 일반 계정명 입력: " user_name < /dev/tty
            valid_account_name "$user_name" || {
                echo "영문 소문자 또는 _로 시작하고 영문 소문자, 숫자, _, -만 사용하세요."
                continue
            }
            if id "$user_name" >/dev/null 2>&1; then
                ensure_admin_access "$user_name" || return 1
                CREATED_USER="$user_name(existing)"
                break
            fi
            confirm_account_name "$user_name" || {
                echo "계정명을 다시 입력해 주세요."
                continue
            }

            while true; do
                read -r -s -p "계정 '$user_name' 비밀번호 입력 (최소 ${MIN_PASSWORD_LENGTH}자): " password < /dev/tty
                echo
                [ "${#password}" -ge "$MIN_PASSWORD_LENGTH" ] || {
                    echo "최소 ${MIN_PASSWORD_LENGTH}자 이상 입력해야 합니다."
                    continue
                }
                read -r -s -p "비밀번호 확인: " password_confirm < /dev/tty
                echo
                [ "$password" = "$password_confirm" ] || {
                    echo "비밀번호가 일치하지 않습니다."
                    continue
                }
                break
            done

            useradd -m -G wheel "$user_name" || {
                echo "ERROR: 일반 계정 생성 실패: $user_name" >&2
                return 1
            }
            ADMIN_USER="$user_name"
            printf '%s:%s\n' "$user_name" "$password" | chpasswd || {
                echo "ERROR: 일반 계정 비밀번호 설정 실패: $user_name" >&2
                return 1
            }
            CREATED_USER="$user_name(created)"
            break
        done
    fi

    ensure_account_password "$ADMIN_USER" || return 1
    sudo -l -U "$ADMIN_USER" >/dev/null 2>&1 || {
        echo "ERROR: 일반 계정 sudo 권한 검증 실패" >&2
        return 1
    }
}

# root SSH 로그인을 차단하되 관리자 일반 계정 확보 후에만 적용한다.
disable_root_ssh_login() {
    sed -i '/^[[:space:]#]*PermitRootLogin[[:space:]]/d' /etc/ssh/sshd_config || return 1
    echo 'PermitRootLogin no' >> /etc/ssh/sshd_config || return 1
    sshd -t || {
        echo "ERROR: root SSH 차단 후 sshd_config 문법 오류" >&2
        return 1
    }
    mark_restart sshd
}

# PAM 심볼릭 링크의 실제 *-ac 파일에 pam_tally2와 pam_cracklib 정책을 적용한다.
configure_pam_security() {
    local pam_link pam_file
    for pam_link in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
        pam_file="$(readlink -f "$pam_link" 2>/dev/null)"
        [ -f "$pam_file" ] || {
            echo "ERROR: PAM 실제 파일을 찾을 수 없습니다: $pam_link" >&2
            return 1
        }

        sed -i '/pam_tally2\.so/d' "$pam_file" || return 1
        sed -i '/^[[:space:]]*auth[[:space:]]\+required[[:space:]]\+pam_env\.so/a auth        required      pam_tally2.so deny=3 unlock_time=300' "$pam_file" || return 1
        sed -i '/^[[:space:]]*account[[:space:]]\+required[[:space:]]\+pam_unix\.so/i account     required      pam_tally2.so' "$pam_file" || return 1
        sed -i 's/[[:space:]]nullok//g' "$pam_file" || return 1

        if grep -q 'pam_cracklib\.so' "$pam_file"; then
            sed -i "s#^[[:space:]]*password[[:space:]]\\+requisite[[:space:]]\\+pam_cracklib\\.so.*#password    requisite     pam_cracklib.so try_first_pass retry=3 minlen=${PASSWORD_MIN_LENGTH} difok=2 lcredit=-1 ucredit=-1 dcredit=-1 ocredit=-1 type=#" "$pam_file" || return 1
        else
            sed -i "/^[[:space:]]*password[[:space:]]\\+sufficient[[:space:]]\\+pam_unix\\.so/i password    requisite     pam_cracklib.so try_first_pass retry=3 minlen=${PASSWORD_MIN_LENGTH} difok=2 lcredit=-1 ucredit=-1 dcredit=-1 ocredit=-1 type=" "$pam_file" || return 1
        fi
        [ "$(grep -c 'pam_tally2\.so' "$pam_file" 2>/dev/null)" -eq 2 ] || {
            echo "ERROR: PAM 잠금 정책 적용 확인 실패: $pam_file" >&2
            return 1
        }
        [ "$(grep -c 'pam_cracklib\.so' "$pam_file" 2>/dev/null)" -eq 1 ] || {
            echo "ERROR: PAM 복잡도 정책 적용 확인 실패: $pam_file" >&2
            return 1
        }
    done
}

# su 실행 파일과 PAM을 wheel 그룹으로 제한한다.
configure_su_restriction() {
    set_file_perms /bin/su root:wheel 4750 || return 1
    sed -i '/pam_wheel\.so.*use_uid/d' /etc/pam.d/su || return 1
    sed -i '/^[[:space:]]*auth[[:space:]]\+sufficient[[:space:]]\+pam_rootok\.so/a auth            required        pam_wheel.so use_uid' /etc/pam.d/su || return 1
    [ "$(grep -Ec '^[[:space:]]*auth[[:space:]]+required[[:space:]]+pam_wheel\.so[[:space:]]+use_uid([[:space:]]|$)' /etc/pam.d/su 2>/dev/null)" -eq 1 ] || {
        echo "ERROR: su wheel 제한 적용 확인 실패" >&2
        return 1
    }
}

# 계정 조치 실패를 main.sh에 반환해 이후 서비스와 방화벽 조치가 실행되지 않게 한다.
apply_account_hardening() {
    remove_unneeded_users || return 1
    configure_password_expiration || return 1
    change_root_password || return 1
    prepare_admin_account || return 1
    disable_root_ssh_login || return 1
    configure_pam_security || return 1
    configure_su_restriction || return 1
}

apply_account_hardening
