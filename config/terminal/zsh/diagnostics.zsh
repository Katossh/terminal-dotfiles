# Explain the most recently completed interactive Zsh command.
#
# Public command:
#   why [--verbose|-v]
#
# Dependencies are optional at source time so this module can be tested and
# loaded independently. The integration layer should source command-state.zsh
# and failure-classifier.zsh before this module.
#
# This command never re-runs the previous command, evaluates its text, or
# attempts to infer stderr that the state tracker does not capture.

_dots_why_clean_text() {
    emulate -L zsh

    local value="${1-}"

    # Commands can contain pasted control characters. Do not let recorded
    # terminal control sequences alter the diagnostic display.
    value="${value//[[:cntrl:]]/ }"

    if (( ${#value} > 240 )); then
        value="${value[1,237]}..."
    fi

    REPLY="$value"
}

_dots_why_age_label() {
    emulate -L zsh

    REPLY=""

    [[ "${DOTS_LAST_TIMESTAMP:-}" == <-> ]] || return 0
    (( ${+EPOCHSECONDS} )) || return 0

    local -i finished_at age_seconds
    finished_at=$DOTS_LAST_TIMESTAMP
    age_seconds=$(( EPOCHSECONDS - finished_at ))

    (( age_seconds < 0 )) && return 0

    if (( age_seconds < 5 )); then
        REPLY="just now"
    elif (( age_seconds < 60 )); then
        REPLY="${age_seconds}s ago"
    elif (( age_seconds < 3600 )); then
        REPLY="$(( age_seconds / 60 ))m ago"
    else
        REPLY="$(( age_seconds / 3600 ))h ago"
    fi
}

_dots_why_fallback_category() {
    emulate -L zsh

    local -i status_code=$1

    case "$status_code" in
        0) REPLY=none ;;
        126) REPLY=permission ;;
        127) REPLY=not_found ;;
        *) REPLY=generic ;;
    esac
}

_dots_why_explain_category() {
    emulate -L zsh

    local category="$1"

    case "$category" in
        none)
            print -- "The command completed successfully. There is no failure to diagnose."
            print -- "Next step: inspect a different command only after running it; this tracker keeps the latest command."
            ;;
        not_found)
            print -- "The shell could not resolve the command name. Exit status 127 usually means command-not-found."
            print -- "Next checks: verify the spelling, run command -v <name>, and inspect PATH."
            print -- "On NixOS, a package may need to be made available through nix shell or the project's nix develop environment."
            ;;
        permission)
            print -- "The command was found but could not be executed, or the process reported a permission failure. Exit status 126 commonly means not executable."
            print -- "Next checks: inspect file permissions with ls -l, the filesystem mount options, and directory traversal permissions."
            print -- "Do not assume sudo is the right fix; first establish which permission check failed."
            ;;
        missing_path)
            print -- "The literal directory passed to cd does not exist at the recorded location."
            print -- "Next checks: run pwd, inspect the parent with ls -la, and verify spelling, case, and whether the directory was moved."
            ;;
        git)
            print -- "A Git-related command returned a non-zero status. The exit code alone cannot identify the exact Git error."
            print -- "Next checks: inspect the command output above, then review git status, the current branch, and the configured remote."
            ;;
        nix)
            print -- "A Nix-related command returned a non-zero status. The exit code alone cannot distinguish evaluation, build, fetch, or activation failures."
            print -- "Next checks: inspect the original Nix error above; for flake evaluation, rerun the relevant check with --show-trace."
            ;;
        network)
            print -- "The network client returned a status commonly associated with DNS, connection, proxy, or timeout failure."
            print -- "Next checks: verify connectivity, DNS resolution, proxy/VPN settings, and whether the remote service is reachable."
            ;;
        interrupted)
            print -- "The command appears to have been interrupted by SIGINT (commonly Ctrl+C)."
            print -- "Next step: decide whether to retry it or inspect what it completed before interruption."
            ;;
        terminated)
            print -- "The command appears to have been terminated by SIGTERM."
            print -- "Next step: check whether a timeout, service manager, or another process requested termination."
            ;;
        killed)
            print -- "The process appears to have received SIGKILL. It could not clean up normally; this status alone does not prove why it was killed."
            print -- "Next checks: inspect system logs and resource pressure if the termination was unexpected."
            ;;
        generic|unknown|*)
            print -- "The command returned a non-zero status, but the available command text and exit code are not enough to identify the cause."
            print -- "Next step: read the command's original output above. This diagnostic does not capture or reconstruct stderr."
            ;;
    esac
}

