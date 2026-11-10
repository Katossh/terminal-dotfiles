# Shared message rendering for interactive Zsh command failures.
#
# This module deliberately does not detect failures or install shell hooks.
# Source it from .zshrc when the failure handler is ready to call
# dots_failure_message CATEGORY COMMAND [DETAIL].
#
# Optional user configuration:
#   DOTS_FAILURE_MESSAGE_CHANCE=100       # 0..100; percentage of failures shown
#   DOTS_FAILURE_STYLE=auto              # normal|anime|ecchi|sarcastic|dramatic|rainbow
#   DOTS_FAILURE_RAINBOW_CHANCE=2         # 0..100; DOTS_FAILURE_RARE_CHANCE remains an alias
#   DOTS_FAILURE_ANIMATION_CHANCE=50      # 0..100; animations require an interactive TTY
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

    local message="${1-}"
    # Rainbow ANSI output is useful only on a colour-capable interactive
    # terminal. Redirected output and NO_COLOR stay plain and copyable.
    if [[ ! -t 1 || -n "${NO_COLOR:-}" || "${TERM:-dumb}" == dumb ]]; then
        print -r -- "$message"
        return 0
    fi

    # Twelve RGB stops add pink, teal, indigo, and warm sunset tones.
    local -a characters colors
    characters=( "${(@s::)message}" )
    colors=(
        $'\e[38;2;255;92;124m'
        $'\e[38;2;255;146;93m'
        $'\e[38;2;255;207;102m'
        $'\e[38;2;190;230;105m'
        $'\e[38;2;91;218;151m'
        $'\e[38;2;68;211;205m'
        $'\e[38;2;92;190;255m'
        $'\e[38;2;112;145;255m'
        $'\e[38;2;157;125;255m'
        $'\e[38;2;206;124;255m'
        $'\e[38;2;255;122;211m'
        $'\e[38;2;255;165;190m'
    )

    local character
    local -i index=$(( (RANDOM % ${#colors[@]}) + 1 ))
    for character in "${characters[@]}"; do
        print -rn -- "${colors[index]}${character}"
        (( index = index % ${#colors[@]} + 1 ))
    done
    print -r -- $'\e[0m'
}

_dots_failure_message_animate() {
    emulate -L zsh

    # Queue the effect for the next ZLE session. This module is loaded
    # from the interactive shell configuration; TTY checks belong in ZLE.
    # The animation itself is asynchronous and never sleeps in precmd.
    [[ "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    typeset -gi _DOTS_FAILURE_ANIMATION_PENDING=1
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
    local animation_chance="${DOTS_FAILURE_ANIMATION_CHANCE:-50}"
    case "$chance" in
        (''|*[!0-9]*) chance=100 ;;
    esac
    case "$rainbow_chance" in
        (''|*[!0-9]*) rainbow_chance=2 ;;
    esac
    case "$animation_chance" in
        (''|*[!0-9]*) animation_chance=50 ;;
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
    local red='' green='' yellow='' blue='' magenta='' cyan='' purple='' dim=''
    local orange='' pink='' rose='' gold='' lime='' teal='' sky='' violet='' lavender='' coral=''
    local reset=''
    if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
        red=$'\e[38;2;248;113;113m'
        green=$'\e[38;2;134;239;172m'
        yellow=$'\e[38;2;253;224;71m'
        blue=$'\e[38;2;147;197;253m'
        magenta=$'\e[38;2;240;171;252m'
        cyan=$'\e[38;2;103;232;249m'
        purple=$'\e[38;2;196;181;253m'
        dim=$'\e[38;2;161;161;170m'
        orange=$'\e[38;2;253;186;116m'
        pink=$'\e[38;2;249;168;212m'
        rose=$'\e[38;2;253;164;175m'
        gold=$'\e[38;2;250;204;21m'
        lime=$'\e[38;2;190;242;100m'
        teal=$'\e[38;2;94;234;212m'
        sky=$'\e[38;2;125;211;252m'
        violet=$'\e[38;2;167;139;250m'
        lavender=$'\e[38;2;221;214;254m'
        coral=$'\e[38;2;251;113;133m'
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
                "${teal}🧩 The command registry has no entry for \"${command}\". Check spelling and PATH.${reset}"
                "${orange}🦊 \"${command}\" tried to sneak past PATH. The gatekeeper noticed.${reset}"
                "${pink}💭 Perhaps \"${command}\" is an alias in another shell. Not this one, though.${reset}"
                "${sky}🛰️ The shell sent a lookup request for \"${command}\". Space returned silence.${reset}"
                "${lime}🔍 Searched the executable trail for \"${command}\". No tracks found.${reset}"
                "${rose}🪄 \"${command}\" has not been summoned. Install it or check your spelling.${reset}"
                "${gold}📚 The command index has a blank page where \"${command}\" should be.${reset}"
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
                "${orange}🔑 \"${command}\" needs a key you have not presented.${reset}"
                "${pink}🚫 The kernel declined \"${command}\". Your enthusiasm is not a capability.${reset}"
                "${teal}🧰 Check execute bits, ownership, and mount options for \"${command}\".${reset}"
                "${lavender}🧱 \"${command}\" reached a locked door. The filesystem is enforcing the rules.${reset}"
                "${gold}🔐 Permission denied for \"${command}\". chmod alone will not fix ownership.${reset}"
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
                "${teal}🗂️ \"${command}\" is not in this directory. Verify the relative path.${reset}"
                "${orange}🧭 The path \"${command}\" led us nowhere. Check every component.${reset}"
                "${pink}🪟 Looking for \"${command}\" through the filesystem window. No such view exists.${reset}"
                "${lime}🌱 The requested location \"${command}\" has not sprouted here.${reset}"
                "${lavender}🧵 One path component is missing from \"${command}\". Follow the trail above.${reset}"
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
                "${green}🌱 Another Git plot twist while running \"${command}\". Inspect the diff before the next act.${reset}"
                "${teal}🪴 Git left a note about \"${command}\". Read status before changing anything else.${reset}"
                "${orange}🦊 The branch is playing hide-and-seek with \"${command}\".${reset}"
                "${pink}🧵 A loose thread in the repository interrupted \"${command}\". Inspect the diff.${reset}"
                "${sky}🧭 Git knows where you are; it just disagrees with where \"${command}\" wants to go.${reset}"
                "${lime}🌿 \"${command}\" stumbled over repository state. Check staged and unstaged changes.${reset}"
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
                "${blue}🧊 \"${command}\" hit an immutable store and an unhelpful evaluation error.${reset}"
                "${teal}🧬 Nix evaluated \"${command}\" and found a dependency-shaped paradox.${reset}"
                "${orange}🦊 A mischievous flake disturbed \"${command}\". Inspect the evaluation trace.${reset}"
                "${pink}🪄 The derivation for \"${command}\" did not materialise. The store remains immutable.${reset}"
                "${sky}🧊 \"${command}\" is frozen at evaluation. Read the first meaningful error, not just the last line.${reset}"
                "${lime}🌱 The build graph for \"${command}\" has a missing branch. Check inputs and outputs.${reset}"
                "${lavender}📦 The Nix store cannot provide what \"${command}\" requested.${reset}"
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
                "${cyan}🪫 The network connection ran out of answers during \"${command}\". Check DNS and routing.${reset}"
                "${orange}🦊 Network DNS may be sending \"${command}\" on a wild goose chase.${reset}"
                "${pink}🪁 The network remote endpoint let go while \"${command}\" was running.${reset}"
                "${sky}🌧️ A network timeout interrupted \"${command}\". Check latency before retrying.${reset}"
                "${teal}🧭 Inspect the network DNS, proxy, VPN, and gateway route after \"${command}\" failed.${reset}"
                "${violet}📶 Network signal dropped during \"${command}\". That host may still be offline.${reset}"
                "${gold}🛰️ Network request for \"${command}\" left the terminal, but no reply came back.${reset}"
            )
            repeat_messages=(
                "${yellow}The network has not recovered since the last attempt. Check connectivity before retrying.${reset}"
                "${cyan}The network still has no signal for \"${command}\". Repeating the request won't repair DNS or routing.${reset}"
                "${purple}The network remote remains unreachable. Inspect the connection details above.${reset}"
            )
            severe_messages=(
                "${red}The network is still unavailable. Repeating \"${command}\" is not a connectivity test.${reset}"
                "${red}The network signal has failed again. Check DNS, routing, proxy/VPN, and remote availability.${reset}"
                "${red}${username}, the network is not going to reconnect out of embarrassment.${reset}"
            )
            ;;
        generic)
            messages=(
                "${yellow}⚠️ Command \"${command}\" failed. The terminal expected a different outcome.${reset}"
                "${purple}💥 Something went sideways while running \"${command}\".${reset}"
                "${cyan}The operation \"${command}\" did not go according to plan.${reset}"
                "${blue}🛰️ Mission control reports that \"${command}\" did not complete successfully.${reset}"
                "${yellow}🧯 \"${command}\" needs a rethink, not another identical attempt.${reset}"
                "${cyan}🧪 The terminal recorded a failed experiment: \"${command}\".${reset}"
                "${orange}🧯 \"${command}\" needs a diagnosis, not a dramatic reboot.${reset}"
                "${pink}🧵 Something in \"${command}\" came undone. The error above may show which thread.${reset}"
                "${teal}🔬 \"${command}\" failed under observation. Inspect its exit status and stderr.${reset}"
                "${sky}🧭 Wrong turn, \"${command}\". The shell kept the receipt.${reset}"
                "${lime}🧰 A tool in the workflow is missing, misconfigured, or having a day.${reset}"
                "${violet}🎲 \"${command}\" rolled a critical failure. The logs contain the actual numbers.${reset}"
                "${gold}🪄 No amount of terminal magic can replace reading the error above.${reset}"
                "${coral}🧨 \"${command}\" made an unexpected exit. Let's not make it a tradition.${reset}"
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
    local -i automatic_style=0
    case "$selected_style" in
        auto|normal|anime|ecchi|sarcastic|dramatic|rainbow) ;;
        *) selected_style=auto ;;
    esac

    if [[ "$selected_style" == auto ]]; then
        automatic_style=1
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

    # Most automatic anime appearances use the adult, flirty ecchi pool;
    # traditional anime archetypes remain available as a distinct override.
    if (( automatic_style )) && [[ "$selected_style" == anime ]] && (( RANDOM % 100 < 65 )); then
        selected_style=ecchi
    fi

    local -i rainbow_output=0
    local -a style_messages
    case "$selected_style" in
        normal)
            # Keep the existing category-aware messages and escalation pools.
            ;;
        anime)
            style_messages=(
                "${magenta}💢 B-baka! \"${command}\" isn't a command! It's not like I wanted you to type something else! ${username}, honestly! ${reset}"
                "${cyan}⚡ \"${command}\" has not awakened its true form. Check the spellbook above! ${reset}"
                "${purple}🜂 The forbidden incantation \"${command}\" has no place in this realm. ${reset}"
                "${yellow}✨ By the power of PATH, I reject \"${command}\"! ${reset}"
                "${magenta}🐾 Nyaa~ \"${command}\" is missing. Did you summon the wrong familiar? ${reset}"
                "${cyan}🌙 Even the stars cannot resolve \"${command}\" in this timeline. ${reset}"
                "${red}🔥 \"${command}\" has reached its final form: not executable. ${reset}"
                "${purple}🌀 A space-time anomaly detected: \"${command}\" does not exist here! ${reset}"
                "${blue}🎴 The PATH card for \"${command}\" has been drawn. It says: \"try another command.\" ${reset}"
                "${yellow}💫 Senpai, \"${command}\" is not in the command registry. ${reset}"
                "${sky}🪽 The familiar searched every directory. \"${command}\" is nowhere to be found. ${reset}"
                "${violet}🔮 The oracle foresaw this typo, but not a command named \"${command}\". ${reset}"
                "${teal}🐉 \"${command}\" challenged the shell dragon and lost. ${reset}"
                "${pink}🎀 A little sparkle won't make \"${command}\" executable. Try again, senpai. ${reset}"
                "${orange}🍡 The command shrine has no offering for \"${command}\". ${reset}"
                "${lime}🌸 The spell is almost right. The command \"${command}\" is not. ${reset}"
            )
            messages=("${style_messages[@]}")
            ;;
        ecchi)
            # Adult-coded anime humour with deliberately varied voices and openings.
            # Keep it playful and suggestive, without explicit content or school-age characters.
            style_messages=(
                "${pink}🐾 Nyaa~ \"${command}\" face-planted in front of the whole terminal. Check stderr, senpai. ${reset}"
                "${rose}Well, well... that was quite an entrance. Too bad \"${command}\" forgot to stick the landing. ${reset}"
                "${coral}💋 Darling, a non-zero exit code is hardly a love letter. Read the error above. ${reset}"
                "${magenta}A velvet-gloved hand points at stderr. \"Start there, sweetheart.\" ${reset}"
                "${yellow}Oh? That was your grand finale? The terminal seems unconvinced. ${reset}"
                "${violet}👠 The vampire countess taps one heel: \"Try that again after reading the logs.\" ${reset}"
                "${pink}\"Mmm... ambitious.\" The adult catgirl folds her arms. \"Now fix the command, nyaa~\" ${reset}"
                "${teal}😼 Purrhaps inspect the flags before sending \"${command}\" back into battle. ${reset}"
                "${purple}A succubus has reviewed the output. Her verdict: less confidence, more debugging. ${reset}"
                "${orange}🍷 \"${command}\" is off tonight's menu, darling. Check the failure details first. ${reset}"
                "${lime}🦊 The kitsune hostess fans herself with nine tails. \"That error is entirely yours, senpai.\" ${reset}"
                "${gold}\"Senpai, senpai...\" The adult anime diva sighs. \"Even I cannot flirt with that exit code.\" ${reset}"
                "${rose}The night-club sorceress dims the lights. The error message remains painfully readable. ${reset}"
                "${coral}🥀 Such elegance, such confidence, such a spectacularly unhelpful result. Inspect the output. ${reset}"
                "${lavender}🔮 The oracle has seen your next move: reading the first error instead of retrying blindly. ${reset}"
                "${pink}With a lazy smile, the gothic enchantress asks: \"Did you really expect that to work?\" ${reset}"
                "${purple}🖤 The succubus is on strike until somebody checks the logs. ${reset}"
                "${rose}🫦 \"Careful, darling. The terminal remembers every failed attempt.\" ${reset}"
                "${sky}\"Try again?\" The mature witch raises an eyebrow. \"Try understanding it first.\" ${reset}"
                "${orange}A mature kitsune gives one tail a flick: \"Check the arguments, then come back.\" ${reset}"
                "${gold}⚡ The demon queen snaps her fingers. Nothing happens. \"Well? Read the error.\" ${reset}"
                "${magenta}💄 The femme-fatale hacker fixes her lipstick. \"The bug is still there, darling.\" ${reset}"
                "${cyan}Nocturnal verdict: \"${command}\" needs attention. The eyeliner, at least, is flawless. ${reset}"
                "${pink}🎀 A wink, a smirk, and a reminder: the useful clue is probably in stderr. ${reset}"
                "${teal}\"That flag was a choice, sweetheart.\" The adult enchantress gestures toward the usage text. ${reset}"
                "${red}🔥 The fire mage's spell fizzles. \"Even magic cannot replace a proper backtrace.\" ${reset}"
                "${violet}Another failed incantation. The adult sorceress suggests checking the first error line. ${reset}"
                "${coral}The demon queen looks over your shoulder. \"You did read the output, didn't you?\" ${reset}"
                "${pink}💞 Nyaa~ even my nine tails can't untangle this one. Let's inspect the logs together. ${reset}"
                "${green}You brought the confidence; the terminal brought the evidence. Guess which one won? ${reset}"
                "${rose}A rose falls onto the keyboard. The error remains. How stubbornly unromantic. ${reset}"
                "${magenta}\"Darling, the answer is above us.\" The vampire countess points at the terminal output. ${reset}"
                "${blue}🦇 The countess has no reflection, but this failure is staring right back at you. ${reset}"
                "${orange}A knowing wink from the adult kitsune: \"One careful diagnosis, then another attempt.\" ${reset}"
                "${lavender}The prompt is not your accomplice, sweetheart. Check the command and its arguments. ${reset}"
                "${cyan}Nyaa~ the terminal hissed, the cursor blinked, and your command still needs debugging. ${reset}"
            )
            messages=("${style_messages[@]}")
            ;;
        sarcastic)
            style_messages=(
                "${yellow}🫠 \"${command}\" failed. Bold strategy. Let's see if reading the error helps. ${reset}"
                "${dim}I would explain why \"${command}\" failed, but the terminal already did that above. ${reset}"
                "${purple}I've seen more convincing attempts than \"${command}\" on a broken keyboard. ${reset}"
                "${cyan}☕ \"${command}\" has once again chosen the difficult path. ${reset}"
                "${yellow}404: command not found. Your confidence, however, remains available. ${reset}"
                "${magenta}🤷 The command was so creative that even PATH couldn't recognize \"${command}\". ${reset}"
                "${blue}Perhaps try a command other than \"${command}\" from this dimension next time. ${reset}"
                "${red}🧯 Repeating the same failed command \"${command}\" is not what we call troubleshooting. ${reset}"
            )
            messages=("${style_messages[@]}")
            ;;
        dramatic)
            style_messages=(
                "${red}☠️ The PATH has spoken. It says no to \"${command}\". ${reset}"
                "${purple}A darkness has fallen upon your PATH. \"${command}\" is missing. ${reset}"
                "${red}⚔️ \"${command}\" has fallen before the shell. Its quest ends here. ${reset}"
                "${magenta}The terminal searched every corner for \"${command}\". Nothing answered. ${reset}"
                "${yellow}🎭 Thus concludes the tragic tale of \"${command}\". ${reset}"
                "${cyan}The failure of \"${command}\" was foretold. The output above contains the prophecy. ${reset}"
            )
            messages=("${style_messages[@]}")
            ;;
        rainbow)
            rainbow_output=1
            style_messages=(
                "🌈 \"${command}\" has entered its fabulous failure era. ✨"
                "🌈 The PATH is a spectrum. \"${command}\" is still missing. 🦄"
                "✨ The failure of \"${command}\" is brought to you in glorious 24-bit colour. 🌈"
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
