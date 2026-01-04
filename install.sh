#!/usr/bin/env bash

# ============================================================================
# Odoo Auto Installer Script - Interactive Edition
# ============================================================================
# Універсальний інтерактивний скрипт для встановлення Odoo
# Підтримує: Ubuntu 20.04, 22.04, 24.04
# Версії Odoo: 17.0, 18.0
# ============================================================================

# Вимкнути pipefail для максимальної сумісності
set -eo pipefail

# Кольори
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функції виводу
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_header() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${CYAN}$1${NC}\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# Безпечне встановлення пакетів (ігнорує помилки)
safe_install() {
    local packages="$@"
    print_info "Встановлення: $packages"
    sudo apt-get install -y $packages 2>/dev/null || {
        print_warning "Деякі пакети не встановлено (не критично)"
        return 0
    }
}

# Перевірка та встановлення команди
ensure_command() {
    local cmd=$1
    local package=${2:-$1}
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        print_info "Встановлення $package..."
        safe_install "$package"
    else
        print_success "$cmd вже встановлено"
    fi
}

# ============================================================================
# Інтерактивний вибір параметрів
# ============================================================================

clear
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║            Odoo Auto Installer (Interactive)               ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Вибір версії Odoo
print_header "Крок 1: Вибір версії Odoo"
echo "Доступні версії:"
echo "  1) Odoo 17.0 (Python 3.10)"
echo "  2) Odoo 18.0 (Python 3.12)"
echo ""
read -p "Оберіть версію (1 або 2) [за замовчуванням: 1]: " version_choice
version_choice=${version_choice:-1}

case $version_choice in
    1)
        ODOO_VERSION="17.0"
        PYTHON_BIN="python3.10"
        ;;
    2)
        ODOO_VERSION="18.0"
        PYTHON_BIN="python3.12"
        ;;
    *)
        print_error "Невірний вибір. Використовую Odoo 17.0"
        ODOO_VERSION="17.0"
        PYTHON_BIN="python3.10"
        ;;
esac

print_success "Обрано: Odoo $ODOO_VERSION (Python: $PYTHON_BIN)"

# Вибір порту
print_header "Крок 2: Налаштування порту"
read -p "Введіть HTTP порт [за замовчуванням: 8069]: " HTTP_PORT
HTTP_PORT=${HTTP_PORT:-8069}
print_success "Порт: $HTTP_PORT"

# Користувач БД
print_header "Крок 3: Налаштування бази даних"
read -p "Введіть ім'я користувача PostgreSQL [за замовчуванням: odoo]: " DB_USER
DB_USER=${DB_USER:-odoo}
print_success "Користувач БД: $DB_USER"

# Директорія встановлення
print_header "Крок 4: Директорія встановлення"
DEFAULT_DIR="$(pwd)/odoo-install"
read -p "Директорія встановлення [за замовчуванням: $DEFAULT_DIR]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_DIR}
print_success "Директорія: $INSTALL_DIR"

# Dev tools
print_header "Крок 5: Додаткові інструменти"
read -p "Встановити dev-tools (pylint, flake8)? (y/n) [за замовчуванням: y]: " install_dev
install_dev=${install_dev:-y}
if [[ "$install_dev" =~ ^[Yy]$ ]]; then
    DEVMODE="--dev"
    print_success "Dev-tools будуть встановлені"
else
    DEVMODE=""
    print_info "Dev-tools не будуть встановлені"
fi

# Підтвердження
print_header "Підтвердження налаштувань"
echo "Версія Odoo:     $ODOO_VERSION"
echo "Python:          $PYTHON_BIN"
echo "HTTP порт:       $HTTP_PORT"
echo "Користувач БД:   $DB_USER"
echo "Директорія:      $INSTALL_DIR"
echo "Dev-tools:       ${DEVMODE:-ні}"
echo ""
read -p "Продовжити встановлення? (y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    print_warning "Встановлення скасовано"
    exit 0
fi

# Створення директорії
mkdir -p "$INSTALL_DIR"
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)"

# ============================================================================
# Встановлення
# ============================================================================

print_header "Крок 1/10: Оновлення системи"
sudo apt-get update || print_warning "apt update завершився з попередженнями"
sudo apt-get upgrade -y || print_warning "apt upgrade завершився з попередженнями"

print_header "Крок 2/10: Встановлення базових пакетів"
# Встановлюємо пакети по одному, ігноруючи помилки
for pkg in wget git curl ca-certificates lsb-release gnupg apt-transport-https \
           build-essential gettext rsync unzip bzip2 dialog \
           gcc g++ make python3-pip python3-venv; do
    safe_install "$pkg"
done

# Встановлення virtualenv через pip якщо немає
if ! command -v virtualenv >/dev/null 2>&1; then
    print_info "Встановлення virtualenv через pip..."
    python3 -m pip install --user virtualenv 2>/dev/null || sudo pip3 install virtualenv 2>/dev/null || true
