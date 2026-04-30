# Deployment Guide — Гайд по деплою в production

## Overview

Полное руководство по развертыванию cstatiWarehouse в production окружении с использованием Docker, PostgreSQL, и облачной инфраструктуры.

## Архитектура Production

```
┌─────────────────────────────────────────────────────────┐
│                    CloudFlare CDN                        │
│              (SSL, DDoS protection, Cache)               │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                  Load Balancer                           │
│              (nginx / AWS ALB)                           │
└────────┬────────────────────────────┬───────────────────┘
         │                            │
         ▼                            ▼
┌──────────────────┐        ┌──────────────────┐
│   Backend #1     │        │   Backend #2     │
│   (Docker)       │        │   (Docker)       │
│   Port 8080      │        │   Port 8080      │
└────────┬─────────┘        └────────┬─────────┘
         │                            │
         └────────────┬───────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │   PostgreSQL           │
         │   (Managed DB)         │
         └────────────────────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │   S3 + CloudFront      │
         │   (Images)             │
         └────────────────────────┘
```

## Prerequisites

### Требования

- **Server**: Ubuntu 22.04 LTS (минимум 2 CPU, 4GB RAM)
- **Docker**: 24.0+
- **Docker Compose**: 2.20+
- **PostgreSQL**: 15+ (managed или self-hosted)
- **Domain**: с настроенным DNS
- **SSL Certificate**: Let's Encrypt или CloudFlare

### Подготовка сервера

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose-plugin

# Create app user
sudo useradd -m -s /bin/bash cstati
sudo usermod -aG docker cstati

# Create directories
sudo mkdir -p /opt/cstati-warehouse
sudo chown cstati:cstati /opt/cstati-warehouse
```

## Backend Deployment

### 1. Dockerfile (Production)

**`backend/Dockerfile.prod`**:

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Install dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${VERSION:-dev} -X main.buildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -o /build/server \
    ./cmd/server

# Runtime stage
FROM alpine:3.18

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/server /app/server
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# Copy migrations
COPY migrations /app/migrations

# Set ownership
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run
CMD ["/app/server"]
```

### 2. Docker Compose (Production)

**`docker-compose.prod.yml`**:

```yaml
version: '3.8'

services:
  backend:
    image: ghcr.io/cstati/warehouse-backend:${VERSION:-latest}
    container_name: cstati-backend
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      # Server
      - SERVER_PORT=8080
      - SERVER_ENV=production
      
      # Database
      - DB_HOST=${DB_HOST}
      - DB_PORT=${DB_PORT:-5432}
      - DB_NAME=${DB_NAME}
      - DB_USER=${DB_USER}
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_SSL_MODE=require
      - DB_MAX_CONNS=25
      - DB_MIN_CONNS=5
      
      # JWT
      - JWT_SECRET=${JWT_SECRET}
      - JWT_ACCESS_TTL=15m
      - JWT_REFRESH_TTL=7d
      
      # S3
      - S3_ENABLED=true
      - S3_BUCKET=${S3_BUCKET}
      - S3_REGION=${S3_REGION}
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
      - CLOUDFRONT_URL=${CLOUDFRONT_URL}
      
      # CORS
      - CORS_ALLOWED_ORIGINS=${CORS_ALLOWED_ORIGINS}
      
      # Rate Limiting
      - RATE_LIMIT_ENABLED=true
      - RATE_LIMIT_RPS=50
      
      # Telegram
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
      
      # Google OAuth
      - GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}
      - GOOGLE_CLIENT_SECRET=${GOOGLE_CLIENT_SECRET}
      
    volumes:
      - ./logs:/app/logs
    networks:
      - cstati-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    image: nginx:alpine
    container_name: cstati-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - ./logs/nginx:/var/log/nginx
    networks:
      - cstati-network
    depends_on:
      - backend
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  cstati-network:
    driver: bridge
```

### 3. Environment Variables

**`.env.production`**:

```bash
# Version
VERSION=1.0.0

# Database (Managed PostgreSQL)
DB_HOST=your-db.region.rds.amazonaws.com
DB_PORT=5432
DB_NAME=cstati_warehouse_prod
DB_USER=cstati_app
DB_PASSWORD=CHANGE_ME_STRONG_PASSWORD

# JWT (Generate with: openssl rand -hex 32)
JWT_SECRET=CHANGE_ME_64_CHAR_HEX_STRING

# S3
S3_BUCKET=cstati-warehouse-images-prod
S3_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
CLOUDFRONT_URL=https://d1234567890.cloudfront.net

# CORS
CORS_ALLOWED_ORIGINS=https://cstati-warehouse.app,https://www.cstati-warehouse.app

# Telegram
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz

# Google OAuth
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your-client-secret
```

**Security**: Храните `.env.production` в безопасном месте (1Password, AWS Secrets Manager).

### 4. Nginx Configuration

**`nginx.conf`**:

