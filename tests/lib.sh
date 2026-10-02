passed=0
failed=0
check() {
    if [ "$2" = "$3" ]; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"
    fi
}
finish() {
    printf '%s passed, %s failed\n' "$passed" "$failed"
    [ "$failed" -eq 0 ]
}
