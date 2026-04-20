#!/usr/bin/env bash

# ============================================================================
# Odoo 19 Extension - Доповнення для встановлення Odoo 19
# ============================================================================
# Цей скрипт розширює install.sh підтримкою Odoo 19
# Вимоги: Python 3.12+, PostgreSQL 13+, Node.js 20+
# ============================================================================

# Кольори (сумісні з оригінальним скриптом)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_header() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${CYAN}$1${NC}\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# ============================================================================
# Конфігурація для Odoo 19
# ============================================================================
ODOO_VERSION="19.0"
ODOO_MAJOR="19"
PYTHON_BIN="python3.12"
MIN_PYTHON_VERSION="3.12"
MIN_POSTGRES_VERSION="13"
NODE_VERSION="20"

# ============================================================================
# Перевірка системних вимог
# ============================================================================

check_system_requirements() {
    print_header "Перевірка вимог для Odoo 19"
    
    # Перевірка Python
    if command -v "$PYTHON_BIN" >/dev/null 2>&1; then
        PYTHON_VERSION=$($PYTHON_BIN --version 2>&1 | awk '{print $2}')
        print_success "Python $PYTHON_VERSION знайдено"
    else
        print_error "Python 3.12 не знайдено. Odoo 19 вимагає Python 3.12+"
        print_info "Встановлення Python 3.12..."
        return 1
    fi
    
    # Перевірка PostgreSQL
    if command -v psql >/dev/null 2>&1; then
        PG_VERSION=$(psql --version 2>&1 | head -n1 | grep -oE '[0-9]+' | head -n1)
        if [[ "$PG_VERSION" -ge "$MIN_POSTGRES_VERSION" ]]; then
            print_success "PostgreSQL $PG_VERSION (>= $MIN_POSTGRES_VERSION) ✓"
        else
            print_warning "PostgreSQL $PG_VERSION застарілий. Рекомендовано оновити до $MIN_POSTGRES_VERSION+"
        fi
    else
        print_info "PostgreSQL не встановлено, буде встановлено автоматично"
    fi
    
    # Перевірка ОС
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$VERSION_ID" in
            "20.04"|"22.04"|"24.04")
                print_success "Ubuntu $VERSION_ID підтримується"
                ;;
            *)
                print_warning "Ubuntu $VERSION_ID - можливі проблеми сумісності"
                ;;
        esac
    fi
}

# ============================================================================
# Встановлення Python 3.12 (якщо потрібно)
# ============================================================================

install_python312() {
    print_header "Встановлення Python 3.12 для Odoo 19"
    
    sudo apt-get update || true
    
    # Додавання deadsnakes PPA
    print_info "Додавання deadsnakes PPA..."
    sudo add-apt-repository ppa:deadsnakes/ppa -y 2>/dev/null || {
        print_warning "Не вдалося додати PPA, спроба без PPA..."
    }
    
    sudo apt-get update || true
    
    # Встановлення Python 3.12
    local python_packages=(
        "python3.12"
        "python3.12-dev"
        "python3.12-venv"
    )
    
    for pkg in "${python_packages[@]}"; do
        print_info "Встановлення $pkg..."
        sudo apt-get install -y "$pkg" 2>/dev/null || {
            print_warning "Не вдалося встановити $pkg"
        }
    done
    
    # Перевірка
    if command -v python3.12 >/dev/null 2>&1; then
        print_success "Python 3.12 успішно встановлено"
        PYTHON_BIN="python3.12"
    else
        print_error "Не вдалося встановити Python 3.12"
        exit 1
    fi
}

# ============================================================================
# Встановлення системних залежностей для Odoo 19
# ============================================================================

