# =============================================================
# SENTINELA SCPH — bloco3_datalake.tf
# BLOCO 3: Data Lake Clínico
# =============================================================

resource "aws_dynamodb_table" "alertas_clinicos" {
  name         = "${var.project_name}-alertas"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "paciente_id"
  range_key    = "timestamp"

  attribute {
    name = "paciente_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "gravidade"
    type = "S"
  }

  global_secondary_index {
    name            = "gravidade-index"
    hash_key        = "gravidade"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.sentinela.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${var.project_name}-alertas-db" }
}

resource "aws_dynamodb_table" "pacientes" {
  name         = "${var.project_name}-pacientes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "paciente_id"

  attribute {
    name = "paciente_id"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.sentinela.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = { Name = "${var.project_name}-pacientes-db" }
}
