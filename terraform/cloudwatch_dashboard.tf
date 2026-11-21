# Stretch Deliverable: CloudWatch Dashboard for the service
resource "aws_cloudwatch_dashboard" "service_dashboard" {
  dashboard_name = "${var.app_name}-service-observability"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum", period = 60, color = "#1f77b4" }],
            [".", "HTTPCode_Target_2XX_Count", ".", ".", { stat = "Sum", period = 60, color = "#2ca02c" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", period = 60, color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ALB Request Traffic & HTTP Codes"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.backend.arn_suffix, { stat = "p95", period = 60, label = "p95 Latency", color = "#ff7f0e" }],
            ["...", { stat = "Average", period = 60, label = "Avg Latency", color = "#17becf" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Backend Latency (p95 & Average)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.backend.arn_suffix, { stat = "Minimum", period = 60, color = "#2ca02c" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Maximum", period = 60, color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Target Group Health (Backend)"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.backend.name, { stat = "Average", period = 60 }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { stat = "Average", period = 60 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Backend Fargate CPU & Memory Utilization"
        }
      }
    ]
  })
}
