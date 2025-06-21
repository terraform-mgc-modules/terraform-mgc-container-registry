#!/usr/bin/env bash

# Terraform Validation Test Suite
#
# This script provides comprehensive testing for Terraform validation functionality.
# It tests various scenarios including:
# - Basic validation of valid/invalid configurations
# - Formatting checks and fixes
# - Different file types (.tf, .tf.json)
# - Variables and outputs
# - Edge cases and error conditions
# - Performance with large configurations
#
# Testing Framework: Custom shell-based testing (no external dependencies)
# Usage: ./test_terraform_validation.sh [OPTIONS]
#
# Requirements:
# - Terraform CLI installed and available in PATH
# - Bash shell (version 4+ recommended)
# - Standard Unix utilities (mktemp, chmod, grep, etc.)

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Global test counters
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    TEST_COUNT=$((TEST_COUNT + 1))
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Expected: '$expected'"
        echo -e "  Actual:   '$actual'"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_true() {
    local condition="$1"
    local message="$2"

    TEST_COUNT=$((TEST_COUNT + 1))
    if [ "$condition" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_false() {
    local condition="$1"
    local message="$2"

    TEST_COUNT=$((TEST_COUNT + 1))
    if [ "$condition" -ne 0 ]; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    TEST_COUNT=$((TEST_COUNT + 1))
    if echo "$haystack" | grep -q "$needle"; then
        echo -e "${GREEN}✓ PASS:${NC} $message"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ FAIL:${NC} $message"
        echo -e "  Expected '$haystack' to contain '$needle'"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Global test directory variable
TEST_DIR=""

# Setup function to create test directories and files
setup_test_env() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"

    # Create a basic valid Terraform configuration
    cat > main.tf << 'EOF'
terraform {
  required_version = ">= 0.12"
}

resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "echo 'Hello from Terraform'"
  }
}
EOF

    # Create an invalid Terraform configuration
    cat > invalid.tf << 'EOF'
resource "invalid_resource_type" "test" {
  invalid_argument = "value"
  missing_required_field
}
EOF

    # Create Terraform configuration with syntax errors
    cat > syntax_error.tf << 'EOF'
resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "echo hello"
  }
  # Missing closing brace
EOF

    # Create poorly formatted Terraform file
    cat > unformatted.tf << 'EOF'
resource "null_resource" "test"   {
provisioner   "local-exec"    {
command="echo hello"
}
}
EOF
}

# Cleanup function
cleanup_test_env() {
    if [ -n "${TEST_DIR:-}" ] && [ -d "$TEST_DIR" ]; then
        cd - > /dev/null 2>&1 || true
        rm -rf "$TEST_DIR"
        TEST_DIR=""
    fi
}

# Error handling trap
trap 'echo -e "${RED}ERROR:${NC} Test execution failed"; cleanup_test_env 2>/dev/null || true; exit 1' ERR

# Test terraform version and availability
test_terraform_prerequisites() {
    echo -e "${BLUE}=== Testing Terraform Prerequisites ===${NC}"

    # Check if terraform is available
    command -v terraform > /dev/null 2>&1
    assert_true $? "Terraform command should be available in PATH"

    # Test version output
    terraform version > /dev/null 2>&1
    assert_true $? "Terraform version command should succeed"

    # Verify version format (basic check)
    version_output=$(terraform version | head -n1)
    assert_contains "$version_output" "Terraform v" "Terraform version should contain 'Terraform v'"

    echo
}

# Test terraform init functionality
test_terraform_init() {
    echo -e "${BLUE}=== Testing Terraform Init ===${NC}"
    setup_test_env

    # Test successful init with valid configuration
    terraform init -backend=false > /dev/null 2>&1
    assert_true $? "Terraform init should succeed with valid configuration"

    # Verify .terraform directory was created
    [ -d ".terraform" ]
    assert_true $? "Terraform init should create .terraform directory"

    # Test init with no configuration files
    rm -f *.tf
    terraform init -backend=false > /dev/null 2>&1
    # Init may succeed even without .tf files

    cleanup_test_env
    echo
}

# Test terraform validate functionality
test_terraform_validate() {
    echo -e "${BLUE}=== Testing Terraform Validate ===${NC}"
    setup_test_env

    terraform init -backend=false > /dev/null 2>&1

    # Valid configuration
    terraform validate > /dev/null 2>&1
    assert_true $? "Terraform validate should pass for valid configuration"

    # JSON output
    json_output=$(terraform validate -json 2>/dev/null || echo '{}')
    assert_contains "$json_output" "valid" "JSON validation output should indicate validity"

    # Mixed valid/invalid files
    terraform validate . > /dev/null 2>&1
    assert_false $? "Terraform validate should fail with invalid files present"

    # Specific valid file
    terraform validate main.tf > /dev/null 2>&1
    assert_true $? "Terraform validate should pass for specific valid file"

    cleanup_test_env
    echo
}

