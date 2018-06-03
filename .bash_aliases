# sync with https://github.com/coolersport/aliases

checkarg() {
  if [[ -z "$1" ]]; then echo $2; kill -INT $$; fi
}
checkconfig() {
  if [[ ! -f "${KUBECONFIG-~/.kube/config}" ]]; then echo 'KUBECONFIG is unset or invalid'; kill -INT $$; fi
}

alias docker-maven='docker run --privileged -it --rm -v /var/run:/var/run:z -v "$PWD":/src:z -v ~/.m2:/root/.m2:z -v /apps/mvn-repo/:/apps/mvn-repo/:z -v ~/.embedmongo:/root/.embedmongo:z -w /src coolersport/maven:3.2.5-jdk-8 mvn'
alias d='docker'
alias di='docker image'
alias db='docker build'

drm() {
  if [[ -z "$@" ]]; then
    docker stop `docker ps --format={{.Names}}` 2>/dev/null
    docker rm `docker ps -a --format={{.Names}}` 2>/dev/null
  else
    docker stop $@ 2>/dev/null; docker rm -f $@ 2>/dev/null
  fi
}

alias dr='docker run -it --rm -v "$PWD":/pwd:z'
alias de='docker exec -it'
alias dl='docker logs -f'
alias ds='docker stats $(docker ps --format={{.Names}})'

alias dc='docker-compose'
alias dcf='docker-compose -f'

alias bfg='java -jar /apps/bfg-1.12.16.jar'
alias k='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE}'
alias ka='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get all'

kp() {
  checkconfig
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get pods $@
}
podname() {
  checkarg "$1" "Parts of pod name is required"
  kp --no-headers=true -o custom-columns=:metadata.name | awk '/'$1'/{i++}i=='${2-1}'{print;exit}'
}

alias kpw='watch -tn1 kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get pods -o wide'
alias kd='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} describe'
alias kaf='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} apply -f'
alias kdf='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} delete -f'

ke() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  name=`podname $1`
  shift
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} exec -it ${name:?No pod matched} $@
}
ke2() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  name=`podname $1 2`
  shift
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} exec -it ${name:?No pod matched} $@
}
ke3() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  name=`podname $1 3`
  shift
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} exec -it ${name:?No pod matched} $@
}

kl() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  name=`podname $1`
  shift
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} logs -f ${name:?No pod matched} $@
}
kl2() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  name=`podname $1 2`
  shift
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} logs -f ${name:?No pod matched} $@
}
kl3() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  name=`podname $1 3`
  shift
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} logs -f ${name:?No pod matched} $@
}

kb() {
  [[ -z $2 ]] && LABELS=$1 || LABELS=$2
  [[ -z $2 ]] && NS="${KUBENAMESPACE:+--namespace $KUBENAMESPACE}" || NS="-n $1"
  kubectl exec -it `kubectl get pods -o go-template --template \'{{range .items}}{{.metadata.name}}{{"\\n"}}{{end}}\' -l "$LABELS" $NS` $NS bash
}

alias ak='kubectl --all-namespaces=true'
alias ks0='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} scale --replicas=0 deploy'
alias ks1='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} scale --replicas=1 deploy'
alias ks2='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} scale --replicas=2 deploy'
