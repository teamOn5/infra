# Cloud Infrastructure Repository

## 1. Architecture Topology
- **Frontend**: Vercel (Next.js)
- **Application Load Balancer (ALB)**: `app-alb-1347922990.ap-northeast-2.elb.amazonaws.com`
- **Backend EC2 (t3.large)**: `15.164.172.146` (Private: `172.31.29.243`)
  - LiveKit WebRTC SFU (7880, 7881, 7882, 50000-60000)
  - Kafka UI (8900)
  - Spring Boot Microservices (8081, 8082, 8083, ...)
- **DB/Middleware EC2 (t3.medium)**: (Private: `172.31.39.86`)
  - MySQL 8.0 (3306)
  - Redis 7 (6379)
  - Apache Kafka 3.7.0 KRaft (9092)
  - Prometheus (9090) & Grafana (3000)
- **DBaaS**: MongoDB Atlas
- **Storage**: AWS S3

## 2. Directory Structure
```
├── backend-server/
│   ├── docker-compose.yml       # LiveKit & Kafka UI
│   ├── docker-compose.apps.yml  # Microservices containers
│   └── livekit/livekit.yaml
├── db-server/
│   ├── docker-compose.yml       # MySQL, Redis, Kafka, Prometheus, Grafana
│   └── prometheus/prometheus.yml
└── scripts/
    └── deploy-service.sh        # Zero-downtime service update script
```
