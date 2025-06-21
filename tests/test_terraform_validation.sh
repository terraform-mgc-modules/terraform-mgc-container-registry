#!/usr/bin/env bats
#
# tests/test_terraform_validation.bats
#
# BATS tests for the terraform_validation.sh script
# To run: install BATS and execute:
#   bats tests/test_terraform_validation.bats
#

# Path to the script under test (assumes it lives in project root)
SCRIPT="${BATS_TEST_DIRNAME}/../terraform_validation.sh"

setup() {
  # Prepare isolated temp directories for mocks and test files
  TMPDIR="$(mktemp -d)"
  TESTDIR="$(mktemp -d)"
  export PATH="$TMPDIR:$PATH"
}

teardown() {
  # Clean up all temporary artifacts
  rm -rf "$TMPDIR" "$TESTDIR"
}

# Helper: write content to a terraform file and echo its path
create_tf_file() {
  local name="$1"; shift
  local content="$*"
  local path="$TESTDIR/$name"
  echo -e "$content" > "$path"
  echo "$path"
}

# Helper: mock terraform CLI to simulate a successful validation
mock_terraform_success() {
  cat << 'EOF' > "$TMPDIR/terraform"
#!/usr/bin/env bash
echo "Terraform validation succeeded"
exit 0
EOF
  chmod +x "$TMPDIR/terraform"
}

# Helper: mock terraform CLI to simulate a generic configuration error
mock_terraform_failure() {
  cat << 'EOF' > "$TMPDIR/terraform"
#!/usr/bin/env bash
echo "Error: Invalid configuration" >&2
exit 1
EOF
  chmod +x "$TMPDIR/terraform"
}

# Helper: mock terraform CLI to simulate a syntax/parse error
mock_terraform_parse_error() {
  cat << 'EOF' > "$TMPDIR/terraform"
#!/usr/bin/env bash
echo "Error: Syntax error in configuration" >&2
exit 1
EOF
  chmod +x "$TMPDIR/terraform"
}

@test "successful terraform validation" {
  mock_terraform_success
  tf="$(create_tf_file main.tf 'resource \"null_resource\" \"test\" {}')"
  run bash "$SCRIPT" "$tf"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Terraform validation succeeded" ]]
}

@test "failed terraform validation reports error message" {
  mock_terraform_failure
  tf="$(create_tf_file invalid.tf 'resource { missing brace')"
  run bash "$SCRIPT" "$tf"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Invalid configuration" ]]
}

@test "parse errors are caught and reported" {
  mock_terraform_parse_error
  tf="$(create_tf_file parse.tf 'this is not valid HCL')"
  run bash "$SCRIPT" "$tf"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Syntax error" ]]
}

@test "no arguments prints usage and exits non-zero" {
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "non-existent file returns file not found error" {
  mock_terraform_success
  run bash "$SCRIPT" "$TESTDIR/nonexistent.tf"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Error: File not found" ]]
}

@test "permission denied on terraform file" {
  mock_terraform_success
  tf="$(create_tf_file restricted.tf 'resource \"null_resource\" {}')"
  chmod 000 "$tf"
  run bash "$SCRIPT" "$tf"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Permission denied" ]]
}

@test "empty terraform file is treated as syntax error" {
  mock_terraform_parse_error
  tf="$(create_tf_file empty.tf '')"
  run bash "$SCRIPT" "$tf"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "Syntax error" ]]
}

@test "large terraform file handling" {
  mock_terraform_success
  # Generate a large file by repeating a valid block many times
  for i in {1..5000}; do
    echo 'resource "null_resource" "large" {}' >> "$TESTDIR/large.tf"
  done
  run bash "$SCRIPT" "$TESTDIR/large.tf"
  [ "$status" -eq 0 ]
}

@test "sequential runs do not conflict with temp artifacts" {
  mock_terraform_success
  tf="$(create_tf_file repeat.tf 'resource \"null_resource\" {}\')"
  run bash "$SCRIPT" "$tf"
  [ "$status" -eq 0 ]
  run bash "$SCRIPT" "$tf"
  [ "$status" -eq 0 ]
}

@test "help flag displays usage and exits zero" {
  run bash "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "integration with real terraform CLI if available" {
  if ! command -v terraform >/dev/null; then
    skip "terraform CLI not installed"
  fi
  # Create a minimal real Terraform configuration
  cat << 'HCL' > "$TESTDIR/real.tf"
provider "null" {}
resource "null_resource" "example" {}
HCL
  run bash "$SCRIPT" "$TESTDIR/real.tf"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Terraform validation succeeded" ]]
}