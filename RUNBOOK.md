# On-Call Runbook & Incident Response

## Alert Routing Overview

CloudWatch metric alarms publish state changes to the SNS Topic:
`arn:aws:sns:us-east-1:123456789012:craon-app-alerts`

Alert notifications are dispatched via:
1. **Email Subscription**: Configured directly in Terraform (`var.alert_email`).
2. **Ops Escalation**: In production, SNS triggers an HTTPS webhook integration with PagerDuty or Opsgenie to page the on-call engineer.

---

## Runbook: High 5XX Error Rate & Unhealthy Targets

### 1. Alert Summary
* **Alarm Name**: `craon-app-High-5XX-Error-Rate` / `craon-app-Unhealthy-Targets`
* **Trigger Condition**: > 5 target 5xx responses within 1 minute, or >= 1 unhealthy host in ALB target group.
* **Severity**: **P1 (Critical)** if customer traffic is impacted; **P2 (Major)** during deployments.

### 2. Immediate Diagnostic Steps (First 2 Minutes)
1. **Check Load Balancer & Health Status**:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn $(aws elbv2 describe-target-groups --names craon-app-backend-tg --query "TargetGroups[0].TargetGroupArn" --output text)
   ```
2. **Query Recent Application Error Logs**:
   Inspect CloudWatch Logs Insights on `/ecs/craon-app-backend`:
   ```sql
   fields @timestamp, request_id, method, path, status, message, error
   | filter status >= 500 or level = "error"
   | sort @timestamp desc
   | limit 25
   ```
3. **Verify Database Connectivity**:
   Check if `/health` is reporting database disconnections:
   ```bash
   curl -s http://<ALB_DNS>/health | jq .
   ```

### 3. Resolution & Mitigation Procedures
* **Case A: Broken Deployment / Bad Release**:
  If errors started immediately following a new deployment, initiate an instant rollback:
  ```bash
  aws ecs update-service \
    --cluster craon-app-cluster \
    --service craon-app-backend \
    --task-definition craon-app-backend:<previous_revision> \
    --force-new-deployment
  ```
* **Case B: Database Connectivity Failure**:
  1. Check MongoDB Atlas status page and cluster metrics.
  2. Verify Secrets Manager credentials have not rotated unexpectedly.
  3. Confirm the Atlas Network Access List allows outbound Fargate IP addresses.
* **Case C: Container Memory / Crash Loop**:
  Restart the ECS service tasks cleanly:
  ```bash
  aws ecs update-service --cluster craon-app-cluster --service craon-app-backend --force-new-deployment
  ```

### 4. Escalation Matrix
* **0-5 Minutes**: On-call DevOps Engineer investigates and executes rollback if deployment-related.
* **5-15 Minutes**: If root cause is unknown or database is unresponsive, escalate to Secondary On-Call and Backend Lead.
* **> 15 Minutes**: Post customer-facing status update on internal status page.

---

# Blameless Postmortem: Simulated Incident Drill (Part 6)

### Incident Summary
* **Date**: 2026-11-21
* **Duration**: 4 minutes (22:04 UTC - 22:08 UTC)
* **Impact**: Elevated HTTP 500 responses on `/api/items/simulate-500` causing ALB 5xx threshold breach. No data corruption or data loss.

### Incident Timeline

| Time (UTC) | Event |
| :--- | :--- |
| **22:04:10** | Release tag `v2-incident-drill` was deployed containing an unhandled exception route on `/api/items/simulate-500`. |
| **22:05:05** | CloudWatch Alarm `craon-app-High-5XX-Error-Rate` fired as 5xx errors exceeded threshold (> 5 errors in 60s). |
| **22:05:30** | SNS notification dispatched to on-call engineer. Engineer acknowledged page. |
| **22:06:15** | On-call engineer reviewed CloudWatch logs, isolated the failure to newly introduced code in `v2`, and initiated rolling rollback to task definition revision `craon-app-backend:1`. |
| **22:07:45** | ECS Fargate rolling deployment completed; healthy containers registered with ALB. |
| **22:08:15** | Automated health check confirmed recovery (`GET /health` returned 200 OK). CloudWatch alarm transitioned back to `OK`. |

### Root Cause
A faulty endpoint was merged without adequate integration test coverage, causing HTTP 500 status codes when accessed.

### Recovery Confirmation
* `GET /health` verified responding with HTTP 200 OK and database state `connected`.
* ALB target group health returned to 2/2 healthy tasks.
* CloudWatch alarm transitioned from `ALARM` to `OK`.

### Follow-up Action Items

| Action Item | Owner | Target Date | Status |
| :--- | :--- | :--- | :--- |
| **1. Implement Automated Smoke Test Gate in CI/CD**: Add an automated integration step to the GitHub Actions CD pipeline that queries `/health` and core API routes before promoting target group traffic. | DevOps Team | 2026-11-25 | Planned |
| **2. Add Route-Level Synthetic Canary Checks**: Configure AWS Synthetics Canary or Datadog Synthetic monitor to ping `/health` every 60 seconds from outside AWS. | SRE Team | 2026-11-28 | Planned |
