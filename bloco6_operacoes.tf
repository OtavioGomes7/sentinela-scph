# =============================================================
# SENTINELA SCPH — bloco6_operacoes.tf
# BLOCO 6: Operações e DevOps
# =============================================================

resource "aws_xray_group" "sentinela" {
  group_name        = "${var.project_name}-rastreamento"
  filter_expression = "service(\"${var.project_name}\")"

  insights_configuration {
    insights_enabled      = true
    notifications_enabled = true
  }

  tags = { Name = "${var.project_name}-xray-group" }
}

resource "aws_cloudwatch_metric_alarm" "erros_lambda_motor" {
  alarm_name          = "${var.project_name}-erros-motor-decisao"
  alarm_description   = "Erros na Lambda do motor de decisao"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.motor_decisao.function_name
  }

  alarm_actions = [aws_sns_topic.alerta_clinico.arn]
  ok_actions    = [aws_sns_topic.alerta_clinico.arn]

  tags = { Name = "${var.project_name}-alarm-erros-motor" }
}

resource "aws_cloudwatch_metric_alarm" "custo_mensal" {
  alarm_name          = "${var.project_name}-custo-alto"
  alarm_description   = "Gasto AWS ultrapassou $50 no mes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 86400
  statistic           = "Maximum"
  threshold           = 50
  treat_missing_data  = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.alerta_clinico.arn]

  tags = { Name = "${var.project_name}-alarm-custo" }
}
