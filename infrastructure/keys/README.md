# Keys Directory

This directory contains SSH keys symlinks and other secrets used by the infrastructure.

## Important
- Never commit actual keys to version control
- Use `.gitignore` to prevent accidental commits
- Store keys securely and distribute through secure channels

## Required Keys
1. `sigdep_rsa.pub` - Public SSH key for admin access
2. Additional keys as needed

## Setup
```bash
# Generate new SSH key pair
ssh-keygen -t rsa -b 4096 -f ./sigdep_rsa -C "admin@example.com"

# Set proper permissions
chmod 600 sigdep_rsa
chmod 644 sigdep_rsa.pub
```

---