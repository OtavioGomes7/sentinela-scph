# =============================================================
# SENTINELA SCPH — bloco2_ingestao.tf
# BLOCO 2: Ingestão de Dados
# =============================================================

resource "aws_kms_key" "sentinela" {
  description             = "Chave de criptografia principal do Sentinela SCPH"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = { Name = "${var.project_name}-kms" }
}

resource "aws_kms_alias" "sentinela" {
  name          = "alias/${var.project_name}"
  target_key_id = aws_kms_key.sentinela.key_id
}

resource "aws_s3_bucket" "bronze" {
  bucket = "${var.project_name}-bronze-${var.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project_name}-bronze", Layer = "Bronze" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bronze" {
  bucket = aws_s3_bucket.bronze.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.sentinela.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "bronze" {
  bucket = aws_s3_bucket.bronze.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket" "silver" {
  bucket = "${var.project_name}-silver-${var.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project_name}-silver", Layer = "Silver" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "silver" {
  bucket = aws_s3_bucket.silver.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.sentinela.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "bronze_lifecycle" {
  bucket = aws_s3_bucket.bronze.id

  rule {
    id     = "mover-para-glacier"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = var.s3_lifecycle_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bronze" {
  bucket                  = aws_s3_bucket.bronze.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "silver" {
  bucket                  = aws_s3_bucket.silver.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "transfer_family" {
  name = "${var.project_name}-transfer-family-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "transfer.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "transfer_family_s3" {
  name = "acesso-s3-bronze"
  role = aws_iam_role.transfer_family.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.bronze.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.bronze.arn
      }
    ]
  })
}

# ---------------------------------------------------------------
# AWS TRANSFER FAMILY (SFTP)
# 💰 CUSTO PAGO: ~$0.30/hora (~$216/mês)
# ---------------------------------------------------------------
resource "aws_transfer_server" "sftp_laudos" {
  identity_provider_type = "SERVICE_MANAGED"
  protocols              = ["SFTP"]
  domain                 = "S3"
  endpoint_type          = "PUBLIC"
  logging_role           = aws_iam_role.transfer_family.arn
  tags                   = { Name = "${var.project_name}-sftp-laudos" }
}

resource "aws_transfer_user" "laboratorio" {
  server_id           = aws_transfer_server.sftp_laudos.id
  user_name           = "laboratorio-parceiro"
  role                = aws_iam_role.transfer_family.arn
  home_directory_type = "LOGICAL"

  home_directory_mappings {
    entry  = "/"
    target = "/${aws_s3_bucket.bronze.id}/laudos"
  }

  tags = { Name = "usuario-laboratorio" }
}

data "aws_caller_identity" "current" {}
