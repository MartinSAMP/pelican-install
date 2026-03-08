# 🦢 Pelican Panel & Wings Installer

> **One-click installer for Pelican Game Server Management Panel**
>
> Optimized, modern, and feature-rich installation script for Pelican Panel & Wings Daemon

![Version](https://img.shields.io/badge/version-v1.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Author](https://img.shields.io/badge/author-Martin%202026-purple.svg)
![Supports](https://img.shields.io/badge/supports-Ubuntu%20%7C%20Debian%20%7C%20AlmaLinux%20%7C%20Rocky%20Linux-orange.svg)

---

## Features

### Modern UI/UX
- **Progress Bar Animation** - Real-time visual progress during installation
- **Color-Coded Interface** - Easy to read with cyan, green, red, and yellow color coding
- **Clean Header Design** - Professional branding with "MARTIN 2026"
- **Interactive Menu** - User-friendly numbered selection system

### Auto SSL Configuration
- **Automatic Domain Validation** - Detects if domain resolves to server
- **Let's Encrypt Integration** - Auto-generates SSL certificates for valid domains
- **IP Detection** - Automatically detects if using IP address (skips SSL)
- **Smart Fallback** - Falls back to HTTP if SSL generation fails

### Auto Firewall Rules
- **UFW Support** (Ubuntu/Debian):
  - Port 22 (SSH) - Prevents lockout
  - Port 80/443 (Panel HTTP/HTTPS)
  - Port 8080 (Wings Daemon)
  - Port 2022 (Wings SFTP)
- **Firewalld Support** (RHEL-based):
  - Auto-enables and configures services
  - Opens required ports automatically

### Installation Modes
- **Install Panel Only** - Web interface only
- **Install Wings Only** - Daemon only
- **Install Both** - Complete setup with one command
- **Uninstall Options** - Remove Panel, Wings, or both
- **Troubleshooting Menu** - Built-in diagnostic tools

---

## Supported Operating Systems

| OS | Version | Status |
|----|---------|--------|
| **Ubuntu** | 22.04 LTS, 24.04 LTS | ✅ Fully Supported |
| **Debian** | 11, 12 | ✅ Fully Supported |
| **AlmaLinux** | 9, 10 | ✅ Fully Supported |
| **Rocky Linux** | 9, 10 | ✅ Fully Supported |
| **CentOS/RHEL** | 8, 9 | ⚠️ Compatible |

---

## Quick Start

### 1. Download & Run

```bash
# Download the installer
curl -sSL https://raw.githubusercontent.com/yourusername/pelican-installer/main/pelican_installer_v3.sh -o pelican_installer.sh

# Make it executable
chmod +x pelican_installer.sh

# Run as root
sudo ./pelican_installer.sh
```

Or using wget:

```bash
wget https://raw.githubusercontent.com/yourusername/pelican-installer/main/pelican_installer_v3.sh
chmod +x pelican_installer_v3.sh
sudo ./pelican_installer_v3.sh
```

### 2. Select Installation Type

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
           PELICAN INSTALLER - MARTIN 2026
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    MAIN MENU

  [1] Install Panel
  [2] Install Wings
  [3] Install Panel + Wings
  [4] Uninstall
  [5] Troubleshooting
  [0] Exit

  Select option: 
```

### 3. Follow the Prompts

The installer will automatically:
- Detect your OS and version
- Update system packages
- Install all dependencies (PHP 8.3, MariaDB, Nginx, Composer)
- Configure SSL (if domain provided)
- Setup firewall rules
- Create admin user
- Display credentials

---

## 📖 Installation Examples

### Example 1: Panel with Auto SSL

```
➜ Enter your FQDN or IP (default: 192.168.1.100): panel.example.com
➜ Configure SSL automatically? (Y/n): Y
➜ Enter Email for Let's Encrypt: admin@example.com

✓ Domain validation passed
✓ SSL Certificate generated successfully
✓ Panel Installation Complete

Panel URL:     https://panel.example.com
Admin Email:   admin@pelican.local
Username:      admin
Password:      [auto-generated]
```

### Example 2: Panel + Wings Complete Setup

```bash
# Select option [3] in menu
➜ Installing Panel...
[████████████████████████████████████████] | 100% - Installing PHP 8.3
[████████████████████████████████████████] | 100% - Downloading Pelican Panel
[████████████████████████████████████████] | 100% - Configuring Nginx

➜ Installing Wings...
[████████████████████████████████████████] | 100% - Installing Docker
[████████████████████████████████████████] | 100% - Downloading Wings binary

✓ Installation Complete!
```

---

## Troubleshooting

Access the built-in troubleshooting menu by selecting option `[5]`:

```
                    TROUBLESHOOTING MENU

  [1] Check Services Status      - View running/stopped services
  [2] Fix Panel Permissions      - Fix 500 errors
  [3] View Panel Logs            - Last 100 lines
  [4] View Nginx Logs            - Last 50 error lines
  [5] Check Database Connectivity - Test DB connection
  [0] Back to Main Menu
```

### Common Issues

| Issue | Solution |
|-------|----------|
| **500 Error** | Run Troubleshooting → Option 2 (Fix Permissions) |
| **Database Error** | Check if MariaDB is running: `systemctl status mariadb` |
| **SSL Failed** | Ensure domain A record points to server IP |
| **Port 8080 in use** | Script auto-kills process on port 8080 |
| **Permission Denied** | Ensure running as root: `sudo su` |

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

**What gets removed:**
- ✅ Panel files (`/var/www/pelican`)
- ✅ Nginx configuration
- ✅ Systemd services
- ✅ Database and user
- ✅ SSL certificates (optional)

---

## Security Features

- **Auto-generated strong passwords** for database and admin user
- **Firewall auto-configuration** with secure defaults
- **SSL/TLS encryption** with modern cipher suites
- **Non-root service execution** where possible
- **Automatic security updates** during installation

---

## System Requirements

### Minimum Requirements
- **RAM**: 2GB (4GB recommended for production)
- **CPU**: 2 cores
- **Disk**: 20GB free space
- **Network**: Public IP (for SSL) or Local IP

### Recommended for Production
- **RAM**: 4GB+
- **CPU**: 4 cores
- **Disk**: 50GB+ SSD
- **OS**: Ubuntu 22.04 LTS or AlmaLinux 9

---

## Manual Configuration

### Default Paths

| Component | Path |
|-----------|------|
| Panel Files | `/var/www/pelican` |
| Nginx Config | `/etc/nginx/sites-available/pelican.conf` (Debian/Ubuntu) |
| | `/etc/nginx/conf.d/pelican.conf` (RHEL) |
| SSL Certs | `/etc/letsencrypt/live/[domain]/` |
| Wings Config | `/etc/pelican/config.yml` |
| Database | `pelican` (MariaDB) |

### Service Management

```bash
# Panel Queue Worker
systemctl status pelican-worker
systemctl restart pelican-worker

# Wings Daemon
systemctl status wings
systemctl restart wings

# Nginx
systemctl status nginx
systemctl restart nginx

# MariaDB
systemctl status mariadb
systemctl restart mariadb
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Credits

- **Original Concept**: Based on Pterodactyl Installer style
- **Author**: Martin (2026)
- **Pelican Project**: https://pelican.dev
- **Community**: Thanks to all contributors and testers

---

## 📞 Support

- **Documentation**: https://pelican.dev/docs
- **Issues**: [GitHub Issues](https://github.com/MartinSAMP/pelican-install/issues)
- **Discord**: [Pelican Discord](https://discord.gg/pelican)

---

<div align="center">

**Made with ❤️ by Martin 2026**

[![Stars](https://img.shields.io/github/stars/yourusername/pelican-installer?style=social)](https://github.com/MartinSAMP/pelican-install/stargazers)
[![Forks](https://img.shields.io/github/forks/yourusername/pelican-installer?style=social)](https://github.com/MartinSAMP/pelican-install/network/members)

</div>
