# ============================================================================
# Exemplo COMPLETO do módulo MGC Container Registry
# ============================================================================
# Este exemplo demonstra TODAS as funcionalidades disponíveis do módulo:
# 1. Criação de múltiplos registries com diferentes configurações
# 2. Habilitação de todos os data sources disponíveis
# 3. Outputs avançados e análises de dados
# 4. Integração com CI/CD
# 5. Monitoramento e alertas
# ============================================================================

terraform {
  required_providers {
    mgc = {
      source  = "magalucloud/mgc"
      version = "0.33.0"
    }
  }
}

# Variáveis para configuração
variable "mgc_api_key" {
  description = "API Key da Magalu Cloud"
  type        = string
  sensitive   = true
}

variable "mgc_region" {
  description = "Região da Magalu Cloud"
  type        = string
  default     = "br-se1"
}

variable "dev_registry_name" {
  description = "Nome do registry de desenvolvimento"
  type        = string
  default     = "dev-apps-registry"
}

variable "prod_registry_name" {
  description = "Nome do registry de produção"
  type        = string
  default     = "prod-apps-registry"
}

variable "monitoring_registry_name" {
  description = "Nome do registry de monitoramento"
  type        = string
  default     = "monitoring-registry"
}

variable "test_repository_name" {
  description = "Nome do repositório para teste de imagens"
  type        = string
  default     = "test-app"
}

# Configuração do provider MGC
provider "mgc" {
  api_key = var.mgc_api_key
  region  = var.mgc_region
}

# ============================================================================
# REGISTRY 1: Desenvolvimento - Configuração Básica
# ============================================================================
module "dev_registry" {
  source = "../../"

  # Configuração básica
  mgc_api_key             = var.mgc_api_key
  mgc_region              = var.mgc_region
  container_registry_name = var.dev_registry_name

  # Data sources desabilitados para performance
  enable_credentials_output = false
  enable_registries_list    = false
  enable_repositories_data  = false
  enable_images_data        = false
}

# ============================================================================
# REGISTRY 2: Produção - TODAS as funcionalidades habilitadas
# ============================================================================
module "prod_registry" {
  source = "../../"

  # Configuração básica
  mgc_api_key             = var.mgc_api_key
  mgc_region              = var.mgc_region
  container_registry_name = var.prod_registry_name

  # 🔑 HABILITAR TODAS as funcionalidades
  enable_credentials_output = true  # Credenciais para CI/CD
  enable_registries_list    = true  # Lista todos os registries (timestamps, storage)
  enable_repositories_data  = true  # Lista repositórios do registry
  enable_images_data        = false # Não há repositório específico ainda
}

# ============================================================================
# REGISTRY 3: Monitoramento - Com consulta específica de imagens
# ============================================================================
module "monitoring_registry" {
  source = "../../"

  # Configuração básica
  mgc_api_key             = var.mgc_api_key
  mgc_region              = var.mgc_region
  container_registry_name = var.monitoring_registry_name

  # Configuração para análise de imagens
  enable_credentials_output = true                     # Credenciais para deploy
  enable_registries_list    = true                     # Dados de armazenamento
  enable_repositories_data  = true                     # Lista repositórios
  repository_name           = var.test_repository_name # Repositório específico
  enable_images_data        = true                     # 🔍 Analisa imagens do repositório
}
