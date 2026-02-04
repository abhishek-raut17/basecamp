#!/usr/bin/env bash
#
# Shared lib: utils file for generic functions and operations
#
# ------------------------------------------------------------------------------
# Cleanup on exit
# ------------------------------------------------------------------------------
cleanup_on_error() {
    local exit_code=$?

    if [ $exit_code -gt 0 ]; then

        log_error "Exit code: $exit_code detected. Running cleanup process ..."
        # cleanup
    fi
}

# ------------------------------------------------------------------------------
# Check if exists (path, file, dir)
# ------------------------------------------------------------------------------
exists() {
    local resource=$1
    local path=$2
    local basedir
    basedir="$(dirname "$path")"

    # Check if path is provided
    if [ -z "$path" ]; then
      log_error "Path not provided"
      return 1
    fi

    # Check if path exists
    if [[ ! -e "$basedir" ]]; then
      log_warn "Path $basedir does not exist"
      return 1
    fi

    # Validate if resource is available at path
    case "$resource" in
      file)
          if [ -f "$path" ]; then
              return 0
          else
              log_warn "No file $path found at parent dir: $basedir"
              return 1
          fi
          ;;
      dir)
          if [ -d "$path" ]; then
              return 0
          else
              log_warn "No dir $path found at parent dir: $basedir"
              return 1
          fi
          ;;
      *)
          log_error "Unknown resource type: $resource"
          return 1
          ;;
    esac
}

# ------------------------------------------------------------------------------
# Validate if attribute is exported
# ------------------------------------------------------------------------------
is_exported() {
    local arg="$1"

    if ! printenv "$arg" >/dev/null 2>&1; then
        log_debug "Argument: '$arg' is not exported. Please add variable to .env"
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Validate required arguments
# ------------------------------------------------------------------------------
validate_required_args() {
    local args=("$@")

    log_debug "Validating if required arguments are provided"

    for item in "${args[@]}"; do
        log_debug "Validating argument: $item"
        
        if ! is_exported "$item"; then
            log_warn "Required argument: $item is not exported"
            return 1
        fi
    done

    log_success "All required arguments provided."
    return 0
}

# ------------------------------------------------------------------------------
# Install CLI bin
# ------------------------------------------------------------------------------
install_bin() {
    local tool="$1"
    local checksum="$2"
    local url="$3"
    local bin_dir="${4:-/usr/local/bin}"

    local cmd
    cmd="$(basename "$tool")"
    cmd="${cmd%%-*}"

    log_info "Installing CLI bin: $cmd in PATH."

    # Check if url is provided
    if [[ -z "$url" ]]; then
        log_error "$url not valid or incorrect format"
        return 1
    fi

    if command -v "$cmd" >/dev/null 2>&1; then
        log_debug "CLI bin: $cmd already in $PATH"
        return 0
    fi

    log_warn "$cmd not found in PATH"
    log_info "Fetching resources from URL: $url/$tool"

    curl -LO "$url/$tool"
    curl -LO "$url/$checksum"

    if cat "$checksum" | grep -q "$tool"; then
        # checksum file already contains filename → direct verify
        cat sha256sum.txt | grep talosctl-linux-amd64 | sha256sum -c -
    else
        # checksum file contains ONLY the hash → add filename dynamically
        local hash
        hash="$(cat "$checksum")"
        echo "$hash  $tool" | sha256sum -c -
    fi

    chmod 0750 "$tool"
    # Testing only (turn off in prod)
    # chown sentinel:ops "$tool"

    mv "$tool" "$bin_dir/$cmd"
    log_info "CLI bin: $cmd installed IN $bin_dir in $PATH"

    return 0
}

# ------------------------------------------------------------------------------
# Install tools
# ------------------------------------------------------------------------------
install_tool() {
    local tool="$1"
    local url="$2"

    log_info "Installing CLI tool: $tool in PATH."

    # Check if url is provided
    if [[ -z "$url" ]]; then
        log_error "$url not valid or incorrect format"
        return 1
    fi

    if command -v "$tool" >/dev/null 2>&1; then
        log_debug "CLI tool: $tool already in PATH"
        return 0
    fi

    log_warn "$tool not found in PATH"
    log_info "Fetching resources from URL: $url"

    curl "$url" | bash

    return 0
}

# ------------------------------------------------------------------------------
# Create directory (with parent if not exists) (default: 0750 permission)
# ------------------------------------------------------------------------------
create_dir() {
    local path="$1"

    log_debug "Provisioning directory at $path"
    
    # Check if directory already exists
    if ! exists "dir" "$path"; then
        mkdir -m 0750 -p "$path"
        log_success "Created directory at $path successfully"
    else
        log_info "Directory already exists at path $path"
        return 0
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Create file
# ------------------------------------------------------------------------------
create_file() {
    local path="$1"
    local dir=$(dirname "$path")

    log_debug "Provisioning file at $path"
    
    # Check if directory already exists, create if not
    create_dir "$dir"
    
    # Check if file already exists
    if ! exists "file" "$path"; then
        touch "$path"
        chmod 0640 "$path"
        log_success "Created file at $path successfully"
    else
        log_info "File already exists at path $path"
        return 0
    fi

    return 0
}

# ------------------------------------------------------------------------------
# Delete file
# ------------------------------------------------------------------------------
delete_file() {
    local path="$1"

    log_debug "Deleting file at: $path"
    
    # Check if file already exists
    if exists "file" "$path"; then
        rm -f "$path"
        log_info "File at: $path deleted successfully"
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Kubernetes: check if the resource exists in cluster
# ------------------------------------------------------------------------------
resource_exists() {
    local resource_type=$1
    local resource_name=$2
    
    if kubectl get "$resource_type" -A | grep "$resource_name" &>/dev/null; then
        return 0  # exists
    else
        return 1  # doesn't exist
    fi
}

# ------------------------------------------------------------------------------
