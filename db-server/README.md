# Database & Middleware Server (EC2 #2)

## Components
- MySQL 8.0 (Schema-per-service: user_db, order_db, live_db, etc.)
- Redis 7 (Alpine)
- Apache Kafka 3.7.0 (KRaft mode - no zookeeper)
- Prometheus & Grafana & Node Exporter

## Setup
```bash
cp .env.example .env
# Edit SERVER_PRIVATE_IP and passwords in .env
docker compose up -d
```
