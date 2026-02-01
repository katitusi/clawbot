const TelegramBot = require('node-telegram-bot-api');
const axios = require('axios');

// =============================================================================
// Configuration
// =============================================================================
const config = {
    telegramToken: process.env.TELEGRAM_BOT_TOKEN,
    allowedUsers: (process.env.TELEGRAM_ALLOWED_USERS || '').split(',').map(id => parseInt(id.trim())).filter(id => !isNaN(id)),
    gatewayUrl: process.env.OPENCLAW_GATEWAY_URL || 'http://openclaw-gateway:18789',
    gatewayToken: process.env.OPENCLAW_GATEWAY_TOKEN,
    logLevel: process.env.LOG_LEVEL || 'info'
};

// =============================================================================
// Validation
// =============================================================================
if (!config.telegramToken) {
    console.error('❌ TELEGRAM_BOT_TOKEN is required!');
    console.error('   Get it from @BotFather in Telegram');
    process.exit(1);
}

if (config.allowedUsers.length === 0) {
    console.error('❌ TELEGRAM_ALLOWED_USERS is required!');
    console.error('   Get your user ID from @userinfobot in Telegram');
    process.exit(1);
}

if (!config.gatewayToken) {
    console.error('❌ OPENCLAW_GATEWAY_TOKEN is required!');
    process.exit(1);
}

// =============================================================================
// Initialize Bot
// =============================================================================
const bot = new TelegramBot(config.telegramToken, { polling: true });

console.log('🤖 Clawbot Telegram interface starting...');
console.log(`📋 Allowed users: ${config.allowedUsers.join(', ')}`);
console.log(`🔗 Gateway URL: ${config.gatewayUrl}`);

// =============================================================================
// Auth Middleware
// =============================================================================
function isAuthorized(userId) {
    return config.allowedUsers.includes(userId);
}

// =============================================================================
// Gateway API Client
// =============================================================================
const gateway = axios.create({
    baseURL: config.gatewayUrl,
    headers: {
        'Authorization': `Bearer ${config.gatewayToken}`,
        'Content-Type': 'application/json'
    },
    timeout: 120000 // 2 minutes for long operations
});

// =============================================================================
// Session Storage (in-memory, per user)
// =============================================================================
const sessions = new Map();

// =============================================================================
// Message Handler
// =============================================================================
bot.on('message', async (msg) => {
    const chatId = msg.chat.id;
    const userId = msg.from.id;
    const text = msg.text;

    // Auth check
    if (!isAuthorized(userId)) {
        console.log(`⛔ Unauthorized access attempt from user ${userId} (@${msg.from.username || 'unknown'})`);
        await bot.sendMessage(chatId, '⛔ Доступ запрещён. Вы не авторизованы для использования этого бота.');
        return;
    }

    // Ignore non-text messages for now
    if (!text) {
        if (msg.document) {
            await bot.sendMessage(chatId, '📎 Получен файл. Функция загрузки файлов пока в разработке.');
        }
        return;
    }

    console.log(`📨 [${userId}] ${text.substring(0, 100)}${text.length > 100 ? '...' : ''}`);

    // Command handling
    if (text.startsWith('/')) {
        await handleCommand(chatId, userId, text);
        return;
    }

    // Regular message - send to agent
    await handleAgentMessage(chatId, userId, text);
});

// =============================================================================
// Command Handler
// =============================================================================
async function handleCommand(chatId, userId, text) {
    const [command, ...args] = text.split(' ');

    switch (command.toLowerCase()) {
        case '/start':
            await bot.sendMessage(chatId, 
                `🤖 *Clawbot* готов к работе!\n\n` +
                `Я — AI-агент с доступом к:\n` +
                `• 📁 Файловой системе (твои проекты)\n` +
                `• 💻 Терминалу\n` +
                `• 🌐 Браузеру\n` +
                `• 🔧 Различным инструментам\n\n` +
                `Просто напиши, что нужно сделать!\n\n` +
                `*Команды:*\n` +
                `/status — статус системы\n` +
                `/skills — доступные навыки\n` +
                `/projects — список проектов\n` +
                `/reset — сбросить сессию\n` +
                `/help — помощь`,
                { parse_mode: 'Markdown' }
            );
            break;

        case '/status':
            await checkStatus(chatId);
            break;

        case '/skills':
            await listSkills(chatId);
            break;

        case '/projects':
            await listProjects(chatId);
            break;

        case '/reset':
            sessions.delete(userId);
            await bot.sendMessage(chatId, '🔄 Сессия сброшена. Начинаем с чистого листа!');
            break;

        case '/help':
            await bot.sendMessage(chatId,
                `📚 *Помощь по Clawbot*\n\n` +
                `*Примеры запросов:*\n` +
                `• "Покажи структуру папки projects"\n` +
                `• "Создай новый Python проект с названием myapp"\n` +
                `• "Найди все TODO в коде"\n` +
                `• "Запусти тесты в проекте X"\n` +
                `• "Открой сайт example.com и сделай скриншот"\n` +
                `• "Проанализируй этот код и найди ошибки"\n\n` +
                `*Рабочие директории:*\n` +
                `\`/home/node/projects\` — твои проекты\n` +
                `\`/home/node/workspace\` — рабочая область\n\n` +
                `*Безопасность:*\n` +
                `Опасные операции выполняются в sandbox.`,
                { parse_mode: 'Markdown' }
            );
            break;

        case '/id':
            await bot.sendMessage(chatId, `🆔 Твой User ID: \`${userId}\``, { parse_mode: 'Markdown' });
            break;

        default:
            await bot.sendMessage(chatId, `❓ Неизвестная команда: ${command}\n\nИспользуй /help для списка команд.`);
    }
}

