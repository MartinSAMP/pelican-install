#!/bin/bash

# Pelican Panel & Wings Installer
# Copyright (c) 2026 Martin
# Supports Debian 11/12, Ubuntu 22.04/24.04, AlmaLinux 9/10, Rocky Linux 9/10

set -e

# Versioning
export SCRIPT_RELEASE="v1.0"
export PANEL_DIR="/var/www/pelican"
export SITE_URL="http://$(curl -4 -s ifconfig.me)"

# Colors
COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_PURPLE='\033[0;35m'
COLOR_NC='\033[0m'

# Progress bar variables
CURRENT_STEP=0
TOTAL_STEPS=0

# -------------- Visual functions -------------- #
print_header() {
    clear
    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo -e "${COLOR_PURPLE}           PELICAN INSTALLER - MARTIN 2026${COLOR_NC}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo ""
    echo -e "  ${COLOR_BLUE}OS:${COLOR_NC} $OS $OS_VER"
    echo -e "  ${COLOR_BLUE}Script:${COLOR_NC} $SCRIPT_RELEASE"
    echo -e "  ${COLOR_BLUE}Website:${COLOR_NC} https://pelican.dev"
    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo ""
}

output() {
    echo -e "${COLOR_BLUE}➜${COLOR_NC} $1"
}

success() {
    echo ""
    echo -e "  ${COLOR_GREEN}✓ SUCCESS:${COLOR_NC} $1"
    echo ""
}

error() {
    echo ""
    echo -e "  ${COLOR_RED}✗ ERROR:${COLOR_NC} $1" 1>&2
    echo ""
}

warning() {
    echo ""
    echo -e "  ${COLOR_YELLOW}⚠ WARNING:${COLOR_NC} $1"
    echo ""
}

# Progress bar function
progress_bar() {
    local current=$1
    local total=$2
    local label=$3
    local width=40

    if [ $total -eq 0 ]; then
        total=1
    fi

    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r  ${COLOR_CYAN}[${COLOR_NC}"

    for ((i = 0; i < filled; i++)); do
        printf "${COLOR_GREEN}█${COLOR_NC}"
    done

    for ((i = 0; i < empty; i++)); do
        printf "${COLOR_CYAN}░${COLOR_NC}"
    done

    printf "${COLOR_CYAN}]${COLOR_NC} ${COLOR_YELLOW}%3d%%${COLOR_NC} - %s" "$percentage" "$label"

    if [ $current -eq $total ]; then
        echo ""
    fi
}

show_progress() {
    local message=$1
    local duration=${2:-1}
    local steps=${3:-20}

    output "$message"

    for ((i = 1; i <= steps; i++)); do
        progress_bar $i $steps "$message"
        sleep $(echo "scale=3; $duration / $steps" | bc -l 2>/dev/null || echo "0.05")
    done
    echo ""
}

# -------------- Core functions -------------- #
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

detect_os() {
    show_progress "Detecting operating system" 0.5 10

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_VER=$VERSION_ID
    else
        error "Unsupported OS: could not detect os-release"
        exit 1
    fi

    case "$ID" in
        debian|ubuntu)
            export PACKAGE_MANAGER="apt"
            export PHP_USER="www-data"
            export NGINX_USER="www-data"
            export NGINX_CONF_DIR="/etc/nginx/sites-available"
            export NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
            export FPM_SOCKET="unix:/run/php/php8.3-fpm.sock"
            ;;
        almalinux|rocky|centos|rhel)
            export PACKAGE_MANAGER="dnf"
            export PHP_USER="nginx"
            export NGINX_USER="nginx"
            export NGINX_CONF_DIR="/etc/nginx/conf.d"
            export NGINX_ENABLED_DIR=""
            export FPM_SOCKET="unix:/run/php-fpm/www.sock"
            ;;
        *)
            error "Unsupported OS: $ID"
            exit 1
            ;;
    esac

    success "OS detected: $OS $OS_VER"
}

