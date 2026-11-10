# Safe command-name suggestions for the custom Zsh failure handler.
#
# The Rust helper (dots-suggest) performs ranking when installed. A bounded
# pure-Zsh implementation remains as a portable fallback.
#
# Contract:
#   - Returns 0 only when the user selects a candidate.
#   - Sets REPLY to the selected command name on success.
#   - Returns 1 when there are no suggestions, selection is cancelled, or the
#     shell is non-interactive.
#   - Never executes a command. The caller must ask for explicit confirmation
#     before running REPLY.

zmodload zsh/parameter 2>/dev/null || true

typeset -g _DOTS_COMMAND_SUGGESTION_CACHE_PATH=''
typeset -gi _DOTS_COMMAND_SUGGESTION_CACHE_READY=0
typeset -gi _DOTS_COMMAND_SUGGESTION_CACHE_FUNCTION_COUNT=-1
typeset -ga _DOTS_COMMAND_SUGGESTION_CACHE_NAMES=()
typeset -ga _DOTS_COMMAND_SUGGESTION_RESULTS=()

typeset -g _DOTS_COMMAND_SUGGESTION_BINARY=''
typeset -g _DOTS_COMMAND_SUGGESTION_BINARY_PATH=''
typeset -g _DOTS_COMMAND_SUGGESTION_BINARY_OVERRIDE=''
typeset -gi _DOTS_COMMAND_SUGGESTION_BINARY_CHECKED=0
typeset -g _DOTS_COMMAND_SUGGESTION_LAST_BACKEND=''

