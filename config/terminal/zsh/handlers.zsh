command_not_found_handler() {
    local RED='\e[31m'
    local GREEN='\e[32m'
    local YELLOW='\e[33m'
    local BLUE='\e[34m'
    local MAGENTA='\e[35m'
    local CYAN='\e[36m'
    local RESET='\e[0m'
    local GOLD='\e[33m'
    local SILVER='\e[37m'
    local TEAL='\e[36m'
    local BROWN='\e[33m'
    local ORANGE='\e[38;5;208m'
    local PURPLE='\e[35m'
    
    local command=$1
    local username=$(whoami)
    
    
    local messages=(
        "${RED}👾 Warning${RED}! A cyber anomaly named ${CYAN}\"${command}\"${RESET} has disrupted the matrix, ${MAGENTA}${username}${RESET}.${RESET}"
        "${TEAL}🏴‍☠️ Arr, yer vessel be stuck on the treacherous reef of ${CYAN}\"${command}\"${RESET}, ${BLUE}${username}${RESET}!${RESET}\n${ORANGE}Beware, the coding seas be treacherous.${RESET}"
        "${BROWN}🏞️ Your coding cowboy, ${GREEN}${username}${BROWN}, faced an outlaw known as ${CYAN}\"${command}\"${RESET}.${RESET}\n${RED}It's a wild frontier out there.${RESET}"
        "${BLUE}🚀 Commander, our mission encountered a space anomaly called ${CYAN}\"${command}\"${RESET}, ${GREEN}${username}${RESET}.${RESET}\n${MAGENTA}The cosmos are ever unpredictable.${RESET}\n${BLUE}Prepare for a hyperdrive maneuver and try again! 🌠🛸${RESET}"
        "${BLUE}📜 In a far, far away kingdom of commands, your brave terminal knight, ${BLUE}couldn't find the castle named ${CYAN}\"${command}\"${RESET}.${RESET}\n${ORANGE}The journey is perilous.${RESET}\n${YELLOW}Shall we seek another command? 🏰🔍${RESET}" 
    )

    # Use Zsh's built-in random variable rather than GNU shuf, which is
    # absent from the default macOS and BSD userlands.
    local random_index=$(( (RANDOM % ${#messages[@]}) + 1 ))
    local random_message="${messages[$random_index]}"
    printf '%b\n' "$random_message"
    return 127
}
