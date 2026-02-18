#!/usr/bin/env bash
#
# Shared lib: logger file for logging
#
# Color codes
declare COLORLESS='\033[1;30m'
declare COLOR_RESET='\033[0m'
declare COLOR_BOLD='\033[1m'
declare COLOR_RED='\033[1;31m'
declare COLOR_GREEN='\033[1;32m'
declare COLOR_YELLOW='\033[1;33m'
declare COLOR_BLUE='\033[1;34m'
declare COLOR_CYAN='\033[1;36m'

# Log levels
declare LOG_LEVEL_DEBUG=0
declare LOG_LEVEL_INFO=1
declare LOG_LEVEL_WARN=2
declare LOG_LEVEL_ERROR=3

# Current log level (default: INFO)
LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

# ------------------------------------------------------------------------------
# Get timestamp
# ------------------------------------------------------------------------------
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# ------------------------------------------------------------------------------
# Log with level
# ------------------------------------------------------------------------------
log_with_level() {
    local level="$1"
    local color="$2"
    local message="$3"
    local timestamp
    local current_file
    timestamp=$(get_timestamp)
    current_file="$(basename "${BASH_SOURCE[2]}" .sh)"

    echo -e "${color}[${level}]${COLOR_RESET} ${timestamp} - ${current_file} - ${message}" >&2
}

# ------------------------------------------------------------------------------
# Debug log (only shown when VERBOSE=true or LOG_LEVEL=DEBUG)
# ------------------------------------------------------------------------------
log_mark() {
    log_with_level " ---> " "$COLORLESS" "$*"
}

# ------------------------------------------------------------------------------
# Debug log (only shown when VERBOSE=true or LOG_LEVEL=DEBUG)
# ------------------------------------------------------------------------------
test_mark() {
    log_with_level "TEST ---> " "$COLORLESS" "$*"
}

# ------------------------------------------------------------------------------
# Debug log (only shown when VERBOSE=true or LOG_LEVEL=DEBUG)
# ------------------------------------------------------------------------------
test_pass() {
    log_with_level "✓" "$COLOR_GREEN" "$*"
}

# ------------------------------------------------------------------------------
# Debug log (only shown when VERBOSE=true or LOG_LEVEL=DEBUG)
# ------------------------------------------------------------------------------
test_error() {
    log_with_level "x" "$COLOR_RED" "$*"
}

# ------------------------------------------------------------------------------
# Debug log (only shown when VERBOSE=true or LOG_LEVEL=DEBUG)
# ------------------------------------------------------------------------------
test_warn() {
    log_with_level "!" "$COLOR_YELLOW" "$*"
}

# ------------------------------------------------------------------------------
# Debug log (only shown when VERBOSE=true or LOG_LEVEL=DEBUG)
# ------------------------------------------------------------------------------
log_debug() {
    if [[ "${VERBOSE:-false}" == "true" ]] || [[ "$LOG_LEVEL" -le "$LOG_LEVEL_DEBUG" ]]; then
        log_with_level "DEBUG" "$COLOR_CYAN" "$*"
    fi
}

# ------------------------------------------------------------------------------
# Info log
# ------------------------------------------------------------------------------
log_info() {
    if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_INFO" ]]; then
        log_with_level "INFO " "$COLOR_BLUE" "$*"
    fi
}

# ------------------------------------------------------------------------------
# Warning log
# ------------------------------------------------------------------------------
log_warn() {
    if [[ "$LOG_LEVEL" -le "$LOG_LEVEL_WARN" ]]; then
        log_with_level "WARN " "$COLOR_YELLOW" "$*"
    fi
}

# ------------------------------------------------------------------------------
# Error log
# ------------------------------------------------------------------------------
log_error() {
    log_with_level "ERROR" "$COLOR_RED" "$*"
}

# ------------------------------------------------------------------------------
# Success log (special case of info with green color)
# ------------------------------------------------------------------------------
log_success() {
    log_with_level "OK   " "$COLOR_GREEN" "$*"
}

# ------------------------------------------------------------------------------
# Fatal error (logs and exits)
# ------------------------------------------------------------------------------
log_fatal() {
    log_with_level "FATAL" "$COLOR_RED" "$*"
    exit 1
}

# ------------------------------------------------------------------------------