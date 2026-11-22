# SNS Topic for Alert Notifications
resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-alerts"

  tags = {
    Name = "${var.app_name}-alerts-sns"
  }
}

# Email subscription for on-call notification
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# 3 Required CloudWatch Alarms (Part 5)

# 1. 5xx Error Rate Alarm
# Threshold: Fires if 5xx errors exceed 5 within a 1-minute evaluation window
# Explanation: A spike in 5xx responses indicates unhandled server crashes, DB outage, or failed upstream dependencies requiring immediate triage.
resource "aws_cloudwatch_metric_alarm" "target_5xx_errors" {
  alarm_name          = "${var.app_name}-High-5XX-Error-Rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Threshold: > 5 HTTP 5xx responses within 1 minute. Triggers when backend suffers unexpected crashes or database outages."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
}

# 2. p95 Latency Alarm
# Threshold: Fires if backend p95 response time exceeds 500ms (0.50s) over 2 consecutive 1-minute periods
# Explanation: Exceeding 500ms at p95 breaches user experience SLO and warns of slow MongoDB queries, thread saturation, or memory pressure.
resource "aws_cloudwatch_metric_alarm" "p95_latency" {
  alarm_name          = "${var.app_name}-High-p95-Latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p95"
  threshold           = 0.50
  alarm_description   = "Threshold: p95 latency > 500ms for 2 consecutive minutes. Triggers when queries lag or tasks suffer compute exhaustion."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
}

# 3. Unhealthy Targets Alarm
# Threshold: Fires if unhealthy target count >= 1 for 1 minute
# Explanation: Even a single failed task reduces cluster capacity by 50% and signals container crash loops or failing health checks.
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "${var.app_name}-Unhealthy-Targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Threshold: >= 1 unhealthy host for 1 minute. Triggers when a backend or frontend container fails its /health probe."
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }
}
