# Keys Directory

This directory contains SSH keys symlinks and other secrets used by the infrastructure.

## Important
- Never commit actual keys to version control
- Use `.gitignore` to prevent accidental commits
- Store keys securely and distribute through secure channels

## Required Keys
1. `linode_basecamp_rsa.pub` - Public SSH key for admin access
2. `basecamp_flux_ed25519.pub` - Public SSH key for fluxcd (Git deploy key)

## Setup
```bash
# Generate new SSH key pair
ssh-keygen -t rsa -b 4096 -f ./linode_basecamp_rsa -C "admin@example.com"
ssh-keygen -t ed25519 -f ./basecamp_flux_ed25519 -C "admin@example.com"

# Set proper permissions
chmod 600 linode_basecamp_rsa
chmod 644 linode_basecamp_rsa.pub

chmod 600 basecamp_flux_ed25519
chmod 644 basecamp_flux_ed25519.pub
```

---