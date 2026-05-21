# =============================================================
# SENTINELA SCPH — bloco4_motor_decisao.tf
# BLOCO 4: Motor de Decisão
# =============================================================

resource "aws_sns_topic" "alerta_clinico" {
  name              = "${var.project_name}-alerta-clinico"
  kms_master_key_id = aws_kms_key.sentinela.arn
  tags              = { Name = "${var.project_name}-sns-alerta" }
}

resource "aws_sns_topic_subscription" "email_medico" {
  topic_arn = aws_sns_topic.alerta_clinico.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_iam_role" "lambda_motor" {
  name = "${var.project_name}-lambda-motor-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Permissão para Lambda criar interfaces de rede na VPC
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_motor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_motor_policy" {
  name = "permissoes-motor-decisao"
  role = aws_iam_role.lambda_motor.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${aws_s3_bucket.bronze.arn}/*", "${aws_s3_bucket.silver.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"]
        Resource = [aws_dynamodb_table.alertas_clinicos.arn, aws_dynamodb_table.pacientes.arn]
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

data "archive_file" "lambda_motor" {
  type        = "zip"
  output_path = "${path.module}/lambda_motor.zip"

  source {
    content  = <<-PYTHON
import json
import boto3
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

TABELA_ALERTAS = os.environ['TABELA_ALERTAS']
SNS_TOPIC_ARN  = os.environ['SNS_TOPIC_ARN']

LIMIAR_HEMATOCRITO_ALTO = 50.0
LIMIAR_PLAQUETAS_BAIXO  = 150000
LIMIAR_LEUCOCITOS_ALTO  = 11000

def lambda_handler(event, context):
    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key    = record['s3']['object']['key']
        processar_exame(bucket, key)
    return {'statusCode': 200, 'body': 'Analise concluida'}

def processar_exame(bucket, key):
    s3 = boto3.client('s3')
    obj = s3.get_object(Bucket=bucket, Key=key)
    exame = json.loads(obj['Body'].read().decode('utf-8'))

    paciente_id = exame.get('paciente_id', 'desconhecido')
    hematocrito = float(exame.get('hematocrito', 0))
    plaquetas   = int(exame.get('plaquetas', 999999))
    leucocitos  = int(exame.get('leucocitos', 0))
    zona_rural  = exame.get('zona_rural', False)

    triade_positiva = (
        hematocrito >= LIMIAR_HEMATOCRITO_ALTO and
        plaquetas   <= LIMIAR_PLAQUETAS_BAIXO  and
        leucocitos  >= LIMIAR_LEUCOCITOS_ALTO
    )

    score = sum([
        hematocrito >= LIMIAR_HEMATOCRITO_ALTO,
        plaquetas   <= LIMIAR_PLAQUETAS_BAIXO,
        leucocitos  >= LIMIAR_LEUCOCITOS_ALTO,
        zona_rural  == True
    ])

    gravidade = "CRITICO" if triade_positiva else ("ALTO" if score >= 2 else "BAIXO")

    tabela = dynamodb.Table(TABELA_ALERTAS)
    tabela.put_item(Item={
        'paciente_id':     paciente_id,
        'timestamp':       datetime.utcnow().isoformat(),
        'gravidade':       gravidade,
        'score':           score,
        'hematocrito':     str(hematocrito),
        'plaquetas':       str(plaquetas),
        'leucocitos':      str(leucocitos),
        'zona_rural':      str(zona_rural),
        'triade_positiva': str(triade_positiva)
    })

    if gravidade in ["CRITICO", "ALTO"]:
        mensagem = f"""
ALERTA SENTINELA SCPH — {gravidade}
Paciente: {paciente_id}
Score de risco: {score}/4
Hematocrito: {hematocrito}%
Plaquetas: {plaquetas}/uL
Leucocitos: {leucocitos}/uL
Zona rural: {zona_rural}
Triade positiva: {triade_positiva}
        """
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"[SENTINELA] Alerta {gravidade} — Paciente {paciente_id}",
            Message=mensagem
        )
PYTHON
    filename = "motor_decisao.py"
  }
}

data "archive_file" "lambda_ia" {
  type        = "zip"
  output_path = "${path.module}/lambda_ia.zip"

  source {
    content  = <<-PYTHON
import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

TABELA_ALERTAS = os.environ['TABELA_ALERTAS']
SNS_TOPIC_ARN  = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    return {"statusCode": 200, "body": "ok"}
PYTHON
    filename = "analise_raio_x.py"
  }
}

resource "aws_lambda_function" "motor_decisao" {
  function_name    = "${var.project_name}-motor-decisao"
  role             = aws_iam_role.lambda_motor.arn
  handler          = "motor_decisao.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_motor.output_path
  source_code_hash = data.archive_file.lambda_motor.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      TABELA_ALERTAS = aws_dynamodb_table.alertas_clinicos.name
      SNS_TOPIC_ARN  = aws_sns_topic.alerta_clinico.arn
      ENVIRONMENT    = var.environment
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.privada_az1.id, aws_subnet.privada_az2.id]
    security_group_ids = [aws_security_group.sentinela_interno.id]
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_vpc]

  tags = { Name = "${var.project_name}-lambda-motor" }
}

resource "aws_s3_bucket_notification" "trigger_lambda" {
  bucket = aws_s3_bucket.bronze.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.motor_decisao.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "laudos/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.motor_decisao.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bronze.arn
}

resource "aws_cloudwatch_log_group" "lambda_motor" {
  name              = "/aws/lambda/${aws_lambda_function.motor_decisao.function_name}"
  retention_in_days = 30
  tags              = { Name = "${var.project_name}-logs-motor" }
}
