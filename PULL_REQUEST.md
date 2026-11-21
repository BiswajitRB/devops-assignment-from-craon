# Pull Request: Ship Full-Stack App to AWS ECS with Terraform, CI/CD, and SRE Observability

**Base Branch**: `main`  
**Compare Branch**: `feat/containerize-and-terraform-infra`

## Description

This PR delivers the end-to-end production platform for the Craon full-stack application as outlined in the DevOps Engineer take-home assignment:
1. **Containerization & Local Dev**: Dockerfiles for frontend (multi-stage Nginx non-root) and backend (Node 20 Alpine non-root) with `HEALTHCHECK`, and a single-command `docker compose up --build`.
2. **Infrastructure as Code (Terraform)**: Declarative definition of AWS default VPC networking, Application Load Balancer, ECS Fargate cluster with 2 tasks for high availability, ECR repositories, Secrets Manager, and MongoDB Atlas M0 managed cluster.
3. **Automated CI/CD**:
   - `ci.yml`: Runs linter, unit tests, and builds Docker images on PRs.
   - `cd.yml`: Authenticates via GitHub OIDC assumable IAM role (no long-lived secret keys), builds/tags images with the commit SHA, pushes to ECR, and triggers rolling ECS deployments.
4. **Monitoring & SRE**:
   - 3 CloudWatch metric alarms (5xx rate, p95 latency, unhealthy targets) with SNS routing.
   - CloudWatch Observability Dashboard.
   - Structured JSON logging with request IDs and Prometheus `/metrics` exposition.
   - SLO/SLI definition and monthly error budget calculation.
5. **On-Call Runbook & Incident Drill**:
   - Operational runbook for target group and 5xx alarms.
   - Blameless postmortem for a simulated bad release incident.
6. **Log Triage Tooling**:
   - POSIX shell script (`scripts/triage.sh`) analyzing top 5 endpoints, 5xx errors/min, and slowest 10 requests against `sample/access.log`.

---

## Deliverables Checklist

- [x] **Part 1**: `ANSWERS.md` (App architecture, 2 production-readiness fixes, Linux & shell answers)
- [x] **Part 1**: `scripts/triage.sh` and `sample/access.log`
- [x] **Part 2**: Production-grade `Dockerfile`s, non-root users, caching layers, `docker-compose.yml`, `.gitignore`
- [x] **Part 3**: Complete Terraform configurations (`terraform/`) validated (`terraform validate` and `terraform plan`)
- [x] **Part 4**: GitHub Actions CI (`ci.yml`) and CD with OIDC (`cd.yml`)
- [x] **Part 5**: CloudWatch Alarms, `/metrics` endpoint, structured JSON logging, SLI/SLO calculations
- [x] **Part 6**: `RUNBOOK.md` with blameless postmortem and simulated incident recovery

---

## Verification & Testing Evidence

1. **Unit & Health Test Suite**:
   ```text
   ✔ Server setup (13.9ms)
   ✔ GET /health returns JSON with status (25.7ms)
   ✔ GET /metrics returns Prometheus format metrics (11.3ms)
   ✔ GET /api/items returns list of items (4.9ms)
   ✔ GET /api/items/simulate-500 returns 500 for incident testing (3.7ms)
   ✔ Teardown server (1.4ms)
   ℹ tests 7 | pass 7 | fail 0
   ```
2. **Frontend Build**:
   ```text
   ✓ 31 modules transformed.
   dist/index.html                   0.40 kB
   dist/assets/index.css             3.46 kB
   dist/assets/index.js            146.69 kB
   ✓ built in 951ms
   ```
3. **Terraform Validation & Plan**:
   ```text
   Success! The configuration is valid.
   Plan: 41 to add, 0 to change, 0 to destroy.
   ```
4. **Log Triage Execution**:
   ```text
   Executed scripts/triage.sh sample/access.log successfully with awk/grep/sort/uniq/cut.
   ```
