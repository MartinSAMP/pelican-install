# 🦢 Pelican Panel & Wings Installer

> **Production-ready, secure, and optimized installer for Pelican Game Server Management Panel**
>
> Modern installation script with enterprise-grade security, comprehensive logging, and intelligent automation

![Version](https://img.shields.io/badge/version-v2.0--optimized-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Author](https://img.shields.io/badge/author-Martin%202026-purple.svg)
![Supports](https://img.shields.io/badge/supports-Ubuntu%2020.04%2F22.04%2F24.04%20%7C%20Debian%2011%2F12%20%7C%20AlmaLinux%208%2F9%20%7C%20Rocky%208%2F9-orange.svg)

---

## 🚀 What's New in v2.0

### 🔒 Security Hardening
- **Secure Credential Storage** - Passwords saved to protected file (chmod 600) instead of displayed in terminal
- **Input Validation** - FQDN, email, and IP validation with retry logic
- **Composer Signature Verification** - SHA384 checksum validation before installation
- **MariaDB Security** - Automatic removal of anonymous users and test databases
- **File Permission Hardening** - `.env` and credentials locked down to root-only access

### 🛡️ Reliability & Safety
- **Comprehensive Logging** - Full installation log at `/var/log/pelican-installer/`
- **Automatic Backups** - Pre-installation backup of existing installations
- **State Tracking** - Resume capability with step-by-step progress tracking
- **Error Recovery** - Intelligent retry logic for downloads and database connections
- **Graceful Interrupt Handling** - Cleanup on Ctrl+C or script failure

### ⚡ Performance Optimizations
- **PHP OPcache Enabled** - Dramatically faster panel performance
- **Composer Caching** - Persistent dependency cache for faster reinstalls
- **Parallel Operations** - Optimized installation flow
- **Nginx FastCGI Tuning** - Optimated buffer sizes and timeouts
- **SSL Session Caching** - Reduced handshake overhead

### 🎯 UX
- **Hidden Password Input** - Secure password entry (no terminal echo)
- **DNS Verification** - Automatic DNS propagation checking with retry
- **Smart Port Detection** - Intelligent port 80/8080 conflict resolution
- **Auto SSL Renewal** - Automatic Let's Encrypt renewal cron job setup

---

## Features

### Modern UI/UX
- **Progress Bar Animation** - Real-time visual progress during installation
- **Color-Coded Interface** - Easy to read with cyan, green, red, and yellow color coding
- **Interactive Menu** - User-friendly numbered selection system
- **Comprehensive Logging** - Every action logged with timestamps

### Auto SSL Configuration
- **Automatic Domain Validation** - Detects if domain resolves to server with DNS retry
- **Let's Encrypt Integration** - Auto-generates SSL certificates for valid domains
- **IP Detection** - Automatically detects if using IP address (skips SSL)
- **Smart Fallback** - Falls back to HTTP if SSL generation fails
- **Auto-Renewal** - Automatic cron job for SSL certificate renewal

### Auto Firewall Rules
- **UFW Support** (Ubuntu/Debian):
  - Port 22 (SSH) - Prevents lockout
  - Port 80/443 (Panel HTTP/HTTPS)
  - Port 8080 (Wings Daemon)
  - Port 2022 (Wings SFTP)
  - Idempotent rules (safe to run multiple times)
- **Firewalld Support** (RHEL-based):
  - Auto-enables and configures services
  - Opens required ports automatically
  - Permanent rule configuration

### Installation Modes
- **Install Panel Only** - Web interface with full LEMP stack
- **Install Wings Only** - Daemon with Docker and SSL options
- **Install Both** - Complete unified setup with one command
- **Uninstall Options** - Remove Panel, Wings, or both with confirmation
- **Troubleshooting Menu** - 8 built-in diagnostic tools

---

## Supported Operating Systems

| OS | Version | Status | Notes |
|----|---------|--------|-------|
| **Ubuntu** | 24.04 LTS | ✅ Fully Supported | Recommended |
| **Ubuntu** | 22.04 LTS | ✅ Fully Supported | Recommended |
| **Ubuntu** | 20.04 LTS | ✅ Fully Supported | |
| **Debian** | 12 | ✅ Fully Supported | |
| **Debian** | 11 | ✅ Fully Supported | |
| **AlmaLinux** | 9 | ✅ Fully Supported | RHEL Alternative |
| **AlmaLinux** | 8 | ✅ Fully Supported | |
| **Rocky Linux** | 9 | ✅ Fully Supported | RHEL Alternative |
| **Rocky Linux** | 8 | ✅ Fully Supported | |
| **CentOS/RHEL** | 8, 9 | ⚠️ Compatible | Migration recommended |

---

## Quick Start

### 1. Download & Run

```bash
# Download the installer
curl -sSL https://raw.githubusercontent.com/MartinSAMP/pelican-install/main/install.sh -o install.sh

# Make it executable
chmod +x install.sh

# Run as root
sudo ./install.sh
```

Or using wget:

```bash
wget https://raw.githubusercontent.com/MartinSAMP/pelican-install/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### 2. Select Installation Type

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
           PELICAN INSTALLER - OPTIMIZED EDITION 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    MAIN MENU

  [1] Install Panel Only
  [2] Install Wings Only
  [3] Install Panel + Wings (Full Stack)
  [4] Uninstall
  [5] Troubleshooting
  [6] View Installation Log
  [0] Exit

  Select option: 
```

### 3. Follow the Prompts

The installer will automatically:
- Detect your OS and version
- Create system backup (if existing installation found)
- Update system packages
- Install all dependencies (PHP 8.3, MariaDB, Nginx, Composer)
- Validate DNS and configure SSL (if domain provided)
- Setup firewall rules with security hardening
- Create admin user with secure password
- Save credentials to protected file
- Display completion summary

---

## Installation Examples

### Example 1: Panel with Auto SSL

```
➜ Enter your FQDN or IP (default: 192.168.1.100): panel.example.com
➜ Configure SSL automatically? (Y/n): Y
➜ Enter Email for Let's Encrypt: admin@example.com

  Detecting operating system [████████████████████] 100%
  Installing PHP 8.3 and extensions [████████████████] 100%
  Generating SSL certificate [████████████████████] 100%

✓ Domain validation passed
✓ SSL Certificate generated successfully
✓ Panel Installation Complete

Panel URL:     https://panel.example.com
Admin Email:   admin@pelican.local
Username:      admin
Password:      [SECURED - Check credentials file]

⚠ IMPORTANT: Delete /var/www/pelican/.install_credentials after saving!
```

### Example 2: Panel + Wings Complete Setup

```bash
# Select option [3] in menu
➜ Installing Pelican Panel...
[████████████████████████████████████████] 100% - Installing PHP 8.3
[████████████████████████████████████████] 100% - Configuring MariaDB
[████████████████████████████████████████] 100% - Downloading Pelican Panel
[████████████████████████████████████████] 100% - Setting up SSL
[████████████████████████████████████████] 100% - Configuring Nginx

➜ Installing Pelican Wings...
[████████████████████████████████████████] 100% - Installing Docker
[████████████████████████████████████████] 100% - Downloading Wings binary
[████████████████████████████████████████] 100% - Configuring SSL

✓ Full Stack Installation Complete!
✓ Log saved to: /var/log/pelican-installer/install-20240311-143022.log
```

### Example 3: Secure Credential Retrieval

```bash
# View credentials (root only)
sudo cat /var/www/pelican/.install_credentials

# Output:
# Pelican Installation Credentials
# Generated: Mon Mar 11 14:30:22 UTC 2024
# KEEP THIS FILE SECURE!
#
# Admin URL: https://panel.example.com
# Admin Email: admin@pelican.local
# Username: admin
# Password: xK9#mP2$vL5@nQ8
#
# Database: pelican
# DB User: pelican
# DB Password: aB7$cD3%eF9&gH4@iJ5

# After saving credentials, delete the file:
sudo rm /var/www/pelican/.install_credentials
```

---

## Troubleshooting

Access the built-in troubleshooting menu by selecting option `[5]`:

```
                    TROUBLESHOOTING MENU

  [1] Check Services Status       - View all service statuses
  [2] Fix Panel Permissions       - Repair 500 errors instantly
  [3] View Panel Logs             - Last 100 lines of Laravel logs
  [4] View Nginx Logs             - Last 50 error lines
  [5] Check Database Connectivity - Test DB with detailed output
  [6] Test Email Configuration    - Verify mail settings
  [7] Check Disk Space            - Storage usage analysis
  [8] View System Resources       - CPU/RAM usage
  [0] Back to Main Menu
```

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **500 Error** | Permission issues | Run Troubleshooting → Option 2 |
| **Database Connection Failed** | MariaDB not running | `systemctl restart mariadb` |
| **SSL Generation Failed** | DNS not propagated | Wait 5-10 minutes, retry |
| **Port 80 in Use** | Existing web server | Script auto-handles with graceful stop |
| **Port 8080 in Use** | Old Wings instance | Script auto-kills with SIGTERM |
| **Permission Denied** | Not root | Run with `sudo` or `sudo su` |
| **Composer Install Fails** | Network/PHP issue | Check log: `/var/log/pelican-installer/` |

### Viewing Logs

```bash
# View latest installation log
sudo ls -la /var/log/pelican-installer/

# View specific log
sudo less /var/log/pelican-installer/install-20240311-143022.log

# Real-time log during install
sudo tail -f /var/log/pelican-installer/install-$(date +%Y%m%d)*.log
```

---

## Uninstallation

Select option `[4]` from main menu:

```
                    UNINSTALL MENU

  [1] Uninstall Panel Only
  [2] Uninstall Wings Only
  [3] Uninstall Both
  [0] Back to Main Menu
```

**Safety Features:**
- ✅ **Automatic Backup** - Creates final backup before removal
- ✅ **Confirmation Prompt** - Type "DELETE" to confirm destructive actions
- ✅ **Selective Removal** - Remove only what you need
- ✅ **Service Cleanup** - Proper systemd service removal

**What gets removed:**
- Panel files (`/var/www/pelican`)
- Nginx configuration
- Systemd services (pelican-worker, wings)
- Database and user (optional)
- Cron jobs
- SSL certificates (optional)

**What gets preserved:**
- Backups in `/var/backups/`
- Installation logs in `/var/log/pelican-installer/`
- Docker images (Wings uninstall only)

## Security Features

### Automatic Security Measures
- **Strong Password Generation** - 24-char database passwords, 16-char admin passwords
- **Credential File Protection** - 600 permissions (root-only)
- **Firewall Auto-Configuration** - Deny incoming by default, allow only required
- **SSL/TLS Hardening** - TLS 1.2/1.3 only, strong cipher suites
- **Security Headers** - X-Frame-Options, X-Content-Type-Options, XSS Protection
- **Non-root Execution** - Services run as dedicated users where possible
- **Automatic Updates** - System packages updated during installation

### Manual Security Checklist

After installation, complete these steps:

1. **Retrieve and Secure Credentials**
   ```bash
   sudo cat /var/www/pelican/.install_credentials
   # Save to password manager, then:
   sudo rm /var/www/pelican/.install_credentials
   ```

2. **Change Default Admin Email**
   - Login to panel
   - Go to Admin → Users
   - Change `admin@pelican.local` to your email

3. **Enable 2FA** (Recommended)
   - Admin → My Account → Security → Enable 2FA

4. **Review Firewall**
   ```bash
   # Ubuntu/Debian
   sudo ufw status verbose
   
   # RHEL-based
   sudo firewall-cmd --list-all
   ```

5. **SSL Auto-Renewal Verification**
   ```bash
   sudo certbot renew --dry-run
   ```

## System Requirements

### Minimum Requirements
- **RAM**: 2GB (3GB with Wings)
- **CPU**: 2 cores
- **Disk**: 20GB free space (SSD recommended)
- **Network**: Public IP (for SSL) or Local IP
- **OS**: Fresh installation recommended

### Recommended for Production
- **RAM**: 4GB+ (8GB for 50+ servers)
- **CPU**: 4 cores+
- **Disk**: 50GB+ NVMe SSD
- **Network**: 1Gbps, Static IP
- **OS**: Ubuntu 22.04 LTS or AlmaLinux 9

### Architecture Support
- **Primary**: x86_64 (AMD64)
- **Wings**: AMD64 only (ARM64 support planned)

## Directory Structure

### Installation Paths

| Component | Path | Permissions |
|-----------|------|-------------|
| Panel Files | `/var/www/pelican` | `www-data:www-data` / `nginx:nginx` |
| Nginx Config (Debian/Ubuntu) | `/etc/nginx/sites-available/pelican.conf` | root:root |
| Nginx Config (RHEL) | `/etc/nginx/conf.d/pelican.conf` | root:root |
| SSL Certificates | `/etc/letsencrypt/live/[domain]/` | root:root |
| Wings Config | `/etc/pelican/config.yml` | root:root |
| Wings Binary | `/usr/local/bin/wings` | root:root |
| Database | `pelican` (MariaDB) | - |
| Logs | `/var/log/pelican-installer/` | root:root |
| Backups | `/var/backups/pelican-[timestamp]/` | root:root |

### Important Files

| File | Purpose | Security Level |
|------|---------|--------------|
| `.env` | Environment configuration | 600 (root-only) |
| `.install_credentials` | Initial credentials | 600 (delete after use) |
| `storage/logs/laravel.log` | Application logs | 644 |
| `config/app.php` | App configuration | 644 |

---

## Service Management

### Panel Services

```bash
# Queue Worker (Background Jobs)
sudo systemctl status pelican-worker
sudo systemctl restart pelican-worker
sudo systemctl stop pelican-worker

# Nginx (Web Server)
sudo systemctl status nginx
sudo systemctl reload nginx  # Graceful restart
sudo nginx -t  # Test configuration

# PHP-FPM
sudo systemctl status php8.3-fpm  # Debian/Ubuntu
sudo systemctl status php-fpm       # RHEL

# MariaDB
sudo systemctl status mariadb
sudo mysql -u root  # Access MySQL shell
```

### Wings Services

```bash
# Wings Daemon
sudo systemctl status wings
sudo systemctl restart wings
sudo systemctl stop wings

# View Wings Logs
sudo journalctl -u wings -f  # Real-time
sudo journalctl -u wings --since "1 hour ago"

# Docker
sudo systemctl status docker
sudo docker ps  # View containers
```

### Maintenance Commands

```bash
# Fix Permissions (fixes 500 errors)
sudo chown -R www-data:www-data /var/www/pelican  # Debian/Ubuntu
sudo chown -R nginx:nginx /var/www/pelican         # RHEL
sudo chmod -R 755 /var/www/pelican/storage /var/www/pelican/bootstrap/cache

# Clear Panel Cache
cd /var/www/pelican
sudo php artisan cache:clear
sudo php artisan config:clear
sudo php artisan view:clear

# Database Migration (if needed)
sudo php artisan migrate --force

# Check Panel Health
cd /var/www/pelican
sudo php artisan db:monitor
```

---

## 🔄 Updating

### Update Script
```bash
# Download latest version
curl -sSL https://raw.githubusercontent.com/MartinSAMP/pelican-install/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

### Manual Panel Update
```bash
cd /var/www/pelican
sudo php artisan down  # Enable maintenance mode

# Backup
sudo tar -czf /var/backups/pelican-update-$(date +%Y%m%d).tar.gz .

# Update
sudo curl -sL https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | sudo tar -xzf -

# Dependencies
sudo composer install --no-dev --optimize-autoloader

# Migrate
sudo php artisan migrate --force
sudo php artisan db:seed --force

# Cache
sudo php artisan cache:clear
sudo php artisan config:cache

# Permissions
sudo chown -R www-data:www-data .  # Adjust user as needed

sudo php artisan up  # Disable maintenance mode
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create** your feature branch (`git checkout -b feature/AmazingFeature`)
3. **Test** on supported OS versions
4. **Commit** your changes (`git commit -m 'Add: AmazingFeature'`)
5. **Push** to the branch (`git push origin feature/AmazingFeature`)
6. **Open** a Pull Request with detailed description

### Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/pelican-install.git
cd pelican-install

# Create test environment (recommended: use VM or container)
# Test on clean OS installations only

# Run shellcheck for syntax validation
shellcheck install.sh
```

### Code Standards
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `shellcheck` for linting
- Test on minimum 2 OS families
- Update README.md for new features
- Add logging for new operations

## 🙏 Credits

- **Original Concept**: Inspired by Pterodactyl Installer community
- **Author & Maintainer**: Martin (2026)
- **Core Project**: [Pelican Panel](https://pelican.dev) by Pelican Dev Team
- **Contributors**: Thanks to all GitHub contributors and testers
- **Community**: [Pelican Discord](https://discord.gg/pelican) for support and feedback

### Dependencies
- [Pelican Panel](https://github.com/pelican-dev/panel) - Game server management panel
- [Pelican Wings](https://github.com/pelican-dev/wings) - Daemon for server management
- [Let's Encrypt](https://letsencrypt.org/) - Free SSL certificates
- [Composer](https://getcomposer.org/) - PHP dependency management

## Support & Resources

### Official Resources
- **Documentation**: https://pelican.dev/docs
- **API Reference**: https://pelican.dev/docs/api
- **GitHub**: https://github.com/pelican-dev/panel

### Community Support
- **Discord**: [Pelican Discord](https://discord.gg/pelican)
- **GitHub Issues**: [Report bugs here](https://github.com/MartinSAMP/pelican-install/issues)
- **Discussions**: [GitHub Discussions](https://github.com/MartinSAMP/pelican-install/discussions)

### Enterprise Support
For production deployments requiring SLA support, consider:
- Pelican Official Support (coming soon)
- Community commercial support providers

## Roadmap

### v2.1 (Planned)
- [ ] ARM64 architecture support
- [ ] Redis auto-configuration
- [ ] Backup/Restore functionality
- [ ] Multi-node Wings deployment
- [ ] Automated update checker

### v2.2 (Planned)
- [ ] PostgreSQL support option
- [ ] Docker Compose deployment mode
- [ ] Cloud-init integration
- [ ] Ansible playbook generation

<div align="center">

**Made with ❤️ by Martin 2026**

[![Stars](https://img.shields.io/github/stars/MartinSAMP/pelican-install?style=social)](https://github.com/MartinSAMP/pelican-install/stargazers)
[![Forks](https://img.shields.io/github/forks/MartinSAMP/pelican-install?style=social)](https://github.com/MartinSAMP/pelican-install/network/members)
[![Issues](https://img.shields.io/github/issues/MartinSAMP/pelican-install)](https://github.com/MartinSAMP/pelican-install/issues)

**[⬆ Back to Top](#-pelican-panel--wings-installer)**

</div>
