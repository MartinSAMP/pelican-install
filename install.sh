#!/bin/bash

# Pelican Panel & Wings Installer - Optimized Version
# Copyright (c) 2026 Martin - Optimized Edition
# Supports: Debian 11/12, Ubuntu 20.04/22.04/24.04, AlmaLinux 8/9, Rocky Linux 8/9

set -euo pipefail
IFS=$'\n\t'

# Trap untuk cleanup saat interrupt
trap 'cleanup_on_exit' EXIT INT TERM

cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        error "Script interrupted or failed with code $exit_code"
        log_message "ERROR: Installation failed at step: ${CURRENT_STEP:-unknown}"
        echo -e "\n${COLOR_YELLOW}Check log: $LOG_FILE${COLOR_NC}"
    fi
    # Restore services yang di-stop untuk SSL
    if [[ "${NGINX_STOPPED:-false}" == "true" ]]; then
        systemctl start nginx 2>/dev/null || true
    fi
    exit $exit_code
}

# Versioning & Paths
readonly SCRIPT_RELEASE="v2.0-optimized"
readonly PANEL_DIR="/var/www/pelican"
readonly LOG_DIR="/var/log/pelican-installer"
readonly LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
readonly BACKUP_DIR="/var/backups/pelican-$(date +%Y%m%d-%H%M%S)"

# Colors
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_PURPLE='\033[0;35m'
readonly COLOR_NC='\033[0m'

# State tracking
CURRENT_STEP="initialization"
declare -A INSTALL_STATE

init_logging() {
    mkdir -p "$LOG_DIR"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    log_message "=== Pelican Installer $SCRIPT_RELEASE Started ==="
    log_message "OS: $(uname -a)"
}

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_header() {
    clear
    cat <<EOF

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}
${COLOR_PURPLE}           PELICAN INSTALLER - MARTIN 2026${COLOR_NC}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}

  ${COLOR_BLUE}OS:${COLOR_NC} ${OS:-Unknown} ${OS_VER:-}
  ${COLOR_BLUE}Script:${COLOR_NC} $SCRIPT_RELEASE
  ${COLOR_BLUE}Log:${COLOR_NC} $LOG_FILE
  ${COLOR_BLUE}Website:${COLOR_NC} https://pelican.dev

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}

EOF
}

output() { echo -e "${COLOR_BLUE}➜${COLOR_NC} $1"; log_message "INFO: $1"; }
success() { echo -e "\n  ${COLOR_GREEN}✓ SUCCESS:${COLOR_NC} $1\n"; log_message "SUCCESS: $1"; }
error() { echo -e "\n  ${COLOR_RED}✗ ERROR:${COLOR_NC} $1\n" >&2; log_message "ERROR: $1"; }
warning() { echo -e "\n  ${COLOR_YELLOW}⚠ WARNING:${COLOR_NC} $1\n"; log_message "WARNING: $1"; }

