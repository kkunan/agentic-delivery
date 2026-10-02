verdicts=()
reasons=()

record() {
    local i=$1 verdict=$2 reason=$3
    verdicts[$i]=$verdict
    reasons[$i]=$reason
    printf '%s  %s  %s  %s\n' "$verdict" "${labels[$i]}" "${files[$i]}" "${tests[$i]}"
}

tally() {
    local wanted=$1 n=0 i
    for ((i = 0; i < ${#labels[@]}; i++)); do
        [ "${verdicts[$i]}" = "$wanted" ] && n=$((n + 1))
    done
    echo "$n"
}

group() {
    local wanted=$1 i lines=""
    for ((i = 0; i < ${#labels[@]}; i++)); do
        [ "${verdicts[$i]}" = "$wanted" ] || continue
        lines="$lines  ${labels[$i]}  ${files[$i]}  ${tests[$i]}"
        [ "$wanted" = error ] && lines="$lines  (${reasons[$i]})"
        lines="$lines"$'\n'
    done
    if [ -z "$lines" ]; then
        printf '%s: none\n' "$wanted"
    else
        printf '%s:\n%s' "$wanted" "$lines"
    fi
}

summary() {
    printf 'runner: %s\n' "$runner"
    printf 'mutate: %s mutations, %s killed, %s survived, %s did-not-compile, %s error\n' \
        "${#labels[@]}" "$(tally killed)" "$(tally survived)" "$(tally did-not-compile)" "$(tally error)"
    local v
    for v in killed survived did-not-compile error; do group "$v"; done
}

report() {
    local text
    text=$(summary)
    printf '\n%s\n' "$text"
    printf '%s\n' "$text" > "$out/mutate-summary.txt"
    [ "$(tally killed)" -eq "${#labels[@]}" ] && exit 0
    exit 1
}
