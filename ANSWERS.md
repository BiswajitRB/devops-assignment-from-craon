# Craon DevOps Take-Home Assignment: ANSWERS.md

## Part 1: Know Your App, and Use the Shell

### 1. App Architecture & Components

* **Open-Source Base Repository**: [BiswajitRB/Python-Based-MCP-Server-for-Crypto-Market-Data](https://github.com/BiswajitRB/Python-Based-MCP-Server-for-Crypto-Market-Data.git)
* **License**: MIT License (included in [LICENSE](file:///d:/homeassigement/LICENSE))
* **What Was Changed / Added for Production Readiness**:
  1. **MongoDB Persistence Layer**: Integrated `pymongo` with auto-reconnect and health checks in `app/services/db_service.py` to persist ticker snapshots and watchlists.
  2. **Prometheus Observability**: Added `/metrics` endpoint using `prometheus-fastapi-instrumentator`.
  3. **Structured JSON Logging**: Implemented request middleware tagging every request with a UUID `request_id`.
  4. **Deep Health Check**: Upgraded `/health` to verify MongoDB connectivity (returning `HTTP 503` if disconnected).
  5. **Incident Drill Endpoint**: Added `/simulate-500` to simulate application failure and verify CloudWatch alarm firing.
  6. **Hardened Distroless Container**: Converted Dockerfile to multi-stage Google Distroless Python (`gcr.io/distroless/python3-debian12:nonroot`).

| Component | Technology | Listening Port | Description |
| :--- | :--- | :--- | :--- |
| **Frontend** | HTML5 / JavaScript Charting UI (`app/static/index.html`) | `8000` (container) / `80` (ALB) | Real-time WebSocket and historical candlestick graph UI served at `/graph`. |
| **Backend API** | Python 3.11, FastAPI, Uvicorn, CCXT | `8000` | REST API providing crypto ticker data, WebSocket streams (`/ws`), Prometheus metrics (`/metrics`), and MongoDB persistence. |
| **Database** | MongoDB 7.0 (Local Compose) / MongoDB Atlas M0 (AWS) | `27017` | Persistent document database storing crypto ticker snapshots and user watchlists. |

### 2. Backend Endpoints

| Method | Endpoint | Description | Status Codes |
| :--- | :--- | :--- | :--- |
| `GET` | `/health` | Deep health check probing MongoDB readiness and application status | `200 OK` (Healthy), `503 Service Unavailable` (DB offline) |
| `GET` | `/metrics` | Prometheus metrics exposition (requests, duration, process memory) | `200 OK` |
| `GET` | `/graph` | Serves real-time frontend chart UI | `200 OK` |
| `GET` | `/ticker` | Fetches live market ticker from exchanges (Binance/CCXT) & saves snapshot | `200 OK`, `400 Bad Request` |
| `GET` | `/watchlist` | Retrieves saved watchlist items from MongoDB | `200 OK` |
| `POST`| `/watchlist` | Saves a crypto symbol and user notes to MongoDB | `200 OK` |
| `WS`  | `/ws` | Real-time WebSocket price stream | `101 Switching Protocols` |
| `GET` | `/simulate-500`| Intentional failure endpoint to simulate incidents & trigger alarms | `500 Internal Server Error` |

### 3. Environment Variables

| Variable | Required | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `PORT` | No | `8000` | Port for Uvicorn HTTP server. |
| `HOST` | No | `0.0.0.0` | Network binding interface (`0.0.0.0` in containers). |
| `MONGODB_URI`| **Yes** (Prod) | `mongodb://localhost:27017/crypto_db` | Connection string securely injected via AWS Secrets Manager. |
| `APP_VERSION`| No | `1.0.0` | Application version tag. |

### 4. Database Unreachability Behavior
* **No Process Crash**: The FastAPI server does not crash or reboot when MongoDB is down; it logs a warning and enters graceful degraded mode.
* **Health Check Fails (HTTP 503)**: `GET /health` calls `DatabaseService.is_healthy()`. When disconnected, it returns `503 Service Unavailable`:
  ```json
  {"status":"unhealthy","checks":{"database":{"status":"disconnected"}}}
  ```
* **ALB Reaction**: The AWS Application Load Balancer marks the target as `unhealthy` after 3 consecutive failed checks, isolating traffic and triggering the CloudWatch `UnHealthyHostCount` alarm.
* **Graceful Degradation**: Ticker queries continue using in-memory `cachetools` cache, keeping market data available to users while ops remediates the database.

---

### 5. Two Production-Readiness Fixes

| Issue | Production Impact | Discovery Method | Resolution Implemented |
| :--- | :--- | :--- | :--- |
| **1. Missing MongoDB Health Verification** | Original app had no database connectivity checks in `/health` (just returned static `{"status": "ok"}`). If MongoDB went down, the ALB would continue routing traffic to broken tasks. | Code review of `app/api/routes/health.py`. | Rewrote `/health` to execute a MongoDB `ping` command. If the database is unreachable, it immediately responds with `HTTP 503`, prompting ALB failover. |
| **2. Unhandled Errors Crashing Uvicorn Workers** | Unhandled exceptions in async endpoints leaked raw stack traces to users and could stall worker event loops. | Tested unexpected API payloads against `/simulate-500`. | Added global structured error middleware in `app/main.py` that catches unhandled exceptions, attaches a unique UUID `request_id`, logs structured JSON, and returns a clean 500 error response. |

---

### 6. Linux and Shell Answers

#### Log Triage Output (`scripts/triage.sh sample/access.log`)
Executed using standard POSIX utilities (`awk`, `grep`, `sort`, `uniq`, `cut`):

```text
==========================================================
          LOG TRIAGE REPORT: sample/access.log
==========================================================

--- 1. TOP 5 ENDPOINTS ---
137     /api/items
135     /health
48      /metrics
18      /api/items/simulate-500
5       /api/slow-query

--- 2. 5xx RESPONSES PER MINUTE ---
1       21/Nov/2026:22:00
1       21/Nov/2026:22:04
4       21/Nov/2026:22:05
3       21/Nov/2026:22:06
1       21/Nov/2026:22:07
1       21/Nov/2026:22:08

--- 3. SLOWEST 10 REQUESTS ---
3.864 sec | status: 200 | "GET /api/slow-query | client: 172.31.14.92
3.191 sec | status: 500 | "GET /api/items/simulate-500 | client: 10.0.1.25
3.158 sec | status: 200 | "GET /api/items/simulate-500 | client: 10.0.1.25
3.127 sec | status: 500 | "GET /api/items/simulate-500 | client: 10.0.1.25
2.875 sec | status: 200 | "GET /api/slow-query | client: 10.0.1.84
2.797 sec | status: 200 | "GET /api/slow-query | client: 10.0.1.84
2.782 sec | status: 500 | "GET /api/items/simulate-500 | client: 172.31.14.92
2.757 sec | status: 200 | "GET /api/items/simulate-500 | client: 192.168.1.105
2.248 sec | status: 200 | "GET /api/slow-query | client: 172.31.14.92
2.208 sec | status: 200 | "GET /api/slow-query | client: 192.168.1.105
```

#### Linux Operational Commands
* **Find process listening on port 8000**:
  ```bash
  sudo ss -tulpn | grep :8000
  # Alternatively:
  sudo lsof -i :8000
  ```
* **See what is using disk space**:
  ```bash
  df -h
  # Drill down top space consumers on root filesystem:
  sudo du -ahx --max-depth=1 / | sort -hr | head -n 15
  ```
* **Follow a log file live**:
  ```bash
  tail -f -n 100 /var/log/nginx/access.log
  ```
* **Check a file's permissions and owner**:
  ```bash
  ls -la /path/to/file
  # Or detailed inode metadata:
  stat /path/to/file
  ```

---

## Part 3: Terraform, AWS, ECS and Networking

### 1. Frontend Hosting Choice
* **Choice Made**: Served directly by the containerized service behind the Application Load Balancer (`/graph` route).
* **Why**:
  1. **Single Origin**: Eliminates CORS complications between the WebSocket stream (`/ws`) and the static chart UI.
  2. **Atomic Deployments**: Frontend UI updates ship atomically with the backend API in the same immutable container image.
  3. **Simplified Architecture**: Avoids maintaining separate S3 bucket policies and CloudFront distributions for a lightweight single-page UI.

### 2. VPC & Networking Architecture

#### Request Path Diagram
```
Browser / Client (Internet)
      │
      ▼ (Port 80/443 via Public Internet)
[ Route 53 DNS ] -> Resolves to ALB DNS Name
      │
      ▼
[ Application Load Balancer ] (Default VPC Public Subnets: us-east-1a, us-east-1b)
      │  Security Group: craon-app-alb-sg (Ingress 80/443 from 0.0.0.0/0)
      │
      └── Target Group (Port 8000) ──> [ ECS Fargate Tasks (FastAPI + Distroless) ]
                                              SG: craon-app-backend-task-sg (Ingress 8000 from ALB SG only)
                                                      │
                                                      ▼ (TLS Egress over Port 27017)
                                              [ MongoDB Atlas Managed Cluster ]
                                              Network Access: Project IP Access List
```

#### Security Group Rules Table

| Security Group | Direction | Protocol | Port | Source / Destination | Purpose / Reason |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `craon-app-alb-sg` | Ingress | TCP | 80, 443 | `0.0.0.0/0` | Public entrypoint for web traffic. |
| `craon-app-alb-sg` | Egress | TCP | 8000 | Backend Task SG | Forwards traffic to Fargate tasks. |
| `craon-app-backend-task-sg` | Ingress | TCP | 8000 | `craon-app-alb-sg` | Allows only ALB to reach FastAPI server. |
| `craon-app-backend-task-sg` | Egress | TCP | 27017 | MongoDB Atlas Cluster | Allows backend to reach MongoDB Atlas replica set. |
| `craon-app-backend-task-sg` | Egress | TCP | 443 | `0.0.0.0/0` | Outbound HTTPS for CCXT crypto exchange API queries. |

---

### 3. Debugging Scenarios

| Issue | First Thing to Check | Secondary Checks & Action |
| :--- | :--- | :--- |
| **HTTP 502 (Bad Gateway)** | ALB Target Group health status and container port binding. | Verify container is listening on port 8000 and bound to `0.0.0.0`. Check CloudWatch logs `/ecs/craon-app-backend` for unhandled crash loops on container start. |
| **HTTP 504 (Gateway Timeout)** | Upstream database latency or CCXT exchange API timeout. | Inspect MongoDB connection latency, check if external exchange API (Binance) is unreachable, or verify security group outbound rules. |
| **Task Cannot Pull Image** | IAM Task Execution Role permissions & ECR repository URL. | Verify `AmazonECSTaskExecutionRolePolicy` is attached to `ecs_execution_role`. Ensure the Fargate task has a route to the internet or an ECR VPC endpoint. |

### 4. Rolling Deployments & 5-Minute Rollback

* **How Rolling Deploy Works**:
  * `deployment_minimum_healthy_percent = 100` and `deployment_maximum_percent = 200`.
  * ECS spins up 2 new task replicas running the new task definition while keeping 2 old tasks running at 100% capacity.
  * ALB registers new targets and runs health checks against `GET /health`.
  * Traffic progressively shifts once new tasks pass health checks; old tasks are then cleanly drained and stopped.
* **How to Roll Back in Under 5 Minutes**:
  Execute a single AWS CLI command to point the service back to the previous task definition revision:
  ```bash
  aws ecs update-service \
    --cluster craon-app-cluster \
    --service craon-app-backend \
    --task-definition craon-app-backend:<previous_revision_number> \
    --force-new-deployment
  ```

---

### 5. Cost Estimate & Teardown Commands

#### Monthly AWS Cost Breakdown (US-East-1)

| Resource | Quantity / Sizing | Monthly Cost (USD) |
| :--- | :--- | :--- |
| **Application Load Balancer** | 1 ALB (~730 hrs + LCU usage) | ~$16.20 |
| **ECS Fargate Tasks (Backend)**| 2 tasks x 0.25 vCPU, 0.5 GB RAM | ~$10.25 |
| **ECR Image Storage** | ~2 GB active images with lifecycle policy | ~$0.20 |
| **CloudWatch Logs & Metrics** | Log ingestion + 3 metric alarms | ~$2.50 |
| **AWS Secrets Manager** | 1 Secret | ~$0.40 |
| **MongoDB Atlas** | Free M0 Sandbox Tier (Shared) | **$0.00** |
| **Total Estimated Cost** | Full production stack | **~$29.55 / month** |

#### Teardown Commands
To completely destroy all infrastructure and avoid incurring costs:
```bash
cd terraform
terraform destroy -auto-approve
```

---

## Part 5: Monitoring, Observability and SRE

### 1. CloudWatch Alarms & Threshold Justifications

| Alarm Name | Metric & Threshold | Evaluation Period | Explanation in One Line |
| :--- | :--- | :--- | :--- |
| **High-5XX-Error-Rate** | `HTTPCode_Target_5XX_Count` > 5 | 1 period (60 sec) | Spikes in 5xx errors signal uncaught exceptions, dependency timeouts, or database disconnections requiring immediate on-call notification. |
| **High-p95-Latency** | `TargetResponseTime` (p95) > 0.50s (500ms) | 2 periods (120 sec) | A sustained p95 latency over 500ms degrades end-user experience and indicates database index exhaustion or event-loop starvation. |
| **Unhealthy-Targets** | `UnHealthyHostCount` >= 1 | 1 period (60 sec) | Any single unhealthy container cuts cluster capacity by 50% and warns of crash loops before total service failure occurs. |

### 2. SRE Principles: SLI, SLO and Error Budget

* **Service Level Indicator (SLI)**:
  $$\text{Availability SLI} = \frac{\text{Total HTTP Requests} - \text{HTTP 5xx Server Errors}}{\text{Total HTTP Requests}} \times 100\%$$
* **Service Level Objective (SLO)**:
  **99.9% availability** over a rolling 30-day window.
* **Monthly Error Budget Calculation**:
  * Total minutes in a 30-day month: $30 \times 24 \times 60 = 43,200\text{ minutes}$.
  * $0.1\%$ allowable downtime: $43,200 \times 0.001 = \mathbf{43.2\text{ minutes}}$ of permitted downtime per month.
* **What the team should do when nearly spent**:
  > *Freeze non-critical feature deployments immediately and redirect engineering sprint capacity exclusively to stability fixes, debt reduction, and resilience engineering until the budget recovers.*