# Auto Firewall Configuration
configure_firewall() {
    output "Configuring Firewall Rules..."

    # Required ports for Pelican
    # Panel: 80, 443 (HTTP/HTTPS)
    # Wings: 8080 (Daemon), 2022 (SFTP)

    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        if command -v ufw &> /dev/null; then
            # Reset UFW to default
            ufw --force reset 2>/dev/null || true

            # Default policies
            ufw default deny incoming
            ufw default allow outgoing

            # Allow SSH (prevent lockout)
            ufw allow 22/tcp comment 'SSH'

            # Allow Panel ports
            ufw allow 80/tcp comment 'HTTP - Pelican Panel'
            ufw allow 443/tcp comment 'HTTPS - Pelican Panel'

            # Allow Wings ports
            ufw allow 8080/tcp comment 'Wings Daemon'
            ufw allow 2022/tcp comment 'Wings SFTP'

            # Enable firewall
            ufw --force enable

            success "UFW Firewall configured with auto-rules"
        fi
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        if command -v firewall-cmd &> /dev/null; then
            # Start and enable firewalld
            systemctl start firewalld 2>/dev/null || true
            systemctl enable firewalld 2>/dev/null || true

            # Add services
            firewall-cmd --permanent --add-service=http 2>/dev/null || true
            firewall-cmd --permanent --add-service=https 2>/dev/null || true
            firewall-cmd --permanent --add-service=ssh 2>/dev/null || true

            # Add custom ports for Wings
            firewall-cmd --permanent --add-port=8080/tcp 2>/dev/null || true
            firewall-cmd --permanent --add-port=2022/tcp 2>/dev/null || true

            # Reload firewall
            firewall-cmd --reload 2>/dev/null || true

            success "Firewalld configured with auto-rules"
        fi
    fi
}

install_dependencies() {
    output "Updating system and installing dependencies..."

    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        show_progress "Updating package lists" 2 30
        apt update -qq > /dev/null 2>&1

        show_progress "Upgrading packages" 3 30
        apt upgrade -y -qq > /dev/null 2>&1

        show_progress "Installing base dependencies" 4 40
        apt install -y -qq lsb-release ca-certificates apt-transport-https             software-properties-common gnupg2 curl zip unzip git socat             cron ufw bc > /dev/null 2>&1

        # PHP Repo
        if [ "$ID" == "ubuntu" ]; then
            show_progress "Adding PHP repository (Ubuntu)" 1 20
            add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
            apt update -qq > /dev/null 2>&1
        else
            show_progress "Adding PHP repository (Debian)" 1 20
            if [ ! -f /etc/apt/sources.list.d/php.list ]; then
                curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg 2>/dev/null
                sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
                apt update -qq > /dev/null 2>&1
            fi
        fi

    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        show_progress "Updating system packages" 3 30
        dnf update -y -q > /dev/null 2>&1

        show_progress "Installing EPEL repository" 1 20
        dnf install -y -q epel-release > /dev/null 2>&1

        # Remi Repo for PHP
        if [ "$ID" == "centos" ] || [ "$ID" == "almalinux" ] || [ "$ID" == "rocky" ]; then
            show_progress "Adding Remi repository" 1 20
            dnf install -y -q https://rpms.remirepo.net/enterprise/remi-release-${OS_VER%%.*}.rpm > /dev/null 2>&1
        fi

        show_progress "Installing base dependencies" 3 40
        dnf install -y -q curl zip unzip git socat cronie bc > /dev/null 2>&1
        systemctl enable --now crond > /dev/null 2>&1
    fi

    success "Dependencies installed"
}

# Auto SSL Detection and Configuration
detect_and_configure_ssl() {
    local domain=$1
    local email=$2

    output "Auto-detecting SSL requirements..."

    # Check if domain is an IP
    if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        warning "IP address detected - SSL will use self-signed certificate"
        return 1
    fi

    # Check if domain resolves to this server
    local server_ip=$(curl -4 -s ifconfig.me)
    local domain_ip=$(dig +short "$domain" 2>/dev/null || echo "")

    if [ -z "$domain_ip" ]; then
        domain_ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' || echo "")
    fi

    if [ "$domain_ip" != "$server_ip" ]; then
        warning "Domain $domain does not resolve to this server ($server_ip)"
        warning "Please ensure DNS A record points to this server for SSL"
        return 1
    fi

    # Check if port 80 is available
    if lsof -i :80 -t >/dev/null 2>&1; then
        warning "Port 80 is in use. Stopping services temporarily..."
        systemctl stop nginx 2>/dev/null || true
        sleep 2
    fi

    success "Domain validation passed - SSL can be configured"
    return 0
}

