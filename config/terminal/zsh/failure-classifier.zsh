# Conservative classifier for failed interactive commands.
#
# Public interface:
#   dots_classify_failure COMMAND_TEXT EXIT_STATUS
#
# The function sets the global Zsh parameter REPLY to one of:
#   none, not_found, permission, missing_path, git, nix, network, generic
#
# It returns 0 when classification completed and 2 for invalid arguments.
# It never executes the supplied command or evaluates its text.
#
# This module intentionally does not inspect stderr. Exit statuses and command
# names alone cannot reliably distinguish every failure; uncertain cases stay
# in the generic category.

dots_classify_failure() {
    emulate -L zsh

    REPLY=unknown

    if (( $# != 2 )); then
        return 2
    fi

    local command_text="$1"
    local exit_status="$2"

    # Zsh exit statuses are decimal integers in the range 0..255.
    if [[ "$exit_status" != <-> ]]; then
        return 2
    fi

    local -i exit_status_num=$(( 10#$exit_status ))

    if (( exit_status_num > 255 )); then
        return 2
    fi

    if (( exit_status_num == 0 )); then
        REPLY=none
        return 0
    fi

    # These are conventional shell statuses. A program can deliberately
    # return them too, so they are useful heuristics rather than proof.
    case "$exit_status_num" in
        126)
            REPLY=permission
            return 0
            ;;
        127)
            REPLY=not_found
            return 0
            ;;
    esac

    # (z) performs shell-word parsing only; it does not evaluate expansions,
    # substitutions, redirections, or command substitutions.
    local -a words
    words=( "${(@z)command_text}" )

    if (( ${#words} == 0 )); then
        REPLY=generic
        return 0
    fi

    local -i command_index=1
    local -i word_count=${#words}

    # Skip leading environment assignments, e.g. FOO=bar git status.
    while (( command_index <= word_count )); do
        if [[ "${words[command_index]}" =~ '^[A-Za-z_][A-Za-z0-9_]*=' ]]; then
            (( command_index += 1 ))
        else
            break
        fi
    done

    # Unwrap common transparent command launchers. Deliberately avoid trying
    # to parse every option accepted by every wrapper.
    while (( command_index <= word_count )); do
        case "${words[command_index]}" in
            command|exec|builtin|noglob|nocorrect|time|nohup)
                (( command_index += 1 ))
                ;;
            sudo|doas)
                (( command_index += 1 ))
                while (( command_index <= word_count )); do
                    case "${words[command_index]}" in
                        --)
                            (( command_index += 1 ))
                            break
                            ;;
                        -u|-g|-h|-p|-C|-D|-R|-T|-r|-t|-U|--user|--group|--host|--prompt|--close-from|--chdir|--chroot|--command-timeout|--role|--type|--other-user)
                            (( command_index += 2 ))
                            ;;
                        -*)
                            (( command_index += 1 ))
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                ;;
            env)
                (( command_index += 1 ))
                while (( command_index <= word_count )); do
                    case "${words[command_index]}" in
                        --)
                            (( command_index += 1 ))
                            break
                            ;;
                        -i|-0|--ignore-environment|--null)
                            (( command_index += 1 ))
                            ;;
                        -u|--unset|-C|--chdir|-S|--split-string)
                            (( command_index += 2 ))
                            ;;
                        -*|[A-Za-z_][A-Za-z0-9_]*=*)
                            (( command_index += 1 ))
                            ;;
                        *)
                            break
                            ;;
                    esac
                done
                ;;
            *)
                break
                ;;
        esac
    done

    if (( command_index > word_count )); then
        REPLY=generic
        return 0
    fi

    local command_name="${words[command_index]##*/}"

    # Missing-path classification is intentionally narrow. Only a literal,
    # unambiguous path passed directly to cd is checked. Variables, command
    # substitutions, globs, and option-like operands are not interpreted.
    if [[ "$command_name" == cd ]]; then
        local target=""
        local target_path=""
        local -i target_index=$(( command_index + 1 ))

        while (( target_index <= word_count )); do
            case "${words[target_index]}" in
                --)
                    (( target_index += 1 ))
                    if (( target_index <= word_count )); then
                        target="${words[target_index]}"
                    fi
                    break
                    ;;
                -L|-P)
                    (( target_index += 1 ))
                    ;;
                -)
                    break
                    ;;
                -*)
                    # Unknown option: do not guess what the operand means.
                    break
                    ;;
                *)
                    target="${words[target_index]}"
                    break
                    ;;
            esac
        done

        if [[ -n "$target" ]] &&
            [[ "$target" != *'$'* ]] &&
            [[ "$target" != *'\x60'* ]] &&
            [[ "$target" != *'*'* ]] &&
            [[ "$target" != *'?'* ]] &&
            [[ "$target" != *'['* ]]; then
            case "$target" in
                '~')
                    target_path="$HOME"
                    ;;
                '~/'*)
                    target_path="$HOME/${target#\~/}"
                    ;;
                *)
                    target_path="$target"
                    ;;
            esac

            if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
                REPLY=missing_path
                return 0
            fi
        fi
    fi

    # Network-related curl statuses documented by curl:
    # 5 proxy DNS, 6 host DNS, 7 connect, 28 timeout.
    # wget uses status 4 for network failure.
    case "$command_name:$exit_status_num" in
        curl:5|curl:6|curl:7|curl:28|wget:4)
            REPLY=network
            return 0
            ;;
    esac

    case "$command_name" in
        git|hub|gh)
            REPLY=git
            ;;
        nix|nix-build|nix-shell|nix-env|nix-store|nix-channel|nixos-rebuild|nix-prefetch-url|nix-copy-closure)
            REPLY=nix
            ;;
        *)
            REPLY=generic
            ;;
    esac

    return 0
}
