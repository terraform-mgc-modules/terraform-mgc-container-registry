#!/usr/bin/env bats

# Test file for shell completion functionality
# Testing framework: BATS (Bash Automated Testing System)

# Set up test environment
setup() {
    # Create temporary directory for test isolation
    export TEST_TEMP_DIR="$(mktemp -d)"
    export OLD_PATH="$PATH"
    export PATH="$TEST_TEMP_DIR:$PATH"
    
    # Source the completion script under test
    if [[ -f "git/test_complete.sh" ]]; then
        source git/test_complete.sh
    elif [[ -f "test_complete.sh" ]]; then
        source test_complete.sh
    else
        skip "Completion script not found"
    fi
    
    # Clear any existing completion state
    unset COMPREPLY COMP_WORDS COMP_CWORD COMP_LINE COMP_POINT
}

teardown() {
    # Clean up temporary directory
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    # Restore original PATH
    if [[ -n "$OLD_PATH" ]]; then
        export PATH="$OLD_PATH"
    fi
    
    # Clear completion state
    unset COMPREPLY COMP_WORDS COMP_CWORD COMP_LINE COMP_POINT
}

@test "completion function _test_complete exists and is callable" {
    # Test that the main completion function is defined
    run type -t _test_complete
    [[ "$status" -eq 0 ]]
    [[ "$output" = "function" ]]
}

@test "completion script sources without errors" {
    # Test that the completion script can be sourced successfully
    run bash -c "source git/test_complete.sh 2>&1"
    [[ "$status" -eq 0 ]]
    [[ ! "$output" =~ [Ee]rror ]]
}

@test "bash completion is registered for testcmd command" {
    # Test that completion is properly registered
    run bash -c "complete -p testcmd"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "_test_complete" ]]
}

@test "COMPREPLY array is initialized properly" {
    # Test that COMPREPLY is properly managed
    export COMP_WORDS=("testcmd" "")
    export COMP_CWORD=1
    export COMP_LINE="testcmd "
    export COMP_POINT=8
    
    _test_complete
    [[ -v COMPREPLY ]]
    [[ "${#COMPREPLY[@]}" -ge 0 ]]
}

@test "completes available commands when no prefix given" {
    # Test basic command completion with empty string
    export COMP_WORDS=("testcmd" "")
    export COMP_CWORD=1
    export COMP_LINE="testcmd "
    export COMP_POINT=8
    
    _test_complete
    
    # Should contain the available commands
    local expected_commands=("start" "stop" "restart" "status" "deploy" "build" "test")
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
    
    # Check if commands are in the completion
    local found=0
    for cmd in "${expected_commands[@]}"; do
        for reply in "${COMPREPLY[@]}"; do
            if [[ "$reply" == "$cmd" ]]; then
                ((found++))
                break
            fi
        done
    done
    [[ "$found" -gt 0 ]]
}

@test "completes commands with partial prefix" {
    # Test command completion with partial input
    export COMP_WORDS=("testcmd" "st")
    export COMP_CWORD=1
    export COMP_LINE="testcmd st"
    export COMP_POINT=10
    
    _test_complete
    
    # Should complete to commands starting with "st"
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
    for reply in "${COMPREPLY[@]}"; do
        [[ "$reply" =~ ^st ]] || [[ "$reply" == "start" ]] || [[ "$reply" == "stop" ]] || [[ "$reply" == "status" ]]
    done
}

@test "completes exact command match" {
    # Test completion with exact command match
    export COMP_WORDS=("testcmd" "start")
    export COMP_CWORD=1
    export COMP_LINE="testcmd start"
    export COMP_POINT=13
    
    _test_complete
    
    # Should include "start" in completions
    local found=false
    for reply in "${COMPREPLY[@]}"; do
        if [[ "$reply" == "start" ]]; then
            found=true
            break
        fi
    done
    [[ "$found" == true ]]
}

@test "completes long options with double dash prefix" {
    # Test long option completion
    export COMP_WORDS=("testcmd" "--")
    export COMP_CWORD=1
    export COMP_LINE="testcmd --"
    export COMP_POINT=10
    
    _test_complete
    
    # Should complete to available long options
    local expected_options=("--help" "--version" "--verbose" "--output" "--input" "--config")
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
    
    local found=0
    for opt in "${expected_options[@]}"; do
        for reply in "${COMPREPLY[@]}"; do
            if [[ "$reply" == "$opt" ]]; then
                ((found++))
                break
            fi
        done
    done
    [[ "$found" -gt 0 ]]
}