```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 10M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_status 429;

    # Upstream backend
    upstream backend {
        least_conn;
        server backend:8080 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    # HTTP -> HTTPS redirect
    server {
        listen 80;
        server_name api.cstati-warehouse.app;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 301 https://$server_name$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name api.cstati-warehouse.app;

        # SSL certificates
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # API endpoints
        location /api/ {
            limit_req zone=api_limit burst=20 nodelay;
            
            proxy_pass http://backend;
            proxy_http_version 1.1;
            
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # WebSocket support
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
        }

        # Health check (no rate limit)
        location /health {
            proxy_pass http://backend;
            access_log off;
        }

        # Swagger UI
        location /swagger/ {
            proxy_pass http://backend;
        }
    }
}
```

### 5. SSL Certificate (Let's Encrypt)

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot certonly --webroot \
    -w /var/www/certbot \
    -d api.cstati-warehouse.app \
    --email admin@cstati-warehouse.app \
    --agree-tos \
    --no-eff-email

# Copy certificates
sudo cp /etc/letsencrypt/live/api.cstati-warehouse.app/fullchain.pem /opt/cstati-warehouse/ssl/
sudo cp /etc/letsencrypt/live/api.cstati-warehouse.app/privkey.pem /opt/cstati-warehouse/ssl/

# Auto-renewal (cron)
sudo crontab -e
# Add: 0 0 * * * certbot renew --quiet && docker-compose -f /opt/cstati-warehouse/docker-compose.prod.yml restart nginx
```

## Database Setup

### PostgreSQL (Managed - Recommended)

**AWS RDS**:

```bash
# Create RDS instance
aws rds create-db-instance \
    --db-instance-identifier cstati-warehouse-prod \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 15.4 \
    --master-username cstati_admin \
    --master-user-password STRONG_PASSWORD \
    --allocated-storage 20 \
    --storage-type gp3 \
    --vpc-security-group-ids sg-xxxxx \
    --db-subnet-group-name cstati-db-subnet \
    --backup-retention-period 7 \
    --preferred-backup-window "03:00-04:00" \
    --preferred-maintenance-window "mon:04:00-mon:05:00" \
    --enable-cloudwatch-logs-exports '["postgresql"]' \
    --storage-encrypted \
    --publicly-accessible false
```

**DigitalOcean Managed Database**:

```bash
# Create via UI or API
doctl databases create cstati-warehouse-prod \
    --engine pg \
    --version 15 \
    --size db-s-1vcpu-1gb \
    --region nyc3 \
    --num-nodes 1
```

### Run Migrations

```bash
# Install goose
go install github.com/pressly/goose/v3/cmd/goose@latest

# Run migrations
cd backend/migrations
goose postgres "host=your-db.region.rds.amazonaws.com port=5432 user=cstati_app password=PASSWORD dbname=cstati_warehouse_prod sslmode=require" up

# Verify
goose postgres "..." status
```

## Deployment Process

### 1. Build & Push Docker Image

**GitHub Actions** (`.github/workflows/deploy.yml`):

```yaml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
      
      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: ./backend
          file: ./backend/Dockerfile.prod
          push: true
          tags: |
            ghcr.io/cstati/warehouse-backend:${{ steps.version.outputs.VERSION }}
            ghcr.io/cstati/warehouse-backend:latest
          build-args: |
            VERSION=${{ steps.version.outputs.VERSION }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
      
      - name: Deploy to server
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.PROD_HOST }}
          username: cstati
          key: ${{ secrets.PROD_SSH_KEY }}
          script: |
            cd /opt/cstati-warehouse
            export VERSION=${{ steps.version.outputs.VERSION }}
            docker-compose -f docker-compose.prod.yml pull
            docker-compose -f docker-compose.prod.yml up -d
            docker-compose -f docker-compose.prod.yml logs -f --tail=100
```

### 2. Manual Deployment

```bash
# On local machine
cd backend
docker build -f Dockerfile.prod -t ghcr.io/cstati/warehouse-backend:1.0.0 .
docker push ghcr.io/cstati/warehouse-backend:1.0.0

# On production server
ssh cstati@your-server.com
cd /opt/cstati-warehouse

# Pull latest image
docker-compose -f docker-compose.prod.yml pull

# Stop old containers
docker-compose -f docker-compose.prod.yml down

# Start new containers
docker-compose -f docker-compose.prod.yml up -d

# Check logs
docker-compose -f docker-compose.prod.yml logs -f backend

# Verify health
curl https://api.cstati-warehouse.app/health
```

### 3. Zero-Downtime Deployment

**Using Docker Swarm**:

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.prod.yml cstati

# Update service (rolling update)
docker service update --image ghcr.io/cstati/warehouse-backend:1.0.1 cstati_backend

# Scale
docker service scale cstati_backend=3
```

## Monitoring & Logging

### 1. Health Checks

**Backend health endpoint** (`/health`):

```go
func (h *HealthHandler) Check(w http.ResponseWriter, r *http.Request) {
    // Check database
    if err := h.db.Ping(r.Context()); err != nil {
        respondJSON(w, http.StatusServiceUnavailable, map[string]string{
            "status": "unhealthy",
            "database": "down",
        })
        return
    }
    
    respondJSON(w, http.StatusOK, map[string]string{
        "status": "healthy",
        "version": version,
        "uptime": time.Since(startTime).String(),
    })
}
```

### 2. Prometheus Metrics

