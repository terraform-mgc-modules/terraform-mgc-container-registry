# ============================================================================
# Exemplo simples do módulo MGC Container Registry
# ============================================================================
# Este exemplo demonstra como usar o módulo MGC Container Registry
# para criar um registry básico na Magalu Cloud.
# O módulo cria um registry com o nome especificado e retorna informações básicas.
# É ideal para testes iniciais e validação de configuração.
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
  description = "API Key da Magalu Cloud para testes"
  type        = string
  sensitive   = true
}

variable "mgc_region" {
  description = "Região da Magalu Cloud (ex: br-se1)"
  type        = string
  default     = "br-se1"
}

variable "container_registry_name" {
  description = "Nome do container registry para este exemplo"
  type        = string
  default     = "teste-simples-registry"
}

# Configuração do provider MGC
provider "mgc" {
  api_key = var.mgc_api_key
  region  = var.mgc_region
}

# Uso do módulo MGC Container Registry
module "simple_registry" {
  source = "../../"

  # Variáveis obrigatórias do módulo
  mgc_api_key             = var.mgc_api_key
  mgc_region              = var.mgc_region
  container_registry_name = var.container_registry_name
}

# Outputs
output "registry_id" {
  description = "ID do registry criado"
  value       = module.simple_registry.container_registry_id
}

output "registry_name" {
  description = "Nome do registry criado"
  value       = module.simple_registry.container_registry_name
}

output "registry_created_at" {
  description = "Data de criação do registry"
  value       = module.simple_registry.container_registry_created_at
}