@test "completes partial long options" {
    # Test partial long option completion
    export COMP_WORDS=("testcmd" "--ver")
    export COMP_CWORD=1
    export COMP_LINE="testcmd --ver"
    export COMP_POINT=13
    
    _test_complete
    
    # Should complete to options starting with "--ver"
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
    local found=false
    for reply in "${COMPREPLY[@]}"; do
        if [[ "$reply" =~ ^--ver ]] || [[ "$reply" == "--version" ]] || [[ "$reply" == "--verbose" ]]; then
            found=true
            break
        fi
    done
    [[ "$found" == true ]]
}

@test "completes single dash options" {
    # Test single dash completion triggers option mode
    export COMP_WORDS=("testcmd" "-")
    export COMP_CWORD=1
    export COMP_LINE="testcmd -"
    export COMP_POINT=9
    
    _test_complete
    
    # Should complete to available options (all start with --)
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
    for reply in "${COMPREPLY[@]}"; do
        [[ "$reply" =~ ^-- ]]
    done
}

@test "completes files for --output option" {
    # Create test files for completion testing
    touch "$TEST_TEMP_DIR/output1.txt"
    touch "$TEST_TEMP_DIR/output2.log"
    touch "$TEST_TEMP_DIR/other.conf"
    
    cd "$TEST_TEMP_DIR"
    
    export COMP_WORDS=("testcmd" "--output" "out")
    export COMP_CWORD=2
    export COMP_LINE="testcmd --output out"
    export COMP_POINT=19
    
    _test_complete
    
    # Should complete with files starting with "out"
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
    local found=false
    for reply in "${COMPREPLY[@]}"; do
        if [[ "$reply" =~ output ]]; then
            found=true
            break
        fi
    done
    [[ "$found" == true ]]
}

@test "completes files for --input option" {
    # Create test files
    touch "$TEST_TEMP_DIR/input.txt"
    touch "$TEST_TEMP_DIR/data.csv"
    mkdir -p "$TEST_TEMP_DIR/inputdir"
    
    cd "$TEST_TEMP_DIR"
    
    export COMP_WORDS=("testcmd" "--input" "")
    export COMP_CWORD=2
    export COMP_LINE="testcmd --input "
    export COMP_POINT=16
    
    _test_complete
    
    # Should complete with all files and directories
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
    # Verify some expected files are present
    local found_files=0
    for reply in "${COMPREPLY[@]}"; do
        if [[ "$reply" == "input.txt" ]] || [[ "$reply" == "data.csv" ]] || [[ "$reply" == "inputdir/" ]]; then
            ((found_files++))
        fi
    done
    [[ "$found_files" -gt 0 ]]
}

@test "completes only .conf files for --config option" {
    # Create test files with different extensions
    touch "$TEST_TEMP_DIR/app.conf"
    touch "$TEST_TEMP_DIR/db.conf"
    touch "$TEST_TEMP_DIR/other.txt"
    touch "$TEST_TEMP_DIR/script.sh"
    
    cd "$TEST_TEMP_DIR"
    
    export COMP_WORDS=("testcmd" "--config" "")
    export COMP_CWORD=2
    export COMP_LINE="testcmd --config "
    export COMP_POINT=17
    
    _test_complete
    
    # Should complete only with .conf files
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
    for reply in "${COMPREPLY[@]}"; do
        [[ "$reply" =~ \.conf$ ]]
    done
}

@test "handles empty COMP_WORDS array gracefully" {
    # Test with empty COMP_WORDS
    export COMP_WORDS=()
    export COMP_CWORD=0
    export COMP_LINE=""
    export COMP_POINT=0
    
    run _test_complete
    [[ "$status" -eq 0 ]]
    [[ -v COMPREPLY ]]
}

@test "handles invalid COMP_CWORD gracefully" {
    # Test with COMP_CWORD out of bounds
    export COMP_WORDS=("testcmd" "test")
    export COMP_CWORD=999
    export COMP_LINE="testcmd test"
    export COMP_POINT=12
    
    run _test_complete
    [[ "$status" -eq 0 ]]
    [[ -v COMPREPLY ]]
}

@test "handles negative COMP_CWORD gracefully" {
    # Test with negative COMP_CWORD
    export COMP_WORDS=("testcmd" "test")
    export COMP_CWORD=-1
    export COMP_LINE="testcmd test"
    export COMP_POINT=12
    
    run _test_complete
    [[ "$status" -eq 0 ]]
    [[ -v COMPREPLY ]]
}

