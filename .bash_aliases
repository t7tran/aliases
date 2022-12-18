# sync with https://github.com/t7tran/aliases

checkarg() {
  if [[ -z "$1" ]]; then echo $2; kill -INT $$; fi
}
checkconfig() {
  if [[ ! -f "${KUBECONFIG-~/.kube/config}" ]]; then echo 'KUBECONFIG is unset or invalid'; kill -INT $$; fi
}

alias maven='docker run --privileged -it --rm -v /var/run:/var/run:z -v "$PWD":/src:z -v ~/.m2:/root/.m2:z -v /apps/mvn-repo/:/apps/mvn-repo/:z -v ~/.embedmongo:/root/.embedmongo:z -w /src coolersport/maven:3.2.5-jdk-8 mvn'
mvnjenkins() {
  id=`docker run -d -u $(id -u):$(id -g) --entrypoint bash --privileged -it --rm -v /var/run:/var/run:z -v "$PWD":/src:z -v ~/.m2:/home/jenkins/.m2:z -v ~/mvn-repo/:/home/jenkins/mvn-repo/:z -v ~/.embedmongo:/home/jenkins/.embedmongo:z -w /src coolersport/jenkins-slave`
  docker exec -u root:root $id sed -i 's/10000/1000/g' /etc/passwd
  docker exec -u root:root $id sed -i 's/10000/1000/g' /etc/group
  docker exec $id mvn $@
  docker stop $id
  docker rm $id
}

alias watch='watch -tn1 '

alias d='docker'
alias di='docker image'
alias db='docker build'

# stop and remove docker containers, if no container IDs provided, all containers will be stopped (if running) and removed
drm() {
  if [[ -z "$@" ]]; then
    docker stop `docker ps --format={{.Names}}` 2>/dev/null
    docker rm `docker ps -a --format={{.Names}}` 2>/dev/null
  else
    docker stop $@ 2>/dev/null; docker rm -f $@ 2>/dev/null
  fi
}

# run a container with current directory mapped to /pwd
alias dr='docker run -it --rm -v "$PWD":/pwd:z'
alias drs='docker run -it --rm -v "$PWD":/pwd:z --entrypoint sh'
alias drb='docker run -it --rm -v "$PWD":/pwd:z --entrypoint bash'
alias dru='docker run -u $(id -u):$(id -g) -it --rm -v "$PWD":/pwd:z'
alias drw='docker run -it --rm -v "$PWD":/pwd:z -w /pwd'
# execute a command inside a container
alias de='docker exec -it'
# view and follow log of a container
alias dl='docker logs -f'
# view stats of all running containers with name column
alias ds='docker stats $(docker ps --format={{.Names}})'

dc() {
  if [[ -f run-config/docker-compose.yml ]]; then
    docker-compose -f run-config/docker-compose.yml "$@"
  else
    docker-compose "$@"
  fi
}

alias dcf='docker-compose -f'
alias dcl='dc logs -f'
alias dce='dc exec'

alias dt='docker stack'
alias dtd='docker stack deploy -c docker-compose.yml'