// =============================================================================
// Check Gateway Status
// =============================================================================
async function checkStatus(chatId) {
    await bot.sendChatAction(chatId, 'typing');
    
    try {
        const response = await gateway.get('/health');
        const data = response.data;
        
        await bot.sendMessage(chatId, 
            `✅ *Статус системы*\n\n` +
            `🟢 Gateway: Online\n` +
            `📦 Version: ${data.version || 'unknown'}\n` +
            `⏱ Uptime: ${data.uptime ? Math.floor(data.uptime / 60) + ' мин' : 'unknown'}\n` +
            `💾 Memory: ${data.memory ? Math.floor(data.memory.heapUsed / 1024 / 1024) + ' MB' : 'unknown'}`,
            { parse_mode: 'Markdown' }
        );
    } catch (error) {
        console.error('Status check error:', error.message);
        await bot.sendMessage(chatId, 
            `❌ *Gateway недоступен*\n\n` +
            `Ошибка: ${error.message}\n\n` +
            `Попробуй:\n` +
            `\`docker compose up -d openclaw-gateway\``,
            { parse_mode: 'Markdown' }
        );
    }
}

// =============================================================================
// List Available Skills
// =============================================================================
async function listSkills(chatId) {
    await bot.sendChatAction(chatId, 'typing');
    
    try {
        const response = await gateway.get('/api/skills');
        const skills = response.data.skills || response.data || [];
        
        if (Array.isArray(skills) && skills.length > 0) {
            const skillList = skills.map(s => `• ${s.name || s}`).join('\n');
            await bot.sendMessage(chatId,
                `🔧 *Доступные навыки:*\n\n${skillList}`,
                { parse_mode: 'Markdown' }
            );
        } else {
            await bot.sendMessage(chatId,
                `🔧 *Навыки*\n\n` +
                `Базовые навыки активны:\n` +
                `• 📁 Файловая система\n` +
                `• 💻 Терминал\n` +
                `• 🌐 Веб-браузер\n` +
                `• 📝 Редактирование кода\n\n` +
                `Дополнительные навыки можно установить через clawhub.`,
                { parse_mode: 'Markdown' }
            );
        }
    } catch (error) {
        console.error('Skills list error:', error.message);
        await bot.sendMessage(chatId,
            `🔧 *Базовые навыки:*\n\n` +
            `• 📁 Работа с файлами\n` +
            `• 💻 Выполнение команд\n` +
            `• 🌐 Веб-браузер\n` +
            `• 📝 Редактирование кода`,
            { parse_mode: 'Markdown' }
        );
    }
}

// =============================================================================
// List Projects
// =============================================================================
async function listProjects(chatId) {
    await bot.sendChatAction(chatId, 'typing');
    
    try {
        const response = await gateway.post('/api/chat', {
            message: 'List all directories in /home/node/projects. Show only folder names, one per line.',
            context: { source: 'telegram', quick: true }
        });
        
        await bot.sendMessage(chatId,
            `📁 *Проекты:*\n\n${response.data.response || 'Папка проектов пуста или недоступна.'}`,
            { parse_mode: 'Markdown' }
        );
    } catch (error) {
        await bot.sendMessage(chatId,
            `📁 *Проекты*\n\n` +
            `Не удалось получить список.\n` +
            `Проверь, что папка проектов подключена в docker-compose.yml`,
            { parse_mode: 'Markdown' }
        );
    }
}

