# =============================================================
# SENTINELA SCPH — outputs.tf
# =============================================================

output "vpc_id" {
  description = "ID da VPC do Sentinela"
  value       = aws_vpc.sentinela.id
}

output "bucket_bronze" {
  description = "Nome do bucket S3 Bronze"
  value       = aws_s3_bucket.bronze.bucket
}

output "bucket_silver" {
  description = "Nome do bucket S3 Silver"
  value       = aws_s3_bucket.silver.bucket
}

output "lambda_motor_arn" {
  description = "ARN da Lambda do motor de decisao"
  value       = aws_lambda_function.motor_decisao.arn
}

output "sns_topic_arn" {
  description = "ARN do topico SNS de alertas"
  value       = aws_sns_topic.alerta_clinico.arn
}

output "dynamodb_alertas" {
  description = "Nome da tabela DynamoDB de alertas"
  value       = aws_dynamodb_table.alertas_clinicos.name
}

output "sftp_endpoint" {
  description = "Endereco do servidor SFTP"
  value       = aws_transfer_server.sftp_laudos.endpoint
}

output "resumo_implantacao" {
  description = "Resumo do deploy"
  value = <<-EOT
    ╔══════════════════════════════════════════════════╗
    ║        SENTINELA SCPH — IMPLANTADO COM SUCESSO   ║
    ╠══════════════════════════════════════════════════╣
    ║  Ambiente : ${var.environment}
    ║  Região   : ${var.aws_region}
    ║  E-mail   : ${var.alert_email}
    ╠══════════════════════════════════════════════════╣
    ║  PRÓXIMOS PASSOS:                                ║
    ║  1. Confirme o e-mail de inscrição SNS           ║
    ║  2. Envie um JSON de laudo para o S3/laudos/     ║
    ║  3. Verifique o alerta no seu e-mail             ║
    ╚══════════════════════════════════════════════════╝
  EOT
}