why() {
    emulate -L zsh
    setopt localoptions no_aliases

    # The state module uses this flag to prevent "why" from replacing the
    # record it is currently explaining when the next prompt is drawn.
    if (( ${+functions[dots_command_state_preserve_previous]} )); then
        dots_command_state_preserve_previous
    fi

    local verbose=0
    local argument

    for argument in "$@"; do
        case "$argument" in
            -v|--verbose)
                verbose=1
                ;;
            -h|--help)
                print -- "Usage: why [--verbose|-v]"
                print -- "Explain the most recently completed interactive Zsh command."
                return 0
                ;;
            *)
                print -u2 -- "why: unknown argument: $argument"
                print -u2 -- "Usage: why [--verbose|-v]"
                return 2
                ;;
        esac
    done

    local command_text="${DOTS_LAST_COMMAND:-}"
    if [[ -z "$command_text" ]]; then
        print -- "No previous interactive command is available."
        print -- "The command-state module must be loaded, and at least one command must have completed."
        return 0
    fi

    local clean_command clean_executed clean_cwd
    _dots_why_clean_text "$command_text"
    clean_command="$REPLY"
    _dots_why_clean_text "${DOTS_LAST_EXECUTED_COMMAND:-}"
    clean_executed="$REPLY"
    _dots_why_clean_text "${DOTS_LAST_CWD:-}"
    clean_cwd="$REPLY"

    local status_text="${DOTS_LAST_STATUS:-0}"
    if [[ "$status_text" != <-> ]] || (( ${#status_text} > 3 )); then
        print -- "The saved command record has an invalid exit status."
        return 0
    fi

    local -i status_code
    status_code=$(( 10#$status_text ))
    if (( status_code > 255 )); then
        print -- "The saved command record has an invalid exit status."
        return 0
    fi

    print -- "Last command: $clean_command"
    print -- "Exit status:  $status_code"

    local age_label
    _dots_why_age_label
    age_label="$REPLY"

    if (( verbose )); then
        [[ -n "$clean_cwd" ]] && print -- "Working dir:  $clean_cwd"
        [[ -n "$clean_executed" && "$clean_executed" != "$clean_command" ]] &&
            print -- "Expanded:     $clean_executed"
        [[ -n "$age_label" ]] && print -- "Completed:    $age_label"
    fi

    if (( status_code == 0 )); then
        print
        _dots_why_explain_category none
        return 0
    fi

    local category=generic
    case "$status_code" in
        130)
            category=interrupted
            ;;
        137)
            category=killed
            ;;
        143)
            category=terminated
            ;;
        *)
            if (( ${+functions[dots_classify_failure]} )); then
                # Prefer the expanded form for aliases and wrappers, but fall
                # back to the exact text entered by the user.
                dots_classify_failure "${clean_executed:-$clean_command}" "$status_code"
                category="${REPLY:-generic}"
            else
                _dots_why_fallback_category "$status_code"
                category="$REPLY"
            fi
            ;;
    esac

    # Accept only the documented classifier values. A malformed or newer
    # classifier result degrades safely to a generic explanation.
    case "$category" in
        none|not_found|permission|missing_path|git|nix|network|generic|interrupted|terminated|killed)
            ;;
        *)
            category=generic
            ;;
    esac

    print
    print -- "Diagnosis ($category)"
    _dots_why_explain_category "$category"

    return 0
}
