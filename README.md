# 🚀 Odoo Auto Installer

Автоматичне встановлення Odoo на Ubuntu Server 24.04 одним скриптом.

## 📋 Підтримувані версії

- ✅ Odoo 17.0
- ✅ Odoo 18.0

## 🎯 Швидкий старт

### Встановлення Odoo 17

```bash
mkdir -p ~/odoo && cd ~/odoo
git clone https://github.com/zhatrus/odoo_start.git odoo17
cd odoo17
chmod +x install.sh
./install.sh --version 17 --port 8069
```

### Встановлення Odoo 18

```bash
mkdir -p ~/odoo && cd ~/odoo
git clone https://github.com/zhatrus/odoo_start.git odoo18
cd odoo18
chmod +x install.sh
./install.sh --version 18 --port 8070 --db-user odoo18
```

## 📦 Що встановлює скрипт?

Скрипт автоматично виконує всі необхідні кроки:

1. ✅ Оновлює систему Ubuntu
2. ✅ Встановлює Python (3.10 для Odoo 17, 3.12 для Odoo 18)
3. ✅ Встановлює всі системні залежності
4. ✅ Створює віртуальне оточення Python
5. ✅ Встановлює PostgreSQL
6. ✅ Встановлює odoo-helper-scripts
7. ✅ Встановлює Odoo обраної версії
8. ✅ Налаштовує конфігурацію
9. ✅ Встановлює dev-tools та лінтери
10. ✅ Відкриває порт у firewall

## ⚙️ Параметри скрипта

| Параметр | Опис | За замовчуванням |
|----------|------|------------------|
| `--version, -v` | Версія Odoo (17 або 18) | 17 |
| `--port, -p` | HTTP порт | 8069 |
| `--install-dir, -d` | Директорія встановлення | ./odoo-install |
| `--db-user` | Користувач PostgreSQL | odoo |
| `--no-create-db-user` | Не створювати користувача БД | - |
| `--python` | Шлях до Python | автовизначення |
| `--no-dev` | Не встановлювати dev-tools | - |
| `--branch` | Гілка Odoo | - |
| `--help, -h` | Показати довідку | - |

## 📝 Приклади використання

### Базове встановлення Odoo 17
```bash
./install.sh
```

### Odoo 17 на порту 15069
```bash
./install.sh --version 17 --port 15069
```

### Odoo 18 з окремим користувачем БД
```bash
./install.sh --version 18 --port 8070 --db-user odoo18
```

### Встановлення в конкретну директорію
```bash
./install.sh --version 17 --install-dir /opt/odoo17
```

### Без dev-tools
```bash
./install.sh --version 17 --no-dev
```

## 🎮 Управління Odoo після встановлення

### Запуск сервера

```bash
cd odoo-install/odoo-17.0  # або odoo-18.0
source ../venv/bin/activate
odoo-helper server start
```

### Зупинка сервера

```bash
odoo-helper server stop
```

### Перезапуск сервера

```bash
odoo-helper server restart
```

### Перегляд логів

```bash
odoo-helper log
```

### Відкрити Odoo в браузері

```bash
odoo-helper browse
```

## 💾 Управління базами даних

### Створити базу даних з демо-даними

```bash
odoo-helper db create --demo testdb
```

### Створити порожню базу

```bash
odoo-helper db create mydb
```

### Список баз даних

```bash
odoo-helper db list
```

### Видалити базу даних

```bash
odoo-helper db drop testdb
```

### Backup бази даних

```bash
odoo-helper db backup mydb
```

### Відновити базу з backup

```bash
odoo-helper db restore mydb backup_file.zip
```

## 📦 Управління модулями

### Оновити список модулів

```bash
odoo-helper addons update-list
```

### Завантажити модуль з Odoo Apps

```bash
odoo-helper fetch --odoo-app module_name
```

### Завантажити модулі з Git репозиторію

```bash
odoo-helper fetch --repo https://github.com/user/repo.git
```

### Додати локальний модуль

```bash
odoo-helper link /path/to/module
```

## 🔍 Перевірка коду (лінтери)

### Перевірка Python коду (pylint)

```bash
odoo-helper lint pylint .
```

### Перевірка стилю коду (flake8)

```bash
odoo-helper lint flake8 .
```

### Перевірка JavaScript/CSS (stylelint)

```bash
odoo-helper lint style .
```

## 🌐 Доступ до Odoo

Після встановлення Odoo буде доступний за адресою:

```
http://YOUR_SERVER_IP:PORT
```

Наприклад:
- `http://192.168.1.100:8069` (Odoo 17)
- `http://192.168.1.100:8070` (Odoo 18)

### Дані для входу

- **Email:** admin
- **Пароль:** admin (або той, що вказаний в `conf/odoo.conf`)

## 📁 Структура директорій після встановлення

```
odoo-install/
├── venv/                    # Віртуальне оточення Python
├── odoo-17.0/              # Встановлений Odoo 17
│   ├── odoo/               # Код Odoo
│   ├── conf/               # Конфігурація
│   │   └── odoo.conf
│   ├── custom_addons/      # Сторонні модулі
│   ├── data/               # Дані Odoo
│   ├── logs/               # Логи
│   ├── repositories/       # Git репозиторії модулів
│   └── backups/            # Backup бази даних
```

## 🔧 Налаштування

### Конфігураційний файл

Основний конфіг: `odoo-install/odoo-17.0/conf/odoo.conf`

```ini
[options]
admin_passwd = admin
db_user = odoo
db_password = odoo
db_host = localhost
db_port = 5432
addons_path = /path/to/odoo/addons,/path/to/custom_addons
http_port = 8069
xmlrpc_interface = 0.0.0.0
data_dir = /path/to/data
```

### Зміна порту

Відредагуйте `conf/odoo.conf`:
```ini
http_port = 15069
```

Не забудьте відкрити новий порт:
```bash
sudo ufw allow 15069/tcp
```

## 🐛 Вирішення проблем

### Odoo не запускається

1. Перевірте логи:
   ```bash
   odoo-helper log
   ```

2. Перевірте права доступу:
   ```bash
   sudo chown -R $USER:$USER ~/odoo/odoo-install
   chmod -R 700 ~/odoo/odoo-install
   ```

3. Перевірте PostgreSQL:
   ```bash
   sudo systemctl status postgresql
   ```

### Не можу підключитися з браузера

1. Перевірте firewall:
   ```bash
   sudo ufw status
   sudo ufw allow 8069/tcp
   ```

2. Перевірте що Odoo слухає на 0.0.0.0:
   ```bash
   grep xmlrpc_interface conf/odoo.conf
   # Має бути: xmlrpc_interface = 0.0.0.0
   ```

### Помилка з PostgreSQL користувачем

Створіть користувача вручну:
```bash
sudo -u postgres psql
CREATE USER odoo WITH PASSWORD 'odoo';
ALTER USER odoo CREATEDB;
\q
```

## 📚 Додаткові ресурси

- [Документація Odoo](https://www.odoo.com/documentation/17.0/)
- [odoo-helper-scripts](https://katyukha.gitlab.io/odoo-helper-scripts/)
- [OCA (Odoo Community Association)](https://github.com/OCA)

## 🤝 Підтримка

Якщо виникли проблеми:
1. Перевірте логи: `odoo-helper log`
2. Перевірте конфігурацію: `cat conf/odoo.conf`
3. Створіть issue в репозиторії

## 📄 Ліцензія

MIT License

---

**Автор:** zhatrus  
**Репозиторій:** https://github.com/zhatrus/odoo_start
