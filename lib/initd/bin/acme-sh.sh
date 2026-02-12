# ===============================================================================
# Step 17: Setup acme.sh for generating and rotating certs for coturn server
# ===============================================================================
setup_acme_sh_certmanager() {
    log_info "Initializing acme.sh for cert issuance and auto-renewal"

    # Set defaults
    local domain="${DOMAIN:-turn.sigdep.cloud}"
    local acme_email="${ACME_EMAIL:-engineering.abhishek17@gmail.com}"
    local acme_dir="${ACME_DIR:-/root/.acme.sh}"
    local cert_home="${CERT_HOME:-/etc/coturn/certs}"
    local dns_provider="${DNS_PROVIDER:-dns_linode_v4}"
    local acme_log="/var/log/acme-sh/acme-sh.log"

    # Validate Linode API token
    if [[ -z "${CLOUD_PROVIDER_PAT:-}" ]]; then
        log_error "CLOUD_PROVIDER_PAT must be set - required for DNS-01 challenge"
        exit 1
    fi

    # ------------------------------------------------------------------------------
    # Step 17.1: Install acme.sh with native cron and logging
    # ------------------------------------------------------------------------------
    if ! exists "file" "${acme_dir}/acme.sh"; then
        log_debug "acme.sh not found at: ${acme_dir}. Installing..."

        if ! command -v git &>/dev/null; then
            log_debug "git not found. Installing..."
            apt update && apt install -y git
        fi

        mkdir -p "$(dirname ${acme_log})"

        git clone https://github.com/acmesh-official/acme.sh.git /tmp/acme.sh
        cd /tmp/acme.sh && ./acme.sh --install \
            --home "${acme_dir}" \
            --accountemail "${acme_email}" \
            --log "${acme_log}" \
            --cron

        log_success "acme.sh installed at: ${acme_dir}"
        log_info "Cron scheduled daily at 03:30, logging to: ${acme_log}"
    else
        log_debug "acme.sh already installed at: ${acme_dir}"
    fi

    # ------------------------------------------------------------------------------
    # Step 17.2: Store Linode API token in acme.sh account.conf
    # acme.sh sources this file on every run, making the token available to cron
    # ------------------------------------------------------------------------------
    log_debug "Storing LINODE_V4_API_KEY in acme.sh account.conf"
    
    if [[ -f "${acme_dir}/account.conf" ]]; then
        # Update existing token or append if missing
        if grep -q "^SAVED_LINODE_V4_API_KEY=" "${acme_dir}/account.conf"; then
            sed -i "s|^SAVED_LINODE_V4_API_KEY=.*|SAVED_LINODE_V4_API_KEY='${CLOUD_PROVIDER_PAT}'|" "${acme_dir}/account.conf"
            log_success "LINODE_V4_API_KEY updated in account.conf"
        else
            echo "SAVED_LINODE_V4_API_KEY='${CLOUD_PROVIDER_PAT}'" >> "${acme_dir}/account.conf"
            log_success "LINODE_V4_API_KEY stored in account.conf"
        fi
    else
        # Create account.conf if it doesn't exist
        echo "SAVED_LINODE_V4_API_KEY='${CLOUD_PROVIDER_PAT}'" > "${acme_dir}/account.conf"
        log_success "Created account.conf with LINODE_V4_API_KEY"
    fi

    # ------------------------------------------------------------------------------
    # Step 17.3: Issue cert with cert-home and reloadcmd
    # acme.sh stores these in its domain config and reuses on every renewal
    # ------------------------------------------------------------------------------
    log_info "Issuing cert for: ${domain}"

    export LINODE_V4_API_KEY="${CLOUD_PROVIDER_PAT}"

    "${acme_dir}/acme.sh" \
        --issue \
        --home "${acme_dir}" \
        --domain "${domain}" \
        --dns "${dns_provider}" \
        --cert-home "${cert_home}" \
        --reloadcmd "systemctl reload coturn" \
        --server letsencrypt \
        --log "${acme_log}"

    if [[ $? -eq 0 ]]; then
        log_success "Cert issued successfully"
        log_info "Certs available at: ${cert_home}/${domain}/"
    else
        log_error "Cert issuance failed. Check logs at: ${acme_log}"
        exit 1
    fi

    log_success "acme.sh setup completed successfully"
}

setup_acme_sh_certmanager
