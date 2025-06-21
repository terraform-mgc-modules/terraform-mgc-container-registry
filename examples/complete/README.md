# 🚀 Exemplo Completo - MGC Container Registry Module

Este exemplo demonstra **TODAS as funcionalidades** disponíveis no módulo MGC Container Registry, criando múltiplos registries com diferentes configurações e casos de uso.

## 🎯 O que este exemplo faz

### 📦 3 Registries com Diferentes Propósitos

1. **📋 Registry de Desenvolvimento (`dev_registry`)**
   - Configuração básica e minimalista
   - Ideal para testes e desenvolvimento
   - Sem funcionalidades extras habilitadas

2. **🏭 Registry de Produção (`prod_registry`)**
   - **TODAS as funcionalidades habilitadas**
   - Credenciais para CI/CD
   - Listagem de todos os registries
   - Análise de repositórios
   - Dados de armazenamento e timestamps

3. **📊 Registry de Monitoramento (`monitoring_registry`)**
   - Configuração especializada para análise
   - Análise específica de imagens em repositórios
   - Monitoramento de uso e performance

## 🔧 Funcionalidades Demonstradas

### ✅ Todas as Opções do Módulo
- ✅ `enable_credentials_output = true` - Credenciais para automação
- ✅ `enable_registries_list = true` - Lista todos os registries da conta
- ✅ `enable_repositories_data = true` - Dados dos repositórios
- ✅ `enable_images_data = true` - Análise específica de imagens
- ✅ `repository_name` - Consulta de repositório específico

### 📊 Outputs Avançados
- 📋 **Informações básicas** de cada registry
- 🔐 **Credenciais sensíveis** para CI/CD
- 📈 **Análise de armazenamento** detalhada
- 🚨 **Alertas** de uso de espaço
- ⚙️ **Configuração para CI/CD** pronta para uso
- 📦 **Resumo de repositórios** por registry
- 🔍 **Análise de imagens** do repositório de teste
- ⚖️ **Comparação** entre todos os registries

## 🚀 Como Executar

### 1. Configurar Credenciais
```bash
# A API key já está configurada no terraform.tfvars
# Verifique se ela tem as permissões necessárias
```

### 2. Inicializar e Validar
```bash
cd examples/complete
terraform init
terraform validate
```

### 3. Visualizar o Plano
```bash
terraform plan
```

### 4. Aplicar as Configurações
```bash
terraform apply
```

## 📋 Outputs Esperados

Após a execução, você verá outputs organizados em categorias:

### 📊 Informações dos Registries
```hcl
dev_registry_info = {
  id   = "registry-dev-id"
  name = "teste-dev-apps-registry"
}

prod_registry_info = {
  id               = "registry-prod-id"
  name             = "teste-prod-apps-registry"
  created_at       = "2025-06-20T..."
  storage_usage_gb = 0.001
  repositories     = 0
  all_registries   = 3
}
```

### 🔐 Credenciais (Sensíveis)
```hcl
prod_registry_credentials = <sensitive>
monitoring_registry_credentials = <sensitive>
```

### ⚙️ Configuração para CI/CD
```hcl
cicd_config = {
  production = {
    registry_url = "registry.magalu.cloud"
    username     = "mgc_user_xxx"
    email        = "user@example.com"
    registry_id  = "registry-prod-id"
  }
  monitoring = {
    registry_url = "registry.magalu.cloud"
    username     = "mgc_user_yyy"
    email        = "user@example.com"
    registry_id  = "registry-monitoring-id"
  }
}
```

### 📈 Análise de Armazenamento
```hcl
storage_analysis = {
  "teste-prod-apps-registry" = {
    storage_bytes = 1048576
    storage_mb    = 1
    storage_gb    = 0.001
    created_at    = "2025-06-20"
    age_days      = "2025-06-20"
  }
}
```

## 🎓 Casos de Uso Demonstrados

### 1. **Desenvolvimento Ágil**
- Registry básico para desenvolvimento local
- Sem overhead de funcionalidades desnecessárias

### 2. **Produção Enterprise**
- Monitoramento completo de recursos
- Credenciais para pipelines de CI/CD
- Análise de uso e custos

### 3. **Observabilidade**
- Análise específica de imagens
- Monitoramento de repositórios
- Alertas de armazenamento

## 🔍 Funcionalidades Testadas

| Funcionalidade   | Dev Registry | Prod Registry | Monitoring Registry |
| ---------------- | ------------ | ------------- | ------------------- |
| Criação básica   | ✅            | ✅             | ✅                   |
| Credenciais      | ❌            | ✅             | ✅                   |
| Lista registries | ❌            | ✅             | ✅                   |
| Repositórios     | ❌            | ✅             | ✅                   |
| Imagens          | ❌            | ❌             | ✅                   |

## 🚨 Notas Importantes

### Sobre o Repositório de Teste
- O `test_repository_name = "test-app"` é usado para demonstrar a análise de imagens
- Se o repositório não existir, o output `test_repository_analysis` será `null`
- Para testar completamente, você pode criar um repositório e fazer push de uma imagem

### Sobre Permissões
- Este exemplo requer todas as permissões do Container Registry
- Verifique se sua API key tem acesso completo

### Sobre Custos
- Este exemplo cria 3 registries simultaneamente
- Lembre-se de executar `terraform destroy` após os testes

## 🧹 Limpeza

Para remover todos os recursos criados:

```bash
terraform destroy -auto-approve
```

## 📚 Referência

- [README Principal](../../README.md) - Documentação completa do módulo
- [Exemplo Simples](../simple/) - Versão básica para começar
