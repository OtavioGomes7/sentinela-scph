# =============================================================
# SENTINELA SCPH — bloco5_ia_visao.tf
# BLOCO 5: IA e Visão Computacional
#
# SageMaker Model e Endpoint estão comentados.
# Para ativar:
#   1. Treine o modelo com TorchXRayVision
#   2. Salve como model.tar.gz
#   3. Faça upload para o bucket sagemaker_artefatos
#   4. Descomente os blocos abaixo
# =============================================================

resource "aws_s3_bucket" "sagemaker_artefatos" {
  bucket = "${var.project_name}-sagemaker-${var.environment}-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project_name}-sagemaker-artefatos" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sagemaker" {
  bucket = aws_s3_bucket.sagemaker_artefatos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.sentinela.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "sagemaker" {
  bucket                  = aws_s3_bucket.sagemaker_artefatos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "sagemaker" {
  name = "${var.project_name}-sagemaker-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_full" {
  role       = aws_iam_role.sagemaker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy" "sagemaker_s3" {
  name = "acesso-s3-artefatos"
  role = aws_iam_role.sagemaker.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.sagemaker_artefatos.arn,
        "${aws_s3_bucket.sagemaker_artefatos.arn}/*",
        aws_s3_bucket.silver.arn,
        "${aws_s3_bucket.silver.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role" "lambda_ia" {
  name = "${var.project_name}-lambda-ia-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_ia_policy" {
  name = "permissoes-ia-raio-x"
  role = aws_iam_role.lambda_ia.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.silver.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.alertas_clinicos.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.alerta_clinico.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = aws_kms_key.sentinela.arn
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "analise_raio_x" {
  function_name    = "${var.project_name}-analise-raio-x"
  role             = aws_iam_role.lambda_ia.arn
  handler          = "analise_raio_x.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_ia.output_path
  source_code_hash = data.archive_file.lambda_ia.output_base64sha256
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      SAGEMAKER_ENDPOINT = "sentinela-scph-endpoint-raio-x"
      TABELA_ALERTAS     = aws_dynamodb_table.alertas_clinicos.name
      SNS_TOPIC_ARN      = aws_sns_topic.alerta_clinico.arn
    }
  }

  tags = { Name = "${var.project_name}-lambda-ia" }
}

resource "aws_cloudwatch_log_group" "lambda_ia" {
  name              = "/aws/lambda/${aws_lambda_function.analise_raio_x.function_name}"
  retention_in_days = 30
  tags              = { Name = "${var.project_name}-logs-ia" }
}

# ---------------------------------------------------------------
# SAGEMAKER MODEL E ENDPOINT — comentados até o modelo ser treinado
# Descomente após fazer upload do model.tar.gz no bucket S3
# ---------------------------------------------------------------

# resource "aws_sagemaker_model" "raio_x_torax" {
#   name               = "${var.project_name}-modelo-raio-x"
#   execution_role_arn = aws_iam_role.sagemaker.arn
#   primary_container {
#     image          = "763104351884.dkr.ecr.${var.aws_region}.amazonaws.com/pytorch-inference:2.1.0-cpu-py310"
#     model_data_url = "s3://${aws_s3_bucket.sagemaker_artefatos.bucket}/modelos/raio_x/model.tar.gz"
#     environment = {
#       SAGEMAKER_PROGRAM          = "inference.py"
#       SAGEMAKER_SUBMIT_DIRECTORY = "/opt/ml/model/code"
#     }
#   }
#   tags = { Name = "${var.project_name}-modelo-raio-x" }
# }

# resource "aws_sagemaker_endpoint_configuration" "raio_x" {
#   name = "${var.project_name}-endpoint-config-raio-x"
#   production_variants {
#     variant_name           = "AllTraffic"
#     model_name             = aws_sagemaker_model.raio_x_torax.name
#     initial_instance_count = 1
#     instance_type          = "ml.t2.medium"
#   }
#   kms_key_arn = aws_kms_key.sentinela.arn
#   tags        = { Name = "${var.project_name}-endpoint-config" }
# }

# resource "aws_sagemaker_endpoint" "raio_x" {
#   name                 = "${var.project_name}-endpoint-raio-x"
#   endpoint_config_name = aws_sagemaker_endpoint_configuration.raio_x.name
#   tags                 = { Name = "${var.project_name}-endpoint-raio-x" }
# }