progress_bar() {
    local current=$1 total=$2 label=$3
    local width=40
    (( total == 0 )) && total=1
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r  ${COLOR_CYAN}[${COLOR_NC}"
    printf "%${filled}s" | tr ' ' '█' | sed "s/█/${COLOR_GREEN}█${COLOR_NC}/g"
    printf "%${empty}s" | tr ' ' '░' | sed "s/░/${COLOR_CYAN}░${COLOR_NC}/g"
    printf "${COLOR_CYAN}]${COLOR_NC} ${COLOR_YELLOW}%3d%%${COLOR_NC} - %s" "$percentage" "$label"
    
    (( current == total )) && echo ""
}

show_progress() {
    local message=$1 duration=${2:-1} steps=${3:-20}
    output "$message"
    
    local sleep_interval=$(awk "BEGIN {printf \"%.3f\", $duration/$steps}")
    for ((i=1; i<=steps; i++)); do
        progress_bar $i $steps "$message"
        sleep "$sleep_interval"
    done
    echo ""
}
\
validate_fqdn() {
    local fqdn=$1
    [[ "$fqdn" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

validate_email() {
    local email=$1
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

validate_ip() {
    local ip=$1
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

secure_input() {
    local prompt=$1
    local -n var=$2
    read -rsp "$prompt" var
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

detect_os() {
    CURRENT_STEP="os_detection"
    show_progress "Detecting operating system" 0.5 10
    
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS - /etc/os-release not found"
        exit 1
    fi
    
    source /etc/os-release
    OS=$NAME
    OS_VER=$VERSION_ID
    ID=${ID:-}
    
    case "$ID" in
        debian)
            if [[ "${VERSION_ID%%.*}" -lt 11 ]]; then
                error "Debian $VERSION_ID not supported. Minimum: Debian 11"
                exit 1
            fi
            export PACKAGE_MANAGER="apt"
            export PHP_USER="www-data"
            export NGINX_USER="www-data"
            export NGINX_CONF_DIR="/etc/nginx/sites-available"
            export NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
            export FPM_SOCKET="unix:/run/php/php8.3-fpm.sock"
            ;;
        ubuntu)
            if [[ "${VERSION_ID%%.*}" -lt 20 ]]; then
                error "Ubuntu $VERSION_ID not supported. Minimum: Ubuntu 20.04"
                exit 1
            fi
            export PACKAGE_MANAGER="apt"
            export PHP_USER="www-data"
            export NGINX_USER="www-data"
            export NGINX_CONF_DIR="/etc/nginx/sites-available"
            export NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
            export FPM_SOCKET="unix:/run/php/php8.3-fpm.sock"
            ;;
        almalinux|rocky)
            if [[ "${VERSION_ID%%.*}" -lt 8 ]]; then
                error "$ID $VERSION_ID not supported. Minimum: 8"
                exit 1
            fi
            export PACKAGE_MANAGER="dnf"
            export PHP_USER="nginx"
            export NGINX_USER="nginx"
            export NGINX_CONF_DIR="/etc/nginx/conf.d"
            export NGINX_ENABLED_DIR=""
            export FPM_SOCKET="unix:/run/php-fpm/www.sock"
            ;;
        centos|rhel)
            warning "CentOS/RHEL detected. Consider migrating to AlmaLinux or Rocky Linux."
            export PACKAGE_MANAGER="dnf"
            export PHP_USER="nginx"
            export NGINX_USER="nginx"
            export NGINX_CONF_DIR="/etc/nginx/conf.d"
            export NGINX_ENABLED_DIR=""
            export FPM_SOCKET="unix:/run/php-fpm/www.sock"
            ;;
        *)
            error "Unsupported OS: $ID"
            log_message "Unsupported OS detected: $ID $VERSION_ID"
            exit 1
            ;;
    esac
    
    success "OS detected: $OS $OS_VER"
    log_message "OS Detection: $OS $OS_VER (ID: $ID)"
}

create_backup() {
    if [[ -d "$PANEL_DIR" ]]; then
        output "Creating backup of existing installation..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$PANEL_DIR" "$BACKUP_DIR/" 2>/dev/null || true
        if [[ -f "$PANEL_DIR/.env" ]]; then
            cp "$PANEL_DIR/.env" "$BACKUP_DIR/env-backup"
        fi
        success "Backup created at $BACKUP_DIR"
    fi
}

configure_firewall() {
    CURRENT_STEP="firewall_config"
    output "Configuring Firewall Rules..."
    log_message "Starting firewall configuration"
    
    local required_ports=(22 80 443 8080 2022)
    local services=("ssh" "http" "https")
    
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        if command -v ufw &>/dev/null; then
            if ! ufw status | grep -q "Status: active"; then
                ufw --force reset
                ufw default deny incoming
                ufw default allow outgoing
                
                for port in "${required_ports[@]}"; do
                    ufw allow "$port/tcp" comment "Pelican $( [[ $port == 22 ]] && echo "SSH" || [[ $port == 80 ]] && echo "HTTP" || [[ $port == 443 ]] && echo "HTTPS" || [[ $port == 8080 ]] && echo "Wings" || echo "SFTP" )"
                done
                
                echo "y" | ufw enable
                success "UFW configured and enabled"
            else
                for port in "${required_ports[@]}"; do
                    ufw allow "$port/tcp" 2>/dev/null || true
                done
                success "UFW rules added"
            fi
            log_message "UFW configured successfully"
        else
            warning "UFW not found. Please configure firewall manually."
            log_message "WARNING: UFW not available"
        fi
        
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        if command -v firewall-cmd &>/dev/null; then
            systemctl enable --now firewalld 2>/dev/null || true
            
            for service in "${services[@]}"; do
                firewall-cmd --permanent --add-service="$service" 2>/dev/null || true
            done
            
            firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null || true
            firewall-cmd --permanent --add-port=2022/tcp 2>/dev/null || true
            
            firewall-cmd --reload 2>/dev/null || true
            success "Firewalld configured"
            log_message "Firewalld configured successfully"
        else
            warning "Firewalld not found. Please configure firewall manually."
            log_message "WARNING: Firewalld not available"
        fi
    fi
}

install_dependencies() {
    CURRENT_STEP="dependencies"
    output "Updating system and installing dependencies..."
    log_message "Starting dependency installation"
    
    local missing_pkgs=()
    
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        export DEBIAN_FRONTEND=noninteractive
        
        show_progress "Updating package lists" 2 30
        apt-get update -qq || { error "Failed to update package lists"; exit 1; }
        
        show_progress "Upgrading packages" 3 30
        apt-get upgrade -y -qq || warning "Some packages failed to upgrade"
        
        show_progress "Installing base dependencies" 4 40
        apt-get install -y -qq \
            lsb-release ca-certificates apt-transport-https \
            software-properties-common gnupg2 curl zip unzip \
            git socat cron ufw openssl lsof jq htop \
            2>/dev/null || {
                error "Failed to install base dependencies"
                exit 1
            }
        
        if [[ "$ID" == "ubuntu" ]]; then
            show_progress "Adding PHP repository (Ubuntu)" 1 20
            add-apt-repository -y ppa:ondrej/php >/dev/null 2>&1 || {
                error "Failed to add PHP PPA"
                exit 1
            }
        else
            show_progress "Adding PHP repository (Debian)" 1 20
            if [[ ! -f /etc/apt/sources.list.d/php.list ]]; then
                curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/deb.sury.org-php.gpg
                echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
            fi
        fi
        apt-get update -qq
        
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        show_progress "Updating system packages" 3 30
        dnf update -y -q || { error "Failed to update packages"; exit 1; }
        
        show_progress "Installing EPEL repository" 1 20
        dnf install -y -q epel-release || warning "EPEL installation failed"
        
        if [[ "$ID" =~ ^(centos|almalinux|rocky)$ ]]; then
            show_progress "Adding Remi repository" 1 20
            dnf install -y -q "https://rpms.remirepo.net/enterprise/remi-release-${OS_VER%%.*}.rpm" || {
                error "Failed to add Remi repository"
                exit 1
            }
        fi
        
        show_progress "Installing base dependencies" 3 40
        dnf install -y -q \
            curl zip unzip git socat cronie openssl \
            lsof jq htop policycoreutils-python-utils \
            2>/dev/null || {
                error "Failed to install base dependencies"
                exit 1
            }
        
        systemctl enable --now crond 2>/dev/null || true
    fi
    
    success "Dependencies installed"
    log_message "Dependencies installation completed"
}

verify_dns() {
    local domain=$1
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local domain_ip=$(dig +short "$domain" 2>/dev/null | head -1)
        [[ -z "$domain_ip" ]] && domain_ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}')
        
        if [[ "$domain_ip" == "$SERVER_IP" ]]; then
            return 0
        fi
        
        warning "DNS check attempt $attempt/$max_attempts failed. Retrying in 5s..."
        sleep 5
        ((attempt++))
    done
    
    return 1
}

detect_and_configure_ssl() {
    local domain=$1
    local email=$2
    
    CURRENT_STEP="ssl_detection"
    output "Auto-detecting SSL requirements..."
    log_message "SSL Detection started for domain: $domain"
    
    if validate_ip "$domain"; then
        warning "IP address detected - SSL will use self-signed certificate"
        log_message "IP address detected, skipping Let's Encrypt"
        return 1
    fi
    
    SERVER_IP=$(curl -4 -s --max-time 10 ifconfig.me || curl -4 -s --max-time 10 icanhazip.com || echo "")
    if [[ -z "$SERVER_IP" ]]; then
        error "Could not determine server IP address"
        return 1
    fi
    
    if ! verify_dns "$domain"; then
        warning "Domain $domain does not resolve to this server ($SERVER_IP)"
        warning "Please ensure DNS A record points to this server"
        log_message "DNS validation failed for $domain"
        return 1
    fi
    
    if ss -tuln | grep -q ":80 "; then
        warning "Port 80 is in use. Checking if it's Nginx..."
        if systemctl is-active --quiet nginx; then
            systemctl stop nginx
            NGINX_STOPPED=true
            sleep 2
        else
            error "Port 80 is occupied by another service. Please free it first."
            return 1
        fi
    fi
    
    success "Domain validation passed - SSL can be configured"
    log_message "SSL validation passed for $domain"
    return 0
}

install_certbot() {
    if ! command -v certbot &>/dev/null; then
        show_progress "Installing Certbot" 2 20
        if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
            apt-get install -y -qq certbot python3-certbot-nginx 2>/dev/null || apt-get install -y -qq certbot
        elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
            dnf install -y -q certbot python3-certbot-nginx 2>/dev/null || dnf install -y -q certbot
        fi
    fi
}

install_panel() {
    CURRENT_STEP="panel_installation"
    output "Installing Pelican Panel..."
    log_message "Starting Panel installation"
    
    create_backup
    
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        show_progress "Installing PHP 8.3 and extensions" 5 50
        apt-get install -y -qq php8.3 php8.3-{cli,common,gd,mysql,mbstring,bcmath,xml,curl,zip,intl,sqlite3,fpm,redis,opcache} 2>/dev/null || {
            error "Failed to install PHP 8.3"
            exit 1
        }
        update-alternatives --set php /usr/bin/php8.3 2>/dev/null || true
        
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        show_progress "Installing PHP 8.3 and extensions" 5 50
        dnf module reset php -y -q
        dnf module enable php:remi-8.3 -y -q
        dnf install -y -q php php-{cli,common,gd,mysqlnd,mbstring,bcmath,xml,curl,zip,intl,pdo,fpm,redis,opcache} 2>/dev/null || {
            error "Failed to install PHP 8.3"
            exit 1
        }
    fi
    
    configure_php_fpm
    
    install_database
    
    install_composer
    
    download_panel
    
    configure_panel
    
    install_webserver
    
    setup_worker
    
    configure_firewall
    
    fix_permissions
    
    cleanup_installation
    
    display_completion_info
}

configure_php_fpm() {
    log_message "Configuring PHP-FPM optimization"
    
    local php_ini="/etc/php/8.3/fpm/php.ini"
    [[ "$PACKAGE_MANAGER" == "dnf" ]] && php_ini="/etc/php.ini"
    
    cp "$php_ini" "${php_ini}.backup" 2>/dev/null || true
    
    sed -i 's/memory_limit = .*/memory_limit = 512M/' "$php_ini"
    sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$php_ini"
    sed -i 's/max_input_vars = .*/max_input_vars = 3000/' "$php_ini"
    sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/' "$php_ini"
    sed -i 's/post_max_size = .*/post_max_size = 100M/' "$php_ini"
    
    cat >> "$php_ini" <<EOF

; OPcache Optimization
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.revalidate_freq=60
opcache.fast_shutdown=1
EOF

    systemctl restart php8.3-fpm 2>/dev/null || systemctl restart php-fpm 2>/dev/null || true
    log_message "PHP-FPM configured"
}

install_database() {
    show_progress "Installing MariaDB server" 3 30
    
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        apt-get install -y -qq mariadb-server 2>/dev/null || {
            error "MariaDB installation failed"
            exit 1
        }
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        dnf install -y -q mariadb-server 2>/dev/null || {
            error "MariaDB installation failed"
            exit 1
        }
    fi
    
    systemctl enable --now mariadb >/dev/null 2>&1
    
    mysql -u root -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
    mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" 2>/dev/null || true
    mysql -u root -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
    mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    log_message "MariaDB installed and secured"
}

install_composer() {
    if ! command -v composer &>/dev/null; then
        show_progress "Installing Composer" 2 20
        local composer_installer="/tmp/composer-setup.php"
        curl -fsS https://getcomposer.org/installer -o "$composer_installer"
        
        local expected_sig=$(curl -fsS https://composer.github.io/installer.sig)
        local actual_sig=$(sha384sum "$composer_installer" | awk '{print $1}')
        
        if [[ "$expected_sig" != "$actual_sig" ]]; then
            error "Composer installer signature verification failed"
            rm -f "$composer_installer"
            exit 1
        fi
        
        php "$composer_installer" --install-dir=/usr/local/bin --filename=composer --quiet
        rm -f "$composer_installer"
    fi
    
    export COMPOSER_HOME="/root/.composer"
    export COMPOSER_CACHE_DIR="/root/.composer/cache"
    mkdir -p "$COMPOSER_CACHE_DIR"
    log_message "Composer installed"
}

download_panel() {
    show_progress "Downloading Pelican Panel" 4 40
    
    mkdir -p "$PANEL_DIR"
    cd "$PANEL_DIR"
    
    local attempt=1
    local max_attempts=3
    local download_success=false
    
    while [[ $attempt -le $max_attempts ]] && [[ "$download_success" == "false" ]]; do
        if curl -fsSL --max-time 60 "https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz" | tar -xzf - 2>/dev/null; then
            download_success=true
        else
            warning "Download attempt $attempt failed. Retrying..."
            sleep 3
            ((attempt++))
        fi
    done
    
    if [[ "$download_success" == "false" ]]; then
        error "Failed to download Panel after $max_attempts attempts"
        exit 1
    fi
    
    log_message "Panel downloaded successfully"
}

configure_panel() {
    output "Configuring Panel..."
    CURRENT_STEP="panel_configuration"
    
    DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
    ADMIN_PASS=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
    
    echo ""
    echo -e "  ${COLOR_CYAN}Current detected IP: ${SERVER_IP:-$(curl -4 -s ifconfig.me)}${COLOR_NC}"
    
    local input_url=""
    while true; do
        read -rp "  Enter your FQDN or IP (default: ${SERVER_IP:-$(curl -4 -s ifconfig.me)}): " input_url
        input_url=${input_url:-${SERVER_IP:-$(curl -4 -s ifconfig.me)}}
        input_url=$(echo "$input_url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
        
        if [[ -n "$input_url" ]]; then
            break
        fi
        warning "Input cannot be empty"
    done
    
    FQDN="$input_url"
    SITE_URL="http://$FQDN"
    
    CONFIGURE_SSL=false
    SSL_TYPE="none"
    
    if ! validate_ip "$FQDN"; then
        echo ""
        read -rp "  ${COLOR_YELLOW}Configure SSL automatically? (Y/n): ${COLOR_NC}" ASK_SSL
        
        if [[ ! "$ASK_SSL" =~ [Nn] ]]; then
            local ssl_email=""
            while true; do
                read -rp "  Enter Email for Let's Encrypt: " ssl_email
                if validate_email "$ssl_email"; then
                    break
                fi
                warning "Invalid email format"
            done
            
            if detect_and_configure_ssl "$FQDN" "$ssl_email"; then
                CONFIGURE_SSL=true
                SSL_TYPE="letsencrypt"
                SITE_URL="https://$FQDN"
                SSL_EMAIL="$ssl_email"
            fi
        fi
    fi
    
    cp .env.example .env
    
    chmod 600 .env
    
    sed -i "s|APP_URL=.*|APP_URL=${SITE_URL}|g" .env
    sed -i "s|DB_DATABASE=.*|DB_DATABASE=pelican|g" .env
    sed -i "s|DB_USERNAME=.*|DB_USERNAME=pelican|g" .env
    sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|g" .env
    
    php artisan key:generate --force --quiet
    
    local db_retry=0
    while [[ $db_retry -lt 3 ]]; do
        mysql -u root -e "CREATE USER IF NOT EXISTS 'pelican'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null && break
        sleep 2
        ((db_retry++))
    done
    
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS pelican CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -u root -e "GRANT ALL PRIVILEGES ON pelican.* TO 'pelican'@'127.0.0.1' WITH GRANT OPTION;"
    mysql -u root -e "FLUSH PRIVILEGES;"
    
    php artisan migrate --seed --force --quiet 2>/dev/null || {
        error "Database migration failed"
        log_message "Migration failed - check database connection"
        exit 1
    }
    
    php artisan storage:link --quiet
    
    show_progress "Creating admin user" 1 10
    php artisan tinker --execute="\App\Models\User::where('email', 'admin@pelican.local')->delete();" --quiet 2>/dev/null || true
    
    php artisan p:user:make \
        --email="admin@pelican.local" \
        --username="admin" \
        --password="$ADMIN_PASS" \
        --admin=1 \
        --no-interaction \
        --quiet 2>/dev/null || {
            warning "Admin user creation might have failed - check logs"
        }
    
    cat > "$PANEL_DIR/.install_credentials" <<EOF
# Pelican Installation Credentials
# Generated: $(date)
# KEEP THIS FILE SECURE!

Admin URL: $SITE_URL
Admin Email: admin@pelican.local
Username: admin
Password: $ADMIN_PASS

Database: pelican
DB User: pelican
DB Password: $DB_PASS
EOF
    chmod 600 "$PANEL_DIR/.install_credentials"
    
    log_message "Panel configured successfully"
}

install_webserver() {
    show_progress "Installing and configuring Nginx" 3 30
    
    if [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        apt-get install -y -qq nginx 2>/dev/null || { error "Nginx installation failed"; exit 1; }
        rm -f /etc/nginx/sites-enabled/default
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        dnf install -y -q nginx 2>/dev/null || { error "Nginx installation failed"; exit 1; }
    fi
    
    systemctl enable --now nginx >/dev/null 2>&1
    
    if [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        systemctl enable --now php-fpm >/dev/null 2>&1
        if [[ -S /run/php-fpm/www.sock ]]; then
            FPM_SOCKET="unix:/run/php-fpm/www.sock"
        else
            FPM_SOCKET="unix:/var/run/php-fpm/www.sock"
        fi
    fi
    
    if [[ "$CONFIGURE_SSL" == "true" ]]; then
        install_certbot
        
        show_progress "Generating SSL certificate" 5 50
        
        systemctl stop nginx 2>/dev/null || true
        NGINX_STOPPED=true
        
        if certbot certonly --standalone -d "$FQDN" --email "$SSL_EMAIL" --agree-tos --non-interactive --quiet 2>/dev/null; then
            success "SSL Certificate generated successfully"
            log_message "SSL Certificate generated for $FQDN"
            
            (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --nginx") | crontab -
        else
            warning "SSL certificate generation failed - falling back to HTTP"
            CONFIGURE_SSL=false
            SITE_URL="http://$FQDN"
            systemctl start nginx 2>/dev/null || true
            NGINX_STOPPED=false
        fi
    fi
    
    generate_nginx_config
}

generate_nginx_config() {
    local nginx_conf="$NGINX_CONF_DIR/pelican.conf"
    
    local security_headers="
    add_header X-Frame-Options \"SAMEORIGIN\" always;
    add_header X-Content-Type-Options \"nosniff\" always;
    add_header X-XSS-Protection \"1; mode=block\" always;
    add_header Referrer-Policy \"strict-origin-when-cross-origin\" always;"
    
    if [[ "$CONFIGURE_SSL" == "true" ]]; then
        cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name $FQDN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $FQDN;
    root $PANEL_DIR/public;
    index index.php;
    
    ssl_certificate /etc/letsencrypt/live/$FQDN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$FQDN/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    
    $security_headers
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass $FPM_SOCKET;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    
    location ~ /\.ht {
        deny all;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF
    else
        cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name _;
    root $PANEL_DIR/public;
    index index.php;
    charset utf-8;
    
    $security_headers
    
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    
    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass $FPM_SOCKET;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF
    fi
    
    if [[ -n "$NGINX_ENABLED_DIR" ]]; then
        ln -sf "$nginx_conf" "$NGINX_ENABLED_DIR/pelican.conf"
    fi
    
    nginx -t 2>/dev/null || {
        error "Nginx configuration test failed"
        log_message "Nginx config test failed"
        exit 1
    }
    
    systemctl restart nginx >/dev/null 2>&1
    log_message "Nginx configured and restarted"
}

setup_worker() {
    show_progress "Setting up queue worker" 1 10
    
    cat > /etc/systemd/system/pelican-worker.service <<EOF
[Unit]
Description=Pelican Queue Worker
After=network-online.target mariadb.service redis.service
Wants=network-online.target

[Service]
User=$PHP_USER
Group=$PHP_USER
Restart=always
ExecStart=/usr/bin/php $PANEL_DIR/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3 --max-time=3600
StartLimitInterval=0
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable --now pelican-worker >/dev/null 2>&1
    
    (crontab -l 2>/dev/null | grep -v "pelican" || true; 
     echo "* * * * * php $PANEL_DIR/artisan schedule:run >> $LOG_DIR/schedule.log 2>&1") | crontab -
    
    log_message "Worker and cron configured"
}

cleanup_installation() {
    if [[ -d "$BACKUP_DIR" ]]; then
        read -rp "  Remove backup files? (y/N): " remove_backup
        if [[ "$remove_backup" =~ [Yy] ]]; then
            rm -rf "$BACKUP_DIR"
        fi
    fi
    
    if [[ "${NGINX_STOPPED:-false}" == "true" ]]; then
        systemctl start nginx 2>/dev/null || true
    fi
}

display_completion_info() {
    echo ""
    echo -e "${COLOR_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo -e "${COLOR_GREEN}                    ✓ PANEL INSTALLATION COMPLETE${COLOR_NC}"
    echo -e "${COLOR_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo ""
    echo -e "  ${COLOR_CYAN}Panel URL:${COLOR_NC}     $SITE_URL"
    echo -e "  ${COLOR_CYAN}Admin Email:${COLOR_NC}   admin@pelican.local"
    echo -e "  ${COLOR_CYAN}Username:${COLOR_NC}      admin"
    echo -e "  ${COLOR_CYAN}Password:${COLOR_NC}      [SECURED - Check file below]"
    echo ""
    echo -e "  ${COLOR_YELLOW}Credentials saved to:${COLOR_NC} $PANEL_DIR/.install_credentials"
    echo -e "  ${COLOR_RED}IMPORTANT:${COLOR_NC}    Delete this file after saving credentials!"
    echo ""
    echo -e "  ${COLOR_CYAN}Installation Path:${COLOR_NC} $PANEL_DIR"
    echo -e "  ${COLOR_CYAN}Log File:${COLOR_NC}          $LOG_FILE"
    echo -e "  ${COLOR_CYAN}SSL Status:${COLOR_NC}        $([ "$CONFIGURE_SSL" == "true" ] && echo "Enabled (Let's Encrypt)" || echo "Disabled (HTTP)")"
    echo ""
    echo -e "${COLOR_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    
    log_message "Installation completed successfully"
    log_message "Panel URL: $SITE_URL"
}

install_wings() {
    CURRENT_STEP="wings_installation"
    output "Installing Pelican Wings..."
    log_message "Starting Wings installation"
    
    configure_firewall
    
    echo ""
    read -rp "  ${COLOR_YELLOW}Are you using Cloudflare Proxy? (y/N): ${COLOR_NC}" USE_CF
    if [[ "$USE_CF" =~ [Yy] ]]; then
        warning "Ensure SSL mode is set to Full/Strict in Cloudflare"
        log_message "Cloudflare proxy detected"
    fi
    
    if ! command -v docker &>/dev/null; then
        show_progress "Installing Docker" 4 40
        curl -fsSL https://get.docker.com | CHANNEL=stable sh 2>/dev/null || {
            error "Docker installation failed"
            exit 1
        }
    else
        output "Docker already installed, skipping..."
    fi
    
    systemctl enable --now docker >/dev/null 2>&1
    
    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "$SUDO_USER" 2>/dev/null || true
    fi
    
    show_progress "Downloading Wings binary" 3 30
    mkdir -p /etc/pelican /var/run/wings
    
    local wings_url="https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_amd64"
    curl -fsSL -o /usr/local/bin/wings "$wings_url" || {
        error "Failed to download Wings binary"
        exit 1
    }
    chmod +x /usr/local/bin/wings
    
    if ! /usr/local/bin/wings --version &>/dev/null; then
        error "Wings binary verification failed"
        exit 1
    fi
    
    if ss -tuln | grep -q ":8080 "; then
        output "Port 8080 is occupied. Attempting to free..."
        local pid=$(ss -tulnp | grep ":8080 " | awk '{print $7}' | cut -d',' -f2 | cut -d'=' -f2)
        if [[ -n "$pid" ]]; then
            kill -15 "$pid" 2>/dev/null || true
            sleep 2
        fi
    fi
    
    cat > /etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pelican Wings Daemon
After=docker.service network-online.target
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pelican
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
ExecStop=/bin/kill -s SIGTERM \$MAINPID
Restart=on-failure
RestartSec=5
StartLimitInterval=600
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload >/dev/null 2>&1
    
    setup_wings_ssl
    
    success "Wings Installation Complete"
    
    handle_wings_deploy
}

setup_wings_ssl() {
    echo ""
    read -rp "  ${COLOR_YELLOW}Configure SSL for Wings node? (y/N): ${COLOR_NC}" CONFIRM_SSL
    
    if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
        local node_fqdn=""
        while true; do
            read -rp "  Enter Node FQDN (e.g. node1.example.com): " node_fqdn
            if validate_fqdn "$node_fqdn"; then
                break
            fi
            warning "Invalid FQDN format"
        done
        
        local ssl_email=""
        while true; do
            read -rp "  Enter Email for Let's Encrypt: " ssl_email
            if validate_email "$ssl_email"; then
                break
            fi
            warning "Invalid email format"
        done
        
        install_certbot
        
        show_progress "Generating SSL certificate" 5 50
        systemctl stop nginx 2>/dev/null || true
        
        if certbot certonly --standalone -d "$node_fqdn" --email "$ssl_email" --agree-tos --non-interactive --quiet 2>/dev/null; then
            success "SSL Certificate Generated!"
            echo ""
            echo -e "  ${COLOR_CYAN}Certificate:${COLOR_NC} /etc/letsencrypt/live/$node_fqdn/fullchain.pem"
            echo -e "  ${COLOR_CYAN}Private Key:${COLOR_NC} /etc/letsencrypt/live/$node_fqdn/privkey.pem"
            echo ""
            warning "Use these paths in Panel > Node > Configuration > SSL"
            log_message "Wings SSL configured for $node_fqdn"
        else
            error "SSL certificate generation failed"
        fi
        
        systemctl start nginx 2>/dev/null || true
    fi
}

handle_wings_deploy() {
    echo ""
    echo -e "  ${COLOR_CYAN}Next Steps:${COLOR_NC}"
    echo -e "  1. Go to Admin -> Nodes -> Create New in Panel"
    echo -e "  2. Copy the auto-deploy command"
    echo ""
    read -rp "  ${COLOR_YELLOW}Paste auto-deploy command (or press Enter to skip): ${COLOR_NC}" DEPLOY_CMD
    
    if [[ -n "$DEPLOY_CMD" ]]; then
        if [[ "$DEPLOY_CMD" =~ ^wings[[:space:]]configure[[:space:]]--panel-url ]]; then
            eval "$DEPLOY_CMD" && {
                systemctl enable --now wings >/dev/null 2>&1
                success "Wings Configured & Started!"
                log_message "Wings auto-deployed successfully"
            } || {
                error "Auto-deploy failed"
                log_message "Wings auto-deploy failed"
            }
        else
            warning "Invalid deploy command format"
            systemctl enable wings >/dev/null 2>&1
            output "Wings enabled. Start manually with: systemctl start wings"
        fi
    else
        systemctl enable wings >/dev/null 2>&1
        output "Wings enabled. Start manually with: systemctl start wings"
    fi
}

fix_permissions() {
    output "Fixing Panel Permissions..."
    chmod -R 755 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache" 2>/dev/null || true
    chown -R "$PHP_USER:$PHP_USER" "$PANEL_DIR" 2>/dev/null || true
    
    chmod 600 "$PANEL_DIR/.env" 2>/dev/null || true
    chmod 600 "$PANEL_DIR/.install_credentials" 2>/dev/null || true
    
    success "Permissions fixed"
    log_message "Permissions fixed"
}

troubleshooting() {
    print_header
    echo -e "${COLOR_PURPLE}                    TROUBLESHOOTING MENU${COLOR_NC}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_NC} Check Services Status"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_NC} Fix Panel Permissions"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_NC} View Panel Logs"
    echo -e "  ${COLOR_CYAN}[4]${COLOR_NC} View Nginx Logs"
    echo -e "  ${COLOR_CYAN}[5]${COLOR_NC} Check Database Connectivity"
    echo -e "  ${COLOR_CYAN}[6]${COLOR_NC} Test Email Configuration"
    echo -e "  ${COLOR_CYAN}[7]${COLOR_NC} Check Disk Space"
    echo -e "  ${COLOR_CYAN}[8]${COLOR_NC} View System Resources"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_NC} Back to Main Menu"
    echo ""
    read -rp "  Select option: " t_action
    
    echo ""
    
    case $t_action in
        1)
            echo -e "${COLOR_CYAN}Service Status:${COLOR_NC}\n"
            systemctl is-active --quiet nginx && echo -e "  ${COLOR_GREEN}●${COLOR_NC} Nginx: Running" || echo -e "  ${COLOR_RED}●${COLOR_NC} Nginx: Stopped"
            systemctl is-active --quiet pelican-worker && echo -e "  ${COLOR_GREEN}●${COLOR_NC} Queue Worker: Running" || echo -e "  ${COLOR_RED}●${COLOR_NC} Queue Worker: Stopped"
            systemctl is-active --quiet docker && echo -e "  ${COLOR_GREEN}●${COLOR_NC} Docker: Running" || echo -e "  ${COLOR_RED}●${COLOR_NC} Docker: Stopped"
            systemctl is-active --quiet mariadb && echo -e "  ${COLOR_GREEN}●${COLOR_NC} MariaDB: Running" || echo -e "  ${COLOR_RED}●${COLOR_NC} MariaDB: Stopped"
            systemctl is-active --quiet wings && echo -e "  ${COLOR_GREEN}●${COLOR_NC} Wings: Running" || echo -e "  ${COLOR_RED}●${COLOR_NC} Wings: Stopped"
            (crontab -l 2>/dev/null | grep -q "pelican") && echo -e "  ${COLOR_GREEN}●${COLOR_NC} Cron: Installed" || echo -e "  ${COLOR_RED}●${COLOR_NC} Cron: Missing"
            ;;
        2)
            fix_permissions
            ;;
        3)
            if [[ -f "$PANEL_DIR/storage/logs/laravel.log" ]]; then
                echo -e "${COLOR_CYAN}Last 100 lines of Panel logs:${COLOR_NC}\n"
                tail -n 100 "$PANEL_DIR/storage/logs/laravel.log"
            else
                error "Panel log file not found"
            fi
            ;;
        4)
            if [[ -f "/var/log/nginx/error.log" ]]; then
                echo -e "${COLOR_CYAN}Last 50 error lines from Nginx:${COLOR_NC}\n"
                tail -n 50 "/var/log/nginx/error.log"
            else
                error "Nginx error log not found"
            fi
            ;;
        5)
            output "Checking Database Connection..."
            if [[ -f "$PANEL_DIR/.env" ]]; then
                cd "$PANEL_DIR"
                php artisan db:monitor 2>/dev/null || {
                    error "Database connection failed"
                    local db_pass=$(grep DB_PASSWORD .env | cut -d'=' -f2)
                    mysql -u pelican -p"$db_pass" -e "SELECT 1;" pelican 2>/dev/null && success "Manual DB connection OK" || error "Manual DB connection failed"
                }
            else
                error ".env file not found"
            fi
            ;;
        6)
            if [[ -f "$PANEL_DIR/.env" ]]; then
                cd "$PANEL_DIR"
                php artisan tinker --execute="Mail::raw('Test email from Pelican', function(\$message) { \$message->to('test@example.com')->subject('Test'); });" 2>/dev/null && success "Email test initiated" || error "Email test failed"
            fi
            ;;
        7)
            echo -e "${COLOR_CYAN}Disk Space:${COLOR_NC}"
            df -h /
            echo ""
            echo -e "${COLOR_CYAN}Panel Directory Size:${COLOR_NC}"
            du -sh "$PANEL_DIR" 2>/dev/null || echo "Not installed"
            ;;
        8)
            echo -e "${COLOR_CYAN}System Resources:${COLOR_NC}\n"
            free -h
            echo ""
            top -bn1 | grep "Cpu(s)" || echo "CPU info unavailable"
            ;;
        0)
            return
            ;;
        *)
            error "Invalid option"
            ;;
    esac
    
    echo ""
    read -rp "  Press Enter to continue..."
}

