#!/bin/zsh

# Load git-prompt.sh if it exists
if [[ -f "${0:A:h}/git-prompt.sh" ]]; then
    source "${0:A:h}/git-prompt.sh"
fi

# ======================================================================
# zstyle Configuration
# ======================================================================

# Helper function to get zstyle value with fallback
__prompt_zstyle() {
    local context="$1"
    local key="$2"
    local default="$3"
    local result

    zstyle -s ":prompt:minimal:${context}" "${key}" result || result="${default}"
    echo "${result}"
}

# Helper function to get zstyle boolean value
__prompt_zstyle_bool() {
    local context="$1"
    local key="$2"
    local default="$3"
    local result

    zstyle -t ":prompt:minimal:${context}" "${key}" 2>/dev/null && result="true" || result="${default}"
    echo "${result}"
}

# Set default zstyle values if not already set
zstyle -s ':prompt:minimal:left' template _ || zstyle ':prompt:minimal:left' template '%sign% '
zstyle -s ':prompt:minimal:right' template _ || zstyle ':prompt:minimal:right' template '%exitcode% %path% (%git%)'
zstyle -s ':prompt:minimal:path' style _ || zstyle ':prompt:minimal:path' style 'minimal'
zstyle -s ':prompt:minimal:sign' char _ || zstyle ':prompt:minimal:sign' char '$'
zstyle -t ':prompt:minimal:vimode' enable 2>/dev/null || zstyle ':prompt:minimal:vimode' enable false

# Backward compatibility: support old environment variables
# These will override zstyle if set
if [[ -n "${PROMPT_PATH_STYLE}" ]]; then
    zstyle ':prompt:minimal:path' style "${PROMPT_PATH_STYLE}"
fi
if [[ -n "${PROMPT_SIGN}" ]]; then
    zstyle ':prompt:minimal:sign' char "${PROMPT_SIGN}"
fi
if [[ -n "${PROMPT_USE_VIM_MODE}" ]] && [[ "${PROMPT_USE_VIM_MODE}" == "true" ]]; then
    zstyle ':prompt:minimal:vimode' enable true
fi

__shorten_path() {
    setopt localoptions noksharrays extendedglob
    local MATCH MBEGIN MEND
    local -a match mbegin mend
    "${2:-echo}" "${1//(#m)[^\/]##\//${MATCH/(#b)([^.])*/$match[1]}/}"
}

__prompt_path() {
    local cwd
    local path_style="$(__prompt_zstyle "path" "style" "minimal")"

    case "${path_style}" in
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

__prompt_git() {
    # Check if __git_ps1 function exists (git-prompt.sh loaded)
    if ! type __git_ps1 &>/dev/null; then
        return 0
    fi

    # Configure git-prompt.sh behavior from zstyle
    if zstyle -t ':prompt:minimal:git' show-dirty 2>/dev/null; then
        export GIT_PS1_SHOWDIRTYSTATE=1
    fi
    if zstyle -t ':prompt:minimal:git' show-untracked 2>/dev/null; then
        export GIT_PS1_SHOWUNTRACKEDFILES=1
    fi
    if zstyle -t ':prompt:minimal:git' show-stash 2>/dev/null; then
        export GIT_PS1_SHOWSTASHSTATE=1
    fi
    if zstyle -t ':prompt:minimal:git' show-upstream 2>/dev/null; then
        export GIT_PS1_SHOWUPSTREAM="auto"
    fi

    # Call __git_ps1 with %s only (formatting is done in template)
    local git_info="$(__git_ps1 "%s")"
    if [[ -n "${git_info}" ]]; then
        echo "${git_info}"
    fi
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
        local default_sign="$(__prompt_zstyle "sign" "char" "$")"
        echo "${default_sign}"
        return 0
    fi
    if [[ ${sign} == "%" ]]; then
        # need to escape in case of using %
        sign="%%"
    fi
    local reset_prompt_color="%f"
    echo "${vim_mode_color}${sign}${reset_prompt_color}"
}

__prompt_sign() {
    local sign="$(__prompt_zstyle "sign" "char" "$")"
    local vimode_enable="$(__prompt_zstyle_bool "vimode" "enable" "false")"

    if [[ "${vimode_enable}" == "true" ]]; then
        echo "$(__vim_mode "${sign}")"
    else
        echo "${sign}"
    fi
}

# Parse template and replace placeholders
__prompt_parse_template() {
    local template="$1"
    local result="${template}"

    # Replace placeholders with actual values
    result="${result//\%sign\%/\$(__prompt_sign)}"
    result="${result//\%git\%/\$(__prompt_git)}"
    result="${result//\%path\%/\$(__prompt_path)}"
    result="${result//\%exitcode\%/\$(__prompt_exitcode)}"

    echo "${result}"
}

__prompt_main() {
    # Allow for functions in the prompt.
    setopt PROMPT_SUBST
    # Hide old prompt
    setopt TRANSIENT_RPROMPT

    # Get templates from zstyle
    local left_template="$(__prompt_zstyle "left" "template" "%sign% ")"
    local right_template="$(__prompt_zstyle "right" "template" "%exitcode% %path% %git%")"

    # Parse templates and set prompts
    PROMPT="$(__prompt_parse_template "${left_template}")"
    RPROMPT="$(__prompt_parse_template "${right_template}")"
}

__prompt_main