_dots_command_suggestion_refresh_cache() {
    emulate -L zsh

    local directory name
    local -aU names

    # PATH discovery happens once per shell (or when PATH changes). Zsh's
    # in-process globbing follows symlinks, which matters for Nix store links.
    for directory in "${path[@]}"; do
        [[ -n "$directory" ]] || directory='.'
        [[ -d "$directory" && -r "$directory" ]] || continue
        names+=( "$directory"/*(N-*:t) )
    done

    # Snapshot shell-resolvable names too. The count checks below invalidate
    # this snapshot when functions or command hashes are added dynamically.
    if (( ${+commands} )); then
        names+=( "${(@k)commands}" )
    fi
    if (( ${+builtins} )); then
        names+=( "${(@k)builtins}" )
    fi
    if (( ${+functions} )); then
        for name in "${(@k)functions}"; do
            [[ "$name" == _* ]] || names+=( "$name" )
        done
    fi

    _DOTS_COMMAND_SUGGESTION_CACHE_NAMES=( "${names[@]}" )
    _DOTS_COMMAND_SUGGESTION_CACHE_PATH="$PATH"
    _DOTS_COMMAND_SUGGESTION_CACHE_FUNCTION_COUNT=${#functions}
    _DOTS_COMMAND_SUGGESTION_CACHE_READY=1
}

_dots_command_suggestion_resolve_binary() {
    emulate -L zsh

    if (( ! _DOTS_COMMAND_SUGGESTION_BINARY_CHECKED )) ||
        [[ "$_DOTS_COMMAND_SUGGESTION_BINARY_PATH" != "$PATH" ]] ||
        [[ "$_DOTS_COMMAND_SUGGESTION_BINARY_OVERRIDE" != "${DOTS_SUGGEST_BIN:-}" ]]; then
        local binary=''
        if [[ -n "${DOTS_SUGGEST_BIN:-}" ]]; then
            [[ -x "$DOTS_SUGGEST_BIN" ]] && binary="$DOTS_SUGGEST_BIN"
        else
            binary="$(builtin whence -p dots-suggest 2>/dev/null)"
        fi

        _DOTS_COMMAND_SUGGESTION_BINARY="$binary"
        _DOTS_COMMAND_SUGGESTION_BINARY_PATH="$PATH"
        _DOTS_COMMAND_SUGGESTION_BINARY_OVERRIDE="${DOTS_SUGGEST_BIN:-}"
        _DOTS_COMMAND_SUGGESTION_BINARY_CHECKED=1
    fi

    REPLY="$_DOTS_COMMAND_SUGGESTION_BINARY"
    [[ -n "$REPLY" && -x "$REPLY" ]]
}

# Banded optimal-string-alignment distance. This fallback avoids external
# processes and retains the previous transposition-aware behavior.
_dots_command_suggestion_distance() {
    emulate -L zsh

    local left="${1-}"
    local right="${2-}"
    local -i limit=${3:-2}
    local -i left_length=${#left}
    local -i right_length=${#right}
    local -i sentinel=$((limit + 1))
    local -i i j start end cost deletion insertion substitution transposition best
    local -i previous_deletion previous_insertion previous_substitution previous_transposition
    local -ai previous previous_previous current

    if (( left_length > right_length + limit || right_length > left_length + limit )); then
        REPLY=$sentinel
        return 0
    fi

    previous=()
    for ((j = 0; j <= right_length && j <= limit; j++)); do
        previous[$((j + 1))]=$j
    done
    previous_previous=()

    for ((i = 1; i <= left_length; i++)); do
        current=()
        current[1]=$(( i <= limit ? i : sentinel ))

        start=$((i - limit))
        (( start < 1 )) && start=1
        end=$((i + limit))
        (( end > right_length )) && end=$right_length

        for ((j = start; j <= end; j++)); do
            if [[ "${left[i]}" == "${right[j]}" ]]; then
                cost=0
            else
                cost=1
            fi

            previous_deletion=${previous[$((j + 1))]:-$sentinel}
            previous_insertion=${current[$j]:-$sentinel}
            previous_substitution=${previous[$j]:-$sentinel}

            deletion=$((previous_deletion + 1))
            insertion=$((previous_insertion + 1))
            substitution=$((previous_substitution + cost))

            (( deletion > sentinel )) && deletion=$sentinel
            (( insertion > sentinel )) && insertion=$sentinel
            (( substitution > sentinel )) && substitution=$sentinel

            best=$deletion
            (( insertion < best )) && best=$insertion
            (( substitution < best )) && best=$substitution

            if (( i > 1 && j > 1 )) &&
                [[ "${left[i]}" == "${right[j - 1]}" && "${left[i - 1]}" == "${right[j]}" ]]; then
                previous_transposition=${previous_previous[$((j - 1))]:-$sentinel}
                transposition=$((previous_transposition + 1))
                (( transposition > sentinel )) && transposition=$sentinel
                (( transposition < best )) && best=$transposition
            fi

            current[$((j + 1))]=$best
        done

        previous_previous=("${previous[@]}")
        previous=("${current[@]}")
    done

    REPLY=${previous[$((right_length + 1))]:-$sentinel}
}

_dots_command_suggestion_candidates() {
    emulate -L zsh
    setopt localoptions no_aliases

    local command="${1-}"
    local name entry output
    _DOTS_COMMAND_SUGGESTION_RESULTS=()
    local -i max_distance max_results=5 helper_status
    local -a ranked suggestions

    [[ -n "$command" ]] || return 1
    [[ "$command" != */* && "$command" != *[[:space:]]* ]] || return 1

    local -i command_length=${#command}
    (( command_length >= 2 )) || return 1

    if (( command_length < 6 )); then
        max_distance=1
    else
        max_distance=2
    fi

    # Rebuild only when the inputs actually change. Counting the Zsh hash
    # tables is O(1); enumerating them is deferred to this invalidation path.
    if (( ! _DOTS_COMMAND_SUGGESTION_CACHE_READY )) ||
        [[ "$_DOTS_COMMAND_SUGGESTION_CACHE_PATH" != "$PATH" ]] ||
        (( _DOTS_COMMAND_SUGGESTION_CACHE_FUNCTION_COUNT != ${#functions} )); then
        _dots_command_suggestion_refresh_cache
    fi

    # On NixOS, dots-suggest is installed declaratively by nix/packages.nix.
    # It reads the cached candidate list from stdin and writes at most five
    # names. A broken/missing helper falls back to the native Zsh algorithm.
    if [[ "${DOTS_SUGGEST_DISABLE_RUST:-0}" != 1 ]] &&
        _dots_command_suggestion_resolve_binary; then
        if output="$("$_DOTS_COMMAND_SUGGESTION_BINARY" "$command" <<< "${(F)_DOTS_COMMAND_SUGGESTION_CACHE_NAMES[@]}")"; then
            if [[ -n "$output" ]]; then
                _DOTS_COMMAND_SUGGESTION_RESULTS=( "${(@f)output}" )
                _DOTS_COMMAND_SUGGESTION_LAST_BACKEND=rust
                return 0
            fi
            return 1
        else
            helper_status=$?
            # Exit 1 is the helper's normal "no candidates" result. Other
            # failures disable nothing; the portable fallback remains usable.
            (( helper_status == 1 )) && return 1
        fi
    fi

    # Portable fallback: the candidate list is still cached, so the expensive
    # Zsh hash enumeration and PATH globbing never run for every typo.
    for name in "${_DOTS_COMMAND_SUGGESTION_CACHE_NAMES[@]}"; do
        [[ -n "$name" && "$name" != _* && "$name" != "$command" ]] || continue

        _dots_command_suggestion_distance "$command" "$name" "$max_distance"
        (( REPLY <= max_distance )) || continue

        ranked+=("${REPLY} $name")
    done

    (( ${#ranked[@]} > 0 )) || return 1
    ranked=("${(@o)ranked}")

    for entry in "${ranked[@]}"; do
        suggestions+=("${entry#* }")
        (( ${#suggestions[@]} >= max_results )) && break
    done

    _DOTS_COMMAND_SUGGESTION_RESULTS=("${suggestions[@]}")
    _DOTS_COMMAND_SUGGESTION_LAST_BACKEND=zsh
    return 0
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

    _dots_command_suggestion_candidates "$command" || return 1
    suggestions=("${_DOTS_COMMAND_SUGGESTION_RESULTS[@]}")

    (( ${#suggestions[@]} > 0 )) || return 1

    if [[ ! -o interactive || ! -r /dev/tty ]]; then
        print -u2 -- "Possible corrections for '$command':"
        for selected in "${suggestions[@]}"; do
            print -u2 -- "  - $selected"
        done
        REPLY=""
        return 1
    fi

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
