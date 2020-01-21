#!/bin/zsh

__shorten_path()
{
    setopt localoptions noksharrays extendedglob
    local MATCH MBEGIN MEND
    local -a match mbegin mend
    "${2:-echo}" "${1//(#m)[^\/]##\//${MATCH/(#b)([^.])*/$match[1]}/}"
}

__prompt_path()
{
    local cwd

    case "$PROMPT_PATH_STYLE" in
        "fullpath")
            cwd="$(print -D "$PWD")"
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

prompt-enable() {
    PROMPT='$ '
    RPROMPT='$(__prompt_path)'
}

prompt-disable() {
    RPROMPT=
}

main() {
    # Allow for functions in the prompt.
    setopt PROMPT_SUBST
    # Hide old prompt
    setopt TRANSIENT_RPROMPT
    prompt-enable
}

main
