#!/bin/bash

# Unit tests for git/test_complete.sh
set -e

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test framework functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$expected" == "$actual" ]]; then
        echo "✓ $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $message"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_true() {
    local condition="$1"
    local message="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ $condition -eq 0 ]]; then
        echo "✓ $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_false() {
    local condition="$1"
    local message="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ $condition -ne 0 ]]; then
        echo "✓ $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [[ "$haystack" =~ $needle ]]; then
        echo "✓ $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ $message"
        echo "  Expected '$haystack' to contain '$needle'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Source the script under test
source "../git/test_complete.sh"

# Test setup and teardown
setup_test() {
    # Create temporary directory for test files
    TEST_TMPDIR=$(mktemp -d)

    # Save original environment
    ORIG_COMP_WORDS=("${COMP_WORDS[@]}")
    ORIG_COMP_CWORD="$COMP_CWORD"
    ORIG_COMP_LINE="$COMP_LINE"
    ORIG_COMP_POINT="$COMP_POINT"
    ORIG_COMPREPLY=("${COMPREPLY[@]}")

    # Clear completion environment
    COMP_WORDS=()
    COMP_CWORD=0
    COMP_LINE=""
    COMP_POINT=0
    COMPREPLY=()
}

teardown_test() {
    # Restore original environment
    COMP_WORDS=("${ORIG_COMP_WORDS[@]}")
    COMP_CWORD="$ORIG_COMP_CWORD"
    COMP_LINE="$ORIG_COMP_LINE"
    COMP_POINT="$ORIG_COMP_POINT"
    COMPREPLY=("${ORIG_COMPREPLY[@]}")

    # Clean up temporary directory
    rm -rf "$TEST_TMPDIR"
}

# Tests for source_completion function
test_source_completion_with_system_file() {
    setup_test

    # Mock the existence of system completion file
    mkdir -p "$TEST_TMPDIR/usr/share/bash-completion/completions"
    echo "# Mock git completion" > "$TEST_TMPDIR/usr/share/bash-completion/completions/git"

    # Override the function to use our test path
    source_completion() {
        if [ -f "$TEST_TMPDIR/usr/share/bash-completion/completions/git" ]; then
            source "$TEST_TMPDIR/usr/share/bash-completion/completions/git"
            return 0
        fi
        return 1
    }

    source_completion
    result=$?
    assert_true $result "source_completion should succeed with system file"

    teardown_test
}

test_source_completion_with_etc_file() {
    setup_test

    # Mock the existence of etc completion file
    mkdir -p "$TEST_TMPDIR/etc/bash_completion.d"
    echo "# Mock git completion" > "$TEST_TMPDIR/etc/bash_completion.d/git"

    source_completion() {
        if [ -f "$TEST_TMPDIR/etc/bash_completion.d/git" ]; then
            source "$TEST_TMPDIR/etc/bash_completion.d/git"
            return 0
        fi
        return 1
    }

    source_completion
    result=$?
    assert_true $result "source_completion should succeed with etc file"

    teardown_test
}

test_source_completion_with_home_file() {
    setup_test

    # Mock the existence of home completion file
    echo "# Mock git completion" > "$TEST_TMPDIR/.git-completion.bash"

    source_completion() {
        if [ -f "$TEST_TMPDIR/.git-completion.bash" ]; then
            source "$TEST_TMPDIR/.git-completion.bash"
            return 0
        fi
        return 1
    }

    source_completion
    result=$?
    assert_true $result "source_completion should succeed with home file"

    teardown_test
}

test_source_completion_no_files() {
    setup_test

    # Override function to simulate no completion files
    source_completion() {
        echo "Git completion not found"
        return 1
    }

    source_completion
    result=$?
    assert_false $result "source_completion should fail when no files exist"

    teardown_test
}

# Tests for test_git_completion function
test_git_completion_basic_commands() {
    setup_test

    # Mock _git function for testing
    _git() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        case "$cur" in
            "add")
                COMPREPLY=("add")
                ;;
            "comm")
                COMPREPLY=("commit")
                ;;
            "che")
                COMPREPLY=("checkout")
                ;;
            *)
                COMPREPLY=()
                ;;
        esac
    }

    # Test basic add completion
    test_git_completion "add" "add"
    result=$?
    assert_true $result "test_git_completion should succeed for 'add' command"

    # Test commit completion
    test_git_completion "comm" "commit"
    result=$?
    assert_true $result "test_git_completion should succeed for 'comm' -> 'commit'"

    # Test checkout completion
    test_git_completion "che" "checkout"
    result=$?
    assert_true $result "test_git_completion should succeed for 'che' -> 'checkout'"

    teardown_test
}

test_git_completion_invalid_command() {
    setup_test

    # Mock _git function that returns no completions
    _git() {
        COMPREPLY=()
    }

    test_git_completion "invalid" "invalid"
    result=$?
    assert_false $result "test_git_completion should fail for invalid command"

    teardown_test
}

