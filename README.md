# 🛡️ Sentinela SCPH
### Plataforma de Inteligência Epidemiológica para Diagnóstico Precoce de Hantavírus

![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazon-aws)
![Terraform](https://img.shields.io/badge/Terraform-IaC-purple?logo=terraform)
![Python](https://img.shields.io/badge/Python-3.12-blue?logo=python)
![Status](https://img.shields.io/badge/Status-Em%20Desenvolvimento-yellow)

---

## 📋 Sobre o Projeto

O **Sentinela SCPH** é uma plataforma de missão crítica desenvolvida para o **diagnóstico precoce da Síndrome Cardiopulmonar por Hantavírus (SCPH)** — uma das zoonoses com maior taxa de letalidade no Brasil, com mortalidade entre 40% e 60% nos casos não diagnosticados a tempo.

O sistema integra dados laboratoriais, imagens radiológicas e contexto geográfico para detectar automaticamente a **Tríade de Gravidade** e emitir alertas clínicos em tempo real para profissionais de saúde.

> _"O diagnóstico tardio é o principal fator de morte por SCPH. O Sentinela nasce para mudar esse cenário."_

---

## 🎯 Problema que Resolve

- ⚠️ Diagnóstico tardio de SCPH por ausência de sistemas de alerta automatizados
- ⚠️ Dados laboratoriais e radiológicos isolados em sistemas distintos
- ⚠️ Ausência de correlação automática entre perfil laboratorial + imagem + contexto geográfico
- ⚠️ Alta mortalidade evitável com diagnóstico nas primeiras 24-48 horas

---

## 🏗️ Arquitetura

```
Exame Laboratorial (SFTP)          Imagem DICOM (Hospital)
         │                                    │
         ▼                                    ▼
  AWS Transfer Family                   AWS DataSync
         │                                    │
         └──────────────┬─────────────────────┘
                        ▼
              ┌─────────────────┐
              │   S3 Bronze     │  ← Dados brutos
              │   S3 Silver     │  ← Dados processados
              │   S3 Glacier    │  ← Arquivo 7 anos
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  AWS HealthLake │  ← Repositório FHIR R4
              │  DynamoDB       │  ← Alertas + Pacientes
              └────────┬────────┘
                       │
                       ▼
         ┌─────────────────────────┐
         │   AWS Lambda            │
         │   Motor de Decisão      │  ← Tríade de Gravidade
         │   • Hematócrito > 50%   │
         │   • Plaquetas < 150.000 │
         │   • Leucocitose > 11.000│
         │   • Contexto rural      │
         └────────────┬────────────┘
                      │
           ┌──────────┴──────────┐
           ▼                     ▼
    Amazon SageMaker        Amazon SNS
    Deep Learning           Alerta Clínico
    Raio-X Tórax            → E-mail Médico
    (Infiltrado bilateral)
           │
           ▼
    CloudWatch + X-Ray
    Monitoramento proativo
```

---

## 🧠 Tríade de Gravidade

O motor de decisão analisa em tempo real:

| Parâmetro | Limiar de Alerta | Significado Clínico |
|---|---|---|
| Hematócrito | ≥ 50% | Hemoconcentração — extravasamento plasmático |
| Plaquetas | ≤ 150.000/µL | Plaquetopenia — comprometimento hematológico |
| Leucócitos | ≥ 11.000/µL | Leucocitose — resposta inflamatória sistêmica |
| Zona rural/silvestre | Presente | Biomarcador ambiental — exposição ao roedor |

**Score 4/4 → Alerta CRÍTICO → Notificação imediata ao médico**

---

## ⚙️ Stack Tecnológica

### Cloud & Infraestrutura
| Serviço | Função |
|---|---|
| Amazon VPC | Rede isolada com sub-redes privadas em múltiplas AZs |
| AWS Transfer Family | Ingestão de laudos laboratoriais via SFTP |
| Amazon S3 | Data Lake em camadas Bronze/Silver/Archive |
| AWS HealthLake | Repositório FHIR R4 para dados clínicos |
| Amazon DynamoDB | Armazenamento de alertas e pacientes |
| AWS Lambda | Motor de decisão serverless |
| Amazon SNS | Sistema de alertas clínicos |
| Amazon SageMaker | Inferência de modelo Deep Learning (Raio-X) |
| AWS KMS | Criptografia de dados PHI |
| Amazon CloudWatch | Monitoramento e dashboards |
| AWS X-Ray | Rastreamento de diagnósticos |

### IaC & DevOps
| Tecnologia | Uso |
|---|---|
| Terraform ≥ 1.5 | Infraestrutura como Código |
| Python 3.12 | Lógica das funções Lambda |
| AWS CLI v2 | Autenticação e gerenciamento |

---

## 📁 Estrutura do Projeto

```
sentinela-scph/
├── variables.tf              # Variáveis configuráveis (região, ambiente, e-mail)
├── providers.tf              # Configuração do provider AWS
├── bloco1_vpc.tf             # Rede isolada, sub-redes, NAT Gateway
├── bloco2_ingestao.tf        # S3 Bronze/Silver, Transfer Family SFTP, KMS
├── bloco3_datalake.tf        # HealthLake FHIR, DynamoDB alertas e pacientes
├── bloco4_motor_decisao.tf   # Lambda Motor + EventBridge + SNS
├── bloco5_ia_visao.tf        # SageMaker + Lambda análise Raio-X
├── bloco6_operacoes.tf       # CloudWatch, X-Ray, alarmes de custo
└── outputs.tf                # Valores exportados após o deploy
```

---

## 🚀 Como Implantar

### Pré-requisitos
- [Terraform ≥ 1.5](https://developer.hashicorp.com/terraform/install)
- [AWS CLI v2](https://aws.amazon.com/cli/)
- Conta AWS com permissões de administrador

### 1. Configurar credenciais AWS
```bash
aws configure
# AWS Access Key ID: <sua-chave>
# AWS Secret Access Key: <sua-chave-secreta>
# Default region name: sa-east-1
# Default output format: json
```

### 2. Clonar e configurar
```bash
git clone https://github.com/seu-usuario/sentinela-scph.git
cd sentinela-scph
```

Edite o `variables.tf` com seu e-mail:
```hcl
variable "alert_email" {
  default = "seu-email@gmail.com"
}
```

### 3. Implantar
```bash
terraform init
terraform plan
terraform apply
```

### 4. Testar
```bash
# Substitua pelo nome real do bucket (aparece nos outputs)
aws s3 cp laudo_teste.json s3://sentinela-scph-bronze-dev-XXXX/laudos/
```

Exemplo de laudo de teste (`laudo_teste.json`):
```json
{
  "paciente_id": "PAC-001-TESTE",
  "hematocrito": 52.5,
  "plaquetas": 95000,
  "leucocitos": 13500,
  "zona_rural": true,
  "municipio": "Chapada dos Guimarães",
  "estado": "MT"
}
```

### 5. Destruir (evitar cobranças)
```bash
terraform destroy
```

---

## 💰 Custos AWS Estimados

| Serviço | Free Tier | Custo/mês (prod) |
|---|---|---|
| Lambda | ✅ 1M invocações grátis | ~$0 em dev |
| S3 | ✅ 5GB grátis/12 meses | ~$0.023/GB |
| DynamoDB | ✅ 25GB grátis | ~$0 em dev |
| SNS | ✅ 1M notificações grátis | ~$0 em dev |
| CloudWatch | ✅ 10 métricas grátis | ~$0 em dev |
| NAT Gateway | ❌ | ~$32/mês |
| Transfer Family | ❌ | ~$0.30/hora |
| SageMaker Endpoint | ❌ | ~$40/mês |
| KMS | ❌ | ~$1/mês/chave |

---

## 🔒 Segurança

- **AWS KMS** — criptografia em repouso para todos os dados PHI
- **VPC privada** — nenhum serviço exposto diretamente à internet
- **IAM com privilégio mínimo** — cada serviço tem apenas as permissões necessárias
- **S3 Block Public Access** — buckets bloqueados para acesso público
- **DynamoDB Point-in-Time Recovery** — backup automático habilitado
- **CloudTrail** — auditoria de todas as ações na conta AWS

---

## 🗺️ Roadmap

- [ ] Treinar modelo TorchXRayVision com dados reais de SCPH
- [ ] Implementar conformidade LGPD (anonimização de dados)
- [ ] Integração com sistemas HIS hospitalares via API Gateway
- [ ] Pipeline CI/CD com GitHub Actions
- [ ] Conformidade ANVISA para uso de IA em diagnóstico
- [ ] Dashboard web para visualização de alertas em tempo real
- [ ] Expansão para outras zoonoses virais agudas

---

## 👨‍💻 Autor

**Otávio Gomes de Oliveira**

- 🔬 Biomédico
- 🏥 Técnico em Análises Clínicas — 16 anos de experiência
- ☢️ Tecnólogo em Radiologia — 10 anos de experiência
- 🤖 Tecnólogo em Inteligência Artificial (cursando)
- ☁️ AWS Cloud Practitioner (em formação)

> Uma visão única: quem melhor para construir um sistema de diagnóstico inteligente do que alguém que passou 16 anos interpretando os exames que o sistema analisa?

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Otávio%20Gomes-blue?logo=linkedin)](https://linkedin.com/in/seu-perfil)
[![GitHub](https://img.shields.io/badge/GitHub-seu--usuario-black?logo=github)](https://github.com/seu-usuario)

---

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

_Desenvolvido com propósito: salvar vidas através da tecnologia._
