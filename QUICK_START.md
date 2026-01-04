# 🚀 Швидкий старт

## Встановлення Odoo 17

```bash
mkdir -p ~/odoo && cd ~/odoo
git clone https://github.com/zhatrus/odoo_start.git odoo17
cd odoo17
chmod +x install.sh
./install.sh --version 17 --port 8069
```

## Встановлення Odoo 18

```bash
mkdir -p ~/odoo && cd ~/odoo
git clone https://github.com/zhatrus/odoo_start.git odoo18
cd odoo18
chmod +x install.sh
./install.sh --version 18 --port 8070 --db-user odoo18
```

## Після встановлення

```bash
# Запуск сервера
cd odoo-install/odoo-18.0  # або odoo-17.0
source ../venv/bin/activate
odoo-helper server start

# Створення бази даних
odoo-helper db create --demo testdb
```

## Доступ

```
http://YOUR_SERVER_IP:8070
```

**Логін:** admin  
**Пароль:** admin