fi

print_header "Крок 3/10: Встановлення Node.js та npm"
# Перевірка Node.js
if ! command -v node >/dev/null 2>&1; then
    print_info "Встановлення Node.js через nodesource..."
    curl -fsSL https://deb.nodesource.com/setup_20.x 2>/dev/null | sudo -E bash - || print_warning "Не вдалося додати nodesource repo"
    safe_install nodejs
else
    print_success "Node.js вже встановлено: $(node --version 2>/dev/null || echo 'unknown')"
fi

# Перевірка npm
if ! command -v npm >/dev/null 2>&1; then
    print_warning "npm не знайдено, але зазвичай встановлюється разом з nodejs"
else
    print_success "npm встановлено: $(npm --version 2>/dev/null || echo 'unknown')"
fi

# Встановлення less через npm (для Odoo)
if command -v npm >/dev/null 2>&1; then
    print_info "Встановлення less через npm..."
    sudo npm install -g less 2>/dev/null || print_warning "Не вдалося встановити less (не критично)"
fi

print_header "Крок 4/10: Встановлення Python $PYTHON_BIN"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    print_info "Додавання deadsnakes PPA..."
    sudo add-apt-repository ppa:deadsnakes/ppa -y 2>/dev/null || print_warning "Не вдалося додати PPA"
    sudo apt-get update || true
    
    print_info "Встановлення $PYTHON_BIN..."
    for pkg in "${PYTHON_BIN}" "${PYTHON_BIN}-dev" "${PYTHON_BIN}-venv" "${PYTHON_BIN}-distutils"; do
        safe_install "$pkg"
    done
fi

# Перевірка Python
if command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    print_success "Python встановлено: $($PYTHON_BIN --version)"
else
    print_error "Не вдалося встановити $PYTHON_BIN"
    exit 1
fi

print_header "Крок 5/10: Встановлення системних залежностей Odoo"
# Встановлюємо залежності по одній, ігноруючи помилки
ODOO_DEPS=(
    libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev
    libjpeg-dev libpq-dev libffi-dev liblcms2-dev libblas-dev
    libatlas-base-dev libwebp-dev libtiff-dev libopenjp2-7
    libharfbuzz-dev libfribidi-dev libxkbcommon0
    libfreetype6-dev libfreetype-dev libpng-dev
)

for dep in "${ODOO_DEPS[@]}"; do
    safe_install "$dep"
done

print_header "Крок 6/10: Встановлення wkhtmltopdf"
if ! command -v wkhtmltopdf >/dev/null 2>&1; then
    safe_install wkhtmltopdf
else
    print_success "wkhtmltopdf вже встановлено"
fi

print_header "Крок 7/10: Створення віртуального оточення"
cd "$INSTALL_DIR"

if [[ ! -d "venv" ]]; then
    print_info "Створення venv з $PYTHON_BIN..."
    
    # Спроба 1: через virtualenv
    if command -v virtualenv >/dev/null 2>&1; then
        virtualenv -p "$PYTHON_BIN" venv 2>/dev/null || {
            # Спроба 2: через python -m venv
            print_warning "virtualenv не спрацював, використовую python -m venv"
            "$PYTHON_BIN" -m venv venv 2>/dev/null || {
                print_error "Не вдалося створити venv"
                exit 1
            }
        }
    else
        "$PYTHON_BIN" -m venv venv
    fi
    
    print_success "Віртуальне оточення створено"
else
    print_success "Віртуальне оточення вже існує"
fi

# Активація venv
source "$INSTALL_DIR/venv/bin/activate"
print_success "Віртуальне оточення активовано: $(python --version)"

print_header "Крок 8/10: Оновлення pip та setuptools"
pip install --upgrade pip 2>/dev/null || print_warning "pip upgrade завершився з попередженнями"
pip install "setuptools<65" "wheel<1.0" 2>/dev/null || print_warning "setuptools install завершився з попередженнями"

print_header "Крок 9/10: Встановлення odoo-helper-scripts"
if ! command -v odoo-helper >/dev/null 2>&1; then
    print_info "Завантаження odoo-helper..."
    wget -q -O /tmp/odoo-helper-install.bash https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash 2>/dev/null || {
        print_error "Не вдалося завантажити odoo-helper"
        exit 1
    }
    
    print_info "Встановлення odoo-helper..."
    sudo bash /tmp/odoo-helper-install.bash || {
        print_error "Не вдалося встановити odoo-helper"
        exit 1
    }
    
    print_success "odoo-helper встановлено"
else
    print_success "odoo-helper вже встановлено"
fi

# Встановлення пререквізитів через odoo-helper
print_info "Встановлення пререквізитів..."
odoo-helper install pre-requirements 2>/dev/null || print_warning "Деякі пререквізити не встановлено"

print_info "Встановлення PostgreSQL..."
odoo-helper install postgres 2>/dev/null || print_warning "PostgreSQL вже встановлено або виникли проблеми"

