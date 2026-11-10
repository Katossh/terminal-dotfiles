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
#   - Zsh builtins and globbing for discovery and ranking.
#   - fzf is optional; a numbered /dev/tty prompt is used without it.

# The parameter module exposes Zsh's command, builtin, and function hash tables.
# It is part of the standard Zsh distribution; keep discovery functional even
# on builds where dynamic module loading is unavailable.
zmodload zsh/parameter 2>/dev/null || true

typeset -g _DOTS_COMMAND_SUGGESTION_CACHE_PATH=''
typeset -gi _DOTS_COMMAND_SUGGESTION_CACHE_READY=0
typeset -ga _DOTS_COMMAND_SUGGESTION_CACHE_NAMES=()
typeset -ga _DOTS_COMMAND_SUGGESTION_RESULTS=()

_dots_command_suggestion_refresh_cache() {
    emulate -L zsh

    local directory
    local -aU names

    # Zsh globbing performs PATH discovery in-process. Follow symlinks because
    # NixOS and many package managers expose executables through symlink farms.
    for directory in "${path[@]}"; do
        [[ -n "$directory" ]] || directory='.'
        [[ -d "$directory" && -r "$directory" ]] || continue
        names+=( "$directory"/*(N-*:t) )
    done

    # Include explicit hash entries and shell builtins. These may not correspond
    # to files currently visible in PATH.
    if (( ${+commands} )); then
        names+=( "${(@k)commands}" )
    fi
    if (( ${+builtins} )); then
        names+=( "${(@k)builtins}" )
    fi

    _DOTS_COMMAND_SUGGESTION_CACHE_NAMES=( "${names[@]}" )
    _DOTS_COMMAND_SUGGESTION_CACHE_PATH="$PATH"
    _DOTS_COMMAND_SUGGESTION_CACHE_READY=1
}

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

    # The caller only needs to know whether the distance is within its small
    # threshold. A banded optimal-string-alignment DP computes only 2k+1 cells
    # per row instead of the full left_length * right_length matrix.
    if (( left_length > right_length + limit || right_length > left_length + limit )); then
        REPLY=$sentinel
        return 0
    fi

    # DP row zero: D[0][j] = j, but cells outside the edit-distance band are
    # represented by the sentinel (limit + 1).
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

            # Count one adjacent transposition as a single edit (e.g. gti -> git).
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

    local command="${1-}"
    local name entry
    _DOTS_COMMAND_SUGGESTION_RESULTS=()
    local -i max_distance max_results=5
    local -aU names
    local -a ranked suggestions

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

    # Rebuild only when PATH changes. Functions are added dynamically on every
    # lookup so interactive helpers defined after startup remain discoverable.
    if (( ! _DOTS_COMMAND_SUGGESTION_CACHE_READY )) ||
        [[ "$_DOTS_COMMAND_SUGGESTION_CACHE_PATH" != "$PATH" ]]; then
        _dots_command_suggestion_refresh_cache
    fi

    names=( "${_DOTS_COMMAND_SUGGESTION_CACHE_NAMES[@]}" )
    if (( ${+functions} )); then
        names+=( "${(@k)functions}" )
    fi
    if (( ${+commands} )); then
        names+=( "${(@k)commands}" )
    fi
    if (( ${+builtins} )); then
        names+=( "${(@k)builtins}" )
    fi

    for name in "${names[@]}"; do
        [[ -n "$name" && "$name" != _* && "$name" != "$command" ]] || continue

        _dots_command_suggestion_distance "$command" "$name" "$max_distance"
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

    _DOTS_COMMAND_SUGGESTION_RESULTS=("${suggestions[@]}")
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

    # In scripts, pipelines, and non-interactive shells, only print useful
    # suggestions. Never block waiting for input that may not exist.
    if [[ ! -o interactive || ! -r /dev/tty ]]; then
        print -u2 -- "Possible corrections for '$command':"
        for selected in "${suggestions[@]}"; do
            print -u2 -- "  - $selected"
        done
        REPLY=""
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