@test "handles special characters in completion input" {
    # Test completion with special characters
    export COMP_WORDS=("testcmd" "test-with-dashes_and_underscores")
    export COMP_CWORD=1
    export COMP_LINE="testcmd test-with-dashes_and_underscores"
    export COMP_POINT=38
    
    run _test_complete
    [[ "$status" -eq 0 ]]
    [[ -v COMPREPLY ]]
}

@test "handles quoted arguments correctly" {
    # Test completion with quoted strings
    export COMP_WORDS=("testcmd" "\"quoted string\"")
    export COMP_CWORD=1
    export COMP_LINE="testcmd \"quoted string\""
    export COMP_POINT=22
    
    run _test_complete
    [[ "$status" -eq 0 ]]
    [[ -v COMPREPLY ]]
}

@test "handles completion in middle of command line" {
    # Test completion when cursor is not at end
    export COMP_WORDS=("testcmd" "sta" "additional")
    export COMP_CWORD=1
    export COMP_LINE="testcmd sta additional"
    export COMP_POINT=11
    
    run _test_complete
    [[ "$status" -eq 0 ]]
    [[ -v COMPREPLY ]]
}

@test "completion performs within reasonable time" {
    # Test performance with normal input
    export COMP_WORDS=("testcmd" "")
    export COMP_CWORD=1
    export COMP_LINE="testcmd "
    export COMP_POINT=8
    
    # Time the completion (should complete quickly)
    run timeout 2s bash -c '_test_complete'
    [[ "$status" -eq 0 ]] # Should not timeout
}

@test "completion works with many files in directory" {
    # Create many files to test performance
    cd "$TEST_TEMP_DIR"
    for i in {1..100}; do
        touch "file$i.txt"
        touch "config$i.conf"
    done
    
    export COMP_WORDS=("testcmd" "--output" "file")
    export COMP_CWORD=2
    export COMP_LINE="testcmd --output file"
    export COMP_POINT=20
    
    run timeout 3s bash -c '_test_complete'
    [[ "$status" -eq 0 ]]
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
}

@test "completion handles concurrent calls" {
    # Test basic thread safety
    export COMP_WORDS=("testcmd" "test")
    export COMP_CWORD=1
    export COMP_LINE="testcmd test"
    export COMP_POINT=12
    
    # Run multiple completions in background
    run bash -c '
        _test_complete &
        _test_complete &
        _test_complete &
        wait
        echo "All completed"
    '
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "All completed" ]]
}

@test "completion works from different working directories" {
    # Test completion from different working directories
    mkdir -p "$TEST_TEMP_DIR/subdir"
    cd "$TEST_TEMP_DIR/subdir"
    
    export COMP_WORDS=("testcmd" "")
    export COMP_CWORD=1
    export COMP_LINE="testcmd "
    export COMP_POINT=8
    
    run _test_complete
    [[ "$status" -eq 0 ]]
    [[ "${#COMPREPLY[@]}" -gt 0 ]]
}

@test "completion state is properly isolated between calls" {
    # First completion call
    export COMP_WORDS=("testcmd" "start")
    export COMP_CWORD=1
    export COMP_LINE="testcmd start"
    export COMP_POINT=13
    
    _test_complete
    local first_reply=("${COMPREPLY[@]}")
    
    # Second completion call with different input
    export COMP_WORDS=("testcmd" "--help")
    export COMP_CWORD=1
    export COMP_LINE="testcmd --help"
    export COMP_POINT=14
    
    _test_complete
    local second_reply=("${COMPREPLY[@]}")
    
    # Results should be different
    [[ "${first_reply[*]}" != "${second_reply[*]}" ]]
}

@test "completion integrates properly with bash complete builtin" {
    # Test actual integration with complete command
    run bash -c "
        source git/test_complete.sh
        complete -p testcmd
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "complete -F _test_complete testcmd" ]]
}

@test "completion function variables do not leak to global scope" {
    # Test that internal variables don't pollute global namespace
    unset cur prev opts commands
    
    export COMP_WORDS=("testcmd" "test")
    export COMP_CWORD=1
    export COMP_LINE="testcmd test"
    export COMP_POINT=12
    
    _test_complete
    
    # These variables should not be set globally
    [[ ! -v cur ]] || [[ -z "$cur" ]]
    [[ ! -v prev ]] || [[ -z "$prev" ]]
    [[ ! -v opts ]] || [[ -z "$opts" ]]
    [[ ! -v commands ]] || [[ -z "$commands" ]]
}