# Системні залежності для версії Odoo
ODOO_MAJOR="${ODOO_VERSION%.*}"
print_info "Встановлення sys-deps для Odoo $ODOO_MAJOR..."
odoo-helper install sys-deps "$ODOO_MAJOR" 2>/dev/null || print_warning "Деякі sys-deps не встановлено"

print_header "Крок 10/10: Встановлення Odoo $ODOO_VERSION"
ODOO_DIR="odoo-${ODOO_VERSION}"

if [[ ! -d "$ODOO_DIR" ]]; then
    print_info "Запуск odoo-install..."
    
    # Спроба з sudo
    sudo odoo-install --ikwid --install-dir "./$ODOO_DIR" \
        --odoo-version "$ODOO_VERSION" \
        $DEVMODE \
        --db-user "$DB_USER" \
        --create-db-user 2>/dev/null || {
        
        # Спроба без sudo
        print_warning "Спроба без sudo..."
        odoo-install --ikwid --install-dir "./$ODOO_DIR" \
            --odoo-version "$ODOO_VERSION" \
            $DEVMODE \
            --db-user "$DB_USER" \
            --create-db-user 2>/dev/null || print_warning "odoo-install завершився з попередженнями"
    }
    
    print_success "Odoo встановлено"
else
    print_warning "$ODOO_DIR вже існує"
fi

# Права доступу (СПОЧАТКУ)
print_info "Налаштування прав доступу..."
sudo chown -R "$USER":"$USER" "$INSTALL_DIR" 2>/dev/null || true
chmod -R 755 "$INSTALL_DIR" 2>/dev/null || true

# Налаштування конфігурації
print_info "Налаштування конфігурації..."
CONF_DIR="$INSTALL_DIR/$ODOO_DIR/conf"
CONF_FILE="$CONF_DIR/odoo.conf"
mkdir -p "$CONF_DIR" 2>/dev/null || true

if [[ ! -f "$CONF_FILE" ]]; then
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
    print_success "Конфігурація створена: $CONF_FILE"
else
    print_warning "Конфігурація вже існує: $CONF_FILE"
fi

# Лінкування з odoo-helper
print_info "Лінкування з odoo-helper..."
if [[ -d "$INSTALL_DIR/$ODOO_DIR" ]]; then
    cd "$INSTALL_DIR/$ODOO_DIR"
    
    # Створюємо odoo-helper.conf якщо не існує
    if [[ ! -f "odoo-helper.conf" ]]; then
        print_info "Створення odoo-helper.conf..."
        cat > "odoo-helper.conf" <<EOF
ODOO_BRANCH=$ODOO_VERSION
ODOO_VERSION=$ODOO_VERSION
ADDONS_DIR=$INSTALL_DIR/$ODOO_DIR/custom_addons
ODOO_CONF_FILE=$INSTALL_DIR/$ODOO_DIR/conf/odoo.conf
EOF
    fi
    
    # Лінкування
    if [[ -d "odoo" ]]; then
        cd odoo
        odoo-helper link . --odoo-version "$ODOO_MAJOR" 2>/dev/null || print_warning "odoo-helper link завершився з попередженнями"
    fi
    
    cd "$INSTALL_DIR/$ODOO_DIR"
else
    print_warning "Директорія $INSTALL_DIR/$ODOO_DIR не знайдена"
fi

# Dev-tools
if [[ -n "$DEVMODE" ]]; then
    print_info "Встановлення dev-tools..."
    odoo-helper install dev-tools 2>/dev/null || print_warning "Деякі dev-tools не встановлено"
fi

# Створення користувача PostgreSQL
print_info "Налаштування PostgreSQL..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD 'odoo';" 2>/dev/null || print_warning "Користувач $DB_USER вже існує"
sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;" 2>/dev/null || true

# Firewall
print_info "Налаштування firewall..."
sudo ufw allow "$HTTP_PORT/tcp" 2>/dev/null || print_warning "UFW не активний"

# ============================================================================
# Завершення
# ============================================================================

print_header "🎉 Встановлення завершено!"
echo ""
print_success "Odoo $ODOO_VERSION встановлено в: $INSTALL_DIR/$ODOO_DIR"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Для запуску Odoo:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  cd $INSTALL_DIR/$ODOO_DIR"
echo "  source $INSTALL_DIR/venv/bin/activate"
echo "  odoo-helper server start"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💾 Для створення бази даних:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  odoo-helper db create --demo testdb"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Доступ до Odoo:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_SERVER_IP")
echo "  http://$SERVER_IP:$HTTP_PORT"
echo "  або"
echo "  http://localhost:$HTTP_PORT"
echo ""
echo "  Логін: admin"
echo "  Пароль: admin"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Файли:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Конфіг: $CONF_FILE"
echo "  Логи:   $INSTALL_DIR/$ODOO_DIR/logs"
echo ""