uninstall_panel() {
    output "Uninstalling Pelican Panel..."
    log_message "Starting Panel uninstallation"
    
    read -rp "Are you sure? This will DELETE all data! Type 'DELETE' to confirm: " confirm
    if [[ "$confirm" != "DELETE" ]]; then
        warning "Uninstall cancelled"
        return
    fi
    
    if [[ -d "$PANEL_DIR" ]]; then
        output "Creating final backup..."
        tar -czf "/var/backups/pelican-final-$(date +%Y%m%d).tar.gz" "$PANEL_DIR" 2>/dev/null || true
    fi
    
    show_progress "Removing Panel files" 2 20
    rm -rf "$PANEL_DIR"
    
    show_progress "Removing Nginx configuration" 1 10
    rm -f "$NGINX_CONF_DIR/pelican.conf"
    [[ -n "$NGINX_ENABLED_DIR" ]] && rm -f "$NGINX_ENABLED_DIR/pelican.conf"
    systemctl restart nginx >/dev/null 2>&1
    
    show_progress "Removing Queue Worker" 1 10
    systemctl disable --now pelican-worker 2>/dev/null || true
    rm -f /etc/systemd/system/pelican-worker.service
    systemctl daemon-reload >/dev/null 2>&1
    
    show_progress "Removing Database" 1 10
    mysql -u root -e "DROP DATABASE IF EXISTS pelican; DROP USER IF EXISTS 'pelican'@'127.0.0.1';" 2>/dev/null || true
    
    # Cleanup cron
    crontab -l 2>/dev/null | grep -v "pelican" | crontab - 2>/dev/null || true
    
    success "Panel Uninstalled Successfully"
    log_message "Panel uninstalled"
}

