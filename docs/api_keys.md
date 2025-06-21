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

⚠️ **Importante:** Nunca commite o arquivo `terraform.tfvars` com API keys para repositórios públicos!

## Provisionamento Local

Após configurar suas credenciais, você pode provisionar o módulo localmente usando os seguintes comandos:

### 1. Inicializar o Terraform

```bash
terraform init
```

Este comando baixa os providers necessários e inicializa o backend do Terraform.

### 2. Planejar a Infraestrutura

```bash
terraform plan -var-file="terraform.tfvars"
```

Este comando mostra quais recursos serão criados, modificados ou destruídos sem fazer alterações reais.

### 3. Aplicar as Mudanças

```bash
terraform apply -var-file="terraform.tfvars"
```

Este comando provisiona os recursos na Magalu Cloud. Será solicitada confirmação antes de aplicar.

### 4. Destruir a Infraestrutura (quando necessário)

```bash
terraform destroy -var-file="terraform.tfvars"
```

Este comando remove todos os recursos criados pelo Terraform. Use com cuidado!

### Exemplo Completo de Workflow

```bash
# 1. Clonar o repositório
git clone https://github.com/nataliagranato/mgc-container-registry.git
cd mgc-container-registry

# 2. Configurar credenciais
export TF_VAR_mgc_api_key="<SUA_API_KEY>"

# 3. Criar arquivo de variáveis (opcional)
cat > terraform.tfvars << EOF
mgc_api_key = "<SUA_API_KEY>"
container_registry_name = "meu-registry-teste"
enable_credentials_output = true
EOF

# 4. Executar Terraform
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# 5. Verificar outputs
terraform output

# 6. Limpar recursos (quando terminar)
terraform destroy -var-file="terraform.tfvars"
```

### Dicas de Uso

- **Sempre execute `terraform plan`** antes de `apply` para revisar mudanças
- **Use `-auto-approve`** apenas em automações: `terraform apply -var-file="terraform.tfvars" -auto-approve`
- **Mantenha o estado** do Terraform em local seguro ou use backend remoto
- **Faça backup** do arquivo `terraform.tfstate` regularmente

## Comandos Terraform Detalhados

### Provisionamento do Root Module

```bash
# No diretório raiz do módulo
cd /home/nataliagranato/mgc-container-registry

# Inicializar
terraform init

# Planejar (revisão das mudanças)
terraform plan -var-file="terraform.tfvars"

# Aplicar configuração
terraform apply -var-file="terraform.tfvars"

# Ver outputs
terraform output

# Destruir quando necessário
terraform destroy -var-file="terraform.tfvars"
```

### Provisionamento do Exemplo Simples

```bash
# Navegar para o exemplo simples
cd /home/nataliagranato/mgc-container-registry/examples/simple

# Inicializar
terraform init

# Planejar
terraform plan -var-file="terraform.tfvars"

# Aplicar
terraform apply -var-file="terraform.tfvars"

# Ver outputs
terraform output

# Destruir
terraform destroy -var-file="terraform.tfvars"
```

### Provisionamento do Exemplo Completo (3 Registries)

```bash
# Navegar para o exemplo completo
cd /home/nataliagranato/mgc-container-registry/examples/complete

# Inicializar
terraform init

# Planejar (mostra criação de 3 registries)
terraform plan -var-file="terraform.tfvars"

# Aplicar (cria dev, prod e monitoring registries)
terraform apply -var-file="terraform.tfvars"

# Ver todos os outputs detalhados
terraform output

# Ver output específico
terraform output registry_details

# Destruir todos os 3 registries
terraform destroy -var-file="terraform.tfvars"
```

### Comandos Avançados

#### Verificar Configuração Específica

```bash
# Validar sintaxe do Terraform
terraform validate

# Formatar arquivos .tf
terraform fmt

# Ver estado atual
terraform show

# Listar recursos no estado
terraform state list

# Ver detalhes de um recurso específico
terraform state show 'mgc_container_registries.main'
```

#### Importar Recursos Existentes

```bash
# Importar registry existente para o estado
terraform import mgc_container_registries.main <registry-id>
```

#### Gerenciamento de Estado

```bash
# Fazer backup do estado
cp terraform.tfstate terraform.tfstate.backup

# Atualizar estado com recursos reais
terraform refresh

# Mover recurso no estado
terraform state mv 'mgc_container_registries.old' 'mgc_container_registries.new'
```

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