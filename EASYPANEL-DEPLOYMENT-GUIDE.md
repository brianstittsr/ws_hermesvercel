# EasyPanel Customer Deployment Guide

Complete step-by-step guide for deploying customer instances of Hermes using EasyPanel, Docker, and Docker Compose.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [EasyPanel Setup](#easypanel-setup)
3. [Docker Socket Configuration](#docker-socket-configuration)
4. [Customer Instance Deployment](#customer-instance-deployment)
5. [Environment Configuration](#environment-configuration)
6. [Port Allocation](#port-allocation)
7. [Testing and Verification](#testing-and-verification)
8. [Multi-Customer Deployment](#multi-customer-deployment)
9. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software
- EasyPanel installed and running
- Docker and Docker Compose installed
- SSH access to the host server
- Basic knowledge of Docker and container management

### Required Information
- GitHub repository URL for Hermes
- Telegram bot tokens for each customer
- GitHub tokens for repository access (if using GitHub integration)
- Mattermost credentials (if using Mattermost integration)

## EasyPanel Setup

### Step 1: Access EasyPanel

1. Open your EasyPanel dashboard (typically `https://your-server.com`)
2. Log in with your admin credentials
3. Navigate to the **Services** section

### Step 2: Create New App Service

1. Click **"Create Service"** or **"Add App"**
2. Select **"Docker Compose"** as the service type
3. Enter a service name (e.g., `hermes-customer-01`)

### Step 3: Configure EasyPanel Settings

**Proxy Configuration:**
- **Proxy Port**: `9120` (Must match the port Hermes dashboard listens on)
- **Domain**: Your customer's domain (e.g., `customer01.yourdomain.com`)
- **SSL**: Enable SSL if available

**Important Notes:**
- Do not use host ports 80/443 (EasyPanel needs these for its proxy)
- The proxy port must match the dashboard port in docker-compose.yml
- EasyPanel will handle reverse proxy automatically

## Docker Socket Configuration

### Step 1: Get Docker Socket GID

On your host server (DigitalOcean, VPS, etc.), run:

```bash
# Get the Docker socket group ID
stat -c '%g' /var/run/docker.sock
```

**Expected Output:** A number like `998`, `999`, or similar

**Common GIDs:**
- Ubuntu/Debian: Usually `998` or `999`
- CentOS/RHEL: Usually `993` or `994`
- Alpine: Usually `999`

### Step 2: Configure DOCKER_GID

In your EasyPanel environment variables or docker-compose.yml:

```yaml
# Set the DOCKER_GID environment variable
DOCKER_GID=998  # Replace with your actual GID
```

### Step 3: Verify Docker Socket Access

After deployment, test Docker socket access:

```bash
# From the host server
docker compose exec dashboard docker ps
```

**Expected Output:** List of running containers

**If this fails:**
- Verify the GID is correct
- Check Docker socket permissions
- Ensure the container has proper group access

## Customer Instance Deployment

### Step 1: Prepare Repository

Clone or download the Hermes repository:

```bash
# SSH into your server
ssh user@your-server.com

# Clone the repository
git clone https://github.com/brianstittsr/ws_hermesvercel.git
cd ws_hermesvercel
```

### Step 2: Create Customer Environment File

Copy the environment template:

```bash
# Copy the customer environment template
cp .env.customer.example .env.customer-customer-01
```

### Step 3: Configure Customer Environment

Edit `.env.customer-customer-01`:

```bash
# Customer identification
CUSTOMER_NAME=customer-01
DASHBOARD_PORT=9120

# Docker socket GID (from Step 1)
DOCKER_GID=998

# Telegram configuration (unique per customer)
TELEGRAM_BOT_TOKEN=your-unique-telegram-bot-token

# Mattermost configuration (optional)
MATTERMOST_TOKEN=customer-mattermost-token
MATTERMOST_URL=https://customer-mattermost.com

# GitHub integration (optional)
GITHUB_TOKEN=ghp_customer-github-token
GITHUB_USERNAME=customer-github-username
GITHUB_REPOS=org/repo1,org/repo2

# Custom data volume
CUSTOMER_DATA_VOLUME=hermes-customer-01-data
```

### Step 4: Deploy to EasyPanel

**Option A: Via EasyPanel UI**

1. In EasyPanel, navigate to your service
2. Go to **"Settings"** → **"Environment Variables"**
3. Add all environment variables from your `.env.customer-customer-01` file
4. Paste the `docker-compose.customer.yml` content into the Compose file section
5. Click **"Deploy"**

**Option B: Via Docker Compose**

```bash
# Deploy using docker-compose
docker-compose -f docker-compose.customer.yml -p customer-01 up -d --build
```

### Step 5: Verify Deployment

Check that containers are running:

```bash
# Check container status
docker-compose -f docker-compose.customer.yml -p customer-01 ps

# Check logs
docker-compose -f docker-compose.customer.yml -p customer-01 logs gateway
docker-compose -f docker-compose.customer.yml -p customer-01 logs dashboard
```

## Environment Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `CUSTOMER_NAME` | Unique customer identifier | `customer-01` |
| `DASHBOARD_PORT` | Dashboard port (must match EasyPanel proxy) | `9120` |
| `DOCKER_GID` | Docker socket group ID | `998` |
| `TELEGRAM_BOT_TOKEN` | Customer's Telegram bot token | `123456:ABC-DEF...` |

### Optional Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `MATTERMOST_TOKEN` | Mattermost bot token | `abc123xyz...` |
| `MATTERMOST_URL` | Mattermost server URL | `https://mattermost.example.com` |
| `GITHUB_TOKEN` | GitHub personal access token | `ghp_123456...` |
| `GITHUB_USERNAME` | GitHub username | `customer-username` |
| `GITHUB_REPOS` | Comma-separated repositories | `org/repo1,org/repo2` |

### Security Best Practices

1. **Never commit environment files** to version control
2. **Use strong, unique tokens** for each customer
3. **Rotate tokens regularly** (every 90 days recommended)
4. **Limit repository access** to only necessary repos
5. **Enable audit logging** for all operations

## Port Allocation

### Port Allocation Strategy

Each customer instance needs a unique port in the range `9120-9199`.

**Allocation Rules:**
- First customer: `9120`
- Second customer: `9121`
- Third customer: `9122`
- And so on...

### Automatic Port Allocation

Use the provided port allocator:

```powershell
# Get next available port
.\port-allocator.ps1

# Get multiple available ports
.\port-allocator.ps1 -Count 3
```

### Manual Port Allocation

Check which ports are in use:

```bash
# Check used ports
netstat -tuln | grep LISTEN

# Or use the collision detector
.\collision-detector.ps1
```

### Port Configuration in EasyPanel

1. Set `DASHBOARD_PORT` in environment variables
2. Set EasyPanel proxy port to match
3. Ensure no port conflicts between customers

## Testing and Verification

### Step 1: Check Container Status

```bash
# Check if containers are running
docker-compose -f docker-compose.customer.yml -p customer-01 ps
```

**Expected Output:**
```
NAME                    STATUS
customer-01-gateway-1   Up
customer-01-dashboard-1 Up
```

### Step 2: Test Dashboard Access

```bash
# Test dashboard accessibility
curl http://localhost:9120
```

**Expected Output:** HTML response from dashboard

### Step 3: Test Docker Socket Access

```bash
# Test Docker socket access
docker-compose -f docker-compose.customer.yml -p customer-01 exec dashboard docker ps
```

**Expected Output:** List of running containers

### Step 4: Test Telegram Integration

1. Send a message to your Telegram bot
2. Verify Hermes responds
3. Check logs for any errors

```bash
# Check gateway logs for Telegram activity
docker-compose -f docker-compose.customer.yml -p customer-01 logs gateway -f
```

### Step 5: Test Gateway Communication

```bash
# Test dashboard can reach gateway
docker-compose -f docker-compose.customer.yml -p customer-01 exec dashboard curl http://gateway:8000
```

**Expected Output:** Gateway API response

## Multi-Customer Deployment

### Deployment Options

**Option 1: Sequential Deployment**

Deploy customers one at a time:

```powershell
# Deploy first customer
.\rapid-deploy.ps1 -CustomerName "customer-01" -Port 9120

# Deploy second customer
.\rapid-deploy.ps1 -CustomerName "customer-02" -Port 9121

# Deploy third customer
.\rapid-deploy.ps1 -CustomerName "customer-03" -Port 9122
```

**Option 2: Batch Deployment**

Deploy multiple customers simultaneously:

```powershell
# Deploy multiple customers at once
.\batch-deploy.ps1 -CustomerNames @("customer-01","customer-02","customer-03") -Parallel
```

### Customer Isolation

Each customer instance is isolated in the following ways:

- **Port Isolation**: Unique dashboard port per customer
- **Network Isolation**: Separate Docker network per customer
- **Data Isolation**: Separate data volume per customer
- **Bot Isolation**: Unique Telegram bot token per customer
- **Process Isolation**: Separate container namespaces

### Customer Management

**List all customers:**
```powershell
.\customer-manager.ps1 -Action List
```

**Check customer status:**
```powershell
.\customer-manager.ps1 -Action Status -CustomerName "customer-01"
```

**Stop customer:**
```powershell
.\customer-manager.ps1 -Action Stop -CustomerName "customer-01"
```

**Remove customer:**
```powershell
.\customer-manager.ps1 -Action Remove -CustomerName "customer-01"
```

## Troubleshooting

### Common Issues

#### Issue 1: Containers Not Starting

**Symptoms:**
- Containers show as "Exited" or won't start
- EasyPanel shows deployment failed

**Solutions:**
```bash
# Check container logs
docker-compose -f docker-compose.customer.yml -p customer-01 logs gateway
docker-compose -f docker-compose.customer.yml -p customer-01 logs dashboard

# Check for permission issues
docker-compose -f docker-compose.customer.yml -p customer-01 down
docker-compose -f docker-compose.customer.yml -p customer-01 up -d --build
```

#### Issue 2: Docker Socket Access Denied

**Symptoms:**
- `docker ps` command fails inside container
- Permission denied errors in logs

**Solutions:**
```bash
# Verify Docker socket GID
stat -c '%g' /var/run/docker.sock

# Update DOCKER_GID in environment
DOCKER_GID=<correct-gid>

# Redeploy
docker-compose -f docker-compose.customer.yml -p customer-01 up -d --build
```

#### Issue 3: Port Conflicts

**Symptoms:**
- Dashboard not accessible
- Port already in use errors

**Solutions:**
```bash
# Check port usage
netstat -tuln | grep 9120

# Use collision detector
.\collision-detector.ps1 -CustomerName "customer-01" -RequestedPort 9120

# Allocate new port
.\port-allocator.ps1
```

#### Issue 4: Gateway Not Reachable

**Symptoms:**
- Dashboard can't connect to gateway
- Network errors in logs

**Solutions:**
```bash
# Check network connectivity
docker-compose -f docker-compose.customer.yml -p customer-01 exec dashboard ping gateway

# Verify GATEWAY_URL
echo $GATEWAY_URL

# Check network configuration
docker network ls | grep customer-01
```

#### Issue 5: Telegram Bot Not Responding

**Symptoms:**
- Telegram bot doesn't respond to messages
- No activity in logs

**Solutions:**
```bash
# Verify Telegram bot token
echo $TELEGRAM_BOT_TOKEN

# Check gateway logs for Telegram activity
docker-compose -f docker-compose.customer.yml -p customer-01 logs gateway -f

# Re-authenticate Telegram
docker-compose -f docker-compose.customer.yml -p customer-01 exec gateway hermes auth add telegram
```

### Diagnostic Commands

**Full System Check:**
```bash
# Check all containers
docker ps

# Check Hermes containers
docker ps | grep hermes

# Check network status
docker network ls

# Check volume status
docker volume ls | grep hermes

# Check resource usage
docker stats
```

**Customer-Specific Diagnostics:**
```bash
# Customer container status
docker-compose -f docker-compose.customer.yml -p customer-01 ps

# Customer logs
docker-compose -f docker-compose.customer.yml -p customer-01 logs

# Customer network
docker network inspect hermes-customer-01-network

# Customer volume
docker volume inspect hermes-customer-01-data
```

### Getting Help

If issues persist:

1. **Check EasyPanel logs**: EasyPanel → Service → Logs
2. **Check Docker logs**: `docker logs <container-name>`
3. **Review this guide**: Ensure all steps were followed correctly
4. **Check GitHub issues**: https://github.com/brianstittsr/ws_hermesvercel/issues
5. **Contact support**: Provide diagnostic information from above

## Additional Resources

- [EasyPanel Documentation](https://easypanel.io/docs)
- [Docker Compose Documentation](https://docs.docker.com/compose)
- [Hermes Documentation](https://github.com/brianstittsr/ws_hermesvercel)
- [GitHub Integration Guide](./github-integration-skill.md)

## Quick Reference

**Deploy Single Customer:**
```powershell
.\rapid-deploy.ps1 -CustomerName "customer-01" -Port 9120
```

**Deploy Multiple Customers:**
```powershell
.\batch-deploy.ps1 -CustomerNames @("customer-01","customer-02") -Parallel
```

**Check Deployment Status:**
```powershell
.\customer-manager.ps1 -Action List
```

**Test Docker Socket Access:**
```bash
docker compose exec dashboard docker ps
```

**Get Docker Socket GID:**
```bash
stat -c '%g' /var/run/docker.sock
```

---

**Last Updated:** June 1, 2026  
**Version:** 1.0.0
