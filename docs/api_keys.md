# Obtendo API Keys da Magalu Cloud

Este guia explica como obter e configurar corretamente as credenciais da Magalu Cloud para usar com este módulo Terraform.

## Pré-requisitos

- Conta ativa na Magalu Cloud
- MGC CLI instalada ([Guia de instalação](https://docs.magalu.cloud/cli/installation))
- Permissões adequadas para Container Registry

## Passo a Passo

### 1. Fazer Login na CLI

```bash
mgc auth login
```

Este comando abrirá automaticamente seu navegador para autenticação. Se o navegador não abrir automaticamente, você verá uma URL no terminal que deve ser acessada manualmente.

### 2. Listar API Keys Disponíveis

Após o login bem-sucedido, liste suas API keys existentes:

```bash
mgc auth api-key list
```

**Exemplo de saída:**
```yaml
- id: <SEU_ID_DA_API_KEY>
  name: minha-api-key
  description: Portal
```

### 3. Obter Detalhes da API Key

Escolha uma API key da lista (recomenda-se usar uma específica para automação) e obtenha seus detalhes:

```bash
mgc auth api-key get <SEU_ID_DA_API_KEY>
```

**Exemplo de saída:**
```yaml
api_key: <SUA_API_KEY>
id: <SEU_ID_DA_API_KEY>
key_pair_id: <SEU_ID_DO_KEY_PAIR>
key_pair_secret: <SEU_SECRET_DO_KEY_PAIR>
name: nataliagranato
scopes:
  - container_registry:read
  - container_registry:write
  - container_registry:admin
created_at: "2025-05-23T10:30:00Z"
expires_at: "2026-05-23T10:30:00Z"
```

### 4. Configurar Variáveis de Ambiente

#### Para uso temporário (sessão atual):

```bash
export TF_VAR_mgc_api_key=<SUA_API_KEY>
```

#### Para uso permanente, adicione ao seu `~/.zshrc`:

```bash
echo 'export TF_VAR_mgc_api_key=<SUA_API_KEY>' >> ~/.zshrc
source ~/.zshrc
```

### 5. Verificar Configuração

Teste se a API key está funcionando:

```bash
# Verificar se a variável está definida
echo $TF_VAR_mgc_api_key

# Testar conectividade
mgc cr registries list
```

## Configuração do Terraform

### Opção 1: Usar Variável de Ambiente (Recomendado)

```hcl
module "container_registry" {
  source = "github.com/nataliagranato/mgc-container-registry"
  
  # A variável TF_VAR_mgc_api_key será usada automaticamente
  container_registry_name = "meu-registry"
}
```

### Opção 2: Definir Explicitamente

```hcl
module "container_registry" {
  source = "github.com/nataliagranato/mgc-container-registry"

  mgc_api_key             = "<SUA_API_KEY>"
  container_registry_name = "meu-registry"
}
```

### Opção 3: Usar terraform.tfvars

Crie um arquivo `terraform.tfvars`:

```hcl
mgc_api_key = "<SUA_API_KEY>"
```

⚠️ **Importante:** Nunca commitez o arquivo `terraform.tfvars` com API keys para repositórios públicos!

## Criação de Nova API Key (Opcional)

Se você preferir criar uma API key específica para Terraform:

### 1. Criar Nova API Key

```bash
mgc auth api-key create \
  --name "terraform-container-registry" \
  --description "API key para automação Terraform do Container Registry"
```

### 2. Configurar Permissões

Certifique-se de que a API key tenha as seguintes permissões:

- ✅ `container_registry:read` - Para listar registries, repositórios e imagens
- ✅ `container_registry:write` - Para criar e modificar registries
- ✅ `container_registry:admin` - Para gerenciar credenciais (se necessário)

### 3. Obter Detalhes da Nova Key

```bash
mgc auth api-key get <novo-id-da-api-key>
```

## Boas Práticas de Segurança

### 🔒 Gerenciamento Seguro

1. **Rotação Regular**: Renove API keys periodicamente
2. **Princípio de Menor Privilégio**: Use apenas as permissões necessárias
3. **Separação de Ambientes**: Use keys diferentes para dev/prod
4. **Monitoramento**: Monitore o uso das API keys

### 🛡️ Armazenamento Seguro

- ✅ **Use variáveis de ambiente**
- ✅ **Use sistemas de gerenciamento de secrets (AWS Secrets Manager, Azure Key Vault, etc.)**
- ✅ **Use o arquivo .env (com .gitignore)**
- ❌ **Nunca hardcode no código**
- ❌ **Nunca commite em repositórios**

### 🔍 Exemplo de Configuração para CI/CD

#### GitHub Actions

```yaml
name: Terraform Deploy
on: [push]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      - name: Terraform Apply
        env:
          TF_VAR_mgc_api_key: ${{ secrets.MGC_API_KEY }}
        run: |
          terraform init
          terraform apply -auto-approve
```

#### GitLab CI

```yaml
deploy:
  script:
    - export TF_VAR_mgc_api_key=$MGC_API_KEY
    - terraform init
    - terraform apply -auto-approve
  variables:
    MGC_API_KEY: $MGC_API_KEY_SECRET
```

## Troubleshooting

### Erro: "API key inválida"

```bash
# Verificar se a key está correta
echo $TF_VAR_mgc_api_key

# Testar conectividade
mgc auth api-key get <id-da-key>
```

### Erro: "Permissões insuficientes"

```bash
# Verificar escopos da API key
mgc auth api-key get <id-da-key> | grep -A 10 scopes
```

### Erro: "Key expirada"

```bash
# Verificar data de expiração
mgc auth api-key get <id-da-key> | grep expires_at

# Renovar se necessário
mgc auth api-key renew <id-da-key>
```

## Referências

- [Documentação oficial MGC CLI](https://docs.magalu.cloud/docs/devops-tools/cli-mgc/overview)
- [Gerenciamento de API Keys](https://docs.magalu.cloud/docs/devops-tools/api-keys/overview)
- [Variáveis de Ambiente](https://docs.magalu.cloud/docs/devops-tools/general/env-variables)

---

## ⚠️ Aviso de Segurança

**NUNCA** exponha suas API keys em:
- Código fonte versionado
- Logs de aplicação
- URLs ou query parameters
- Documentação pública
- Screenshots ou vídeos

Sempre use métodos seguros de armazenamento e transmissão de credenciais.