# find image tags on docker hub
dhub() {
  image=$1
  tag=$2
  notfound="Image $image not found."
  [[ $image == */* ]] || image=library/$image
  url="https://hub.docker.com/v2/repositories/$image/tags/?page_size=100&page=1"
  while [[ $url == http* ]]; do
    json=`curl -s -H "Authorization: JWT " "$url"`
    [[ $json == '{"detail": "'* ]] && echo $notfound && break
    notfound=
    if [[ -n $tag ]]; then
      line=`echo $json | jq -r '.results[] | .name + " " + (.images[0].size | tostring)' | grep "^$tag "`
      if [[ $? -eq 0 ]]; then
        echo "$tag = `echo $line | grep -oP '[0-9]+$' | numfmt --to=iec-i`"
        break
      else
        echo -n '.'
      fi
    else
      echo $json | jq -r '.results[] | .name + " " + (.images[0].size | tostring)' | while IFS= read -r line; do
        echo "`echo $line | cut -d ' ' -f 1` = `echo $line | grep -oP '[0-9]+$' | numfmt --to=iec-i`"
      done
    fi
    url=`echo $json | jq -r '.next'`
  done
}

# short-form of kubectl against current namespace
alias k='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE}'
# list all resources of the current namespace
alias ka='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get all'

kns() {
  if [[ -n "$1" ]]; then
    export KUBENAMESPACE=$1
  else
    options=(`k get ns --no-headers=true -o custom-columns=:metadata.name --sort-by=.metadata.name`)
    select_option "${options[@]}"
    ns=$?
    export KUBENAMESPACE=${options[$ns]}
    [[ "$KUBENAMESPACE" == 'default' ]] && export KUBENAMESPACE=
  fi
}

# list all pods (or those matching given parameters) of current namespace
kp() {
  checkconfig
  if [[ -z "$@" ]]; then
    k get pods $@
  else
    k get pods | grep -E -- `echo $@ | tr ' ' '|'`
  fi
}

# list all pods (or those matching given parameters) of current namespace sorted by created time
kps() {
  checkconfig
  if [[ -z "$@" ]]; then
    k get pods --sort-by=.status.startTime $@
  else
    k get pods --sort-by=.status.startTime | grep -E -- `echo $@ | tr ' ' '|'`
  fi  
}

# find the most recent pod whose name matches the parameter
# if the first parameter is a number n, it will find the nth most recent pod
podname() {
  checkarg "$1" "Parts of pod name is required"
  name=$1
  shift
  no=1
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    no=$1
    shift
  fi
  ns=
  while [[ -n $1 ]]; do 
    if [[ "$1" == '-n' || "$1" == '--namespace' ]]; then ns="-n $2"; break; fi
    shift
  done;
  k get pods --no-headers=true -o custom-columns=:metadata.name --sort-by=.status.startTime $ns | tac | awk '/'$name'/{i++}i=='${no}'{print;exit}'
}

# find the node name which the most recent matching pod name is running on
# if the first parameter is a number n, it will find the nth most recent pod
podnode() {
  checkarg "$1" "Parts of pod name is required"
  name=$1
  shift
  no=1
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    no=$1
    shift
  fi  
  ns= 
  while [[ -n $1 ]]; do 
    if [[ "$1" == '-n' || "$1" == '--namespace' ]]; then ns="-n $2"; break; fi
    shift
  done;
  k get pods --no-headers=true -o custom-columns=:metadata.name,:spec.nodeName --sort-by=.status.startTime $ns | tac | awk '/'$name'/{i++}i=='${no}'{print;exit}' | grep -oP ' +\K.+$'
}

# list all pods in the current namespace using wide output format
alias kpw='watch -tn1 kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get pods -o wide'
# list all pods in the current namespace using wide output format sorted by created time
#alias kpws='watch -tn1 kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get pods -o wide --sort-by=.status.startTime'
kpws() {
  if [[ -z "$@" ]]; then
    watch -ctn1 "kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get pods -o wide --sort-by=.status.startTime | awk {'print "'$1" " $2" " $3" " $4" " $5" " $6" " $7'"'} | column -t"
  else
    filter=`echo "NAME $@" | tr ' ' '|'`
    watch -ctn1 "kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get pods -o wide --sort-by=.status.startTime | awk {'print "'$1" " $2" " $3" " $4" " $5" " $6" " $7'"'} | column -t | grep --color=always -E -- '$filter'"
  fi
}
# describe a resource
alias kd='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} describe'
kdpo() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  name=`podname $@`
  shift
  kd po ${name:?No pod matched}
}

# create/update resources described in one or more yaml files
alias kaf='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} apply -f'
# delete resources described in one or more yaml files
alias kdf='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} delete -f'

# force delete one or more pods
kdpf() {
  k delete po --grace-period=0 --force $@
}
kdpe() {
  if [[ $1 != 'Error' && $1 != 'Evicted' ]]; then
    echo "Please specify 'Error' or 'Evicted' pods to be deleted."
    return
  fi
  k delete po `kp $1 | grep -oP '^[^ ]+' | tr '\n' ' '`
}

# execute a command on the most recent pod whose name matches the first parameter
ke() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  name=`podname $@`
  shift
  k exec -it ${name:?No pod matched} $@
}
# execute a command on the second most recent pod whose name matches the first parameter
ke2() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  a1=$1
  shift
  name=`podname $a1 2 $@`
  k exec -it ${name:?No pod matched} $@
}
# execute a command on the third most recent pod whose name matches the first parameter
ke3() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  a1=$1
  shift
  name=`podname $a1 3 $@`
  k exec -it ${name:?No pod matched} $@
}
# view and follow log of the most recent pod whose name matches the first parameter
kl() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  name=`podname $@`
  shift
  k logs -f ${name:?No pod matched} --tail=2000 $@
}
# view and follow log of the second most recent pod whose name matches the first parameter
kl2() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  a1=$1
  shift
  name=`podname $a1 2 $@`
  k logs -f ${name:?No pod matched} --tail=2000 $@
}
# view and follow log of the third most recent pod whose name matches the first parameter
kl3() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  a1=$1
  shift
  name=`podname $a1 3 $@`
  k logs -f ${name:?No pod matched} --tail=2000 $@
}

# run kubectl against all namespaces
alias ak='kubectl --all-namespaces=true'
# watch pods on all namespaces
alias akpw='watch -tn1 kubectl --all-namespaces=true get pods -o wide'

# running stats on CPU & MEMORY requested by all pods
akstats() {
  ( echo -e "NODE\tNAMESPACE\tPOD NAME\tCPU REQUESTED\tMEMORY REQUESTED"; ak get pods -o json | jq -r '.items[]|.spec.nodeName + "\t" + .metadata.namespace + "\t" + .metadata.name + "\t" + (if .spec.containers[0].resources.requests.cpu == null then "-" else .spec.containers[0].resources.requests.cpu end) + "\t" + (if .spec.containers[0].resources.requests.memory == null then "-" else .spec.containers[0].resources.requests.memory end)' | sort ) | column -ts $'\t'
}

# scale one or more deployments to a specified number of replicas (first parameter)
ks() {
  repl=1
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    repl=$1
    shift
  fi  
  k scale --replicas=$repl deploy $@
}

# scale one or more deployments to 0 replicas
alias ks0='ks 0'
# scale one or more deployments to 1 replica
alias ks1='ks 1'
# scale one or more deployments to 2 replicas
alias ks2='ks 2'
# scale one or more deployments to 3 replicas
alias ks3='ks 3'

#https://github.com/kubernetes/kubernetes/issues/17512#issuecomment-317757388
kutil() {
  k get nodes --no-headers | awk '{print $1}' | xargs -I {} sh -c 'echo {} ; kubectl describe node {} | grep Allocated -A 5 | grep -ve Event -ve Allocated -ve percent -ve -- ; echo '
}

kcpualloc() {
  kutil | grep % | awk '{print $1}' | awk '{ sum += $1 } END { if (NR > 0) { print sum/(NR*40), "%\n" } }'
}

kmemalloc() {
  kutil | grep % | awk '{print $5}' | awk '{ sum += $1 } END { if (NR > 0) { print sum/(NR*150), "%\n" } }'
}

alias h='helm'
alias htf='helm template "../${PWD##*/}" --output-dir build -f'

ht() {
  if [[ -n "$@" ]]; then
    helm template "$@"
  elif [[ "$1" == '-f' && $# -eq 2 ]]; then
    helm template "../${PWD##*/}" --output-dir build "$@"
  elif [[ -d templates && -f Chart.yaml ]]; then
    helm template "../${PWD##*/}" --output-dir build
  else
    echo "The current directory isn't a helm chart"
  fi
}

alias t='terraform'
alias tp='terraform plan'
alias ta='terraform apply'
alias tay='terraform apply -auto-approve'
alias ti='terraform import'
tpt() {
  terraform plan -target=$1
}
tat() {
  terraform apply -target=$1
}
taty() {
  terraform apply -auto-approve -target=$1
}

# compute password hash using different algorithms
hashpassword() {
  if [ -z $1 ]; then
    echo 'Syntax: hashpassword <password>'
    return 1
  fi
  echo "Password : $1"
  echo 'Base64   : '`echo -n $1 | base64 -w0`
  echo 'MD5      : '`echo -n $1 | md5sum | cut -d' ' -f1`
  echo 'Sha1     : '`echo -n $1 | sha1sum | cut -d' ' -f1`
  echo 'Sha256   : '`echo -n $1 | sha256sum | cut -d' ' -f1`
  echo 'BCrypt   : '`htpasswd -bnBC 10 "" $1 | tr -d ':\n' | sed 's/$2y/$2a/'`
  read -p 'Jetty OBF: (y/N) ' obf
  [[ "$obf" == 'y' || "$obf" == 'Y' ]] && echo `docker run -it --rm coolersport/jetty bash -c 'java -cp lib/jetty-util-*.jar  org.eclipse.jetty.util.security.Password '$1' 2>&1 | grep OBF'`
}

# generate a random password with different hashing algorithms
randompasswordstring() {
  for i in {1..100}; do
    PASS=`openssl rand -base64 17`
    PASS=${PASS//=/@}
    PASS=${PASS//+/@}
    PASS=${PASS//\//@}
    [[ "$PASS" == *@* ]] && break
  done
  echo $PASS
}
randompassword() {
  if [ -z $1 ]; then
    echo 'Generating random password...'
    PASS=`randompasswordstring`
  else
    echo 'Hashing given base64 password...'
    PASS=`echo -n $1 | base64 -d`
  fi

  hashpassword $PASS
}
randompasswords() {
  for i in {1..10}; do
    PASS=`randompasswordstring`
    echo -n "$i. "
    echo -n $PASS | base64 -w0
    echo
  done
}

# erase all duplicate commands in bash history
erasedups() {
  tac $HISTFILE | awk '!x[$0]++' | tac | grep -vP '^(.+[ \t]|(ll|ls|mv|cd|cp|rm|mkdir|echo|cat|kdpf|vi|php|grep|alias) .+|(exit|history).*)$' | sponge $HISTFILE
}

# https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu
select_option() {

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1 "; }
    print_selected()   { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    trap - 2

    return $selected
}
