#!/bin/bash

set -euo pipefail

BASE_DIR="/usr/local/src/secure_os_collection/u18"

source "$BASE_DIR/common.sh"

check_root

source "$BASE_DIR/system.sh"
source "$BASE_DIR/accounts.sh"
source "$BASE_DIR/services.sh"

exit 0