install_odoo19_dependencies() {
    print_header "Встановлення залежностей Odoo 19"
    
    # Оновлений список для Odoo 19
    local ODOO19_DEPS=(
        # Базові
        wget git curl ca-certificates lsb-release gnupg apt-transport-https
        build-essential gettext rsync unzip bzip2 dialog
        gcc g++ make python3-pip
        
        # Python бібліотеки (системні)
        libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev
        libjpeg-dev libpq-dev libffi-dev liblcms2-dev libblas-dev
        libatlas-base-dev libwebp-dev libtiff-dev libopenjp2-7-dev
        libharfbuzz-dev libfribidi-dev libxkbcommon-dev
        libfreetype6-dev libpng-dev
        
        # Додаткові для Odoo 19
        libssl-dev libxslt1.1
        python3-setuptools python3-wheel
    )
    
    for dep in "${ODOO19_DEPS[@]}"; do
        print_info "Встановлення: $dep"
        sudo apt-get install -y "$dep" 2>/dev/null || {
            print_warning "Пакет $dep не встановлено (не критично)"
        }
    done
}

# ============================================================================
# Налаштування Node.js 20 для Odoo 19
# ============================================================================

setup_nodejs20() {
    print_header "Налаштування Node.js 20 для Odoo 19"
    
    if command -v node >/dev/null 2>&1; then
        NODE_CURRENT=$(node --version 2>&1 | grep -oE '[0-9]+' | head -n1)
        if [[ "$NODE_CURRENT" -ge 20 ]]; then
            print_success "Node.js $(node --version) вже встановлено"
            return 0
        fi
    fi
    
    print_info "Встановлення Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x 2>/dev/null | sudo -E bash - || {
        print_warning "Проблема з nodesource, спроба альтернативного методу..."
    }
    
    sudo apt-get install -y nodejs 2>/dev/null || {
        print_error "Не вдалося встановити Node.js 20"
        return 1
    }
    
    print_success "Node.js $(node --version) встановлено"
    
    # Встановлення less
    if command -v npm >/dev/null 2>&1; then
        sudo npm install -g less 2>/dev/null || print_warning "Не вдалося встановити less"
    fi
}

# ============================================================================
# Інтерактивне встановлення Odoo 19
# ============================================================================

interactive_install() {
    clear
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    Odoo 19 Installer                       ║"
    echo "║              (Extension for install.sh)                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Перевірка вимог
    check_system_requirements || install_python312
    
    # Налаштування параметрів
    print_header "Конфігурація встановлення"
    
    read -p "HTTP порт [за замовчуванням: 8069]: " HTTP_PORT
    HTTP_PORT=${HTTP_PORT:-8069}
    
    read -p "Користувач PostgreSQL [за замовчуванням: odoo19]: " DB_USER
    DB_USER=${DB_USER:-odoo19}
    
    DEFAULT_DIR="$(pwd)/odoo19-install"
    read -p "Директорія встановлення [за замовчуванням: $DEFAULT_DIR]: " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_DIR}
    
    read -p "Встановити dev-tools? (y/n) [y]: " install_dev
    install_dev=${install_dev:-y}
    DEVMODE=$([[ "$install_dev" =~ ^[Yy]$ ]] && echo "--dev" || echo "")
    
    # Підтвердження
    print_header "Підтвердження налаштувань"
    echo "Версія:      Odoo 19.0 (Python 3.12+)"
    echo "Порт:        $HTTP_PORT"
    echo "Користувач:  $DB_USER"
    echo "Директорія:  $INSTALL_DIR"
    echo "Dev-tools:   ${DEVMODE:-ні}"
    echo ""
    
    read -p "Продовжити? (y/n): " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && { print_warning "Скасовано"; exit 0; }
    
    # Створення директорії
    mkdir -p "$INSTALL_DIR"
    INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"
    
    # Встановлення
    install_odoo19_dependencies
    setup_nodejs20
    
    # Віртуальне оточення
    print_header "Створення віртуального оточення"
    cd "$INSTALL_DIR"
    
    if [[ ! -d "venv" ]]; then
        $PYTHON_BIN -m venv venv 2>/dev/null || {
            print_error "Не вдалося створити venv"
            exit 1
        }
        print_success "venv створено"
    fi
    
    source "$INSTALL_DIR/venv/bin/activate"
    pip install --upgrade pip setuptools wheel 2>/dev/null || true
    
    # odoo-helper
    print_header "Встановлення odoo-helper-scripts"
    if ! command -v odoo-helper >/dev/null 2>&1; then
        wget -q -O /tmp/odoo-helper-install.bash \
            https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash 2>/dev/null
        sudo bash /tmp/odoo-helper-install.bash || {
            print_error "Не вдалося встановити odoo-helper"
            exit 1
        }
    fi
    
    odoo-helper install pre-requirements 2>/dev/null || true
    odoo-helper install postgres 2>/dev/null || true
    odoo-helper install sys-deps "19" 2>/dev/null || true
    
    # Встановлення Odoo 19
    print_header "Встановлення Odoo 19.0"
    ODOO_DIR="odoo-19.0"
    
    if [[ ! -d "$ODOO_DIR" ]]; then
        sudo odoo-install --ikwid --install-dir "./$ODOO_DIR" \
            --odoo-version "19.0" \
            $DEVMODE \
            --db-user "$DB_USER" \
            --create-db-user 2>/dev/null || {
            print_warning "Спроба без sudo..."
            odoo-install --ikwid --install-dir "./$ODOO_DIR" \
                --odoo-version "19.0" \
                $DEVMODE \
                --db-user "$DB_USER" \
                --create-db-user 2>/dev/null || true
        }
    fi
    
    # Права доступу та конфігурація
    sudo chown -R "$USER":"$USER" "$INSTALL_DIR" 2>/dev/null || true
    chmod -R 755 "$INSTALL_DIR" 2>/dev/null || true
    
    # Конфігурація
    CONF_DIR="$INSTALL_DIR/$ODOO_DIR/conf"
    CONF_FILE="$CONF_DIR/odoo.conf"
    mkdir -p "$CONF_DIR"
    
    cat > "$CONF_FILE" <<EOF
