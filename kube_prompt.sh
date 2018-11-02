#!/usr/bin/env bash

# based on bash-it minimal theme

dark_grey="\[$(tput setaf 8)\]"
light_grey="\[$(tput setaf 248)\]"

# Max length of PWD to display
MAX_PWD_LENGTH=20

# Displays last X characters of pwd
# copied from hawaii50 theme
function limited_pwd() {

    # Replace $HOME with ~ if possible 
    RELATIVE_PWD=${PWD/#$HOME/\~}

    local offset=$((${#RELATIVE_PWD}-$MAX_PWD_LENGTH))

    if [ $offset -gt "0" ]
    then
        local truncated_symbol="..."
        TRUNCATED_PWD=${RELATIVE_PWD:$offset:$MAX_PWD_LENGTH}
        echo -e "${truncated_symbol}/${TRUNCATED_PWD#*/}"
    else
        echo -e "${RELATIVE_PWD}"
    fi
}

function kube() {
    if [[ -n "$KUBECONFIG" && -n "$KUBENAMESPACE" ]]; then
        echo -ne "\e[37m${KUBECONFIG##*[./]}\e[90m.\e[33m${KUBENAMESPACE}"
    fi
}

export PS1='$(kube)\e[0m \e[1m$(limited_pwd)\e[0m$ '
