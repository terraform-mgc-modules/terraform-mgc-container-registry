# Comandos MGC CLI para Container Registry

Este documento apresenta os comandos essenciais da CLI da Magalu Cloud para gerenciamento de Container Registries.

## Pré-requisitos

- MGC CLI instalada
- Conta ativa na Magalu Cloud
- Permissões para Container Registry

## Autenticação

### Fazer Login na Conta

```bash
mgc auth login
```

Este comando abrirá o navegador para autenticação ou solicitará suas credenciais no terminal.

## Gerenciamento de Registries

### Listar Registries Existentes

```bash
mgc cr registries list
```

**Exemplo de saída:**
```yaml
results:
- created_at: "2025-06-21T00:00:09Z"
  id: a35678d2-47f5-4219-9cdf-16902c51fab8
  name: teste-principal-registry
  storage_usage_bytes: 0
  updated_at: "2025-06-21T00:00:09Z"
- created_at: "2025-06-21T00:15:22Z"
  id: b8f9c3a1-84d2-4567-a1b2-123456789abc
  name: dev-apps-registry
  storage_usage_bytes: 104857600
  updated_at: "2025-06-21T01:30:45Z"
- created_at: "2025-06-20T22:45:30Z"
  id: c9e8d7f6-95e3-4678-b2c3-234567890def
  name: prod-microservices-registry
  storage_usage_bytes: 2147483648
  updated_at: "2025-06-21T02:15:18Z"
```

### Criar um Novo Registry

```bash
mgc cr registries create --name "meu-novo-registry"
```

### Visualizar Detalhes de um Registry

```bash
mgc cr registries get --id "a35678d2-47f5-4219-9cdf-16902c51fab8"
```

### Deletar um Registry

```bash
mgc cr registries delete --id "a35678d2-47f5-4219-9cdf-16902c51fab8"
```

## Gerenciamento de Credenciais

### Obter Credenciais do Registry

```bash
mgc cr credentials list
```

**Exemplo de saída:**
```yaml
email: granatonatalia@gmail.com
password: YkrE85dWCI6snkW0UK4Xt52j77b*D@F0
username: a54b4f78-63aa-4baf-a9f7-467a1f0bd848
```

⚠️ **Importante:** As credenciais são sensíveis e devem ser tratadas com segurança. Use variáveis de ambiente ou sistemas de gerenciamento de segredos.

### Usando as Credenciais para Docker Login

```bash
# Usando as credenciais obtidas
echo "YkrE85dWCI6snkW0UK4Xt52j77b*D@F0" | docker login registry.magalu.cloud \
  --username a54b4f78-63aa-4baf-a9f7-467a1f0bd848 \
  --password-stdin
```

## Gerenciamento de Repositórios

### Listar Repositórios em um Registry

```bash
mgc cr repositories list --registry-name "teste-principal-registry"
```

**Exemplo de saída:**
```yaml
results:
- created_at: "2025-06-21T01:15:30Z"
  name: frontend-app
  registry_id: a35678d2-47f5-4219-9cdf-16902c51fab8
  updated_at: "2025-06-21T02:45:22Z"
- created_at: "2025-06-21T01:20:45Z"
  name: backend-api
  registry_id: a35678d2-47f5-4219-9cdf-16902c51fab8
  updated_at: "2025-06-21T03:10:15Z"
```

### Criar um Repositório

```bash
mgc cr repositories create \
  --registry-name "teste-principal-registry" \
  --name "minha-aplicacao"
```

## Gerenciamento de Imagens

### Listar Imagens em um Repositório

```bash
mgc cr images list \
  --registry-name "teste-principal-registry" \
  --repository-name "frontend-app"
```

**Exemplo de saída:**
```yaml
results:
- created_at: "2025-06-21T02:30:15Z"
  digest: sha256:abc123def456789012345678901234567890abcdef1234567890abcdef123456
  registry_id: a35678d2-47f5-4219-9cdf-16902c51fab8
  repository_name: frontend-app
  size_bytes: 157286400
  tags:
  - latest
  - v1.2.3
  - stable
  updated_at: "2025-06-21T02:30:15Z"
- created_at: "2025-06-21T01:45:30Z"
  digest: sha256:def789abc123456789012345678901234567890abcdef1234567890abcdef456
  registry_id: a35678d2-47f5-4219-9cdf-16902c51fab8
  repository_name: frontend-app
  size_bytes: 142606336
  tags:
  - v1.2.2
  - previous
  updated_at: "2025-06-21T01:45:30Z"
```

