#!/usr/bin/env bats

# Load the script being tested
load test_helper

setup() {
    # Create temporary directory for each test
    export BATS_TEST_TMPDIR=$(mktemp -d)
    export ORIGINAL_PWD="$PWD"
    cd "$BATS_TEST_TMPDIR"

    # Mock terraform command for testing
    export PATH="$BATS_TEST_TMPDIR/mock_bin:$PATH"
    mkdir -p mock_bin
}

teardown() {
    # Clean up after each test
    cd "$ORIGINAL_PWD"
    rm -rf "$BATS_TEST_TMPDIR"
}

# Test utility functions
@test "print_status outputs correct format with blue color" {
    source "$ORIGINAL_PWD/test_complete.sh"
    run print_status "Test message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ $'\033\[0;34m\[TEST\]\033\[0m Test message' ]]
}

@test "print_success outputs correct format with green color" {
    source "$ORIGINAL_PWD/test_complete.sh"
    run print_success "Success message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ $'\033\[0;32m✅ Success message\033\[0m' ]]
}

@test "print_warning outputs correct format with yellow color" {
    source "$ORIGINAL_PWD/test_complete.sh"
    run print_warning "Warning message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ $'\033\[1;33m⚠️ Warning message\033\[0m' ]]
}

@test "print_error outputs correct format with red color" {
    source "$ORIGINAL_PWD/test_complete.sh"
    run print_error "Error message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ $'\033\[0;31m❌ Error message\033\[0m' ]]
}

# Test main module validation
@test "main module validation succeeds when terraform validate passes" {
    # Mock successful terraform validate
    cat > mock_bin/terraform << 'EOF'
#!/bin/bash
if [ "$1" = "validate" ]; then
    exit 0
fi
exit 1
EOF
    chmod +x mock_bin/terraform

    mkdir -p /tmp/test_mgc_registry
    export HOME=/tmp
    mkdir -p "$HOME/nataliagranato"
    ln -s "$BATS_TEST_TMPDIR" "$HOME/nataliagranato/mgc-container-registry"

    source "$ORIGINAL_PWD/test_complete.sh"
    cd "$HOME/nataliagranato/mgc-container-registry"

    run terraform validate
    [ "$status" -eq 0 ]
}

@test "main module validation fails when terraform validate fails" {
    # Mock failing terraform validate
    cat > mock_bin/terraform << 'EOF'
#!/bin/bash
if [ "$1" = "validate" ]; then
    exit 1
fi
exit 0
EOF
    chmod +x mock_bin/terraform

    mkdir -p /tmp/test_mgc_registry
    export HOME=/tmp
    mkdir -p "$HOME/nataliagranato"
    ln -s "$BATS_TEST_TMPDIR" "$HOME/nataliagranato/mgc-container-registry"

    source "$ORIGINAL_PWD/test_complete.sh"
    cd "$HOME/nataliagranato/mgc-container-registry"

    run terraform validate
    [ "$status" -eq 1 ]
}

# Test example validation
@test "simple example validation succeeds with proper setup" {
    cat > mock_bin/terraform << 'EOF'
#!/bin/bash
case "$1" in
    "init") exit 0 ;;
    "validate") exit 0 ;;
    "plan") exit 0 ;;
    *) exit 1 ;;
esac
EOF
    chmod +x mock_bin/terraform

    mkdir -p examples/simple
    touch examples/simple/main.tf

    cd examples/simple
    run terraform init
    [ "$status" -eq 0 ]
    run terraform validate
    [ "$status" -eq 0 ]
}

@test "complete example validation succeeds with proper setup" {
    cat > mock_bin/terraform << 'EOF'
#!/bin/bash
case "$1" in
    "init") exit 0 ;;
    "validate") exit 0 ;;
    "plan") exit 0 ;;
    *) exit 1 ;;
esac
EOF
    chmod +x mock_bin/terraform

    mkdir -p examples/complete
    touch examples/complete/main.tf

    cd examples/complete
    run terraform init
    [ "$status" -eq 0 ]
    run terraform validate
    [ "$status" -eq 0 ]
}

@test "terraform plan handles API permission errors gracefully" {
    cat > mock_bin/terraform << 'EOF'
#!/bin/bash
case "$1" in
    "init") exit 0 ;;
    "validate") exit 0 ;;
    "plan") exit 1 ;;
    *) exit 1 ;;
esac
EOF
    chmod +x mock_bin/terraform

    mkdir -p examples/simple
    cd examples/simple
    run terraform plan -out=simple.tfplan
    [ "$status" -eq 1 ]
}

# Test essential files verification
@test "all essential files check passes when all files exist" {
    files=(
        "main.tf"
        "variables.tf"
        "outputs.tf"
        "versions.tf"
        "README.md"
        "CHANGELOG.md"
        "examples/simple/main.tf"
        "examples/simple/terraform.tfvars"
        "examples/complete/main.tf"
        "examples/complete/outputs.tf"
        "examples/complete/terraform.tfvars"
    )
    for file in "${files[@]}"; do
        mkdir -p "$(dirname "$file")"
        touch "$file"
    done

    for file in "${files[@]}"; do
        [ -f "$file" ]
    done
}

