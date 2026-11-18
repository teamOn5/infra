# 클라우드 인프라 저장소 (Cloud Infrastructure Repository)

## 1. 인프라 아키텍처 구성 (Architecture Topology)

본 저장소는 라이브 커머스 서비스 운영에 필요한 클라우드 인프라 및 배포 환경을 관리합니다.

### 전체 인프라 구성

- **프론트엔드 (Frontend)**
  - 배포 플랫폼: Vercel
  - 프레임워크: Next.js

- **애플리케이션 로드 밸런서 (ALB)**
  - 주소: `app-alb-1347922990.ap-northeast-2.elb.amazonaws.com`
  - 역할: 외부 요청을 백엔드 EC2 서버로 분산

- **백엔드 서버 (Backend EC2)**
  - 인스턴스 유형: `t3.large`
  - 퍼블릭 IP: `15.164.172.146`
  - 프라이빗 IP: `172.31.29.243`
  - 주요 구성 요소:
    - LiveKit WebRTC SFU (7880, 7881, 7882, 50000~60000)
    - Kafka UI (8900)
    - Spring Boot 마이크로서비스 (8081, 8082, 8083 등)

- **데이터베이스 및 미들웨어 서버 (DB/Middleware EC2)**
  - 인스턴스 유형: `t3.medium`
  - 프라이빗 IP: `172.31.39.86`
  - 주요 구성 요소:
    - MySQL 8.0 (3306)
    - Redis 7 (6379)
    - Apache Kafka 3.7.0 - KRaft 모드 (9092)
    - Prometheus (9090)
    - Grafana (3000)

- **관리형 데이터베이스 (DBaaS)**
  - MongoDB Atlas
  - 역할: 별도의 클라우드 환경에서 MongoDB 데이터베이스 관리

- **객체 스토리지 (Object Storage)**
  - AWS S3
  - 역할: 이미지 및 미디어 파일 저장

## 2. 디렉터리 구조 (Directory Structure)

```text
├── backend-server/
│   ├── docker-compose.yml          # LiveKit 및 Kafka UI 실행 설정
│   ├── docker-compose.apps.yml     # Spring Boot 마이크로서비스 컨테이너 설정
│   └── livekit/
│       └── livekit.yaml            # LiveKit 서버 설정
│
├── db-server/
│   ├── docker-compose.yml          # MySQL, Redis, Kafka, Prometheus, Grafana 실행 설정
│   └── prometheus/
│       └── prometheus.yml          # Prometheus 메트릭 수집 설정
│
└── scripts/
    └── deploy-service.sh           # 서비스 무중단 업데이트 배포 스크립트
```

## 3. 주요 관리 범위

- AWS EC2 기반 서버 인프라 구축 및 관리
- Docker Compose 기반 컨테이너 실행 환경 구성
- 데이터베이스 및 미들웨어 운영 환경 구축
- 서비스 모니터링 및 메트릭 수집 환경 구성
- Spring Boot 마이크로서비스 배포 자동화
- LiveKit 기반 실시간 영상 통신 환경 구성
- AWS S3 기반 파일 저장소 관리