install_panel() {
    output "Installing Pelican Panel..."

    # Install PHP & Extensions
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        show_progress "Installing PHP 8.3 and extensions" 5 50
        apt install -y -qq php8.3 php8.3-{cli,common,gd,mysql,mbstring,bcmath,xml,curl,zip,intl,sqlite3,fpm} > /dev/null 2>&1
        update-alternatives --set php /usr/bin/php8.3 2>/dev/null || true
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        show_progress "Installing PHP 8.3 and extensions" 5 50
        dnf module reset php -y -q > /dev/null 2>&1
        dnf module enable php:remi-8.3 -y -q > /dev/null 2>&1
        dnf install -y -q php php-{cli,common,gd,mysqlnd,mbstring,bcmath,xml,curl,zip,intl,pdo,fpm} > /dev/null 2>&1
    fi

    # Database
    show_progress "Installing MariaDB server" 3 30
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        apt install -y -qq mariadb-server > /dev/null 2>&1
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        dnf install -y -q mariadb-server > /dev/null 2>&1
    fi
    systemctl enable --now mariadb > /dev/null 2>&1

    # Composer
    if ! command -v composer &> /dev/null; then
        show_progress "Installing Composer" 2 20
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer > /dev/null 2>&1
    fi

    # Download Panel
    show_progress "Downloading Pelican Panel" 4 40
    mkdir -p "$PANEL_DIR"
    cd "$PANEL_DIR"
    curl -sL https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xzf - 2>/dev/null

    # Permissions
    chmod -R 755 storage/* bootstrap/cache/ 2>/dev/null || true
    if [ "$PACKAGE_MANAGER" == "dnf" ]; then
        chown -R nginx:nginx "$PANEL_DIR"
        PHP_USER="nginx"
    else
        chown -R www-data:www-data "$PANEL_DIR"
        PHP_USER="www-data"
    fi

    # Install Deps
    show_progress "Installing PHP dependencies" 5 50
    export COMPOSER_ALLOW_SUPERUSER=1
    composer install --no-dev --optimize-autoloader --quiet > /dev/null 2>&1

    # Setup Config
    output "Configuring Panel..."
    cp .env.example .env

    # Generate Passwords
    DB_PASS=$(openssl rand -base64 16)
    ADMIN_PASS=$(openssl rand -base64 12)

    # URL Input with validation
    echo ""
    echo -e "  ${COLOR_CYAN}Current detected IP: $(curl -4 -s ifconfig.me)${COLOR_NC}"
    echo -n "  Enter your FQDN or IP (default: $(curl -4 -s ifconfig.me)): "
    read -r input_url

    if [[ ! -z "$input_url" ]]; then
        input_url=$(echo "$input_url" | sed -e 's|^[^/]*//||' -e 's|/.*$||')
        SITE_URL="http://$input_url"
        FQDN="$input_url"
    else
        FQDN=$(curl -4 -s ifconfig.me)
        SITE_URL="http://$FQDN"
    fi

    # Auto SSL Detection
    CONFIGURE_SSL=false
    SSL_TYPE="none"

    if ! [[ "$FQDN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo ""
        echo -n "  ${COLOR_YELLOW}Configure SSL automatically? (Y/n): ${COLOR_NC}"
        read -r ASK_SSL

        if [[ ! "$ASK_SSL" =~ [Nn] ]]; then
            echo -n "  Enter Email for Let's Encrypt: "
            read -r SSL_EMAIL

            if detect_and_configure_ssl "$FQDN" "$SSL_EMAIL"; then
                CONFIGURE_SSL=true
                SSL_TYPE="letsencrypt"
                SITE_URL="https://$FQDN"
            fi
        fi
    fi

    # Update .env
    sed -i "s|APP_URL=http://localhost|APP_URL=${SITE_URL}|g" .env
    sed -i "s|APP_URL=http://panel.test|APP_URL=${SITE_URL}|g" .env
    sed -i "s|DB_DATABASE=panel|DB_DATABASE=pelican|g" .env
    sed -i "s|DB_USERNAME=pelican|DB_USERNAME=pelican|g" .env
    sed -i "s|DB_PASSWORD=|DB_PASSWORD=${DB_PASS}|g" .env

    php artisan key:generate --force --quiet > /dev/null 2>&1

    # Database Setup
    show_progress "Setting up database" 2 20
    mysql -u root -e "CREATE OR REPLACE USER 'pelican'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS pelican;" 2>/dev/null
    mysql -u root -e "GRANT ALL PRIVILEGES ON pelican.* TO 'pelican'@'127.0.0.1' WITH GRANT OPTION;" 2>/dev/null
    mysql -u root -e "FLUSH PRIVILEGES;" 2>/dev/null

    php artisan migrate --seed --force --quiet > /dev/null 2>&1
    php artisan storage:link --quiet > /dev/null 2>&1

    # Create User
    show_progress "Creating admin user" 1 10
    php artisan tinker --execute="\\App\\Models\\User::where('email', 'admin@pelican.local')->delete();" --quiet 2>/dev/null || true
    php artisan p:user:make --email="admin@pelican.local" --username="admin" --password="$ADMIN_PASS" --admin=1 --no-interaction --quiet > /dev/null 2>&1

    # Nginx
    show_progress "Installing and configuring Nginx" 3 30
    if [ "$PACKAGE_MANAGER" == "apt" ]; then
        apt install -y -qq nginx > /dev/null 2>&1
        rm -f /etc/nginx/sites-enabled/default
    elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
        dnf install -y -q nginx > /dev/null 2>&1
    fi

    systemctl enable --now nginx > /dev/null 2>&1

    # Determine proper PHP-FPM socket path
    if [ "$PACKAGE_MANAGER" == "dnf" ]; then
        systemctl enable --now php-fpm > /dev/null 2>&1
        if [ -S /run/php-fpm/www.sock ]; then
            FPM_SOCKET="unix:/run/php-fpm/www.sock"
        else
            FPM_SOCKET="unix:/var/run/php-fpm/www.sock"
        fi
    fi

    # SSL Certificate Generation
    if [ "$CONFIGURE_SSL" = true ]; then
        show_progress "Installing Certbot" 2 20
        if [ "$PACKAGE_MANAGER" == "apt" ]; then
            apt install -y -qq certbot > /dev/null 2>&1
        elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
            dnf install -y -q certbot > /dev/null 2>&1
        fi

        show_progress "Generating SSL certificate" 5 50
        systemctl stop nginx 2>/dev/null || true

        if certbot certonly --standalone -d "$FQDN" --email "$SSL_EMAIL" --agree-tos --non-interactive --quiet 2>/dev/null; then
            success "SSL Certificate generated successfully"
        else
            warning "SSL certificate generation failed - falling back to HTTP"
            CONFIGURE_SSL=false
            SITE_URL="http://$FQDN"
            systemctl start nginx 2>/dev/null || true
        fi
    fi

    # Generate Nginx Config
    if [ "$CONFIGURE_SSL" = true ]; then
        cat <<EOF > $NGINX_CONF_DIR/pelican.conf
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
    else
        cat <<EOF > $NGINX_CONF_DIR/pelican.conf
server {
    listen 80;
    server_name _;
    root $PANEL_DIR/public;
    index index.php;
    charset utf-8;

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

    if [ ! -z "$NGINX_ENABLED_DIR" ]; then
        ln -sf $NGINX_CONF_DIR/pelican.conf $NGINX_ENABLED_DIR/pelican.conf
    fi

    systemctl restart nginx > /dev/null 2>&1

    # Queue Worker
    show_progress "Setting up queue worker" 1 10
    cat <<EOF > /etc/systemd/system/pelican-worker.service
[Unit]
Description=Pelican Queue Worker
After=network-online.target
Wants=network-online.target

[Service]
User=$PHP_USER
Group=$PHP_USER
Restart=always
ExecStart=/usr/bin/php $PANEL_DIR/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload > /dev/null 2>&1
    systemctl enable --now pelican-worker > /dev/null 2>&1

    # Cron
    (crontab -l 2>/dev/null; echo "* * * * * php $PANEL_DIR/artisan schedule:run >> /dev/null 2>&1") | crontab - > /dev/null 2>&1

    # Configure Firewall
    configure_firewall

    fix_permissions > /dev/null 2>&1

    # Final Success Display
    echo ""
    echo -e "${COLOR_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo -e "${COLOR_GREEN}                    ✓ PANEL INSTALLATION COMPLETE${COLOR_NC}"
    echo -e "${COLOR_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
    echo ""
    echo -e "  ${COLOR_CYAN}Panel URL:${COLOR_NC}     $SITE_URL"
    echo -e "  ${COLOR_CYAN}Admin Email:${COLOR_NC}   admin@pelican.local"
    echo -e "  ${COLOR_CYAN}Username:${COLOR_NC}      admin"
    echo -e "  ${COLOR_CYAN}Password:${COLOR_NC}      $ADMIN_PASS"
    echo ""
    echo -e "  ${COLOR_YELLOW}Database Credentials:${COLOR_NC}"
    echo -e "  ${COLOR_CYAN}Database:${COLOR_NC}      pelican"
    echo -e "  ${COLOR_CYAN}DB User:${COLOR_NC}       pelican"
    echo -e "  ${COLOR_CYAN}DB Password:${COLOR_NC}   $DB_PASS"
    echo ""
    echo -e "  ${COLOR_CYAN}Installation Path:${COLOR_NC} $PANEL_DIR"
    echo -e "  ${COLOR_CYAN}SSL Status:${COLOR_NC}      $([ "$CONFIGURE_SSL" = true ] && echo "Enabled (Let's Encrypt)" || echo "Disabled (HTTP)")"
    echo ""
    echo -e "${COLOR_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_NC}"
}

install_wings() {
    output "Installing Pelican Wings..."

    # Configure Firewall
    configure_firewall

    # Cloudflare Question
    echo ""
    echo -n "  ${COLOR_YELLOW}Are you using Cloudflare Proxy? (y/N): ${COLOR_NC}"
    read -r USE_CF
    if [[ "$USE_CF" =~ [Yy] ]]; then
        warning "Ensure SSL mode is set to Full/Strict in Cloudflare"
    fi

    # Docker
    show_progress "Installing Docker" 4 40
    curl -sSL https://get.docker.com/ | CHANNEL=stable sh > /dev/null 2>&1
    systemctl enable --now docker > /dev/null 2>&1

    # Wings Binary
    show_progress "Downloading Wings binary" 3 30
    mkdir -p /etc/pelican /var/run/wings
    curl -sL -o /usr/local/bin/wings "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_amd64"
    chmod u+x /usr/local/bin/wings

    # Check and kill likely existing wings process
    if lsof -i :8080 -t >/dev/null 2>&1; then
        output "Freeing port 8080..."
        kill -9 $(lsof -i :8080 -t) 2>/dev/null || true
    fi

    # Systemd
    cat <<EOF > /etc/systemd/system/wings.service
[Unit]
Description=Pelican Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pelican
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload > /dev/null 2>&1

    # Wings SSL Setup
    echo ""
    echo -n "  ${COLOR_YELLOW}Configure SSL for Wings node? (y/N): ${COLOR_NC}"
    read -r CONFIRM_SSL

    if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
        echo -n "  Enter Node FQDN (e.g. node1.example.com): "
        read -r NODE_FQDN
        echo -n "  Enter Email for Let's Encrypt: "
        read -r SSL_EMAIL

        show_progress "Installing Certbot" 2 20
        if [ "$PACKAGE_MANAGER" == "apt" ]; then
            apt install -y -qq certbot > /dev/null 2>&1
        elif [ "$PACKAGE_MANAGER" == "dnf" ]; then
            dnf install -y -q certbot > /dev/null 2>&1
        fi

        show_progress "Generating SSL certificate" 5 50
        systemctl stop nginx 2>/dev/null || true

        if certbot certonly --standalone -d "$NODE_FQDN" --email "$SSL_EMAIL" --agree-tos --non-interactive --quiet 2>/dev/null; then
            success "SSL Certificate Generated!"
            echo ""
            echo -e "  ${COLOR_CYAN}Certificate:${COLOR_NC} /etc/letsencrypt/live/$NODE_FQDN/fullchain.pem"
            echo -e "  ${COLOR_CYAN}Private Key:${COLOR_NC} /etc/letsencrypt/live/$NODE_FQDN/privkey.pem"
            echo ""
            warning "Use these paths in Panel > Node > Configuration > SSL"
        else
            error "SSL certificate generation failed"
        fi

        systemctl start nginx 2>/dev/null || true
    fi

    success "Wings Installation Complete"
    echo ""
    echo -e "  ${COLOR_CYAN}Next Steps:${COLOR_NC}"
    echo -e "  1. Go to Admin -> Nodes -> Create New in Panel"
    echo -e "  2. Copy the auto-deploy command"
    echo ""
    echo -n "  ${COLOR_YELLOW}Paste auto-deploy command (or press Enter to skip): ${COLOR_NC}"
    read -r DEPLOY_CMD

    if [[ ! -z "$DEPLOY_CMD" ]]; then
        eval "$DEPLOY_CMD"
        systemctl enable --now wings > /dev/null 2>&1
        success "Wings Configured & Started!"
    else
        systemctl enable wings > /dev/null 2>&1
        output "Wings enabled. Start manually with: systemctl start wings"
    fi
}

fix_permissions() {
    output "Fixing Panel Permissions..."
    chmod -R 755 $PANEL_DIR/storage $PANEL_DIR/bootstrap/cache 2>/dev/null || true
    chown -R $PHP_USER:$PHP_USER $PANEL_DIR 2>/dev/null || true
    success "Permissions fixed"
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
    echo -e "  ${COLOR_CYAN}[0]${COLOR_NC} Back to Main Menu"
    echo ""
    echo -n "  Select option: "
    read -r t_action

    echo ""

    case $t_action in
        1)
            echo -e "${COLOR_CYAN}Service Status:${COLOR_NC}"
            echo ""
            systemctl is-active --quiet nginx && echo -e "  ${COLOR_GREEN}●${COLOR_NC} Nginx: Running" || echo -e "  ${COLOR_RED}●${COLOR_NC} Nginx: Stopped"
            systemctl is-active --quiet pelican-worker && echo -e "  ${COLOR_GREEN}●${COLOR_NC} Queue Worker: Running" || echo -e "  ${COLOR_RED}●${COLOR_NC} Queue Worker: Stopped"
            systemctl is-active --quiet docker && echo -e "  ${COLOR_GREEN}●${COLOR_NC} Docker: Running" || echo -e "  ${COLOR_RED}●${COLOR_NC} Docker: Stopped"
            systemctl is-active --quiet mariadb && echo -e "  ${COLOR_GREEN}●${COLOR_NC} MariaDB: Running" || echo -e "  ${COLOR_RED}●${COLOR_NC} MariaDB: Stopped"
            (crontab -l 2>/dev/null | grep -q "artisan schedule:run") && echo -e "  ${COLOR_GREEN}●${COLOR_NC} Cron: Installed" || echo -e "  ${COLOR_RED}●${COLOR_NC} Cron: Missing"
            ;;
        2)
            fix_permissions
            ;;
        3)
            if [ -f "$PANEL_DIR/storage/logs/laravel.log" ]; then
                echo -e "${COLOR_CYAN}Last 100 lines of Panel logs:${COLOR_NC}"
                echo ""
                tail -n 100 "$PANEL_DIR/storage/logs/laravel.log"
            else
                error "Panel log file not found"
            fi
            ;;
        4)
            if [ -f "/var/log/nginx/error.log" ]; then
                echo -e "${COLOR_CYAN}Last 50 error lines from Nginx:${COLOR_NC}"
                echo ""
                tail -n 50 "/var/log/nginx/error.log"
            else
                error "Nginx error log not found"
            fi
            ;;
        5)
            output "Checking Database Connection..."
            if [ -f "$PANEL_DIR/.env" ]; then
                cd "$PANEL_DIR"
                php artisan db:monitor
            else
                error ".env file not found"
            fi
            ;;
        0)
            return
            ;;
        *)
            error "Invalid option"
            ;;
    esac

    echo ""
    echo -n "  Press Enter to continue..."
    read -r
}

