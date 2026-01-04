# 🚀 Швидкий старт

## Інтерактивне встановлення

```bash
mkdir -p ~/odoo && cd ~/odoo
git clone https://github.com/zhatrus/odoo_start.git odoo-setup
cd odoo-setup
chmod +x install.sh
./install.sh
```

Скрипт сам запитає всі необхідні параметри:
- Версію Odoo (17 або 18)
- HTTP порт
- Користувача бази даних
- Директорію встановлення
- Dev-tools (так/ні)

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