[options]
admin_passwd = admin
db_user = $DB_USER
db_password = odoo
db_host = localhost
db_port = 5432
addons_path = $INSTALL_DIR/$ODOO_DIR/odoo/addons,$INSTALL_DIR/$ODOO_DIR/custom_addons
http_port = $HTTP_PORT
xmlrpc_interface = 0.0.0.0
data_dir = $INSTALL_DIR/$ODOO_DIR/data
EOF
    
    # odoo-helper.conf
    cd "$INSTALL_DIR/$ODOO_DIR"
    cat > "odoo-helper.conf" <<EOF
PROJECT_ROOT_DIR=$INSTALL_DIR/$ODOO_DIR
ODOO_BRANCH=19.0
ODOO_VERSION=19.0
ADDONS_DIR=$INSTALL_DIR/$ODOO_DIR/custom_addons
ODOO_CONF_FILE=$CONF_FILE
VENV_DIR=$INSTALL_DIR/venv
EOF
    
    [[ -d "odoo" ]] && cd odoo && odoo-helper link . --odoo-version "19" 2>/dev/null || true
    
    # PostgreSQL
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD 'odoo';" 2>/dev/null || true
    sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;" 2>/dev/null || true
    
    # Firewall
    sudo ufw allow "$HTTP_PORT/tcp" 2>/dev/null || true
    
    # Генерація скриптів керування
    print_header "Генерація скриптів керування"
    local MGMT_DIR="$INSTALL_DIR/$ODOO_DIR"

    cat > "$MGMT_DIR/start-server.sh" <<STARTSCRIPT
#!/bin/bash
SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
cd "\$SCRIPT_DIR"
source "$INSTALL_DIR/venv/bin/activate"
export PGUSER=$DB_USER
export PGPASSWORD=odoo
export PGHOST=localhost
echo "Запуск Odoo 19.0..."
odoo-helper server start
echo "Odoo доступний: http://\$(hostname -I 2>/dev/null | awk '{print \$1}' || echo localhost):$HTTP_PORT"
STARTSCRIPT

    cat > "$MGMT_DIR/stop-server.sh" <<STOPSCRIPT
#!/bin/bash
SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
cd "\$SCRIPT_DIR"
source "$INSTALL_DIR/venv/bin/activate"
echo "Зупинка Odoo..."
odoo-helper server stop 2>/dev/null || pkill -f "python.*odoo" 2>/dev/null || true
echo "Odoo зупинено"
STOPSCRIPT

    cat > "$MGMT_DIR/restart-server.sh" <<RESTARTSCRIPT