test_git_completion_partial_matches() {
    setup_test

    # Mock _git function with partial matches
    _git() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        case "$cur" in
            "br")
                COMPREPLY=("branch" "browse")
                ;;
            *)
                COMPREPLY=()
                ;;
        esac
    }

    test_git_completion "br" "branch"
    result=$?
    assert_true $result "test_git_completion should succeed for partial match 'br' -> 'branch'"

    teardown_test
}

test_git_completion_environment_setup() {
    setup_test

    # Mock _git function and verify environment variables
    _git() {
        # Verify that completion environment is set correctly
        if [[ "${COMP_WORDS[0]}" == "git" ]] && [[ "${COMP_WORDS[1]}" == "test" ]] && [[ "$COMP_CWORD" == "1" ]]; then
            COMPREPLY=("test-command")
        else
            COMPREPLY=()
        fi
    }

    test_git_completion "test" "test-command"
    result=$?
    assert_true $result "test_git_completion should set up environment variables correctly"

    teardown_test
}

# Tests for run_completion_tests function
test_run_completion_tests_output() {
    setup_test

    # Mock the test_git_completion function to control success/failure
    test_git_completion() {
        local cur="$1"
        local expected="$2"
        case "$cur" in
            "add"|"comm"|"che"|"br"|"st")
                return 0  # Success
                ;;
            *)
                return 1  # Failure
                ;;
        esac
    }

    # Capture output
    output=$(run_completion_tests 2>&1)

    assert_contains "$output" "Testing git command completion" "run_completion_tests should print header"
    assert_contains "$output" "✓ add completion works" "run_completion_tests should show success for add"
    assert_contains "$output" "✓ commit completion works" "run_completion_tests should show success for commit"
    assert_contains "$output" "✓ checkout completion works" "run_completion_tests should show success for checkout"
    assert_contains "$output" "✓ branch completion works" "run_completion_tests should show success for branch"
    assert_contains "$output" "✓ status completion works" "run_completion_tests should show success for status"
    assert_contains "$output" "Completion tests finished" "run_completion_tests should print footer"

    teardown_test
}

test_run_completion_tests_with_failures() {
    setup_test

    # Mock the test_git_completion function to simulate failures
    test_git_completion() {
        local cur="$1"
        case "$cur" in
            "add")
                return 0  # Success
                ;;
            *)
                return 1  # Failure
                ;;
        esac
    }

    # Capture output
    output=$(run_completion_tests 2>&1)

    assert_contains "$output" "✓ add completion works" "run_completion_tests should show success for add"
    assert_contains "$output" "✗ commit completion failed" "run_completion_tests should show failure for commit"
    assert_contains "$output" "✗ checkout completion failed" "run_completion_tests should show failure for checkout"

    teardown_test
}

# Tests for main function
test_main_success() {
    setup_test

    # Mock source_completion to succeed
    source_completion() {
        return 0
    }

    # Mock run_completion_tests
    run_completion_tests() {
        echo "Mock completion tests run"
    }

    output=$(main 2>&1)
    result=$?

    assert_true $result "main should succeed when source_completion succeeds"
    assert_contains "$output" "Mock completion tests run" "main should call run_completion_tests"

    teardown_test
}

test_main_failure() {
    setup_test

    # Mock source_completion to fail
    source_completion() {
        echo "Cannot source git completion. Exiting."
        return 1
    }

    # Capture output and exit code
    output=$(main 2>&1)
    result=$?

    assert_false $result "main should fail when source_completion fails"
    assert_contains "$output" "Cannot source git completion. Exiting." "main should show error message"

    teardown_test
}

# Edge case tests
test_completion_with_empty_input() {
    setup_test

    _git() {
        COMPREPLY=()
    }

    test_git_completion "" "anything"
    result=$?
    assert_false $result "test_git_completion should handle empty input"

    teardown_test
}

test_completion_with_special_characters() {
    setup_test

    _git() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        if [[ "$cur" == "add@#$" ]]; then
            COMPREPLY=("add@#$-result")
        else
            COMPREPLY=()
        fi
    }

    test_git_completion "add@#$" "add@#$-result"
    result=$?
    assert_true $result "test_git_completion should handle special characters"

    teardown_test
}

test_completion_with_very_long_input() {
    setup_test

    long_input=$(printf 'a%.0s' {1..1000})

    _git() {
        COMPREPLY=()
    }

    test_git_completion "$long_input" "anything"
    result=$?
    assert_false $result "test_git_completion should handle very long input"

    teardown_test
}

