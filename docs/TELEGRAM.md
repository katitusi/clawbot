# 📱 Clawbot Telegram Bot Setup

Это руководство по настройке Telegram-интерфейса для Clawbot.

## 🚀 Быстрая настройка

### 1. Создание бота в Telegram

1. Откройте Telegram и найдите **@BotFather**
2. Отправьте команду `/newbot`
3. Введите имя бота (например: `My Clawbot`)
4. Введите username бота (например: `my_clawbot_bot`)
5. Скопируйте полученный токен (формат: `123456789:ABCdefGHIjklMNO...`)

### 2. Получение вашего User ID

1. Найдите в Telegram **@userinfobot**
2. Отправьте любое сообщение
3. Скопируйте ваш `User ID` (число, например: `123456789`)

### 3. Настройка .env файла

Откройте файл `.env` и заполните:

```env
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_ALLOWED_USERS=123456789
```

Для нескольких пользователей:
```env
TELEGRAM_ALLOWED_USERS=123456789,987654321,456789123
```

### 4. Запуск

```powershell
# Запуск с Telegram ботом
docker compose --profile telegram up -d

# Просмотр логов
docker compose logs -f telegram-bot
```

## 💬 Использование бота

### Команды

| Команда | Описание |
|---------|----------|
| `/start` | Приветствие и краткая справка |
| `/status` | Проверка состояния Gateway |
| `/skills` | Список доступных навыков |
| `/projects` | Список папок с проектами |
| `/reset` | Сброс сессии |
| `/help` | Помощь |
| `/id` | Показать ваш User ID |

### Примеры запросов

```
📁 Работа с файлами:
- "Покажи структуру папки projects"
- "Найди все файлы .py в проекте ROS2"
- "Прочитай файл README.md"

💻 Работа с кодом:
- "Создай Python скрипт для парсинга JSON"
- "Найди все TODO в коде"
- "Проанализируй этот код на ошибки"

🔧 Команды терминала:
- "Запусти git status в папке clawbot"
- "Покажи размер папки projects"

🌐 Веб-операции:
- "Открой сайт github.com и сделай скриншот"
```

## 🔧 Troubleshooting

### Бот не отвечает

1. Проверьте статус контейнера:
```powershell
docker compose ps
```

2. Проверьте логи:
```powershell
docker compose logs telegram-bot
```

3. Убедитесь что Gateway запущен:
```powershell
docker compose logs openclaw-gateway
```

### "Доступ запрещён"

Ваш User ID не в списке `TELEGRAM_ALLOWED_USERS`. Добавьте его:
```powershell
# Узнать ID: отправьте /id боту (если есть доступ) или используйте @userinfobot
```

### "Gateway недоступен"

```powershell
# Перезапустите сервисы
docker compose down
docker compose --profile telegram up -d
```

## 📊 Архитектура

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Telegram App   │────►│  telegram-bot   │────►│ openclaw-gateway│
│    (Mobile)     │     │   (Container)   │     │   (Container)   │
│                 │◄────│                 │◄────│                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                                ┌─────────────────┐
                                                │  Your Projects  │
                                                │  /home/node/    │
                                                │   projects/     │
                                                └─────────────────┘
```

## 🔒 Безопасность

- ✅ Авторизация по User ID — только вы можете использовать бота
- ✅ Бот работает в изолированном контейнере
- ✅ Gateway token защищает API
- ✅ Опасные операции выполняются в sandbox

## 📁 Структура файлов

```
clawbot/
├── telegram-bot/
│   ├── index.js        # Основной код бота
│   └── package.json    # Зависимости
├── Dockerfile.telegram # Dockerfile для бота
├── docker-compose.yml  # Конфигурация сервисов
├── .env               # Ваши настройки (не коммитить!)
└── .env.example       # Шаблон настроек
```