#!/bin/bash
SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
cd "\$SCRIPT_DIR"
echo "Перезапуск Odoo..."
bash "\$SCRIPT_DIR/stop-server.sh"
sleep 2
bash "\$SCRIPT_DIR/start-server.sh"
RESTARTSCRIPT

    cat > "$MGMT_DIR/status-server.sh" <<STATUSSCRIPT
#!/bin/bash
SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
cd "\$SCRIPT_DIR"
source "$INSTALL_DIR/venv/bin/activate"
echo "--- Odoo 19.0 статус ---"
odoo-helper server status 2>/dev/null || {
    if pgrep -f "python.*odoo" > /dev/null 2>&1; then
        echo "Статус: ЗАПУЩЕНО"
        pgrep -fa "python.*odoo"
    else
        echo "Статус: ЗУПИНЕНО"
    fi
}
echo ""
echo "URL: http://\$(hostname -I 2>/dev/null | awk '{print \$1}' || echo localhost):$HTTP_PORT"
echo "Логи: tail -f $MGMT_DIR/logs/odoo.log"
STATUSSCRIPT

    chmod +x "$MGMT_DIR/start-server.sh" "$MGMT_DIR/stop-server.sh" \
             "$MGMT_DIR/restart-server.sh" "$MGMT_DIR/status-server.sh"
    print_success "Скрипти створено в: $MGMT_DIR"

    # Пропозиція shell-аліасів
    print_header "Shell-команди для керування Odoo"
    echo "Ви можете додати зручні команди в shell:"
    echo ""
    echo "  odoo-start    — запуск сервера"
    echo "  odoo-stop     — зупинка сервера"
    echo "  odoo-restart  — перезапуск сервера"
    echo "  odoo-status   — статус сервера"
    echo "  odoo-log      — перегляд логів в реальному часі"
    echo ""
    read -p "Додати ці команди в ~/.bashrc та ~/.zshrc? (y/n) [y]: " add_aliases
    add_aliases=${add_aliases:-y}

    if [[ "$add_aliases" =~ ^[Yy]$ ]]; then
        local ALIASES_BLOCK="
# === Odoo 19.0 management (added by install_odoo19.sh) ===
alias odoo-start='bash $MGMT_DIR/start-server.sh'
alias odoo-stop='bash $MGMT_DIR/stop-server.sh'
alias odoo-restart='bash $MGMT_DIR/restart-server.sh'
alias odoo-status='bash $MGMT_DIR/status-server.sh'
alias odoo-log='tail -f $MGMT_DIR/logs/odoo.log'
# === End Odoo management ==="

        for RC_FILE in "$HOME/.bashrc" "$HOME/.zshrc"; do
            if [[ -f "$RC_FILE" ]]; then
                if ! grep -q "Odoo 19.0 management" "$RC_FILE" 2>/dev/null; then
                    echo "$ALIASES_BLOCK" >> "$RC_FILE"
                    print_success "Додано в $RC_FILE"
                else
                    print_warning "Аліаси вже є в $RC_FILE"
                fi
            fi
        done

        eval "$ALIASES_BLOCK" 2>/dev/null || true
        print_success "Команди активовані в поточній сесії"
        print_info "Щоб активувати в нових вікнах: source ~/.bashrc"
    else
        print_info "Аліаси не додано. Скрипти доступні в: $MGMT_DIR"
    fi

    # Завершення
    print_header "🎉 Odoo 19.0 встановлено!"
    echo ""
    echo "Директорія: $INSTALL_DIR/$ODOO_DIR"
    echo ""
    echo "Запуск:     $MGMT_DIR/start-server.sh"
    echo "Зупинка:    $MGMT_DIR/stop-server.sh"
    echo "Перезапуск: $MGMT_DIR/restart-server.sh"
    echo "Статус:     $MGMT_DIR/status-server.sh"
    echo ""
    echo "URL: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):$HTTP_PORT"
}

# ============================================================================
# Запуск
# ============================================================================

# Якщо запущено напряму
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    interactive_install
fi