uninstall_wings() {
    output "Uninstalling Pelican Wings..."
    log_message "Starting Wings uninstallation"
    
    read -rp "Stop and remove Wings? (y/N): " confirm
    [[ ! "$confirm" =~ [Yy] ]] && return
    
    show_progress "Stopping Wings service" 1 10
    systemctl disable --now wings 2>/dev/null || true
    
    show_progress "Removing Wings files" 1 10
    rm -f /usr/local/bin/wings
    rm -f /etc/systemd/system/wings.service
    rm -rf /etc/pelican
    rm -rf /var/run/wings
    systemctl daemon-reload >/dev/null 2>&1
    
    success "Wings Uninstalled Successfully"
    log_message "Wings uninstalled"
}

perform_uninstall() {
    print_header
    echo -e "${COLOR_PURPLE}                    UNINSTALL MENU${COLOR_NC}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_NC} Uninstall Panel Only"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_NC} Uninstall Wings Only"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_NC} Uninstall Both"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_NC} Back to Main Menu"
    echo ""
    read -rp "  Select option: " action
    
    case $action in
        1) uninstall_panel ;;
        2) uninstall_wings ;;
        3) 
            uninstall_panel
            uninstall_wings
            ;;
        0) return ;;
        *) error "Invalid option" ;;
    esac
    
    echo ""
    read -rp "  Press Enter to continue..."
}

