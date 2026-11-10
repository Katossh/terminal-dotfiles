# Shared message rendering for interactive Zsh command failures.
#
# This module deliberately does not detect failures or install shell hooks.
# Source it from .zshrc when the failure handler is ready to call
# dots_failure_message CATEGORY COMMAND [DETAIL].
#
# Optional user configuration:
#   DOTS_FAILURE_MESSAGE_CHANCE=100       # 0..100; percentage of failures shown
#   DOTS_FAILURE_STYLE=auto              # normal|anime|sarcastic|dramatic|rainbow
#   DOTS_FAILURE_RAINBOW_CHANCE=2         # 0..100; DOTS_FAILURE_RARE_CHANCE remains an alias
#   DOTS_FAILURE_ANIMATION_CHANCE=4       # 0..100; animations require an interactive TTY
#   DOTS_FAILURE_ANIMATION=0              # disable animation independently
#   DOTS_FAILURE_MESSAGE_ESCALATION=1     # set to 0 to disable repeat escalation
#   NO_COLOR=1                            # disable ANSI colours

typeset -g _DOTS_FAILURE_MESSAGE_LAST_KEY=''
typeset -g _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE=''
typeset -gi _DOTS_FAILURE_MESSAGE_STREAK=0

_dots_failure_message_sanitize() {
    emulate -L zsh

    local value="${1-}"
    REPLY="${value//[[:cntrl:]]/ }"
}