uninstall_panel() {
    output "Uninstalling Pelican Panel..."

    show_progress "Removing Panel files" 2 20
    rm -rf /var/www/pelican

    show_progress "Removing Nginx configuration" 1 10
    rm -f $NGINX_CONF_DIR/pelican.conf
    if [ ! -z "$NGINX_ENABLED_DIR" ]; then
        rm -f $NGINX_ENABLED_DIR/pelican.conf
    fi
    systemctl restart nginx > /dev/null 2>&1

    show_progress "Removing Queue Worker" 1 10
    systemctl disable --now pelican-worker 2>/dev/null || true
    rm -f /etc/systemd/system/pelican-worker.service
    systemctl daemon-reload > /dev/null 2>&1

    show_progress "Removing Database" 1 10
    mysql -u root -e "DROP DATABASE IF EXISTS pelican; DROP USER IF EXISTS 'pelican'@'127.0.0.1';" 2>/dev/null || true

    success "Panel Uninstalled Successfully"
}

uninstall_wings() {
    output "Uninstalling Pelican Wings..."

    show_progress "Stopping Wings service" 1 10
    systemctl disable --now wings 2>/dev/null || true

    show_progress "Removing Wings files" 1 10
    rm -f /usr/local/bin/wings
    rm -f /etc/systemd/system/wings.service
    rm -rf /etc/pelican
    systemctl daemon-reload > /dev/null 2>&1

    success "Wings Uninstalled Successfully"
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
    echo -n "  Select option: "
    read -r action

    case $action in
        1)
            uninstall_panel
            ;;
        2)
            uninstall_wings
            ;;
        3)
            uninstall_panel
            uninstall_wings
            ;;
        0)
            return
            ;;
        *)
            error "Invalid option"
            ;;
    esac

    echo ""
    echo -n "  Press Enter to continue..."
    read -r
}

