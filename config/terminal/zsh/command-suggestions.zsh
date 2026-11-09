# Safe command-name suggestions for the custom Zsh failure handler.
#
# This module is intentionally standalone. Source it from .zshrc and call
# dots_suggest_command "$command_name" from command_not_found_handler.
#
# Contract:
#   - Returns 0 only when the user selects a candidate.
#   - Sets REPLY to the selected command name on success.
#   - Returns 1 when there are no suggestions, selection is cancelled, or the
#     shell is non-interactive.
#   - Never executes a command. The caller must ask for explicit confirmation
#     before running REPLY.
#
# Runtime dependencies:
#   - Zsh builtins only for discovery and ranking.
#   - fzf is optional; a numbered /dev/tty prompt is used without it.

_dots_command_suggestion_distance() {
    emulate -L zsh

    local left="${1-}"
    local right="${2-}"
    local -i left_length=${#left}
    local -i right_length=${#right}
    local -i i j cost deletion insertion substitution transposition best
    local -a previous previous_previous current

    # A larger length difference cannot pass the caller's edit-distance limit.
    if (( left_length > right_length + 2 || right_length > left_length + 2 )); then
        REPLY=99
        return 0
    fi

    # Optimal String Alignment distance: ordinary Levenshtein edits plus one
    # adjacent transposition. This makes common typos such as "gti" -> "git"
    # count as one edit instead of two.
    for ((j = 0; j <= right_length; j++)); do
        previous[$((j + 1))]=$j
    done

    for ((i = 1; i <= left_length; i++)); do
        current=()
        current[1]=$i

        for ((j = 1; j <= right_length; j++)); do
            if [[ "${left[i]}" == "${right[j]}" ]]; then
                cost=0
            else
                cost=1
            fi

            deletion=$((previous[j + 1] + 1))
            insertion=$((current[j] + 1))
            substitution=$((previous[j] + cost))

            best=$deletion
            (( insertion < best )) && best=$insertion
            (( substitution < best )) && best=$substitution

            if (( i > 1 && j > 1 )) &&
                [[ "${left[i]}" == "${right[j - 1]}" && "${left[i - 1]}" == "${right[j]}" ]]; then
                transposition=$((previous_previous[j - 1] + 1))
                (( transposition < best )) && best=$transposition
            fi

            current[$((j + 1))]=$best
        done

        previous_previous=("${previous[@]}")
        previous=("${current[@]}")
    done

    REPLY=${previous[$((right_length + 1))]}
}

_dots_command_suggestion_candidates() {
    emulate -L zsh

    local command="${1-}"
    local entry name kind
    local -i max_distance max_results=5
    local -a names ranked suggestions

    # Do not guess at paths, multi-word command strings, or empty input.
    [[ -n "$command" ]] || return 1
    [[ "$command" != */* && "$command" != *[[:space:]]* ]] || return 1

    local -i command_length=${#command}
    (( command_length >= 2 )) || return 1

    # Keep short command names conservative; permit two edits only for longer
    # names, where a single typo is less likely to create a misleading match.
    if (( command_length < 6 )); then
        max_distance=1
    else
        max_distance=2
    fi

    # whence refreshes the command hash when matching patterns and reports
    # aliases, builtins, external commands, functions, and reserved words.
    # Reserved words and private helper functions are not useful corrections.
    while IFS= read -r entry; do
        name="${entry%%: *}"
        kind="${entry##*: }"

        [[ -n "$name" ]] || continue
        [[ "$kind" == reserved || "$kind" == alias ]] && continue
        [[ "$name" == _* ]] && continue
        names+=("$name")
    done < <(builtin whence -wm '*' 2>/dev/null)

    typeset -U names

    for name in "${names[@]}"; do
        [[ "$name" == "$command" ]] && continue

        _dots_command_suggestion_distance "$command" "$name"
        (( REPLY <= max_distance )) || continue

        ranked+=("${REPLY} $name")
    done

    (( ${#ranked[@]} > 0 )) || return 1

    # Distances are single-digit and precede the candidate, so lexical sorting
    # ranks by distance first and then alphabetically for stable output.
    ranked=("${(@o)ranked}")

    for entry in "${ranked[@]}"; do
        suggestions+=("${entry#* }")
        (( ${#suggestions[@]} >= max_results )) && break
    done

    print -rl -- "${suggestions[@]}"
}

dots_suggest_command() {
    emulate -L zsh

    local command="${1-}"
    local selected choice
    local -i index=1
    local -a suggestions

    REPLY=""

    (( $# == 1 )) || return 1
    [[ -n "$command" ]] || return 1

    local candidate_output
    candidate_output="$(_dots_command_suggestion_candidates "$command")" || return 1
    suggestions=("${(@f)candidate_output}")

    (( ${#suggestions[@]} > 0 )) || return 1

    # In scripts, pipelines, and non-interactive shells, only print useful
    # suggestions. Never block waiting for input that may not exist.
    if [[ ! -o interactive || ! -r /dev/tty ]]; then
        print -u2 -- "Possible corrections for '$command':"
        for selected in "${suggestions[@]}"; do
            print -u2 -- "  - $selected"
        done
        return 1
    fi

    # fzf is optional. Selection only populates REPLY; execution is left to the
    # caller, which must require a separate explicit confirmation.
    if [[ "${DOTS_SUGGEST_DISABLE_FZF:-0}" != 1 ]] &&
        builtin whence -p fzf >/dev/null 2>&1; then
        if selected="$(print -rl -- "${suggestions[@]}" | command fzf \
            --no-multi \
            --prompt="Correction > " \
            --height=40% \
            --layout=reverse \
            --border)"; then
            [[ -n "$selected" ]] || return 1
            for choice in "${suggestions[@]}"; do
                if [[ "$choice" == "$selected" ]]; then
                    REPLY=$selected
                    return 0
                fi
            done
        fi
        return 1
    fi

    # Dependency-free interactive fallback for systems without fzf.
    print -u2 -- "Possible corrections for '$command':"
    for selected in "${suggestions[@]}"; do
        print -u2 -- "  $index) $selected"
        ((index++))
    done

    print -u2 -n -- "Select a correction (1-${#suggestions[@]}) or press Enter to cancel: "
    IFS= read -r choice </dev/tty || return 1
    [[ "$choice" == <-> ]] || return 1
    (( choice >= 1 && choice <= ${#suggestions[@]} )) || return 1

    REPLY="${suggestions[$choice]}"
    return 0
}
