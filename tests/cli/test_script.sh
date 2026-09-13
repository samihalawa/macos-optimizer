#!/usr/bin/env bats

ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
CLI="$ROOT/cli/src/macos-optimizer.sh"
WRAP="$ROOT/cli/src/script.sh"

@test "optimizer script exists and is executable" {
  [ -x "$CLI" ]
}

@test "compatibility wrapper exists and is executable" {
  [ -x "$WRAP" ]
}

@test "script shows version number" {
  run "$CLI" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"2.2.0"* ]]
}

@test "script shows help" {
  run "$CLI" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "wrapper forwards version" {
  run "$WRAP" --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"2.2.0"* ]]
}

@test "unknown flag fails" {
  run "$CLI" --not-a-real-flag
  [ "$status" -ne 0 ]
}

@test "interactive path requires macOS" {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    skip "Runs on macOS — interactive path not asserted here"
  fi
  run "$CLI"
  [ "$status" -ne 0 ]
  [[ "$output" == *"requires macOS"* ]]
}
