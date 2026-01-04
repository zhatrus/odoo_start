#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Odoo Auto Installer Script
# ============================================================================
# Універсальний скрипт для автоматичного встановлення Odoo на Ubuntu Server
# Підтримує версії: 17.0, 18.0
# Використання:
#   ./install.sh --version 17 --port 8069
#   ./install.sh --version 18 --port 8070 --db-user odoo18
# ============================================================================

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функції для виводу
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Параметри за замовчуванням
ODOO_VERSION="17.0"
INSTALL_DIR="$(pwd)/odoo-install"
HTTP_PORT="8069"
DB_USER="odoo"
CREATE_DB_USER="yes"
PYTHON_FOR_17="python3.10"
PYTHON_FOR_18="python3.12"
DEVMODE="--dev"
BRANCH=""
PYTHON_BIN=""

# Парсинг аргументів
while [[ $# -gt 0 ]]; do
  case $1 in
    --version|-v)
      ODOO_VERSION="$2"
      # Додаємо .0 якщо не вказано
      if [[ ! "$ODOO_VERSION" =~ \. ]]; then
        ODOO_VERSION="${ODOO_VERSION}.0"
      fi
      shift 2
      ;;
    --install-dir|-d)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --port|-p)
      HTTP_PORT="$2"
      shift 2
      ;;
    --db-user)
      DB_USER="$2"
      shift 2
      ;;
    --no-create-db-user)
      CREATE_DB_USER="no"
      shift
      ;;
    --python)
      PYTHON_BIN="$2"
      shift 2
      ;;
    --no-dev)
      DEVMODE=""
      shift
      ;;
    --branch)
      BRANCH="--odoo-branch $2"
      shift 2
      ;;
    --help|-h)
      echo "Використання: $0 [ОПЦІЇ]"
      echo ""
      echo "Опції:"
      echo "  --version, -v VERSION    Версія Odoo (17 або 18, за замовчуванням: 17)"
      echo "  --port, -p PORT          HTTP порт (за замовчуванням: 8069)"
      echo "  --install-dir, -d DIR    Директорія встановлення (за замовчуванням: ./odoo-install)"
      echo "  --db-user USER           Користувач PostgreSQL (за замовчуванням: odoo)"
      echo "  --no-create-db-user      Не створювати користувача БД"
      echo "  --python PYTHON          Шлях до Python (автовизначення за версією)"
      echo "  --no-dev                 Не встановлювати dev-tools"
      echo "  --branch BRANCH          Гілка Odoo"
      echo "  --help, -h               Показати цю довідку"
      echo ""
      echo "Приклади:"
      echo "  $0 --version 17 --port 8069"
      echo "  $0 --version 18 --port 8070 --db-user odoo18"
      exit 0
      ;;
    *)
      print_error "Невідомий параметр: $1"
      echo "Використовуйте --help для довідки"
      exit 1
      ;;
  esac
done

# Вибір Python за версією
if [[ -z "$PYTHON_BIN" ]]; then
  if [[ "$ODOO_VERSION" == 17* ]]; then
    PYTHON_BIN="$PYTHON_FOR_17"
  else
    PYTHON_BIN="$PYTHON_FOR_18"
  fi
fi

# Виведення конфігурації
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Odoo Auto Installer - Конфігурація               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_info "Версія Odoo:        $ODOO_VERSION"
print_info "Директорія:         $INSTALL_DIR"
print_info "HTTP порт:          $HTTP_PORT"
print_info "Користувач БД:      $DB_USER"
print_info "Python:             $PYTHON_BIN"
print_info "Створити DB user:   $CREATE_DB_USER"
print_info "Dev режим:          ${DEVMODE:-ні}"
echo ""

# Підтвердження
read -p "Продовжити встановлення? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Встановлення скасовано"
    exit 0
fi

# Створення директорії
mkdir -p "$INSTALL_DIR"
INSTALL_DIR="$(realpath "$INSTALL_DIR")"

