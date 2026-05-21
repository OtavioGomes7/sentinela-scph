# =============================================================
# SENTINELA SCPH — bloco1_vpc.tf
# BLOCO 1: Fundação de Rede
# =============================================================

resource "aws_vpc" "sentinela" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "privada_az1" {
  vpc_id            = aws_vpc.sentinela.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "${var.project_name}-privada-az1" }
}

resource "aws_subnet" "privada_az2" {
  vpc_id            = aws_vpc.sentinela.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"
  tags              = { Name = "${var.project_name}-privada-az2" }
}

resource "aws_subnet" "publica_az1" {
  vpc_id                  = aws_vpc.sentinela.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-publica-az1" }
}

resource "aws_subnet" "publica_az2" {
  vpc_id                  = aws_vpc.sentinela.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-publica-az2" }
}

resource "aws_internet_gateway" "sentinela" {
  vpc_id = aws_vpc.sentinela.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "sentinela" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.publica_az1.id
  tags          = { Name = "${var.project_name}-nat" }
  depends_on    = [aws_internet_gateway.sentinela]
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.sentinela.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sentinela.id
  }
  tags = { Name = "${var.project_name}-rt-publica" }
}

resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.sentinela.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.sentinela.id
  }
  tags = { Name = "${var.project_name}-rt-privada" }
}

resource "aws_route_table_association" "publica_az1" {
  subnet_id      = aws_subnet.publica_az1.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table_association" "publica_az2" {
  subnet_id      = aws_subnet.publica_az2.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table_association" "privada_az1" {
  subnet_id      = aws_subnet.privada_az1.id
  route_table_id = aws_route_table.privada.id
}

resource "aws_route_table_association" "privada_az2" {
  subnet_id      = aws_subnet.privada_az2.id
  route_table_id = aws_route_table.privada.id
}

resource "aws_security_group" "sentinela_interno" {
  name        = "${var.project_name}-interno"
  description = "Permite comunicacao interna entre servicos do Sentinela"
  vpc_id      = aws_vpc.sentinela.id

  ingress {
    description = "Trafego interno da VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.sentinela.cidr_block]
  }

  egress {
    description = "Saida para internet via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg-interno" }
}
