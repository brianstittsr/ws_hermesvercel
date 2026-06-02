# EasyPanel Customer Deployment Guide

A simple step-by-step guide to set up Hermes for your customers using EasyPanel.

## What You'll Need

- EasyPanel installed and running on your server
- Docker and Docker Compose installed
- Access to your server (SSH or direct access)
- Telegram bot tokens for each customer
- GitHub tokens (if you want to use GitHub features)

## Getting Started with EasyPanel
`
### Step 1: Open EasyPanel

1. Go to your EasyPanel website (usually `https://your-server.com`)
2. Log in with your username and password
3. Click on "Services" in the menu

### Step 2: Create a New Service

1. Click "Create Service" or "Add App"
2. Choose "Docker Compose" as the type
3. Name it something like "hermes-customer-01"

### Step 3: Set Up the Connection

**Port Settings:**
- Set the proxy port to `9120`
- Add your customer's domain (like `customer01.yourdomain.com`)
- Turn on SSL if you have it

**Important:** Don't use ports 80 or 443 - EasyPanel needs those for itself.

## Setting Up Docker Access

### Step 1: Find Your Docker Group Number

On your server, run this command:

```bash
stat -c '%g' /var/run/docker.sock
```

You'll get a number like `998` or `999`. Write this down.

### Step 2: Add the Number to Your Settings

In your EasyPanel settings or configuration file, add:

```
DOCKER_GID=998
```

(Replace 998 with the number you got in step 1)

### Step 3: Test It Works

After you deploy, test it with:

```bash
docker compose exec dashboard docker ps
```

If you see a list of containers, it's working!

## Setting Up a Customer

### Step 1: Get the Hermes Files

```bash
# Connect to your server
ssh user@your-server.com

# Download Hermes
git clone https://github.com/brianstittsr/ws_hermesvercel.git
cd ws_hermesvercel
```

### Step 2: Create a Customer Settings File

```bash
# Copy the template
cp .env.customer.example .env.customer-customer-01
```

### Step 3: Fill in the Customer Details

Edit the `.env.customer-customer-01` file:

```
# Customer name
CUSTOMER_NAME=customer-01
DASHBOARD_PORT=9120

# Docker group number (from earlier)
DOCKER_GID=998

# Hermes home directory (important for saving model settings)
HERMES_HOME=/home/hermes

# Telegram bot token (get this from Telegram)
TELEGRAM_BOT_TOKEN=your-telegram-bot-token-here

# Optional: Mattermost
MATTERMOST_TOKEN=your-mattermost-token
MATTERMOST_URL=https://your-mattermost.com

# Optional: GitHub
GITHUB_TOKEN=your-github-token
GITHUB_USERNAME=your-github-username
GITHUB_REPOS=org/repo1,org/repo2
```

### Step 4: Deploy It

**Using EasyPanel:**
1. Go to your service in EasyPanel
2. Click "Settings" then "Environment Variables"
3. Add all the settings from your file
4. Paste the docker-compose.customer.yml content
5. Click "Deploy"

**Using Command Line:**
```bash
docker-compose -f docker-compose.customer.yml -p customer-01 up -d --build
```

### Step 5: Check It's Running

```bash
# See if containers are running
docker-compose -f docker-compose.customer.yml -p customer-01 ps

# See the logs
docker-compose -f docker-compose.customer.yml -p customer-01 logs gateway
docker-compose -f docker-compose.customer.yml -p customer-01 logs dashboard
```

## What Each Setting Does

**Required Settings:**
- `CUSTOMER_NAME` - A unique name for this customer
- `DASHBOARD_PORT` - The port number (must match EasyPanel)
- `DOCKER_GID` - The Docker group number from earlier
- `TELEGRAM_BOT_TOKEN` - The token for their Telegram bot

**Optional Settings:**
- `MATTERMOST_TOKEN` - If using Mattermost chat
- `MATTERMOST_URL` - Your Mattermost server address
- `GITHUB_TOKEN` - For GitHub access
- `GITHUB_USERNAME` - GitHub username
- `GITHUB_REPOS` - Which GitHub repos to access

## Choosing Port Numbers

Each customer needs their own port number. Use numbers from 9120 to 9199.

**Simple rule:**
- First customer: 9120
- Second customer: 9121
- Third customer: 9122
- And so on...

**Find an available port:**
```powershell
.\port-allocator.ps1
```

**Check what's already in use:**
```bash
netstat -tuln | grep LISTEN
```

## Testing Everything Works

### 1. Check Containers Are Running
```bash
docker-compose -f docker-compose.customer.yml -p customer-01 ps
```

You should see both gateway and dashboard showing as "Up".

### 2. Test the Dashboard
```bash
curl http://localhost:9120
```

You should get HTML code back.

### 3. Test Docker Access
```bash
docker-compose -f docker-compose.customer.yml -p customer-01 exec dashboard docker ps
```

You should see a list of containers.

### 4. Test Telegram
Send a message to your Telegram bot and check if Hermes responds.