# ============================================================================
# 1. Оновлення системи
# ============================================================================
print_info "Крок 1/12: Оновлення системи..."
sudo apt update
sudo apt upgrade -y

# ============================================================================
# 2. Встановлення базових пакетів
# ============================================================================
print_info "Крок 2/12: Встановлення базових пакетів..."
sudo apt install -y wget git curl ca-certificates lsb-release gnupg apt-transport-https \
  build-essential gettext rsync unzip bzip2 dialog \
  nodejs npm python3-distutils gcc g++ make virtualenv

# ============================================================================
# 3. Встановлення Python
# ============================================================================
print_info "Крок 3/12: Встановлення Python $PYTHON_BIN..."
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  print_warning "Python $PYTHON_BIN не знайдено, додаємо deadsnakes PPA..."
  sudo add-apt-repository ppa:deadsnakes/ppa -y
  sudo apt update
  sudo apt install -y "${PYTHON_BIN}" "${PYTHON_BIN}-dev" "${PYTHON_BIN}-venv"
fi

# Перевірка
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  print_error "Не вдалося встановити $PYTHON_BIN"
  exit 1
fi
print_success "Python $PYTHON_BIN встановлено: $($PYTHON_BIN --version)"

# ============================================================================
# 4. Встановлення системних залежностей Odoo
# ============================================================================
print_info "Крок 4/12: Встановлення системних залежностей Odoo..."
sudo apt install -y libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev \
  libjpeg-dev libpq-dev libffi-dev liblcms2-dev libblas-dev libatlas-base-dev \
  libwebp-dev libtiff-dev libopenjp2-7 libharfbuzz-dev libfribidi-dev \
  libxkbcommon0 libfreetype6-dev libpng-dev node-less

# ============================================================================
# 5. Встановлення wkhtmltopdf
# ============================================================================
print_info "Крок 5/12: Встановлення wkhtmltopdf..."
if ! command -v wkhtmltopdf >/dev/null 2>&1; then
  sudo apt install -y wkhtmltopdf || print_warning "wkhtmltopdf не встановлено (не критично)"
fi

# ============================================================================
# 6. Створення віртуального оточення
# ============================================================================
print_info "Крок 6/12: Створення віртуального оточення..."
cd "$INSTALL_DIR"
if [[ ! -d "venv" ]]; then
  virtualenv -p "$PYTHON_BIN" venv
  print_success "Віртуальне оточення створено"
else
  print_warning "Віртуальне оточення вже існує"
fi

# Активація venv
source "$INSTALL_DIR/venv/bin/activate"
print_success "Віртуальне оточення активовано: $(python --version)"

# ============================================================================
# 7. Оновлення pip та встановлення setuptools
# ============================================================================
print_info "Крок 7/12: Оновлення pip та setuptools..."
pip install --upgrade pip
pip install "setuptools<65" "wheel<1.0"

# ============================================================================
# 8. Встановлення odoo-helper-scripts
# ============================================================================
print_info "Крок 8/12: Встановлення odoo-helper-scripts..."
if ! command -v odoo-helper >/dev/null 2>&1; then
  wget -O /tmp/odoo-helper-install.bash https://gitlab.com/katyukha/odoo-helper-scripts/raw/master/install-system.bash
  sudo bash /tmp/odoo-helper-install.bash
  print_success "odoo-helper встановлено"
else
  print_warning "odoo-helper вже встановлено"
fi

# Перевірка
if ! command -v odoo-helper >/dev/null 2>&1; then
  print_error "odoo-helper не знайдено після встановлення"
  exit 1
fi

# ============================================================================
# 9. Встановлення PostgreSQL та пререквізитів
# ============================================================================
print_info "Крок 9/12: Встановлення PostgreSQL..."
odoo-helper install pre-requirements || true
odoo-helper install postgres || true

# Встановлення системних залежностей для версії Odoo
ODOO_MAJOR_VERSION="${ODOO_VERSION%.*}"
print_info "Встановлення sys-deps для Odoo $ODOO_MAJOR_VERSION..."
odoo-helper install sys-deps "$ODOO_MAJOR_VERSION" || true

