# Shared message rendering for interactive Zsh command failures.
#
# This module deliberately does not detect failures or install shell hooks.
# Source it from .zshrc when the failure handler is ready to call
# dots_failure_message CATEGORY COMMAND [DETAIL].
#
# Optional user configuration:
#   DOTS_FAILURE_MESSAGE_CHANCE=100       # 0..100; percentage of failures shown
#   DOTS_FAILURE_RARE_CHANCE=3            # 0..100; chance of a rare message
#   DOTS_FAILURE_MESSAGE_ESCALATION=1     # set to 0 to disable repeat escalation
#   NO_COLOR=1                            # disable ANSI colours

typeset -g _DOTS_FAILURE_MESSAGE_LAST_KEY=''
typeset -g _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE=''
typeset -gi _DOTS_FAILURE_MESSAGE_STREAK=0

dots_failure_message() {
    emulate -L zsh
    setopt localoptions no_aliases

    local category="${1:-generic}"
    category="${category:l}"
    local command="${2:-unknown}"
    local detail="${3:-}"
    local username="${USER:-${LOGNAME:-user}}"

    # Keep caller-provided text on one line and prevent it from injecting
    # terminal control sequences into the message.
    command="${command//$'\e'/}"
    command="${command//$'\n'/ }"
    command="${command//$'\r'/ }"
    detail="${detail//$'\e'/}"
    detail="${detail//$'\n'/ }"
    detail="${detail//$'\r'/ }"
    username="${username//$'\e'/}"
    username="${username//$'\n'/ }"
    username="${username//$'\r'/ }"

    case "$category" in
        not_found|permission|missing_path|git|nix|generic) ;;
        *) category=generic ;;
    esac

    # Validate percentages before using them in arithmetic expressions.
    local chance="${DOTS_FAILURE_MESSAGE_CHANCE:-100}"
    local rare_chance="${DOTS_FAILURE_RARE_CHANCE:-3}"
    case "$chance" in
        (''|*[!0-9]*) chance=100 ;;
    esac
    case "$rare_chance" in
        (''|*[!0-9]*) rare_chance=3 ;;
    esac
    # Strip leading zeroes so values such as 08 remain decimal in arithmetic.
    while [[ "$chance" == 0* && "$chance" != 0 ]]; do
        chance="${chance#0}"
    done
    while [[ "$rare_chance" == 0* && "$rare_chance" != 0 ]]; do
        rare_chance="${rare_chance#0}"
    done
    (( chance > 100 )) && chance=100
    (( rare_chance > 100 )) && rare_chance=100
    if (( chance == 0 || RANDOM % 100 >= chance )); then
        return 0
    fi

    # Respect NO_COLOR and avoid emitting escape sequences into redirected
    # output, logs, or tests.
    local red='' green='' yellow='' blue='' magenta='' cyan='' purple='' dim='' reset=''
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        red=$'\e[31m'
        green=$'\e[32m'
        yellow=$'\e[33m'
        blue=$'\e[34m'
        magenta=$'\e[35m'
        cyan=$'\e[36m'
        purple=$'\e[38;5;141m'
        dim=$'\e[2m'
        reset=$'\e[0m'
    fi

    local failure_key="${category}:${command}"
    if [[ "$_DOTS_FAILURE_MESSAGE_LAST_KEY" == "$failure_key" ]]; then
        _DOTS_FAILURE_MESSAGE_STREAK=$((_DOTS_FAILURE_MESSAGE_STREAK + 1))
    else
        _DOTS_FAILURE_MESSAGE_LAST_KEY="$failure_key"
        _DOTS_FAILURE_MESSAGE_STREAK=1
    fi

    local escalation=1
    case "${DOTS_FAILURE_MESSAGE_ESCALATION:-1}" in
        0|false|no|off) escalation=0 ;;
    esac

    local -a messages
    local -a repeat_messages
    local -a severe_messages

    case "$category" in
        not_found)
            messages=(
                "${red}👾 Warning! A cyber anomaly named \"${command}\" has disrupted the matrix, ${magenta}${username}${red}.${reset}"
                "${cyan}📡 Signal lost: \"${command}\" does not exist in this shell's reality.${reset}"
                "${purple}🛸 Command \"${command}\" was not found. Perhaps it escaped the simulation.${reset}"
                "${yellow}🔎 No trace of \"${command}\" could be found. The search party has been dismissed.${reset}"
            )
            repeat_messages=(
                "${yellow}Still looking for \"${command}\"? The matrix insists it is not real.${reset}"
                "${cyan}We searched again. \"${command}\" remains missing, ${username}.${reset}"
                "${purple}A second transmission confirms that \"${command}\" is still not a command.${reset}"
            )
            severe_messages=(
                "${red}I admire your persistence, ${username}. \"${command}\" is still imaginary.${reset}"
                "${red}The anomaly is now ignoring us. Stop asking for \"${command}\".${reset}"
                "${red}At this point, \"${command}\" appears to be a personal project. It still does not exist.${reset}"
            )
            ;;
        permission)
            messages=(
                "${red}⛔ Access denied. \"${command}\" is beyond your current clearance.${reset}"
                "${yellow}🔒 The system refused \"${command}\". Your credentials did not impress it.${reset}"
                "${purple}🚧 Permission denied. This door is not opening for ${username} today.${reset}"
            )
            repeat_messages=(
                "${yellow}The access policy has not changed since your last attempt.${reset}"
                "${cyan}Still no clearance for \"${command}\". Asking again rarely helps.${reset}"
                "${purple}The system has reviewed your request twice. The answer remains no.${reset}"
            )
            severe_messages=(
                "${red}Persistence is not a permission bit, ${username}.${reset}"
                "${red}You have been denied so consistently that it is becoming a system feature.${reset}"
                "${red}The lock is not confused. It knows exactly who you are.${reset}"
            )
            ;;
        missing_path)
            messages=(
                "${yellow}🗺️ Destination not found: \"${command}\" appears to exist only in your imagination.${reset}"
                "${cyan}📁 The requested path \"${command}\" has vanished into the filesystem fog.${reset}"
                "${purple}No such location as \"${command}\". Check the map, explorer.${reset}"
            )
            repeat_messages=(
                "${yellow}The path \"${command}\" has not materialised on the second attempt.${reset}"
                "${cyan}We checked again. That destination is still missing.${reset}"
                "${purple}Perhaps the directory is hiding. Or perhaps the path is wrong.${reset}"
            )
            severe_messages=(
                "${red}The filesystem has confirmed: \"${command}\" is not here. Repeating the search won't summon it.${reset}"
                "${red}Three expeditions, zero directories. Reconsider the coordinates.${reset}"
                "${red}Your map is fictional, ${username}. The path is still missing.${reset}"
            )
            ;;
        git)
            messages=(
                "${green}🌿 Git has encountered a plot twist while running \"${command}\".${reset}"
                "${yellow}🧩 The repository disagrees with \"${command}\". Check its current state.${reset}"
                "${purple}Your branch has entered an existential crisis. Git rejected \"${command}\".${reset}"
            )
            repeat_messages=(
                "${yellow}The repository has not changed its mind about \"${command}\".${reset}"
                "${cyan}Another Git failure. Perhaps inspect the branch before trying again.${reset}"
                "${purple}Git remembers what happened last time. Apparently, so should we.${reset}"
            )
            severe_messages=(
                "${red}The repository is still unhappy. Repeating \"${command}\" is not a recovery strategy.${reset}"
                "${red}Your Git history is acquiring more drama than useful commits.${reset}"
                "${red}The branch has filed another complaint against ${username}.${reset}"
            )
            ;;
        nix)
            messages=(
                "${blue}❄️ The derivation has rejected your offering: \"${command}\".${reset}"
                "${cyan}Nix could not complete \"${command}\". The store remains unimpressed.${reset}"
                "${purple}A flake of uncertainty has interrupted \"${command}\".${reset}"
            )
            repeat_messages=(
                "${yellow}The Nix evaluation still disagrees. Check the error above before rebuilding.${reset}"
                "${cyan}Another failed derivation. The store is not going to fix itself.${reset}"
                "${purple}Have you checked the inputs, outputs, and current working tree?${reset}"
            )
            severe_messages=(
                "${red}The derivation has rejected the same offering again. Read the trace, ${username}.${reset}"
                "${red}Nix has made its position clear. Repeating the build is not new information.${reset}"
                "${red}The store has seen enough. Time to inspect the actual evaluation error.${reset}"
            )
            ;;
        generic)
            messages=(
                "${yellow}⚠️ Command \"${command}\" failed. The terminal expected a different outcome.${reset}"
                "${purple}💥 Something went sideways while running \"${command}\".${reset}"
                "${cyan}The operation \"${command}\" did not go according to plan.${reset}"
                "${blue}🛰️ Mission control reports that \"${command}\" did not complete successfully.${reset}"
            )
            repeat_messages=(
                "${yellow}That did not work the first time. The second attempt has not helped.${reset}"
                "${cyan}The same failure again. The output above may contain a useful clue.${reset}"
                "${purple}Repeating \"${command}\" produced the same disappointing result.${reset}"
            )
            severe_messages=(
                "${red}We have established that \"${command}\" is still failing. Consider changing the approach.${reset}"
                "${red}This is no longer a surprise. It is a pattern.${reset}"
                "${red}${username}, the command has failed again. Perhaps read what it told you.${reset}"
            )
            ;;
    esac

    if (( escalation )); then
        if (( _DOTS_FAILURE_MESSAGE_STREAK >= 3 )); then
            messages=("${severe_messages[@]}")
        elif (( _DOTS_FAILURE_MESSAGE_STREAK == 2 )); then
            messages=("${repeat_messages[@]}")
        fi
    fi

    # Rare lines are deliberately infrequent and category-neutral.
    local -a rare_messages=(
        "${purple}🛰️ Unusual telemetry detected. The matrix has logged this incident for further entertainment.${reset}"
        "${cyan}📼 A corrupted transmission reads: \"Have you tried reading the error above?\"${reset}"
        "${yellow}👁️ Something in the terminal is watching this failure counter. Probably just a shell script.${reset}"
    )
    if (( rare_chance > 0 && RANDOM % 100 < rare_chance )); then
        messages=("${rare_messages[@]}")
    fi

    local previous_template="$_DOTS_FAILURE_MESSAGE_LAST_TEMPLATE"
    local selected_template=''
    local index=0
    local attempts=0
    while (( attempts < ${#messages[@]} )); do
        index=$(( (RANDOM % ${#messages[@]}) + 1 ))
        selected_template="${messages[$index]}"
        [[ "$selected_template" != "$previous_template" ]] && break
        attempts=$((attempts + 1))
    done
    _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE="$selected_template"

    printf '%s\n' "$selected_template"
    if [[ -n "$detail" ]]; then
        printf '  %s↳ %s%s\n' "$dim" "$detail" "$reset"
    fi

    # Rendering a message must never replace the failed command's status.
    return 0
}