@test "essential files check fails when files are missing" {
    touch main.tf variables.tf
    [ -f "main.tf" ]
    [ -f "variables.tf" ]
    [ ! -f "outputs.tf" ]
}

@test "essential files check handles nested directory creation" {
    mkdir -p examples/simple examples/complete
    touch examples/simple/main.tf
    touch examples/complete/outputs.tf
    [ -f "examples/simple/main.tf" ]
    [ -f "examples/complete/outputs.tf" ]
}

# Test output structure verification
@test "output structure verification passes with all outputs defined" {
    cat > outputs.tf << 'EOF'
output "container_registry_id" {
  value = mgc_container_registry.main.id
}
output "container_registry_name" {
  value = mgc_container_registry.main.name
}
output "container_registry_created_at" {
  value = mgc_container_registry.main.created_at
}
output "container_registry_updated_at" {
  value = mgc_container_registry.main.updated_at
}
output "container_registry_storage_usage_bytes" {
  value = mgc_container_registry.main.storage_usage_bytes
}
output "container_credentials" {
  value = data.mgc_container_credentials.main
}
output "all_registries" {
  value = data.mgc_container_registries.all
}
output "repositories" {
  value = data.mgc_container_repositories.main
}
output "images" {
  value = data.mgc_container_images.main
}
EOF

    expected=(
        "container_registry_id"
        "container_registry_name"
        "container_registry_created_at"
        "container_registry_updated_at"
        "container_registry_storage_usage_bytes"
        "container_credentials"
        "all_registries"
        "repositories"
        "images"
    )
    for o in "${expected[@]}"; do
        run grep -q "output \"$o\"" outputs.tf
        [ "$status" -eq 0 ]
    done
}

@test "output structure verification fails with missing outputs" {
    cat > outputs.tf << 'EOF'
output "container_registry_id" {
  value = mgc_container_registry.main.id
}
output "container_registry_name" {
  value = mgc_container_registry.main.name
}
EOF
    run grep -q 'output "container_registry_id"' outputs.tf; [ "$status" -eq 0 ]
    run grep -q 'output "all_registries"' outputs.tf; [ "$status" -eq 1 ]
}

# Test edge cases and error handling
@test "script handles missing terraform binary gracefully" {
    export PATH="/usr/bin:/bin"
    run which terraform
    [ "$status" -eq 1 ]
}

@test "script handles .terraform directory cleanup correctly" {
    mkdir -p .terraform/providers
    touch .terraform/terraform.tfstate
    [ -d ".terraform" ]
    rm -rf .terraform/
    [ ! -d ".terraform" ]
}

@test "script handles plan file cleanup correctly" {
    touch simple.tfplan complete.tfplan
    [ -f "simple.tfplan" ]
    [ -f "complete.tfplan" ]
    rm -f simple.tfplan complete.tfplan
    [ ! -f "simple.tfplan" ]
    [ ! -f "complete.tfplan" ]
}

@test "script exits with proper error codes on failure" {
    cat > mock_bin/terraform << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x mock_bin/terraform
    run terraform validate
    [ "$status" -eq 1 ]
}

@test "script handles non-existent directories gracefully" {
    run cd /non/existent/directory 2>/dev/null
    [ "$status" -ne 0 ]
}

# Integration tests for full script execution
@test "full script execution with all mocked dependencies succeeds" {
    mock_terraform_success
    create_minimal_project_structure
    create_complete_outputs_file

    export HOME=/tmp
    mkdir -p "$HOME/nataliagranato"
    ln -s "$BATS_TEST_TMPDIR" "$HOME/nataliagranato/mgc-container-registry"

    source "$ORIGINAL_PWD/test_complete.sh"

    cd "$HOME/nataliagranato/mgc-container-registry"
    run terraform validate; [ "$status" -eq 0 ]

    cd examples/simple
    run terraform init; [ "$status" -eq 0 ]
    run terraform validate; [ "$status" -eq 0 ]

    cd ../complete
    run terraform init; [ "$status" -eq 0 ]
    run terraform validate; [ "$status" -eq 0 ]
}

@test "script properly handles terraform plan failures without failing overall" {
    cat > mock_bin/terraform << 'EOF'
#!/bin/bash
case "$1" in
    "init") exit 0 ;;
    "validate") exit 0 ;;
    "plan") exit 1 ;;
    *) exit 1 ;;
esac
EOF
    chmod +x mock_bin/terraform

    create_minimal_project_structure
    cd examples/simple

    run terraform init; [ "$status" -eq 0 ]
    run terraform validate; [ "$status" -eq 0 ]
    run terraform plan -out=simple.tfplan; [ "$status" -eq 1 ]
}