```bash
# Watch the logs
docker-compose -f docker-compose.customer.yml -p customer-01 logs gateway -f
```

### 5. Test Gateway Connection
```bash
docker-compose -f docker-compose.customer.yml -p customer-01 exec dashboard curl http://gateway:8000
```

## Setting Up Multiple Customers

### Option 1: One at a Time

```powershell
# First customer
.\rapid-deploy.ps1 -CustomerName "customer-01" -Port 9120

# Second customer
.\rapid-deploy.ps1 -CustomerName "customer-02" -Port 9121

# Third customer
.\rapid-deploy.ps1 -CustomerName "customer-03" -Port 9122
```

### Option 2: All at Once

```powershell
# Deploy multiple customers together
.\batch-deploy.ps1 -CustomerNames @("customer-01","customer-02","customer-03") -Parallel
```

### How Customers Stay Separate

Each customer gets:
- Their own port number
- Their own network
- Their own data storage
- Their own Telegram bot
- Their own containers

### Managing Customers

**See all customers:**
```powershell
.\customer-manager.ps1 -Action List
```

**Check one customer:**
```powershell
.\customer-manager.ps1 -Action Status -CustomerName "customer-01"
```

**Stop a customer:**
```powershell
.\customer-manager.ps1 -Action Stop -CustomerName "customer-01"
```

**Remove a customer:**
```powershell
.\customer-manager.ps1 -Action Remove -CustomerName "customer-01"
```

## Fixing Common Problems

### Problem: Containers Won't Start

**What you see:** Containers show as "Exited" or EasyPanel says deployment failed

**Try this:**
```bash
# Check the logs
docker-compose -f docker-compose.customer.yml -p customer-01 logs gateway
docker-compose -f docker-compose.customer.yml -p customer-01 logs dashboard

# Try rebuilding
docker-compose -f docker-compose.customer.yml -p customer-01 down
docker-compose -f docker-compose.customer.yml -p customer-01 up -d --build
```

### Problem: Docker Access Denied

**What you see:** Docker commands fail inside the container

**Try this:**
```bash
# Check your Docker group number
stat -c '%g' /var/run/docker.sock

# Update the DOCKER_GID setting
DOCKER_GID=<correct-number>

# Redeploy
docker-compose -f docker-compose.customer.yml -p customer-01 up -d --build
```

### Problem: Port Already in Use

**What you see:** Dashboard won't load, port errors

**Try this:**
```bash
# Check what's using the port
netstat -tuln | grep 9120

# Find a free port
.\port-allocator.ps1

# Use a different port number
```

### Problem: Gateway Not Connected

**What you see:** Dashboard can't reach the gateway

**Try this:**
```bash
# Test the connection
docker-compose -f docker-compose.customer.yml -p customer-01 exec dashboard ping gateway

# Check the network
docker network ls | grep customer-01
```

### Problem: Telegram Bot Not Working

**What you see:** Bot doesn't respond to messages

**Try this:**
```bash
# Check your token
echo $TELEGRAM_BOT_TOKEN

# Watch the logs
docker-compose -f docker-compose.customer.yml -p customer-01 logs gateway -f

# Re-authenticate
docker-compose -f docker-compose.customer.yml -p customer-01 exec gateway hermes auth add telegram
```

### Problem: Model Provider Not Saved

**What you see:** Model provider set with `hermes model` is lost after restart

**Cause:** Hermes stores configuration in `~/.hermes/` which needs to be persisted

**Try this:**
```bash
# Check if HERMES_HOME is set
echo $HERMES_HOME

# Check if home volume is mounted
docker volume ls | grep hermes-home

# Verify configuration directory exists
docker-compose -f docker-compose.customer.yml -p customer-01 exec gateway ls -la /home/hermes/.hermes

# Ensure HERMES_HOME is in your environment variables
HERMES_HOME=/home/hermes
```

## Useful Commands

**Check everything:**
```bash
docker ps
docker network ls
docker volume ls | grep hermes
```

**Check one customer:**
```bash
docker-compose -f docker-compose.customer.yml -p customer-01 ps
docker-compose -f docker-compose.customer.yml -p customer-01 logs
```

## Quick Reference

**Deploy one customer:**
```powershell
.\rapid-deploy.ps1 -CustomerName "customer-01" -Port 9120
```

**Deploy many customers:**
```powershell
.\batch-deploy.ps1 -CustomerNames @("customer-01","customer-02") -Parallel
```

**See all customers:**
```powershell
.\customer-manager.ps1 -Action List
```

**Test Docker access:**
```bash
docker compose exec dashboard docker ps
```

**Get Docker group number:**
```bash
stat -c '%g' /var/run/docker.sock
```

## Need More Help?

1. Check EasyPanel logs in the EasyPanel dashboard
2. Check Docker logs with `docker logs <container-name>`
3. Make sure you followed all the steps in this guide
4. Check for help at https://github.com/brianstittsr/ws_hermesvercel/issues

---

**Last Updated:** June 1, 2026
