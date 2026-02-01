# =============================================================================
# Clawbot Quick Setup Script for Windows
# =============================================================================
# Run this script in PowerShell to quickly set up Clawbot
# =============================================================================

Write-Host "🤖 Clawbot Quick Setup" -ForegroundColor Cyan
Write-Host "=" * 50

# Check Docker
Write-Host "`n📋 Checking Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✅ $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker not found! Please install Docker Desktop." -ForegroundColor Red
    Write-Host "   Download: https://www.docker.com/products/docker-desktop/" -ForegroundColor Gray
    exit 1
}

# Check Docker Compose
try {
    $composeVersion = docker compose version
    Write-Host "✅ $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker Compose not found!" -ForegroundColor Red
    exit 1
}

# Check .env file
Write-Host "`n📋 Checking configuration..." -ForegroundColor Yellow
$envFile = Join-Path $PSScriptRoot ".env"

if (!(Test-Path $envFile)) {
    Write-Host "⚠️  .env file not found, creating from template..." -ForegroundColor Yellow
    Copy-Item (Join-Path $PSScriptRoot ".env.example") $envFile
    Write-Host "✅ Created .env file" -ForegroundColor Green
}

# Read current .env
$envContent = Get-Content $envFile -Raw

# Check GATEWAY_TOKEN
if ($envContent -match "OPENCLAW_GATEWAY_TOKEN=CHANGE_ME" -or $envContent -match "OPENCLAW_GATEWAY_TOKEN=\s*$") {
    Write-Host "`n🔐 Generating secure Gateway Token..." -ForegroundColor Yellow
    $token = -join ((1..32) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })
    $envContent = $envContent -replace "OPENCLAW_GATEWAY_TOKEN=.*", "OPENCLAW_GATEWAY_TOKEN=$token"
    Set-Content $envFile $envContent
    Write-Host "✅ Gateway token generated and saved" -ForegroundColor Green
}

# Show remaining setup steps
Write-Host "`n" + "=" * 50
Write-Host "📝 REMAINING SETUP STEPS:" -ForegroundColor Cyan
Write-Host "=" * 50

$needsSetup = @()

# Check API keys
if ($envContent -match "OPENAI_API_KEY=\s*$" -and $envContent -match "ANTHROPIC_API_KEY=\s*$" -and $envContent -match "GOOGLE_API_KEY=\s*$") {
    $needsSetup += @{
        Step = "1"
        Title = "Add AI API Key"
        Description = "Edit .env and add at least one API key:`n   OPENAI_API_KEY=sk-xxx... or ANTHROPIC_API_KEY=sk-ant-xxx..."
    }
}

# Check Telegram
if ($envContent -match "TELEGRAM_BOT_TOKEN=\s*$") {
    $needsSetup += @{
        Step = "2"
        Title = "Configure Telegram Bot (Optional)"
        Description = "1. Message @BotFather on Telegram`n   2. Send /newbot and create your bot`n   3. Copy the token to .env: TELEGRAM_BOT_TOKEN=xxx`n   4. Message @userinfobot to get your user ID`n   5. Add to .env: TELEGRAM_ALLOWED_USERS=your_id"
    }
}

if ($needsSetup.Count -gt 0) {
    foreach ($item in $needsSetup) {
        Write-Host "`n$($item.Step). $($item.Title)" -ForegroundColor Yellow
        Write-Host "   $($item.Description)" -ForegroundColor Gray
    }
} else {
    Write-Host "✅ All configuration looks complete!" -ForegroundColor Green
}

Write-Host "`n" + "=" * 50
Write-Host "🚀 QUICK START COMMANDS:" -ForegroundColor Cyan
Write-Host "=" * 50

Write-Host "`n# Build images (first time only):" -ForegroundColor Yellow
Write-Host "docker compose build" -ForegroundColor White

Write-Host "`n# Start Gateway only:" -ForegroundColor Yellow
Write-Host "docker compose up -d openclaw-gateway" -ForegroundColor White

Write-Host "`n# Start with Telegram bot:" -ForegroundColor Yellow
Write-Host "docker compose --profile telegram up -d" -ForegroundColor White

Write-Host "`n# View logs:" -ForegroundColor Yellow
Write-Host "docker compose logs -f" -ForegroundColor White

Write-Host "`n# Stop everything:" -ForegroundColor Yellow
Write-Host "docker compose down" -ForegroundColor White

Write-Host "`n" + "=" * 50
Write-Host "📁 Your projects will be available at: /home/node/projects" -ForegroundColor Cyan
Write-Host "=" * 50
Write-Host ""
