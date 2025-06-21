# ============================================================================
# OUTPUTS DO EXEMPLO COMPLETO - Demonstra todas as funcionalidades
# ============================================================================

# ============================================================================
# OUTPUTS BÁSICOS - Informações dos registries criados
# ============================================================================

output "dev_registry_info" {
  description = "📋 Informações básicas do registry de desenvolvimento"
  value = {
    id   = module.dev_registry.container_registry_id
    name = module.dev_registry.container_registry_name
  }
}

output "prod_registry_info" {
  description = "🏭 Informações completas do registry de produção"
  value = {
    id               = module.prod_registry.container_registry_id
    name             = module.prod_registry.container_registry_name
    created_at       = module.prod_registry.container_registry_created_at
    updated_at       = module.prod_registry.container_registry_updated_at
    storage_usage_gb = module.prod_registry.container_registry_storage_usage_bytes != null ? module.prod_registry.container_registry_storage_usage_bytes / 1024 / 1024 / 1024 : null
    repositories     = try(length(module.prod_registry.repositories), 0)
    all_registries   = try(length(module.prod_registry.all_registries), 0)
  }
}

output "monitoring_registry_info" {
  description = "📊 Informações do registry de monitoramento com análise de imagens"
  value = {
    id           = module.monitoring_registry.container_registry_id
    name         = module.monitoring_registry.container_registry_name
    repositories = try(length(module.monitoring_registry.repositories), 0)
    images       = try(length(module.monitoring_registry.images), 0)
    test_repo    = var.test_repository_name
  }
}

# ============================================================================
# OUTPUTS SENSÍVEIS - Credenciais para CI/CD
# ============================================================================

output "prod_registry_credentials" {
  description = "🔐 Credenciais do registry de produção (SENSÍVEL)"
  value       = module.prod_registry.container_credentials
  sensitive   = true
}

output "monitoring_registry_credentials" {
  description = "🔐 Credenciais do registry de monitoramento (SENSÍVEL)"
  value       = module.monitoring_registry.container_credentials
  sensitive   = true
}

# ============================================================================
# OUTPUTS AVANÇADOS - Análises e Integrações
# ============================================================================

# Análise completa de armazenamento
output "storage_analysis" {
  description = "📈 Análise detalhada de uso de armazenamento de todos os registries"
  value = try(length(module.prod_registry.all_registries), 0) > 0 ? {
    for registry in module.prod_registry.all_registries :
    registry.name => {
      storage_bytes = try(registry.storage_usage_bytes, 0)
      storage_mb    = try(registry.storage_usage_bytes, 0) != null ? registry.storage_usage_bytes / 1024 / 1024 : 0
      storage_gb    = try(registry.storage_usage_bytes, 0) != null ? registry.storage_usage_bytes / 1024 / 1024 / 1024 : 0
      created_at    = try(registry.created_at, "N/A")
      updated_at    = try(registry.updated_at, "N/A")
      age_days      = try(formatdate("YYYY-MM-DD", registry.created_at), "N/A")
    }
  } : {}
}

# Configuração para CI/CD
locals {
  prod_credentials       = module.prod_registry.container_credentials
  monitoring_credentials = module.monitoring_registry.container_credentials
}

output "cicd_config" {
  description = "⚙️ Configuração completa para pipelines de CI/CD"
  sensitive   = true
  value = {
    # Registry de produção
    production = local.prod_credentials != null ? {
      registry_url = "registry.magalu.cloud"
      username     = local.prod_credentials.username
      email        = local.prod_credentials.email
      registry_id  = module.prod_registry.container_registry_id
      # password deve ser acessado via output sensível
    } : null

    # Registry de monitoramento
    monitoring = local.monitoring_credentials != null ? {
      registry_url = "registry.magalu.cloud"
      username     = local.monitoring_credentials.username
      email        = local.monitoring_credentials.email
      registry_id  = module.monitoring_registry.container_registry_id
      # password deve ser acessado via output sensível
    } : null
  }
}

# Alertas de armazenamento
output "storage_alerts" {
  description = "🚨 Alertas de armazenamento (registries > 1GB)"
  value = {
    for name, info in(try(length(module.prod_registry.all_registries), 0) > 0 ? {
      for registry in module.prod_registry.all_registries :
      registry.name => registry if try(registry.storage_usage_bytes, 0) != null && try(registry.storage_usage_bytes, 0) > 1073741824 # 1GB
    } : {}) :
    name => {
      storage_gb = try(info.storage_usage_bytes, 0) != null ? info.storage_usage_bytes / 1024 / 1024 / 1024 : 0
      message    = "⚠️ Registry ${name} está usando ${try(info.storage_usage_bytes, 0) != null ? info.storage_usage_bytes / 1024 / 1024 / 1024 : 0}GB"
      action     = "Considere limpeza de imagens antigas"
    }
  }
}

# Resumo de repositórios por registry
output "repositories_summary" {
  description = "📦 Resumo de repositórios por registry"
  value = {
    production = {
      registry_name = module.prod_registry.container_registry_name
      repositories  = module.prod_registry.repositories
      count         = try(length(module.prod_registry.repositories), 0)
    }
    monitoring = {
      registry_name    = module.monitoring_registry.container_registry_name
      repositories     = module.monitoring_registry.repositories
      count            = try(length(module.monitoring_registry.repositories), 0)
      test_repo_images = try(length(module.monitoring_registry.images), 0)
    }
  }
}

# Análise de imagens do repositório de teste
output "test_repository_analysis" {
  description = "🔍 Análise detalhada das imagens do repositório de teste"
  value = try(length(module.monitoring_registry.images), 0) > 0 ? {
    repository_name = var.test_repository_name
    total_images    = try(length(module.monitoring_registry.images), 0)
    images          = module.monitoring_registry.images
    registry        = module.monitoring_registry.container_registry_name
  } : null
}

# ============================================================================
# OUTPUTS DE COMPARAÇÃO - Análise entre registries
# ============================================================================

output "registries_comparison" {
  description = "⚖️ Comparação entre todos os registries criados"
  value = {
    total_registries = 3
    registries = {
      development = {
        name = module.dev_registry.container_registry_name
        features_enabled = [
          "basic_creation"
        ]
      }
      production = {
        name = module.prod_registry.container_registry_name
        features_enabled = [
          "credentials_output",
          "registries_list",
          "repositories_data"
        ]
      }
      monitoring = {
        name = module.monitoring_registry.container_registry_name
        features_enabled = [
          "credentials_output",
          "registries_list",
          "repositories_data",
          "images_data"
        ]
      }
    }
  }
}

