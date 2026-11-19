# teamOn 인프라 & 마이크로서비스 개발 가이드 (팀원 공유용)

이 문서는 **teamOn** 프로젝트의 전체 인프라 구성, 환경 접속 정보, 그리고 새로운 마이크로서비스를 개발 및 배포할 때 따라야 할 표준 가이드라인입니다.

---

##  1. 전체 아키텍처 및 접속 URL 맵

```
[클라이언트 / 사용자]
       │
       ▼
1. Frontend (Next.js - Vercel)
   👉 https://onfrontend.vercel.app/
       │
       │ (/api/* -> ALB 자동 프록시, CORS 프리)
       ▼
2. AWS ALB (Application Load Balancer)
   👉 http://app-alb-1347922990.ap-northeast-2.elb.amazonaws.com
       │
       ▼
3. Spring Cloud Gateway (EC2 Port 8080)
   ├── 전역 JWT 인증 및 보안 필터링
   └── Eureka에서 서비스 주소 조회 후 라우팅
       │
       ├─────────────────────────────────┐
       ▼                                 ▼
   [Eureka Server] (EC2: 8761)     [LiveKit SFU] (EC2: 7880, 7882)
   - 서비스 실시간 등록/관리        - WebRTC 실시간 영상/음성 스트리밍
       │
       ▼
4. 각 마이크로서비스 컨테이너 (8081, 8082, 8083 ...)
       │
       ▼ (AWS 사설망 통신: 172.31.39.86)
5. DB & 미들웨어 (EC2 #2)
   - MySQL 8.0 (3306) | Redis 7 (6379) | Kafka KRaft (9092) | 모니터링 (Prometheus, Grafana)
```

###  주요 접속 주소 및 대시보드
| 서비스 | 용도 | 접속 주소 | 비고 |
| :--- | :--- | :--- | :--- |
| **프론트엔드 웹** | 서비스 메인 웹 | `https://onfrontend.vercel.app/` | Vercel 자동 배포 |
| **API Entry Point** | 백엔드 통합 API 진입로 | `http://app-alb-1347922990.ap-northeast-2.elb.amazonaws.com` | ALB -> Gateway |
| **LiveKit SFU** | 실시간 영상/음성 스트리밍 | `ws://15.164.172.146:7880` | WebRTC (UDP: 7882, 50000~60000) |
| **Kafka UI** | 카프카 토픽/메시지 모니터링 | `http://15.164.172.146:8900` | 브라우저 즉시 접속 가능 |
| **Eureka Server** | 서비스 등록/헬스 대시보드 | `http://15.164.172.146:8761` | 브라우저 즉시 접속 가능 |
| **Grafana** | 서버/컨테이너 모니터링 | `http://<DB_서버_EIP>:3000` | ID: `admin` / PW: `<팀_내부_공유>` |
| **MongoDB Atlas** | NoSQL (실시간 채팅/시청 로그) | `mongodb+srv://<USERNAME>:<PASSWORD>@cluster0.61vehwi.mongodb.net/live_stream_db?retryWrites=true&w=majority` | Cloud DBaaS (계정/PW 팀 내부 공유) |

---

##  2. 백엔드 개발자용 미들웨어 접속 설정 (`application.yml`)

각 마이크로서비스는 **AWS VPC 사설망(Private IP)**을 통해 DB 및 미들웨어와 초고속/보안 통신합니다.

```yaml
spring:
  # 1. MySQL 설정 (서비스별 스키마 지정: user_db, order_db, live_db 등)
  datasource:
    url: jdbc:mysql://172.31.39.86:3306/본인_DB_이름?useSSL=false&allowPublicKeyRetrieval=true&characterEncoding=UTF-8&serverTimezone=Asia/Seoul
    username: user
    password: "${DB_PASSWORD:<DB_PASSWORD>}"
    driver-class-name: com.mysql.cj.jdbc.Driver

  # 2. Redis 캐시 및 세션 설정
  data:
    redis:
      host: 172.31.39.86
      port: 6379
      password: "${REDIS_PASSWORD:<REDIS_PASSWORD>}"

  # 3. MongoDB Atlas (NoSQL DBaaS) - 실시간 채팅 로그 및 시청 기록
    mongodb:
      uri: ${MONGODB_URI:mongodb+srv://<USERNAME>:<PASSWORD>@cluster0.61vehwi.mongodb.net/live_stream_db?retryWrites=true&w=majority}

  # 4. Apache Kafka 메시지 브로커 설정
  kafka:
    bootstrap-servers: 172.31.39.86:9092
    consumer:
      group-id: ${spring.application.name}-group
      auto-offset-reset: earliest
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.apache.kafka.common.serialization.StringDeserializer
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.apache.kafka.common.serialization.StringSerializer

# 5. Eureka 클라이언트 등록 설정 (필수!)
eureka:
  client:
    service-url:
      defaultZone: ${EUREKA_CLIENT_SERVICEURL_DEFAULTZONE:http://172.31.29.243:8761/eureka/}
    register-with-eureka: true
    fetch-registry: true
  instance:
    prefer-ip-address: true

# 6. LiveKit 연동 설정 (라이브/스트리밍 관련 서비스만 해당)
livekit:
  host: http://172.31.29.243:7880
  api-key: ${LIVEKIT_API_KEY:<LIVEKIT_API_KEY>}
  api-secret: ${LIVEKIT_API_SECRET:<LIVEKIT_API_SECRET>}
```