# Test terraform fmt functionality
test_terraform_fmt() {
    echo -e "${BLUE}=== Testing Terraform Format ===${NC}"
    setup_test_env

    terraform fmt -check unformatted.tf > /dev/null 2>&1
    assert_false $? "Terraform fmt -check should fail for unformatted files"

    terraform fmt unformatted.tf > /dev/null 2>&1
    assert_true $? "Terraform fmt should succeed in formatting files"

    terraform fmt -check unformatted.tf > /dev/null 2>&1
    assert_true $? "Terraform fmt -check should pass after formatting"

    terraform fmt -diff unformatted.tf > /dev/null 2>&1
    assert_true $? "Terraform fmt -diff should work"

    terraform fmt -recursive . > /dev/null 2>&1
    assert_true $? "Terraform fmt -recursive should work on directory"

    cleanup_test_env
    echo
}

# Test different Terraform file types and configurations
test_terraform_file_types() {
    echo -e "${BLUE}=== Testing Different File Types ===${NC}"
    setup_test_env

    cat > config.tf.json << 'EOF'
{
  "terraform": {
    "required_version": ">= 0.12"
  },
  "resource": {
    "null_resource": {
      "json_test": {
        "provisioner": {
          "local-exec": {
            "command": "echo 'JSON config'"
          }
        }
      }
    }
  }
}
EOF

    terraform init -backend=false > /dev/null 2>&1
    terraform validate config.tf.json > /dev/null 2>&1
    assert_true $? "Should validate .tf.json files"

    terraform validate . > /dev/null 2>&1
    # May fail due to invalid.tf and syntax_error.tf

    rm -f invalid.tf syntax_error.tf
    terraform validate . > /dev/null 2>&1
    assert_true $? "Should validate directory with mixed valid file types"

    cleanup_test_env
    echo
}

# Test terraform configuration with variables and outputs
test_terraform_variables_outputs() {
    echo -e "${BLUE}=== Testing Variables and Outputs ===${NC}"
    setup_test_env

    cat > variables.tf << 'EOF'
variable "test_var" {
  description = "Test variable"
  type        = string
  default     = "test_value"
}

variable "number_var" {
  description = "Number variable"
  type        = number
  default     = 42
}

variable "list_var" {
  description = "List variable"
  type        = list(string)
  default     = ["item1", "item2"]
}
EOF

    cat > outputs.tf << 'EOF'
output "test_output" {
  description = "Test output"
  value       = var.test_var
}

output "computed_output" {
  description = "Computed output"
  value       = "\${var.test_var}-\${var.number_var}"
}

output "list_output" {
  description = "List output"
  value       = var.list_var
}
EOF

    cat > main.tf << 'EOF'
terraform {
  required_version = ">= 0.12"
}

resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "echo \${var.test_var}"
  }
}
EOF

    terraform init -backend=false > /dev/null 2>&1
    terraform validate > /dev/null 2>&1
    assert_true $? "Should validate configuration with variables and outputs"

    cleanup_test_env
    echo
}

# Test terraform modules
test_terraform_modules() {
    echo -e "${BLUE}=== Testing Terraform Modules ===${NC}"
    setup_test_env

    mkdir -p modules/test_module
    cat > modules/test_module/main.tf << 'EOF'
variable "input_var" {
  description = "Input variable for module"
  type        = string
}

resource "null_resource" "module_resource" {
  provisioner "local-exec" {
    command = "echo \${var.input_var}"
  }
}

output "module_output" {
  value = var.input_var
}
EOF

    cat > main.tf << 'EOF'
terraform {
  required_version = ">= 0.12"
}

module "test" {
  source    = "./modules/test_module"
  input_var = "module_test"
}
EOF

    terraform init -backend=false > /dev/null 2>&1
    terraform validate > /dev/null 2>&1
    assert_true $? "Should validate configuration with local modules"

    cleanup_test_env
    echo
}

# Test Terraform-specific syntax and validation rules
test_terraform_syntax_validation() {
    echo -e "${BLUE}=== Testing Terraform Syntax Validation ===${NC}"
    setup_test_env

    cat > duplicate_resources.tf << 'EOF'
resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "echo first"
  }
}

resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "echo second"
  }
}
EOF

    terraform init -backend=false > /dev/null 2>&1
    terraform validate duplicate_resources.tf > /dev/null 2>&1
    assert_false $? "Should fail validation with duplicate resource names"

    cat > invalid_interpolation.tf << 'EOF'
resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "\${invalid.reference}"
  }
}
EOF

    terraform validate invalid_interpolation.tf > /dev/null 2>&1
    assert_false $? "Should fail validation with invalid variable references"

    cat > complex_valid.tf << 'EOF'
terraform {
  required_version = ">= 0.12"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = "test-project"
  }
}

resource "null_resource" "complex" {
  count = var.environment == "prod" ? 2 : 1

  provisioner "local-exec" {
    command = "echo 'Resource \${count.index} in \${var.environment}'"
  }

  triggers = {
    environment = var.environment
    timestamp   = timestamp()
  }
}

output "resource_count" {
  value = length(null_resource.complex)
}
EOF

    terraform init -backend=false > /dev/null 2>&1
    terraform validate complex_valid.tf > /dev/null 2>&1
    assert_true $? "Should validate complex but correct configuration"

    cleanup_test_env
    echo
}

# Test provider-specific validation
test_terraform_provider_validation() {
    echo -e "${BLUE}=== Testing Provider Validation ===${NC}"
    setup_test_env

    cat > provider_config.tf << 'EOF'
terraform {
  required_version = ">= 0.12"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "null" {}

resource "null_resource" "with_provider" {
  provisioner "local-exec" {
    command = "echo 'Using null provider'"
  }
}
EOF

    terraform init -backend=false > /dev/null 2>&1
    terraform validate > /dev/null 2>&1
    assert_true $? "Should validate configuration with provider requirements"

    cat > invalid_provider.tf << 'EOF'
terraform {
  required_version = ">= 0.12"
}

resource "nonexistent_provider_resource" "test" {
  invalid_argument = "value"
}
EOF

    terraform validate invalid_provider.tf > /dev/null 2>&1
    assert_false $? "Should fail validation with nonexistent provider resources"

    cleanup_test_env
    echo
}

# Test edge cases and error conditions
test_terraform_edge_cases() {
    echo -e "${BLUE}=== Testing Edge Cases ===${NC}"

    # Empty directory
    empty_dir=$(mktemp -d)
    cd "$empty_dir"
    terraform validate > /dev/null 2>&1
    assert_false $? "Terraform validate should fail in empty directory"
    cd - > /dev/null
    rm -rf "$empty_dir"

    # Only non-tf files
    non_tf_dir=$(mktemp -d)
    cd "$non_tf_dir"
    echo "not terraform" > readme.txt
    echo "still not terraform" > config.yml
    terraform validate > /dev/null 2>&1
    assert_false $? "Terraform validate should fail with no .tf files"
    cd - > /dev/null
    rm -rf "$non_tf_dir"

    # Malformed JSON
    json_dir=$(mktemp -d)
    cd "$json_dir"
    cat > malformed.tf.json << 'EOF'
{
  "resource": {
    "null_resource": {
      "test": {
        "invalid": "json"
      }
    }
  }
  // Missing closing brace
EOF
    terraform validate > /dev/null 2>&1
    assert_false $? "Terraform validate should fail with malformed JSON"
    cd - > /dev/null
    rm -rf "$json_dir"

    # Very long file names
    long_name_dir=$(mktemp -d)
    cd "$long_name_dir"
    long_name="a$(printf 'b%.0s' {1..100}).tf"
    if touch "$long_name" 2>/dev/null; then
        echo 'resource "null_resource" "test" {}' > "$long_name"
        terraform validate > /dev/null 2>&1
        assert_true $? "Should handle files with very long names"
    fi
    cd - > /dev/null
    rm -rf "$long_name_dir"

    echo
}

# Test permission and access issues
test_terraform_permissions() {
    echo -e "${BLUE}=== Testing Permission Issues ===${NC}"

    if [ "$(id -u)" -ne 0 ]; then
        readonly_dir=$(mktemp -d)
        cd "$readonly_dir"
        echo 'resource "null_resource" "test" {}' > main.tf

        chmod 444 main.tf
        chmod 555 .

        terraform validate > /dev/null 2>&1
        result=$?

        chmod 755 .
        chmod 644 main.tf
        cd - > /dev/null
        rm -rf "$readonly_dir"

        echo -e "${YELLOW}INFO:${NC} Read-only directory test completed (result: $result)"
    else
        echo -e "${YELLOW}SKIP:${NC} Permission tests skipped (running as root)"
    fi

    echo
}

# Test performance with large configurations
test_terraform_performance() {
    echo -e "${BLUE}=== Testing Performance ===${NC}"
    setup_test_env

    cat > large_config.tf << 'EOF'
terraform {
  required_version = ">= 0.12"
}
EOF

    for i in $(seq 1 50); do
        cat >> large_config.tf << EOF
resource "null_resource" "test_$i" {
  provisioner "local-exec" {
    command = "echo test_$i"
  }
}
EOF
    done

    start_time=$(date +%s)
    terraform init -backend=false > /dev/null 2>&1
    terraform validate > /dev/null 2>&1
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    assert_true $? "Should validate large configuration"

    if [ $duration -lt 60 ]; then
        echo -e "${GREEN}✓ PASS:${NC} Performance test - validation completed in ${duration}s"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}✗ FAIL:${NC} Performance test - validation took too long (${duration}s)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    TEST_COUNT=$((TEST_COUNT + 1))

    cleanup_test_env
    echo
}

# Test runner function that executes all test suites
run_all_tests() {
    echo -e "${YELLOW}========================================"
    echo -e "  Terraform Validation Test Suite"
    echo -e "========================================"
    echo -e "Testing Framework: Custom shell-based${NC}"
    echo

    # Prerequisites
    echo -e "${BLUE}Checking prerequisites...${NC}"
    if ! command -v terraform > /dev/null 2>&1; then
        echo -e "${RED}ERROR:${NC} Terraform is not installed or not in PATH"
        echo -e "${YELLOW}Please install Terraform CLI to run these tests${NC}"
        exit 1
    fi
    version_output=$(terraform version | head -n1)
    echo -e "${GREEN}Found:${NC} $version_output"
    echo

    test_terraform_prerequisites
    test_terraform_init
    test_terraform_validate
    test_terraform_fmt
    test_terraform_file_types
    test_terraform_variables_outputs
    test_terraform_modules
    test_terraform_syntax_validation
    test_terraform_provider_validation
    test_terraform_edge_cases
    test_terraform_permissions
    test_terraform_performance

    echo -e "${YELLOW}========================================"
    echo -e "           Test Summary"
    echo -e "========================================${NC}"
    echo "Total tests executed: $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"

    if [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${GREEN}"
        echo "🎉 All tests passed successfully!"
        echo -e "Terraform validation functionality is working correctly.${NC}"
        exit 0
    else
        echo -e "${RED}"
        echo "❌ Some tests failed!"
        echo -e "Please review the failed tests above.${NC}"
        exit 1
    fi
}

# Help function
show_help() {
    cat << EOF
Terraform Validation Test Suite

This script provides comprehensive testing for Terraform validation functionality.

Usage: $0 [OPTIONS]

Options:
    -h, --help     Show this help message
    -v, --verbose  Enable verbose output (set DEBUG=1)
    --version      Show version information

Test Categories:
    - Prerequisites: Terraform CLI availability and version
    - Init: terraform init functionality
    - Validate: terraform validate with various scenarios
    - Format: terraform fmt functionality
    - File Types: Support for .tf and .tf.json files
    - Variables/Outputs: Variable and output validation
    - Modules: Local module validation
    - Syntax: Terraform-specific syntax rules
    - Providers: Provider configuration validation
    - Edge Cases: Error conditions and unusual scenarios
    - Permissions: File permission handling
    - Performance: Large configuration handling

Requirements:
    - Terraform CLI installed and available in PATH
    - Bash shell (version 4+ recommended)
    - Standard Unix utilities (mktemp, chmod, etc.)

Examples:
    $0                    # Run all tests
    DEBUG=1 $0            # Run with verbose output
    $0 --help             # Show this help

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)   show_help; exit 0 ;;
        -v|--verbose) export DEBUG=1 ;;
        --version)   echo "Terraform Validation Test Suite v1.0.0"; exit 0 ;;
        *)           echo -e "${RED}ERROR:${NC} Unknown option: $1"; echo "Use --help for usage information"; exit 1 ;;
    esac
    shift
done

# Enable debug mode if requested
if [ "${DEBUG:-}" = "1" ]; then
    set -x
    echo -e "${YELLOW}DEBUG mode enabled${NC}"
fi

# Ensure cleanup happens on exit
trap 'cleanup_test_env 2>/dev/null || true' EXIT

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi