# 1. CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This alarm fires when ECS CPU exceeds 85% for 4 minutes"

  dimensions = {
    ClusterName = "${var.project_name}-${var.environment}-cluster"
    ServiceName = "${var.project_name}-${var.environment}-service"
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-alb-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Fires if ALB detects 10 or more 5xx errors in 1 minute"
}

# 2. Infra CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "infra" {
  dashboard_name = "${var.project_name}-${var.environment}-infra-dashboard"

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
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-${var.environment}-service", "ClusterName", "${var.project_name}-${var.environment}-cluster"],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "ECS Service Resource Utilization (Compute/Memory)"
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
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", "${var.project_name}-${var.environment}-db"],
            [".", "CPUUtilization", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "PostgreSQL Infrastructure (Disk/CPU)"
        }
      }
    ]
  })
}

# 3. Application CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "app" {
  dashboard_name = "${var.project_name}-${var.environment}-app-dashboard"

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
            ["AWS/ApplicationELB", "RequestCount"],
            [".", "HTTPCode_Target_5XX_Count"],
            [".", "HTTPCode_Target_4XX_Count"],
            [".", "TargetResponseTime"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "ALB Application Metrics (Traffic/Errors/Latency)"
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
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "${var.project_name}-${var.environment}-db"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          title   = "Application Database Usage"
        }
      }
    ]
  })
}