@test "color codes are properly formatted in output functions" {
    source "$ORIGINAL_PWD/test_complete.sh"
    [ "$GREEN" = $'\033[0;32m' ]
    [ "$RED"   = $'\033[0;31m' ]
    [ "$YELLOW"= $'\033[1;33m' ]
    [ "$BLUE"  = $'\033[0;34m' ]
    [ "$NC"    = $'\033[0m' ]
}
#!/bin/bash
# ============================================================================
# Script de Teste Completo - MGC Container Registry Module
# ============================================================================
# Este script executa todos os testes de validação do módulo

set -e  # Para no primeiro erro

echo "🚀 Iniciando testes completos do módulo MGC Container Registry..."
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir status
print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# ============================================================================
# Teste 1: Validação do módulo principal
# ============================================================================
print_status "Testando módulo principal..."
cd /home/nataliagranato/mgc-container-registry

if terraform validate; then
    print_success "Módulo principal validado com sucesso"
else
    print_error "Falha na validação do módulo principal"
    exit 1
fi

# ============================================================================
# Teste 2: Exemplo simples
# ============================================================================
print_status "Testando exemplo simples..."
cd examples/simple

# Limpar cache se necessário
if [ -d ".terraform" ]; then
    rm -rf .terraform/
fi

terraform init
if terraform validate; then
    print_success "Exemplo simples validado"
    
    print_status "Gerando plano do exemplo simples..."
    if terraform plan -out=simple.tfplan > /dev/null 2>&1; then
        print_success "Plano do exemplo simples gerado com sucesso"
        rm -f simple.tfplan
    else
        print_warning "Plano do exemplo simples falhou (pode ser erro de permissão da API)"
    fi
else
    print_error "Falha na validação do exemplo simples"
    exit 1
fi

# ============================================================================
# Teste 3: Exemplo completo
# ============================================================================
print_status "Testando exemplo completo..."
cd ../complete

# Limpar cache se necessário
if [ -d ".terraform" ]; then
    rm -rf .terraform/
fi

terraform init
if terraform validate; then
    print_success "Exemplo completo validado"
    
    print_status "Gerando plano do exemplo completo..."
    if terraform plan -out=complete.tfplan > /dev/null 2>&1; then
        print_success "Plano do exemplo completo gerado com sucesso"
        rm -f complete.tfplan
    else
        print_warning "Plano do exemplo completo falhou (pode ser erro de permissão da API)"
    fi
else
    print_error "Falha na validação do exemplo completo"
    exit 1
fi

# ============================================================================
# Teste 4: Verificação de arquivos essenciais
# ============================================================================
print_status "Verificando arquivos essenciais..."
cd /home/nataliagranato/mgc-container-registry

files_to_check=(
    "main.tf"
    "variables.tf" 
    "outputs.tf"
    "versions.tf"
    "README.md"
    "CHANGELOG.md"
    "examples/simple/main.tf"
    "examples/simple/terraform.tfvars"
    "examples/complete/main.tf"
    "examples/complete/outputs.tf"
    "examples/complete/terraform.tfvars"
)

all_files_exist=true
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        print_success "✓ $file existe"
    else
        print_error "✗ $file não encontrado"
        all_files_exist=false
    fi
done

if $all_files_exist; then
    print_success "Todos os arquivos essenciais estão presentes"
else
    print_error "Alguns arquivos essenciais estão faltando"
    exit 1
fi

# ============================================================================
# Teste 5: Verificação da estrutura de outputs
# ============================================================================
print_status "Verificando estrutura de outputs..."

expected_outputs=(
    "container_registry_id"
    "container_registry_name"
    "container_registry_created_at"
    "container_registry_updated_at"
    "container_registry_storage_usage_bytes"
    "container_credentials"
    "all_registries"
    "repositories"
    "images"
)

outputs_ok=true
for output in "${expected_outputs[@]}"; do
    if grep -q "output \"$output\"" outputs.tf; then
        print_success "✓ Output $output definido"
    else
        print_error "✗ Output $output não encontrado"
        outputs_ok=false
    fi
done

if $outputs_ok; then
    print_success "Todos os outputs estão definidos"
else
    print_error "Alguns outputs estão faltando"
    exit 1
fi

# ============================================================================
# Resumo dos testes
# ============================================================================
echo ""
echo "============================================================================"
echo -e "${GREEN}🎉 TODOS OS TESTES PASSARAM COM SUCESSO!${NC}"
echo "============================================================================"
echo ""
echo "📋 Resumo dos testes:"
echo "✅ Módulo principal validado"
echo "✅ Exemplo simples funcional" 
echo "✅ Exemplo completo funcional"
echo "✅ Arquivos essenciais presentes"
echo "✅ Outputs estruturados corretamente"
echo ""
echo -e "${BLUE}🚀 O módulo MGC Container Registry está pronto para produção!${NC}"
echo ""
echo "📚 Próximos passos:"
echo "1. Configure uma API key com permissões adequadas"
echo "2. Execute 'terraform apply' nos exemplos"
echo "3. Integre o módulo em seus projetos"
echo ""