# Main Menu
show_main_menu() {
    print_header
    echo -e "${COLOR_PURPLE}                    MAIN MENU${COLOR_NC}"
    echo ""
    echo -e "  ${COLOR_CYAN}[1]${COLOR_NC} Install Panel"
    echo -e "  ${COLOR_CYAN}[2]${COLOR_NC} Install Wings"
    echo -e "  ${COLOR_CYAN}[3]${COLOR_NC} Install Panel + Wings"
    echo -e "  ${COLOR_CYAN}[4]${COLOR_NC} Uninstall"
    echo -e "  ${COLOR_CYAN}[5]${COLOR_NC} Troubleshooting"
    echo -e "  ${COLOR_CYAN}[0]${COLOR_NC} Exit"
    echo ""
    echo -n "  Select option: "
}

# Main Loop
check_root

# Install bc for progress calculations if not present
if ! command -v bc &> /dev/null; then
    apt install -y bc 2>/dev/null || dnf install -y bc 2>/dev/null || true
fi

detect_os

done=false
while [ "$done" == false ]; do
    show_main_menu
    read -r action

    case $action in
        1)
            echo ""
            install_dependencies
            install_panel
            echo ""
            echo -n "  Press Enter to return to menu..."
            read -r
            ;;
        2)
            echo ""
            install_dependencies
            install_wings
            echo ""
            echo -n "  Press Enter to return to menu..."
            read -r
            ;;
        3)
            echo ""
            install_dependencies
            install_panel
            install_wings
            echo ""
            echo -n "  Press Enter to return to menu..."
            read -r
            ;;
        4)
            perform_uninstall
            ;;
        5)
            troubleshooting
            ;;
        0)
            echo ""
            echo -e "  ${COLOR_GREEN}Thank you for using Pelican Installer - Martin 2026${COLOR_NC}"
            echo ""
            done=true
            ;;
        *)
            error "Invalid option"
            sleep 1
            ;;
    esac
done