## Workflow Completo de Uso

### 1. Setup Inicial

```bash
# Fazer login
mgc auth login

# Verificar registries existentes
mgc cr registries list

# Obter credenciais
mgc cr credentials list
```

### 2. Configurar Docker

```bash
# Fazer login no registry com Docker
echo "YkrE85dWCI6snkW0UK4Xt52j77b*D@F0" | docker login registry.magalu.cloud \
  --username a54b4f78-63aa-4baf-a9f7-467a1f0bd848 \
  --password-stdin
```

### 3. Push de uma Imagem

```bash
# Fazer build da imagem
docker build -t minha-app:latest .

# Fazer tag para o registry
docker tag minha-app:latest registry.magalu.cloud/teste-principal-registry/minha-app:latest

# Fazer push da imagem
docker push registry.magalu.cloud/teste-principal-registry/minha-app:latest
```

### 4. Pull de uma Imagem

```bash
# Fazer pull da imagem
docker pull registry.magalu.cloud/teste-principal-registry/minha-app:latest
```

## Comandos de Monitoramento

### Verificar Uso de Armazenamento

```bash
# Listar registries com informações de storage
mgc cr registries list --format table
```

### Auditoria de Repositórios

```bash
# Listar todos os repositórios
mgc cr repositories list --registry-name "teste-principal-registry" --format json
```

### Análise de Imagens

```bash
# Verificar imagens em um repositório específico
mgc cr images list \
  --registry-name "teste-principal-registry" \
  --repository-name "frontend-app" \
  --format yaml
```

## Formatação de Saída

A CLI MGC suporta diferentes formatos de saída:

```bash
# Formato JSON
mgc cr registries list --format json

# Formato YAML (padrão)
mgc cr registries list --format yaml

# Formato tabela
mgc cr registries list --format table
```

## Filtros e Consultas

### Filtrar por Nome

```bash
# Buscar registries por nome
mgc cr registries list --name "prod-*"
```

### Filtrar por Data

```bash
# Buscar registries criados em uma data específica
mgc cr registries list --created-after "2025-06-20"
```

## Comandos de Ajuda

### Ajuda Geral

```bash
mgc cr --help
```

### Ajuda para Subcomandos

```bash
mgc cr registries --help
mgc cr credentials --help
mgc cr repositories --help
mgc cr images --help
```

## Exemplos de Automação

### Script para Backup de Metadados

```bash
#!/bin/bash

# Backup de informações de registries
mgc cr registries list --format json > registries_backup_$(date +%Y%m%d).json

# Backup de repositórios
for registry in $(mgc cr registries list --format json | jq -r '.[].name'); do
  mgc cr repositories list --registry-name "$registry" --format json > "repositories_${registry}_$(date +%Y%m%d).json"
done
```

### Script para Limpeza de Imagens Antigas

```bash
#!/bin/bash

REGISTRY_NAME="teste-principal-registry"
REPOSITORY_NAME="frontend-app"

# Listar imagens antigas (exemplo: mais de 30 dias)
mgc cr images list \
  --registry-name "$REGISTRY_NAME" \
  --repository-name "$REPOSITORY_NAME" \
  --created-before "$(date -d '30 days ago' --iso-8601)" \
  --format json
```

## Troubleshooting

### Problemas de Autenticação

```bash
# Verificar status da autenticação
mgc auth status

# Renovar token
mgc auth refresh
```

### Problemas de Conectividade

```bash
# Verificar conectividade com a API
mgc cr registries list --debug
```

### Verificar Versão da CLI

```bash
mgc version
```

## Referências

- [Documentação oficial MGC CLI](https://docs.magalu.cloud/cli)
- [Container Registry API Reference](https://docs.magalu.cloud/container-registry)
- [Guia de Autenticação](https://docs.magalu.cloud/authentication)

---

## Notas de Segurança

⚠️ **Credenciais Sensíveis**: Nunca exponha credenciais em logs ou scripts versionados  
🔒 **Autenticação**: Use sempre tokens atualizados e válidos  
🛡️ **Permissões**: Verifique se sua conta tem as permissões necessárias  
📝 **Auditoria**: Mantenha logs de atividades para auditoria de segurança