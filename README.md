# Hermes Agent — Web UI & Docker Deployment

Browser-based dashboard for managing Hermes Agent configuration, API keys, and monitoring active sessions. Deployable with Docker Compose for production use.

## Stack

- **Vite** + **React 19** + **TypeScript**
- **Tailwind CSS v4** with custom dark theme
- **shadcn/ui**-style components (hand-rolled, no CLI dependency)
- **Docker Compose** for containerized deployment

## Quick Start (Docker)

```bash
# Clone and start the services
git clone <repository-url>
cd HermesVercel
docker-compose up -d --build

# The dashboard will be available at http://localhost:9120
```

## Auto-Start Setup

### Option 1: Windows Auto-Start (Recommended)

Run the provided PowerShell script to configure automatic startup:

```powershell
# Run as administrator
.\setup-autostart.ps1
```

Or use the batch file:
```cmd
setup-autostart.bat
```

This will:
- Add Docker Desktop to Windows startup
- Start Docker Desktop if not running
- Start Hermes containers automatically
- Configure containers to restart on system boot

### Option 2: Manual Auto-Start

1. **Add Docker Desktop to Windows startup:**
   - Press `Win + R`, type `shell:startup`
   - Create shortcut to `C:\Program Files\Docker\Docker\Docker Desktop.exe`

2. **Start containers on boot:**
   ```cmd
   # Create a startup script
   echo @echo off > "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\start-hermes.bat"
   echo cd /d "C:\path\to\HermesVercel" >> "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\start-hermes.bat"
   echo docker-compose up -d >> "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\start-hermes.bat"
   ```

### Current Auto-Start Behavior

Your containers are already configured with `restart: unless-stopped`, which means they will:
- ✅ Auto-restart if Docker daemon restarts
- ✅ Auto-restart if containers crash
- ✅ Persist across system reboots (once Docker is running)

## Authentication Setup

After starting the services, you need to authenticate with the required providers:

```bash
# Authenticate with Codex (ChatGPT) for AI model access
docker-compose exec gateway hermes auth codex

# Set up messaging platforms (optional)
docker-compose exec gateway hermes gateway setup
# Follow prompts to configure Telegram, Mattermost, etc.

# Check authentication status
docker-compose exec gateway hermes auth status
```

## Development

```bash
# Start the backend API server
cd ../
python -m hermes_cli.main web --no-open

# In another terminal, start the Vite dev server (with HMR + API proxy)
cd web/
npm run dev
```

The Vite dev server proxies `/api` requests to `http://127.0.0.1:9120` (the FastAPI backend).

## Build

```bash
npm run build
```

This outputs to `../hermes_cli/web_dist/`, which the FastAPI server serves as a static SPA. The built assets are included in the Python package via `pyproject.toml` package-data.

## Troubleshooting

### Permission Denied Errors
If you see `Permission denied: '/opt/data/config.yaml'` or similar errors:

```bash
# Reset containers and volumes
docker-compose down -v
docker-compose up -d --build

# Re-authenticate
docker-compose exec gateway hermes auth codex
```

### Authentication Failures
- **Codex**: Run `docker-compose exec gateway hermes auth codex` to re-authenticate
- **Mattermost**: Check `MATTERMOST_TOKEN` and `MATTERMOST_URL` environment variables
- **Telegram**: Ensure only one bot instance is running per token

### Common Issues
- **'NoneType' object is not iterable**: Re-authenticate with Codex
- **Invalid HTTP request received**: Usually harmless dashboard warnings
- **Platform paused after failures**: Fix underlying issue, then run `/platform resume <platform>` in chat

## Structure

```
src/
├── components/ui/   # Reusable UI primitives (Card, Badge, Button, Input, etc.)
├── lib/
│   ├── api.ts       # API client — typed fetch wrappers for all backend endpoints
│   └── utils.ts     # cn() helper for Tailwind class merging
├── pages/
│   ├── StatusPage   # Agent status, active/recent sessions
│   ├── ConfigPage   # Dynamic config editor (reads schema from backend)
│   └── EnvPage      # API key management with save/clear
├── App.tsx          # Main layout and navigation
├── main.tsx         # React entry point
└── index.css        # Tailwind imports and theme variables
```

## Environment Variables

Key environment variables for Docker deployment:

- `HERMES_UID=10000` - Container user ID
- `HERMES_GID=10000` - Container group ID  
- `GATEWAY_ALLOW_ALL_USERS=true` - Allow all users (development)
- `MATTERMOST_TOKEN` - Mattermost bot token (optional)
- `MATTERMOST_URL` - Mattermost server URL (optional)