show_main_menu() {
    print_header
    echo -e "${COLOR_PURPLE}                    MAIN MENU${COLOR_NC}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_NC} Install Panel Only"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_NC} Install Wings Only"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_NC} Install Panel + Wings)"
    echo -e "  ${COLOR_CYAN}[4]${COLOR_NC} Uninstall"
    echo -e "  ${COLOR_CYAN}[5]${COLOR_NC} Troubleshooting"
    echo -e "  ${COLOR_CYAN}[6]${COLOR_NC} View Installation Log"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_NC} Exit"
    echo ""
    read -rp "  Select option: " action
}

view_log() {
    if [[ -f "$LOG_FILE" ]]; then
        less "$LOG_FILE"
    else
        error "Log file not found"
        sleep 1
    fi
}

main() {
    check_root
    init_logging
    detect_os
    
    local done=false
    while [[ "$done" == false ]]; do
        show_main_menu
        
        case $action in
            1)
                echo ""
                install_dependencies
                install_panel
                echo ""
                read -rp "  Press Enter to return to menu..."
                ;;
            2)
                echo ""
                install_dependencies
                install_wings
                echo ""
                read -rp "  Press Enter to return to menu..."
                ;;
            3)
                echo ""
                install_dependencies
                install_panel
                install_wings
                echo ""
                read -rp "  Press Enter to return to menu..."
                ;;
            4)
                perform_uninstall
                ;;
            5)
                troubleshooting
                ;;
            6)
                view_log
                ;;
            0)
                echo ""
                echo -e "  ${COLOR_GREEN}Thank you for using Pelican Installer - Martin 2026${COLOR_NC}"
                echo -e "  ${COLOR_CYAN}Log saved to: $LOG_FILE${COLOR_NC}"
                echo ""
                done=true
                ;;
            *)
                error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Start
main