**Install Prometheus**:

```yaml
# docker-compose.monitoring.yml
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"
    networks:
      - cstati-network

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    networks:
      - cstati-network

volumes:
  prometheus-data:
  grafana-data:
```

**`prometheus.yml`**:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'cstati-backend'
    static_configs:
      - targets: ['backend:8080']
```

### 3. Centralized Logging

**Using Loki**:

```yaml
# docker-compose.logging.yml
services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml
      - loki-data:/loki
    networks:
      - cstati-network

  promtail:
    image: grafana/promtail:latest
    volumes:
      - ./promtail-config.yml:/etc/promtail/config.yml
      - /var/log:/var/log
      - ./logs:/app/logs
    networks:
      - cstati-network

volumes:
  loki-data:
```

## Backup Strategy

### 1. Database Backups

**Automated backups** (cron):

```bash
#!/bin/bash
# /opt/cstati-warehouse/scripts/backup-db.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/cstati-warehouse/backups"
BACKUP_FILE="$BACKUP_DIR/db_backup_$DATE.sql.gz"

# Create backup
PGPASSWORD=$DB_PASSWORD pg_dump \
    -h $DB_HOST \
    -U $DB_USER \
    -d $DB_NAME \
    | gzip > $BACKUP_FILE

# Upload to S3
aws s3 cp $BACKUP_FILE s3://cstati-backups/database/

# Keep only last 30 days locally
find $BACKUP_DIR -name "db_backup_*.sql.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_FILE"
```

**Crontab**:

```bash
# Daily at 2 AM
0 2 * * * /opt/cstati-warehouse/scripts/backup-db.sh >> /var/log/cstati-backup.log 2>&1
```

### 2. Configuration Backups

```bash
# Backup .env and configs
tar -czf config_backup_$(date +%Y%m%d).tar.gz \
    .env.production \
    nginx.conf \
    docker-compose.prod.yml

# Upload to S3
aws s3 cp config_backup_*.tar.gz s3://cstati-backups/config/
```

## Security Checklist

- [ ] **Firewall**: Только порты 80, 443, 22 открыты
- [ ] **SSH**: Только key-based authentication
- [ ] **SSL**: Let's Encrypt с auto-renewal
- [ ] **Secrets**: Хранятся в AWS Secrets Manager / 1Password
- [ ] **Database**: Не публично доступна
- [ ] **Rate Limiting**: Включен на nginx и backend
- [ ] **CORS**: Только разрешенные origins
- [ ] **Updates**: Автоматические security updates
- [ ] **Backups**: Ежедневные бэкапы БД
- [ ] **Monitoring**: Prometheus + Grafana настроены
- [ ] **Logging**: Централизованные логи
- [ ] **Health Checks**: Настроены и работают

## Troubleshooting

### Backend не запускается

```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs backend

# Check environment variables
docker-compose -f docker-compose.prod.yml config

# Test database connection
docker-compose -f docker-compose.prod.yml exec backend sh
# Inside container:
wget -O- http://localhost:8080/health
```

### High CPU/Memory

```bash
# Check resource usage
docker stats

# Scale down if needed
docker-compose -f docker-compose.prod.yml scale backend=1

# Check for memory leaks
docker-compose -f docker-compose.prod.yml exec backend top
```

### Database connection issues

```bash
# Test connection from server
psql -h $DB_HOST -U $DB_USER -d $DB_NAME

# Check security groups (AWS)
aws ec2 describe-security-groups --group-ids sg-xxxxx

# Check connection pool
# In backend logs, look for "connection pool exhausted"
```

## Rollback Procedure

```bash
# Rollback to previous version
cd /opt/cstati-warehouse
export VERSION=1.0.0  # Previous stable version
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d

# Rollback database migration
cd backend/migrations
goose postgres "..." down
```

## Performance Tuning

### PostgreSQL

```sql
-- Increase connection pool
ALTER SYSTEM SET max_connections = 200;

-- Tune shared buffers (25% of RAM)
ALTER SYSTEM SET shared_buffers = '1GB';

-- Increase work_mem
ALTER SYSTEM SET work_mem = '16MB';

-- Enable query logging for slow queries
ALTER SYSTEM SET log_min_duration_statement = 1000;

-- Reload configuration
SELECT pg_reload_conf();
```

### Backend

```bash
# Increase Go max procs
GOMAXPROCS=4

# Tune database pool
DB_MAX_CONNS=50
DB_MIN_CONNS=10
```

## Cost Optimization

### AWS Cost Estimate (Monthly)

- **EC2 t3.small** (2 vCPU, 2GB RAM): $15
- **RDS db.t3.micro** (PostgreSQL): $15
- **S3** (100GB storage): $2.30
- **CloudFront** (100GB transfer): $8.50
- **Total**: ~$41/month

### DigitalOcean Cost Estimate

- **Droplet** (2 vCPU, 2GB RAM): $12
- **Managed PostgreSQL** (1GB RAM): $15
- **Spaces** (250GB): $5
- **Total**: ~$32/month

## References

- [Docker Production Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Nginx Performance Tuning](https://www.nginx.com/blog/tuning-nginx/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
