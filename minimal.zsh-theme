#!/bin/zsh

declare -g PROMPT_PATH_STYLE=${PROMPT_PATH_STYLE:-"minimal"}
declare -g PROMPT_SIGN=${PROMPT_SIGN:-"$"}
declare -g PROMPT_USE_VIM_MODE=${PROMPT_USE_VIM_MODE:-false}

__shorten_path() {
    setopt localoptions noksharrays extendedglob
    local MATCH MBEGIN MEND
    local -a match mbegin mend
    "${2:-echo}" "${1//(#m)[^\/]##\//${MATCH/(#b)([^.])*/$match[1]}/}"
}

__prompt_path() {
    local cwd

    case "${PROMPT_PATH_STYLE}" in
        "fullpath")
            cwd="$(print -D "${PWD}")"
            ;;
        "shortpath")
            cwd="$(__shorten_path "${PWD/$HOME/~}")"
            ;;
        "minimal")
            cwd="$(print -P %2~)"
            ;;
        *)
            cwd=
            ;;
    esac
    echo "$cwd"
}

__prompt_exitcode() {
    local ON_COLOR="%{${fg[green]}%}"
    local OFF_COLOR="%{${reset_color}%}"
    local ERR_COLOR="%{${fg[red]}%}"
    echo "%(?..${ERR_COLOR}%? ⏎  ) ${OFF_COLOR}"
}

vim_mode_color=""

function zle-keymap-select zle-line-init zle-line-finish {
    # https://tutorialmore.com/questions-292160.htm
    # https://unix.stackexchange.com/questions/547/make-my-zsh-prompt-show-mode-in-vi-mode
    case ${KEYMAP} in
        main|viins)
            # vim_mode_color="$fg[black]-- INSERT --$reset_color"
            # vim_mode_color="insert"
            vim_mode_color=""
            ;;
        vicmd)
            # vim_mode_color="$fg[white]-- NORMAL --$reset_color"
            # vim_mode_color="normal"
            # vim_mode_color="$fg[white]$$reset_color"
            vim_mode_color="%F{white}"
            ;;
        vivis|vivli)
            # vim_mode_color="$fg[yellow]-- VISUAL --$reset_color"
            # vim_mode_color="visual"
            # vim_mode_color="$fg[yellow]$$reset_color"
            vim_mode_color="%F{yellow}"
            ;;
        virep)
            # vim_mode_color="$fg[red]-- REPLACE --$reset_color"
            # vim_mode_color="$fg[red]$$reset_color"
            vim_mode_color="%F{red}"
            ;;
    esac
    zle reset-prompt
}

zle -N zle-line-init
zle -N zle-line-finish
zle -N zle-keymap-select

__vim_mode() {
    local sign=${1}
    if [[ -z ${sign} ]]; then
        echo "${PROMPT_SIGN}"
        return 0
    fi
    if [[ ${sign} == "%" ]]; then
        # need to escape in case of using %
        sign="%%"
    fi
    local reset_prompt_color="%f"
    echo "${vim_mode_color}${sign}${reset_prompt_color}"
}

__prompt_run() {
    local prompt
    prompt="${PROMPT_SIGN}"

    if ${PROMPT_USE_VIM_MODE:-false}; then
        prompt="$(__vim_mode ${PROMPT_SIGN})"
    fi

    echo "${prompt}"
}

prompt-enable() {
    PROMPT='$(__prompt_run) '
    RPROMPT='$(__prompt_exitcode) $(__prompt_path)'
}

prompt-disable() {
    RPROMPT=
}

__prompt_main() {
    # Allow for functions in the prompt.
    setopt PROMPT_SUBST
    # Hide old prompt
    setopt TRANSIENT_RPROMPT
    prompt-enable
}

__prompt_main
