export PS1='$([[ -n "$KUBECONFIG" ]] && echo -ne "\[\e[37m\]${KUBECONFIG##*[./]}\[\e[90m\] ")$([[ -n "$KUBENAMESPACE" ]] && echo -ne "\[\e[33m\]${KUBENAMESPACE} ")\[\e[0m\]\w\$ '
