# =============================================================
# SENTINELA SCPH — variables.tf
# Todas as variáveis configuráveis do projeto.
# Para mudar de região ou ambiente, edite apenas este arquivo.
# =============================================================

variable "aws_region" {
  description = "Região AWS onde o Sentinela será implantado"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, producao)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Nome do projeto — usado como prefixo em todos os recursos"
  type        = string
  default     = "sentinela-scph"
}

variable "alert_email" {
  description = "E-mail que receberá os alertas clínicos do SNS"
  type        = string
  # IMPORTANTE: troque pelo seu e-mail real antes de rodar o terraform apply
  default     = "otavio7ia@gmail.com"
}

variable "s3_lifecycle_glacier_days" {
  description = "Dias até mover dados antigos do S3 para o Glacier"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos"
  type        = map(string)
  default = {
    Project   = "Sentinela-SCPH"
    Author    = "Otavio Gomes de Oliveira"
    ManagedBy = "Terraform"
    Purpose   = "Diagnostico-precoce-Hantavirus"
  }
}