// =============================================================================
// Handle Agent Message
// =============================================================================
async function handleAgentMessage(chatId, userId, text) {
    // Send typing indicator
    await bot.sendChatAction(chatId, 'typing');

    // Keep sending typing indicator for long operations
    const typingInterval = setInterval(() => {
        bot.sendChatAction(chatId, 'typing').catch(() => {});
    }, 4000);

    // Get or create session
    let session = sessions.get(userId);
    if (!session) {
        session = { id: null, history: [] };
        sessions.set(userId, session);
    }

    try {
        // Send message to gateway
        const response = await gateway.post('/api/chat', {
            session_id: session.id,
            message: text,
            context: {
                source: 'telegram',
                user_id: userId,
                workspace: '/home/node/projects'
            }
        });

        clearInterval(typingInterval);

        // Update session
        if (response.data.session_id) {
            session.id = response.data.session_id;
        }
        
        // Keep last 20 messages in history
        session.history.push({ role: 'user', content: text });
        session.history.push({ role: 'assistant', content: response.data.response });
        if (session.history.length > 40) {
            session.history = session.history.slice(-40);
        }

        // Send response
        const reply = response.data.response || 'Получен пустой ответ от агента.';
        await sendLongMessage(chatId, reply);

    } catch (error) {
        clearInterval(typingInterval);
        console.error(`❌ Gateway error:`, error.message);
        
        if (error.response?.status === 401) {
            await bot.sendMessage(chatId, 
                '🔐 *Ошибка авторизации*\n\n' +
                'Проверьте OPENCLAW\\_GATEWAY\\_TOKEN в .env файле.',
                { parse_mode: 'Markdown' }
            );
        } else if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
            await bot.sendMessage(chatId, 
                '🔌 *Gateway недоступен*\n\n' +
                'Запустите:\n`docker compose up -d openclaw-gateway`',
                { parse_mode: 'Markdown' }
            );
        } else if (error.code === 'ETIMEDOUT') {
            await bot.sendMessage(chatId,
                '⏱ *Таймаут*\n\n' +
                'Операция заняла слишком много времени. Попробуйте разбить задачу на части.',
                { parse_mode: 'Markdown' }
            );
        } else {
            await bot.sendMessage(chatId, `❌ Ошибка: ${error.message}`);
        }
    }
}

// =============================================================================
// Send Long Messages (Telegram limit: 4096 chars)
// =============================================================================
async function sendLongMessage(chatId, text) {
    const maxLength = 4000;
    
    // Try to send as markdown first
    const sendWithFallback = async (content) => {
        try {
            await bot.sendMessage(chatId, content, { parse_mode: 'Markdown' });
        } catch (parseError) {
            // Fallback: send without markdown
            try {
                await bot.sendMessage(chatId, content);
            } catch (sendError) {
                console.error('Failed to send message:', sendError.message);
            }
        }
    };
    
    if (text.length <= maxLength) {
        await sendWithFallback(text);
        return;
    }

    // Split by paragraphs or force split
    const chunks = [];
    let remaining = text;
    
    while (remaining.length > 0) {
        if (remaining.length <= maxLength) {
            chunks.push(remaining);
            break;
        }
        
        // Try to split at paragraph
        let splitIndex = remaining.lastIndexOf('\n\n', maxLength);
        
        // Try to split at line break
        if (splitIndex === -1 || splitIndex < maxLength / 2) {
            splitIndex = remaining.lastIndexOf('\n', maxLength);
        }
        
        // Try to split at sentence
        if (splitIndex === -1 || splitIndex < maxLength / 2) {
            splitIndex = remaining.lastIndexOf('. ', maxLength);
            if (splitIndex !== -1) splitIndex += 1;
        }
        
        // Force split at max length
        if (splitIndex === -1 || splitIndex < maxLength / 2) {
            splitIndex = maxLength;
        }
        
        chunks.push(remaining.substring(0, splitIndex));
        remaining = remaining.substring(splitIndex).trim();
    }

    // Send chunks with small delay
    for (let i = 0; i < chunks.length; i++) {
        const chunk = chunks[i];
        const header = chunks.length > 1 ? `📄 (${i + 1}/${chunks.length})\n\n` : '';
        await sendWithFallback(header + chunk);
        
        if (i < chunks.length - 1) {
            await new Promise(resolve => setTimeout(resolve, 500));
        }
    }
}

// =============================================================================
// Error Handlers
// =============================================================================
bot.on('polling_error', (error) => {
    console.error('Polling error:', error.message);
});

bot.on('error', (error) => {
    console.error('Bot error:', error.message);
});

// =============================================================================
// Health Check Server
// =============================================================================
const http = require('http');
const healthServer = http.createServer((req, res) => {
    if (req.url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ 
            status: 'ok', 
            uptime: process.uptime(),
            sessions: sessions.size,
            allowedUsers: config.allowedUsers.length
        }));
    } else if (req.url === '/') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('Clawbot Telegram Bot is running!');
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

const healthPort = process.env.HEALTH_PORT || 3000;
healthServer.listen(healthPort, () => {
    console.log(`🏥 Health check server on port ${healthPort}`);
});

// =============================================================================
// Graceful Shutdown
// =============================================================================
const shutdown = () => {
    console.log('👋 Shutting down gracefully...');
    bot.stopPolling();
    healthServer.close();
    setTimeout(() => process.exit(0), 1000);
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

// =============================================================================
// Startup Complete
// =============================================================================
console.log('✅ Clawbot Telegram bot is running!');
console.log('📱 Send /start to your bot to begin');