_dots_failure_message_rainbow() {
    emulate -L zsh

    local message="\${1-}"
    # Rainbow ANSI output is useful only on a colour-capable interactive
    # terminal. Redirected output and NO_COLOR stay plain and copyable.
    if [[ ! -t 1 || -n "\${NO_COLOR:-}" || "\${TERM:-dumb}" == dumb ]]; then
        print -r -- "$message"
        return 0
    fi

    local -a characters colors
    characters=( "\${(@s::)message}" )
    colors=(
        $'\e[38;2;255;75;75m'
        $'\e[38;2;255;165;60m'
        $'\e[38;2;245;220;75m'
        $'\e[38;2;90;210;120m'
        $'\e[38;2;80;170;255m'
        $'\e[38;2;185;115;255m'
    )

    local character
    local -i index=1
    for character in "\${characters[@]}"; do
        print -rn -- "\${colors[index]}\${character}"
        (( index = index % \${#colors[@]} + 1 ))
    done
    print -r -- $'\e[0m'
}

_dots_failure_message_animate() {
    emulate -L zsh

    # Never animate redirected logs, CI output, or terminals without cursor
    # control. The short animation is deliberately capped at four frames.
    [[ -t 1 && "\${TERM:-dumb}" != dumb && "\${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local color="\${1-}"
    local reset="\${2-}"
    local frame
    local -a frames=( '✧' '✦' '✨' '✦' )

    for frame in "\${frames[@]}"; do
        printf '\r\033[2K%s%s%s  Consulting the machine spirits...' "$color" "$frame" "$reset"
        command sleep 0.04 2>/dev/null || break
    done
    printf '\r\033[2K'
}

dots_failure_message() {
    emulate -L zsh
    setopt localoptions no_aliases

    local category="${1:-generic}"
    category="${category:l}"
    local command="${2:-unknown}"
    local detail="${3:-}"
    local username="${USER:-${LOGNAME:-user}}"

    # Replace every control character (including BEL, backspace, DEL, and
    # terminal escape bytes) instead of only the common ESC/CR/LF trio.
    _dots_failure_message_sanitize "$command"
    command="$REPLY"
    _dots_failure_message_sanitize "$detail"
    detail="$REPLY"
    _dots_failure_message_sanitize "$username"
    username="$REPLY"

    case "$category" in
        not_found|permission|missing_path|git|nix|network|generic) ;;
        *) category=generic ;;
    esac

    # Validate percentages before using them in arithmetic expressions.
    local chance="${DOTS_FAILURE_MESSAGE_CHANCE:-100}"
    # DOTS_FAILURE_RARE_CHANCE is retained as a backwards-compatible alias.
    local rainbow_chance="${DOTS_FAILURE_RAINBOW_CHANCE:-${DOTS_FAILURE_RARE_CHANCE:-2}}"
    local animation_chance="${DOTS_FAILURE_ANIMATION_CHANCE:-4}"
    case "$chance" in
        (''|*[!0-9]*) chance=100 ;;
    esac
    case "$rainbow_chance" in
        (''|*[!0-9]*) rainbow_chance=2 ;;
    esac
    case "$animation_chance" in
        (''|*[!0-9]*) animation_chance=4 ;;
    esac
    # Strip leading zeroes so values such as 08 remain decimal in arithmetic.
    while [[ "$chance" == 0* && "$chance" != 0 ]]; do
        chance="${chance#0}"
    done
    while [[ "$rainbow_chance" == 0* && "$rainbow_chance" != 0 ]]; do
        rainbow_chance="${rainbow_chance#0}"
    done
    while [[ "$animation_chance" == 0* && "$animation_chance" != 0 ]]; do
        animation_chance="${animation_chance#0}"
    done
    (( chance > 100 )) && chance=100
    (( rainbow_chance > 100 )) && rainbow_chance=100
    (( animation_chance > 100 )) && animation_chance=100
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
    local escalation_setting="${DOTS_FAILURE_MESSAGE_ESCALATION:-1}"
    escalation_setting="${escalation_setting:l}"
    case "$escalation_setting" in
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
                "${blue}🧭 PATH checked. \"${command}\" is still off the map.${reset}"
                "${magenta}✨ \"${command}\" may exist in another universe, but not this shell.${reset}"
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
                "${purple}🚧 Permission denied for \"${command}\". This door is not opening for ${username} today.${reset}"
                "${red}🛡️ \"${command}\" hit a permission wall. Check the owner and mode bits.${reset}"
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
                "${blue}🧭 The filesystem map has no entry for \"${command}\".${reset}"
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
                "${green}🌱 Another Git plot twist. Inspect the diff before the next act.${reset}"
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
                "${blue}🧊 The Nix store remains immutable. The evaluation error, unfortunately, does too.${reset}"
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
        network)
            messages=(
                "${cyan}🌐 The network has gone dark while running \"${command}\". Check the route before blaming the matrix.${reset}"
                "${yellow}📡 Network route unavailable for \"${command}\". DNS, proxy, VPN, or the remote service may be responsible.${reset}"
                "${purple}🛰️ Network signal lost during \"${command}\". The destination has not answered the call.${reset}"
                "${cyan}🪫 The connection ran out of answers. Check DNS and routing.${reset}"
            )
            repeat_messages=(
                "${yellow}The network has not recovered since the last attempt. Check connectivity before retrying.${reset}"
                "${cyan}The network still has no signal for \"${command}\". Repeating the request won't repair DNS or routing.${reset}"
                "${purple}The network remote remains unreachable. Inspect the connection details above.${reset}"
            )
            severe_messages=(
                "${red}The network is still unavailable. Repeating \"${command}\" is not a connectivity test.${reset}"
                "${red}The signal has failed again. Check DNS, routing, proxy/VPN, and remote availability.${reset}"
                "${red}${username}, the network is not going to reconnect out of embarrassment.${reset}"
            )
            ;;
        generic)
            messages=(
                "${yellow}⚠️ Command \"${command}\" failed. The terminal expected a different outcome.${reset}"
                "${purple}💥 Something went sideways while running \"${command}\".${reset}"
                "${cyan}The operation \"${command}\" did not go according to plan.${reset}"
                "${blue}🛰️ Mission control reports that \"${command}\" did not complete successfully.${reset}"
                "${yellow}🧯 That command needs a rethink, not another identical attempt.${reset}"
                "${cyan}🧪 The terminal recorded a failed experiment: \"${command}\".${reset}"
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

    # Pick a style independently of the failure category. The normal pool keeps
    # the useful category-specific wording above; the other pools add personality.
    local selected_style="${DOTS_FAILURE_STYLE:-auto}"
    selected_style="${selected_style:l}"
    case "$selected_style" in
        auto|normal|anime|sarcastic|dramatic|rainbow) ;;
        *) selected_style=auto ;;
    esac

    if [[ "$selected_style" == auto ]]; then
        local -i style_roll=$((RANDOM % 100))
        if (( style_roll < rainbow_chance )); then
            selected_style=rainbow
        elif (( rainbow_chance >= 100 )); then
            selected_style=rainbow
        else
            # Reserve the configured rainbow share, then distribute the rest
            # across the exact 48/28/14/8 proportions.
            style_roll=$(( (style_roll - rainbow_chance) * 98 / (100 - rainbow_chance) ))
            if (( style_roll < 48 )); then
                selected_style=normal
            elif (( style_roll < 76 )); then
                selected_style=anime
            elif (( style_roll < 90 )); then
                selected_style=sarcastic
            else
                selected_style=dramatic
            fi
        fi
    fi

    local -i rainbow_output=0
    local -a style_messages
    case "$selected_style" in
        normal)
            # Keep the existing category-aware messages and escalation pools.
            ;;
        anime)
            style_messages=(
                "${magenta}💢 B-baka! \\"${command}\\" isn't a command! It's not like I wanted you to type something else! ${username}, honestly! ${reset}"
                "${cyan}⚡ \\"${command}\\" has not awakened its true form. Check the spellbook above! ${reset}"
                "${purple}🜂 The forbidden incantation \\"${command}\\" has no place in this realm. ${reset}"
                "${yellow}✨ By the power of PATH, I reject \\"${command}\\"! ${reset}"
                "${magenta}🐾 Nyaa~ \\"${command}\\" is missing. Did you summon the wrong familiar? ${reset}"
                "${cyan}🌙 Even the stars cannot resolve \\"${command}\\" in this timeline. ${reset}"
                "${red}🔥 \\"${command}\\" has reached its final form: not executable. ${reset}"
                "${purple}🌀 A space-time anomaly detected: \\"${command}\\" does not exist here! ${reset}"
                "${blue}🎴 The PATH card has been drawn. It says: \\"try another command.\\" ${reset}"
                "${yellow}💫 Senpai, \\"${command}\\" is not in the command registry. ${reset}"
            )
            messages=("${style_messages[@]}")
            ;;
        sarcastic)
            style_messages=(
                "${yellow}🫠 \\"${command}\\" failed. Bold strategy. Let's see if reading the error helps. ${reset}"
                "${dim}I would explain the error, but the terminal already did that above. ${reset}"
                "${purple}I've seen more convincing commands on a broken keyboard. ${reset}"
                "${cyan}☕ \\"${command}\\" has once again chosen the difficult path. ${reset}"
                "${yellow}404: command not found. Your confidence, however, remains available. ${reset}"
                "${magenta}🤷 The command was so creative that even PATH couldn't recognize it. ${reset}"
                "${blue}Perhaps try a command from this dimension next time. ${reset}"
                "${red}🧯 Repeating the same failed command is not what we call troubleshooting. ${reset}"
            )
            messages=("${style_messages[@]}")
            ;;
        dramatic)
            style_messages=(
                "${red}☠️ The PATH has spoken. It says no to \\"${command}\\". ${reset}"
                "${purple}A darkness has fallen upon your PATH. One command is missing. ${reset}"
                "${red}⚔️ \\"${command}\\" has fallen before the shell. Its quest ends here. ${reset}"
                "${magenta}The terminal searched every corner of this realm. Nothing answered. ${reset}"
                "${yellow}🎭 Thus concludes the tragic tale of \\"${command}\\". ${reset}"
                "${cyan}The error was foretold. The output above contains the prophecy. ${reset}"
            )
            messages=("${style_messages[@]}")
            ;;
        rainbow)
            rainbow_output=1
            style_messages=(
                "🌈 \\"${command}\\" has entered its fabulous failure era. ✨"
                "🌈 The PATH is a spectrum. \\"${command}\\" is still missing. 🦄"
                "✨ This failure is brought to you in glorious 24-bit colour. 🌈"
            )
            messages=("${style_messages[@]}")
            ;;
    esac

    if (( rainbow_output )); then
        _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE=''
    fi


    local previous_template="$_DOTS_FAILURE_MESSAGE_LAST_TEMPLATE"
    local message_count="${#messages[@]}"
    local index=$(( (RANDOM % message_count) + 1 ))
    local selected_template="${messages[$index]}"
    if [[ "$selected_template" == "$previous_template" ]] && (( message_count > 1 )); then
        # Deterministic fallback guarantees that the previous template is
        # not repeated, even if RANDOM produces the same index repeatedly.
        index=$(( (index % message_count) + 1 ))
        selected_template="${messages[$index]}"
    fi
    _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE="$selected_template"

    if (( RANDOM % 100 < animation_chance )); then
        _dots_failure_message_animate "$cyan" "$reset"
    fi

    if (( rainbow_output )); then
        _dots_failure_message_rainbow "$selected_template"
    else
        printf '%s\n' "$selected_template"
    fi
    if [[ -n "$detail" ]]; then
        printf '  %s↳ %s%s\n' "$dim" "$detail" "$reset"
    fi

    # Rendering a message must never replace the failed command's status.
    return 0
}