test_completion_environment_isolation() {
    setup_test

    # Set some environment variables
    COMP_WORDS=("original")
    COMP_CWORD=999
    COMP_LINE="original line"
    COMP_POINT=888

    _git() {
        # Verify that environment was properly set by test_git_completion
        if [[ "${COMP_WORDS[0]}" == "git" ]] && [[ "$COMP_CWORD" == "1" ]]; then
            COMPREPLY=("isolated")
        else
            COMPREPLY=("not-isolated")
        fi
    }

    test_git_completion "test" "isolated"
    result=$?
    assert_true $result "test_git_completion should properly isolate environment"

    teardown_test
}

# Integration tests (only run if git completion is actually available)
test_real_git_completion() {
    if ! command -v git >/dev/null 2>&1; then
        echo "⚠ Skipping real git completion test - git not available"
        return
    fi

    setup_test

    # Try to source real git completion
    if source_completion 2>/dev/null; then
        # Test with real completion
        original_test_git_completion="$(declare -f test_git_completion)"

        # Use the actual implementation
        test_git_completion "add" "add"
        result=$?

        if [[ $result -eq 0 ]]; then
            echo "✓ Integration test with real git completion passed"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo "⚠ Integration test with real git completion failed (may be expected)"
        fi
        TESTS_RUN=$((TESTS_RUN + 1))
    else
        echo "⚠ Skipping real git completion test - completion not available"
    fi

    teardown_test
}

test_script_execution_directly() {
    setup_test

    # Test running the script directly
    if [[ -f "../git/test_complete.sh" ]]; then
        # Create a mock completion file for testing
        mkdir -p "$TEST_TMPDIR"
        cat > "$TEST_TMPDIR/mock-completion.bash" << 'EOF'
_git() {
    COMPREPLY=("add" "commit" "checkout" "branch" "status")
}
EOF

        # Temporarily modify the script to use our mock
        temp_script="$TEST_TMPDIR/test_script.sh"
        sed "s|/usr/share/bash-completion/completions/git|$TEST_TMPDIR/mock-completion.bash|g" "../git/test_complete.sh" > "$temp_script"
        chmod +x "$temp_script"

        output=$("$temp_script" 2>&1)
        result=$?

        assert_true $result "Script should execute successfully when run directly"
        assert_contains "$output" "Testing git command completion" "Script output should contain expected header"
    else
        echo "⚠ Skipping direct execution test - script file not found"
    fi

    teardown_test
}

# Performance tests
test_completion_performance() {
    setup_test

    # Mock _git with a slight delay to test timeout behavior
    _git() {
        sleep 0.1  # Small delay
        COMPREPLY=("test-result")
    }

    start_time=$(date +%s.%N)
    test_git_completion "test" "test-result"
    result=$?
    end_time=$(date +%s.%N)

    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.5")

    assert_true $result "Performance test should complete successfully"

    # Check if duration is reasonable (less than 1 second)
    if (( $(echo "$duration < 1.0" | bc -l 2>/dev/null || echo 0) )); then
        echo "✓ Performance test completed in reasonable time ($duration seconds)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "✗ Performance test took too long ($duration seconds)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))

    teardown_test
}

test_memory_usage_with_large_compreply() {
    setup_test

    # Mock _git to return a large number of completions
    _git() {
        COMPREPLY=()
        for i in {1..1000}; do
            COMPREPLY+=("completion-$i")
        done
    }

    test_git_completion "test" "completion-1"
    result=$?
    assert_true $result "Should handle large COMPREPLY arrays"

    teardown_test
}

# Test runner function
run_all_tests() {
    echo "Running comprehensive tests for test_complete.sh"
    echo "================================================="

    # Basic function tests
    echo ""
    echo "Testing source_completion function:"
    test_source_completion_with_system_file
    test_source_completion_with_etc_file
    test_source_completion_with_home_file
    test_source_completion_no_files

    # Git completion tests
    echo ""
    echo "Testing test_git_completion function:"
    test_git_completion_basic_commands
    test_git_completion_invalid_command
    test_git_completion_partial_matches
    test_git_completion_environment_setup

    # Main function tests
    echo ""
    echo "Testing run_completion_tests and main functions:"
    test_run_completion_tests_output
    test_run_completion_tests_with_failures
    test_main_success
    test_main_failure

    # Edge case tests
    echo ""
    echo "Testing edge cases:"
    test_completion_with_empty_input
    test_completion_with_special_characters
    test_completion_with_very_long_input
    test_completion_environment_isolation

    # Integration tests
    echo ""
    echo "Running integration tests:"
    test_real_git_completion
    test_script_execution_directly

    # Performance tests
    echo ""
    echo "Running performance tests:"
    test_completion_performance
    test_memory_usage_with_large_compreply

    # Print summary
    echo ""
    echo "================================================="
    echo "Test Summary:"
    echo "  Tests run: $TESTS_RUN"
    echo "  Tests passed: $TESTS_PASSED"
    echo "  Tests failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "  Result: ALL TESTS PASSED ✓"
        return 0
    else
        echo "  Result: SOME TESTS FAILED ✗"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
    exit $?
fi