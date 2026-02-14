#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
set -euo pipefail
# ------------------------------------------------------------------------------
# Source shared modules
# ------------------------------------------------------------------------------
source "$(dirname "$0")/shared/logger.sh"

trap 'log_fatal "utils failed at line $LINENO"' ERR

installer() {

    local tool="${1:-}"
    local file_type="${2:-}"
    local url="${3:-}"
    local bin_dir="${4:-${INSTALL_BIN_DIR}}"
    local output_file

    cd "$(mktemp -d)" && pwd
    case "$file_type" in
    bin)
        output_file="${tool}"
        ;;
    zip)
        output_file="${tool}.${file_type}"
        ;;
    *)
        output_file="${tool}"
        ;;
    esac

    log_debug "Download URL: ${url}"
    log_debug "Writing to output file: ${output_file}"

    # error handle downloading
    if ! curl -fL "${url}" -o "${output_file}"; then
        log_error "Failed to download ${tool}"
        return 1
    fi

    # If zip type, then unzip
    if [[ -n "${file_type}" ]] && [[ "${file_type}" == "zip" ]]; then
        unzip "${output_file}"
    fi

    chmod +x "${tool}"
    mv "${tool}" "${bin_dir}/${tool}" || return 1
}

install_bin() {

    local tool_name="${1:-}"
    local download_url="${2:-}"
    local file_type="${3:-bin}"
    local bin_dir="${4:-${INSTALL_BIN_DIR}}"

    local tool
    tool="$(basename "$tool_name")"
    tool="${tool%%-*}"

    log_info "Preparing to install bin: ${tool} at ${bin_dir}"

    # validate tool name and url for downloading binary
    if [[ ! -n "$tool" ]] || [[ ! -n "$download_url" ]] || [[ ! -n "$bin_dir" ]]; then
        log_error "Error: invalid input for bin download. Required: \\n
        bin install directory: [${bin_dir}] \\n
        tool: [${tool}] \\n
        download url: [${download_url}]"
        return 1
    fi

    # check if bin_dir is in $PATH
    if ! echo "$PATH" | grep -q "$bin_dir"; then
        log_error "Install bin directory ${bin_dir} not in $PATH \\nPlease add ${bin_dir} to PATH before proceeding"
        return 1
    fi

    # check if tool already exists in $PATH
    if ! command -v "$tool" >/dev/null 2>&1; then
        log_warn "CLI bin: ${tool} not in $PATH"
        installer "${tool}" "${file_type}" "${download_url}" "${bin_dir}" || return 1
    else
        local current_path="$(which "$tool")"
        log_info "CLI bin: ${tool} already installed at: ${current_path}"
        return 0
    fi

    log_success "CLI bin: ${tool} installed at: ${bin_dir}"
}

install_dir() {

    local directory="${1:-}"
    if [[ ! -d "${directory}" ]]; then
        log_debug "Directory not found. Creating directory at ${directory}"
        mkdir -p "${directory}"
        chmod -R 750 "${directory}"
    else
        log_info "Required directory: ${directory} already exists"
    fi
}

# ------------------------------------------------------------------------------
