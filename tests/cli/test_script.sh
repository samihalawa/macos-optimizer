#!/usr/bin/env bats

load '../test_helper'

@test "script exists and is executable" {
    [ -x "$BATS_TEST_DIRNAME/../../cli/src/script.sh" ]
}

@test "script shows version number" {
    run "$BATS_TEST_DIRNAME/../../cli/src/script.sh" --version
    [ "$status" -eq 0 ]
    [[ "$output" =~ "2.1" ]]
}

@test "script requires macOS" {
    if [[ "$(uname)" != "Darwin" ]]; then
        skip "Test only runs on macOS"
    fi
    run "$BATS_TEST_DIRNAME/../../cli/src/script.sh"
    [ "$status" -eq 0 ]
} 