# ============================================================================
# 10. Встановлення Odoo
# ============================================================================
print_info "Крок 10/12: Встановлення Odoo $ODOO_VERSION..."
ODOO_DIR="odoo-${ODOO_VERSION}"

if [[ ! -d "$ODOO_DIR" ]]; then
  # Спроба з sudo
  sudo odoo-install --ikwid --install-dir "./$ODOO_DIR" --odoo-version "$ODOO_VERSION" \
    $DEVMODE $BRANCH --db-user "$DB_USER" --create-db-user 2>/dev/null || {
    # Спроба без sudo
    print_warning "Спроба встановлення без sudo..."
    odoo-install --ikwid --install-dir "./$ODOO_DIR" --odoo-version "$ODOO_VERSION" \
      $DEVMODE $BRANCH --db-user "$DB_USER" --create-db-user || true
  }
  print_success "Odoo встановлено в $ODOO_DIR"
else
  print_warning "$ODOO_DIR вже існує, пропускаємо встановлення"
fi

# ============================================================================
# 11. Налаштування конфігурації
# ============================================================================
print_info "Крок 11/12: Налаштування конфігурації..."
CONF_DIR="$INSTALL_DIR/$ODOO_DIR/conf"
CONF_FILE="$CONF_DIR/odoo.conf"
mkdir -p "$CONF_DIR"

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
  print_success "Конфігураційний файл створено"
else
  print_warning "Конфігураційний файл вже існує"
fi

# Налаштування прав доступу
sudo chown -R "$USER":"$USER" "$INSTALL_DIR"
chmod -R 700 "$INSTALL_DIR"

# Лінкування з odoo-helper
if [[ -d "$INSTALL_DIR/$ODOO_DIR/odoo" ]]; then
  cd "$INSTALL_DIR/$ODOO_DIR/odoo"
  odoo-helper link . --odoo-version "$ODOO_MAJOR_VERSION" || true
fi

# ============================================================================
# 12. Встановлення dev-tools
# ============================================================================
if [[ -n "$DEVMODE" ]]; then
  print_info "Крок 12/12: Встановлення dev-tools..."
  odoo-helper install dev-tools || print_warning "Dev-tools не встановлено (не критично)"
else
  print_info "Крок 12/12: Пропускаємо dev-tools (--no-dev)"
fi

# Створення PostgreSQL користувача якщо потрібно
if [[ "$CREATE_DB_USER" == "yes" ]]; then
  print_info "Створення користувача PostgreSQL $DB_USER..."
  sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD 'odoo';" 2>/dev/null || print_warning "Користувач $DB_USER вже існує"
  sudo -u postgres psql -c "ALTER USER $DB_USER CREATEDB;" 2>/dev/null || true
fi

# Відкриття порту в firewall
print_info "Налаштування firewall..."
sudo ufw allow "$HTTP_PORT/tcp" 2>/dev/null || print_warning "UFW не активний або не встановлений"

# ============================================================================
# Завершення
# ============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Встановлення завершено успішно!               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_success "Odoo $ODOO_VERSION встановлено в: $INSTALL_DIR/$ODOO_DIR"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Для запуску Odoo виконайте:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  cd $INSTALL_DIR/$ODOO_DIR"
echo "  source $INSTALL_DIR/venv/bin/activate"
echo "  odoo-helper server start"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Для створення бази даних:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  odoo-helper db create --demo testdb"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Доступ до Odoo:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  http://$(hostname -I | awk '{print $1}'):$HTTP_PORT"
echo "  або"
echo "  http://localhost:$HTTP_PORT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Корисні команди:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  odoo-helper server stop       # Зупинити сервер"
echo "  odoo-helper server restart    # Перезапустити сервер"
echo "  odoo-helper db list           # Список баз даних"
echo "  odoo-helper log               # Переглянути логи"
echo ""
echo "Логи: $INSTALL_DIR/$ODOO_DIR/logs"
echo "Конфіг: $CONF_FILE"
echo ""
