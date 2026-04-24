#!/usr/bin/env bats
# bats-core test suite cho install.sh
# Pre-req: brew install bats-core shellcheck
# Run: bats Distribution/tests/test_install.bats

setup() {
    INSTALL_SCRIPT="${BATS_TEST_DIRNAME}/../install.sh"
}

@test "install.sh exists and is executable" {
    [ -x "$INSTALL_SCRIPT" ]
}

@test "install.sh --help prints usage" {
    run "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"TFTMac"* ]]
}

@test "install.sh --dry-run prints all 7 install steps without executing" {
    run "$INSTALL_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[1/7] Download"* ]]
    [[ "$output" == *"[2/7] Mount"* ]]
    [[ "$output" == *"[3/7] Copy"* ]]
    [[ "$output" == *"[4/7] xattr -cr"* ]]
    [[ "$output" == *"[5/7] spctl"* ]]
    [[ "$output" == *"[6/7] Eject"* ]]
    [[ "$output" == *"[7/7] Launch"* ]]
    # Ensure no side effects — should NOT have run curl/hdiutil/cp
    [[ "$output" == *"DRY: curl"* ]]
}

@test "install.sh unknown arg exits 1 with error message" {
    run "$INSTALL_SCRIPT" --nonsense-flag
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown arg"* ]]
}

@test "install.sh passes bash syntax check" {
    run bash -n "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "install.sh passes shellcheck (if installed)" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed"
    fi
    run shellcheck "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
}