---

##  3. 새 마이크로서비스 생성 & CI/CD 연동 절차 (팀원 필독)

새로운 도메인 서비스(예: `chat-service`, `order-service`)를 만들 때는 아래 5단계만 수행하면 **완전 자동 배포**됩니다.

### Step 1. 레포지토리 생성
- **GitHub Organization([teamOn5](https://github.com/teamOn5))** 안에 `[서비스명]-service` 이름으로 Public 레포지토리 생성.
- *(중요: Organization 레벨에서 `DOCKER_USERNAME`, `DOCKER_PASSWORD`, `EC2_SSH_KEY`가 자동 상속되므로 개별 레포에 비밀키를 추가할 필요가 없습니다!)*

### Step 2. `build.gradle` 필수 라이브러리 추가
Eureka 클라이언트와 Actuator를 반드시 포함해야 합니다:
```groovy
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    implementation 'org.springframework.cloud:spring-cloud-starter-netflix-eureka-client'
    // ... JPA, Redis, Kafka 등 필요한 라이브러리 추가
}
```

메인 Application 클래스에 `@EnableDiscoveryClient` 추가:
```java
@SpringBootApplication
@EnableDiscoveryClient
public class ChatServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(ChatServiceApplication.class, args);
    }
}
```

### Step 3. 루트 경로에 `Dockerfile` 추가
```dockerfile
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY build/libs/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Step 4. `.github/workflows/deploy.yml` 추가
서비스명(`SERVICE_NAME`)만 본인 서비스 이름으로 변경합니다:
```yaml
name: Deploy Service

on:
  push:
    branches: [ "main" ]

env:
  SERVICE_NAME: chat-service # <-- 본인 서비스명으로 수정!

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: 1. 코드 체크아웃
        uses: actions/checkout@v4

      - name: 2. JDK 17 설치
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: 3. Gradle 빌드
        run: |
          chmod +x gradlew
          ./gradlew clean bootJar -x test

      - name: 4. Docker Hub 로그인
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: 5. Docker 이미지 빌드 및 푸시
        run: |
          IMAGE_NAME=${{ secrets.DOCKER_USERNAME }}/${{ env.SERVICE_NAME }}
          docker build -t $IMAGE_NAME:latest -t $IMAGE_NAME:${{ github.sha }} .
          docker push $IMAGE_NAME:latest
          docker push $IMAGE_NAME:${{ github.sha }}

      - name: 6. 백엔드 EC2 원격 자동 배포
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: 15.164.172.146
          username: ubuntu
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd ~/infra-backend
            curl -s -O https://raw.githubusercontent.com/teamOn5/infra/main/backend-server/docker-compose.apps.yml
            export DOCKER_USERNAME=${{ secrets.DOCKER_USERNAME }}
            export IMAGE_TAG=${{ github.sha }}
            docker compose -f docker-compose.apps.yml pull ${{ env.SERVICE_NAME }}
            docker compose -f docker-compose.apps.yml up -d --no-deps ${{ env.SERVICE_NAME }}
            docker image prune -f
```

### Step 5. `infra` 레포 & `gateway` 레포 등록 (1회)
1. **`teamOn5/infra` 레포의 `docker-compose.apps.yml`** 에 새 서비스 포트 매핑 추가 (예: `8084:8080`)
2. **`teamOn5/gateway` 레포의 `application.yml`** 에 경로 라우팅 규칙 추가:
   ```yaml
   - id: chat-service-route
     uri: lb://CHAT-SERVICE
     predicates:
       - Path=/api/chats/**
   ```

---

##  4. 프론트엔드 개발자 안내 사항 (Next.js)

1. **CORS 신경 쓸 필요 없음:**  
   Next.js에 ALB 프록시(`rewrites`)가 설정되어 있으므로, 클라이언트 코드에서는 도메인 없이 **상대 경로**로 호출하면 됩니다:
   ```javascript
   // 예시: 자동으로 ALB -> Gateway -> user-service로 전달됨
   const res = await fetch('/api/users/profile');
   const data = await res.json();
   ```
2. **LiveKit 실시간 영상/음성 스트리밍 연결:**  
   LiveKit React SDK 연결 시 아래 URL을 사용합니다:
   - 환경 변수: `process.env.NEXT_PUBLIC_LIVEKIT_URL` (`ws://15.164.172.146:7880`)

---

##  5. 성능 및 메모리 최적화 필수 준수 사항

- **메모리(RAM) 관리:**  
  인스턴스(`t3.large` 8GB)에서 8~10개의 마이크로서비스가 공존하므로, 모든 서비스는 **최대 메모리 384MB 이하**로 실행되도록 컨테이너 제한이 걸려 있습니다.
  무거운 배치 작업이나 대용량 메모리 적재 로직은 지양해 주세요.
- **로컬 실행 팁:**  
  로컬 PC에서 개발할 때는 Eureka 없이 독립 테스트하거나, `application-local.yml` 프로파일을 활용하여 `localhost` 기반으로 개발하는 것을 권장합니다.
