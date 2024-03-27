locals {
  name_prefix = "tesla-http-proxy"

  # Alarm actions
  alarm_actions             = [
    data.terraform_remote_state.alarms.outputs.sns_topics.monitoring_alerts
  ]
  ok_actions                = local.alarm_actions
  insufficient_data_actions = local.alarm_actions

  # Thresholds
  threshold_p95_latency          = 60 # in seconds
  threshold_unhealthy_host       = 1
  threshold_internal_error_count = 1
  threshold_upstream_error_count = 3

  # Alarm dimensions
  dim_lb_with_target = {
    TargetGroup  = aws_lb_target_group.tesla_http_proxy_target.arn_suffix
    LoadBalancer = aws_lb.tesla_http_proxy_lb.arn_suffix
  }
  dim_lb = {
    LoadBalancer = aws_lb.tesla_http_proxy_lb.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name                = "${local.name_prefix}-unhealthy-hosts"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  alarm_description         = "More than ${local.threshold_unhealthy_host} unhealthy hosts"
  alarm_actions             = local.alarm_actions
  ok_actions                = local.ok_actions
  insufficient_data_actions = local.insufficient_data_actions

  namespace   = "AWS/ApplicationELB"
  dimensions  = local.dim_lb_with_target
  metric_name = "UnHealthyHostCount"

  datapoints_to_alarm = 3
  evaluation_periods  = 5
  threshold           = local.threshold_unhealthy_host
  period              = 300
  statistic           = "Maximum"
}

resource "aws_cloudwatch_metric_alarm" "p95_latency" {
  alarm_name                = "${local.name_prefix}-p95-latency"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  alarm_description         = "p95 latency exceeds ${local.threshold_p95_latency} seconds"
  alarm_actions             = local.alarm_actions
  ok_actions                = local.ok_actions
  insufficient_data_actions = local.insufficient_data_actions

  namespace          = "AWS/ApplicationELB"
  dimensions         = local.dim_lb_with_target
  metric_name        = "TargetResponseTime"
  treat_missing_data = "notBreaching"

  datapoints_to_alarm = 1
  evaluation_periods  = 1
  threshold           = local.threshold_p95_latency
  period              = 300
  extended_statistic  = "p95"
}

resource "aws_cloudwatch_metric_alarm" "internal-errors" {
  alarm_name                = "${local.name_prefix}-internal-errors"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  alarm_description         = "Internal ELB error rate exceeds ${local.threshold_internal_error_count} in the last 5 minutes"
  alarm_actions             = local.alarm_actions
  ok_actions                = local.ok_actions
  insufficient_data_actions = [] # It's normal to have no data on this metric

  namespace          = "AWS/ApplicationELB"
  dimensions         = local.dim_lb
  metric_name        = "HTTPCode_ELB_5XX_Count"
  treat_missing_data = "notBreaching"

  datapoints_to_alarm = 1
  evaluation_periods  = "1"
  threshold           = local.threshold_internal_error_count
  period              = 300
  statistic           = "Sum"
}

resource "aws_cloudwatch_metric_alarm" "upstream-errors" {
  alarm_name                = "${local.name_prefix}-upstream-errors"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  alarm_description         = "Upstream ELB error rate exceeds ${local.threshold_upstream_error_count} in the last 5 minutes"
  alarm_actions             = local.alarm_actions
  ok_actions                = local.ok_actions
  insufficient_data_actions = [] # It's normal to have no data on this metric

  namespace          = "AWS/ApplicationELB"
  dimensions         = local.dim_lb
  metric_name        = "HTTPCode_Target_5XX_Count"
  treat_missing_data = "notBreaching"

  datapoints_to_alarm = 1
  evaluation_periods  = "1"
  threshold           = local.threshold_upstream_error_count
  period              = 300
  statistic           = "Sum"
}
