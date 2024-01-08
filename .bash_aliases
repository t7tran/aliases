# sync with https://github.com/t7tran/aliases

checkarg() {
  if [[ -z "$1" ]]; then echo $2; kill -INT $$; fi
}
checkconfig() {
  if [[ ! -f "${KUBECONFIG-~/.kube/config}" ]]; then echo 'KUBECONFIG is unset or invalid'; kill -INT $$; fi
}

alias maven='docker run --privileged -it --rm -v /var/run:/var/run:z -v "$PWD":/src:z -v ~/.m2:/root/.m2:z -v /apps/mvn-repo/:/apps/mvn-repo/:z -v ~/.embedmongo:/root/.embedmongo:z -w /src coolersport/maven:3.2.5-jdk-8 mvn'
mvnjenkins() {
  local id=`docker run -d -u $(id -u):$(id -g) --entrypoint bash --privileged -it --rm -v /var/run:/var/run:z -v "$PWD":/src:z -v ~/.m2:/home/jenkins/.m2:z -v ~/mvn-repo/:/home/jenkins/mvn-repo/:z -v ~/.embedmongo:/home/jenkins/.embedmongo:z -w /src coolersport/jenkins-slave`
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
alias dips='docker inspect -f "{{.Name}} - {{.NetworkSettings.IPAddress }}" $(docker ps -aq)'

dc() {
  if [[ -f run-config/docker-compose.yml ]]; then
    docker-compose --project-directory run-config -f run-config/docker-compose.yml "$@"
  elif [[ -f run-config/docker-compose.yaml ]]; then
    docker-compose --project-directory run-config -f run-config/docker-compose.yaml "$@"
  elif [[ -x run-config/docker-compose.sh ]]; then
    ./run-config/docker-compose.sh "$@"
  elif [[ -x docker-compose.sh ]]; then
    ./docker-compose.sh "$@"
  else
    docker-compose "$@"
  fi
}

alias dcf='docker-compose -f'
alias dcl='dc logs -f'
alias dce='dc exec'
alias dcips='docker inspect -f "{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}" $(docker ps -aq)'

alias dt='docker stack'
alias dtd='docker stack deploy -c docker-compose.yml'

# find image tags on docker hub
dhub() {
  local image=$1
  local tag=$2
  local notfound="Image $image not found."
  [[ $image == */* ]] || image=library/$image
  local url="https://hub.docker.com/v2/repositories/$image/tags/?page_size=100&page=1"
  while [[ $url == http* ]]; do
    local json=`curl -s -H "Authorization: JWT " "$url"`
    [[ $json == '{"detail": "'* ]] && echo $notfound && break
    notfound=
    if [[ -n $tag ]]; then
      local line=`echo $json | jq -r '.results[] | .name + " " + (.images[0].size | tostring)' | grep "^$tag "`
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
# short-form of k9s against current namespace or all namespaces
alias k9='K9S_CONFIG_DIR=~/.local/share/k9s k9s --namespace ${KUBENAMESPACE:-all} --headless'
# list all resources of the current namespace
alias ka='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get all'

alias m=microk8s
# short-form of kubectl against current namespace for microk8s
alias mk='microk8s kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE}'
# run microk8s kubectl against all namespaces
alias amk='microk8s kubectl --all-namespaces=true'

kns() {
  if [[ -n "$1" ]]; then
    export KUBENAMESPACE=$1
  else
    local options=()
    while read line; do
      options+=($line "")
    done < <(k get ns --no-headers=true -o custom-columns=:metadata.name --sort-by=.metadata.name)
    local ns=$(dialog \
                      --no-lines \
                      --clear \
                      --backtitle "$KUBECONFIG" \
                      --title "Current namespace: ${KUBENAMESPACE:-default}" \
		      --default-item "${KUBENAMESPACE:-default}" \
                      --menu "Switch to:" 0 0 0 \
                      "${options[@]}" \
                      2>&1 >/dev/tty)
    export KUBENAMESPACE=$ns
  fi
  [[ "$KUBENAMESPACE" == 'default' ]] && export KUBENAMESPACE=
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
  # drop unsupported args from other commands
  local skip=
  for arg do
    shift
    [[ "$skip" == "all" ]] && continue
    [[ -n $skip ]] && skip= && continue
    skip= 
    case $arg in
      (--container=*) : ;;
                 (-c) skip=yes ;;
                 (--) skip=all ;;
                  (*) set -- "$@" "$arg" ;;
    esac
  done

  checkarg "$1" "Parts of pod name is required"
  local name=$1
  shift
  local no=1
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    no=$1
    shift
  fi

#  local ns=
#  while [[ -n $1 ]]; do 
#    if [[ "$1" == '-n' || "$1" == '--namespace' ]]; then ns="-n $2"; break; fi
#    shift
#  done;
#  k get pods --no-headers=true -o custom-columns=:metadata.name --sort-by=.status.startTime $ns | tac | awk '/'$name'/{i++}i=='${no}'{print;exit}'
  k get pods --no-headers=true -o custom-columns=:metadata.name --sort-by=.status.startTime "$@" | tac | awk '/'$name'/{i++}i=='${no}'{print;exit}'
}

# find the node name which the most recent matching pod name is running on
# if the first parameter is a number n, it will find the nth most recent pod
podnode() {
  checkarg "$1" "Parts of pod name is required"
  local name=$1
  shift
  local no=1
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    no=$1
    shift
  fi  
  local ns= 
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
    local filter=`echo "NAME $@" | tr ' ' '|'`
    watch -ctn1 "kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get pods -o wide --sort-by=.status.startTime | awk {'print "'$1" " $2" " $3" " $4" " $5" " $6" " $7'"'} | column -t | grep --color=always -E -- '$filter'"
  fi
}
# describe a resource
alias kd='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} describe'
kdpo() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  local name=`podname $@`
  shift
  kd po ${name:?No pod matched}
}

# create resources described in one or more yaml files
kcf() {
  for a in "$@"; do
    for f in `find . -mindepth 1 -maxdepth 1 -type d -name "*${a%/}*"`; do
      kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} create -f "$f"
    done
  done
}
# create/update resources described in one or more yaml files
kaf() {
  for a in "$@"; do
    for f in `find . -mindepth 1 -maxdepth 1 -type d -name "*${a%/}*"`; do
      kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} apply -f "$f"
    done
  done
}
# generate and apply
gkaf() {
  if [[ ! -x ../generate.sh ]]; then
    echo No ../generate.sh script found.
    return
  fi
  ../generate.sh ${PWD##*/} "$@" && kaf "$@"
}
# replace resources described in one or more yaml files
krf() {
  for a in "$@"; do
    for f in `find . -mindepth 1 -maxdepth 1 -type d -name "*${a%/}*"`; do
      kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} replace -f "$f"
    done
  done
}
# delete resources described in one or more yaml files
kdf() {
  for a in "$@"; do
    for f in `find . -mindepth 1 -maxdepth 1 -type d -name "*${a%/}*"`; do
      kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} delete -f "$f"
    done
  done
}
# get events in the current namespace sorted by time
kev() {
  local command=( kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get events --sort-by=".metadata.creationTimestamp" -A )
  if [[ $1 == 'Normal' || $1 == 'Warning' ]]; then
    command+=( --field-selector=type=$1 )
    shift
  fi
  "${command[@]}" "$@"
}
# get events in all namespaces sorted by time
akev() {
  local command=( kev --all-namespaces=true )
  if [[ $1 == 'Normal' || $1 == 'Warning' ]]; then
    command+=( --field-selector=type=$1 )
    shift
  fi
  "${command[@]}" "$@"
}

kraf() {
  local target=$1
  local config=${2:-config}
  krf `ls -1 ${target:?}/*.yml  | grep    "${config}" | tr "\n" "," | head -c -1`
  kaf `ls -1 ${target:?}/*.yml  | grep -v "${config}" | tr "\n" "," | head -c -1`
}

# force delete one or more pods
kdpf() {
  k delete po --grace-period=0 --force $@
}
kdpe() {
  if [[ $1 == *Running* ]]; then
    echo "'Running' is disallowed."
    return
  fi
  for s in $1; do
    pods=`kp $s 2>/dev/null | grep -oP '^[^ ]+' | tr '\n' ' '`
    shift
    [[ -n $pods ]] && k delete po $pods "$@"
  done
}
akdpe() {
  if [[ $1 == *Running* ]]; then
    echo "'Running' is disallowed."
    return
  fi
  local currentNS=$KUBENAMESPACE
  namespaces=`k get ns --no-headers=true -o custom-columns=:metadata.name --sort-by=.metadata.name`
  local state=$1
  shift
  for ns in $namespaces; do
    KUBENAMESPACE=$ns
    kdpe "$state" "$@"
  done
  KUBENAMESPACE=$currentNS
}
kdpef() {
  kdpe $1 --grace-period=0 --force
}
akdpef() {
  akdpe $1 --grace-period=0 --force
}

# execute a command on the most recent pod whose name matches the first parameter
ke() {
  kex 1 "$@"
}
# execute a command on the second most recent pod whose name matches the first parameter
ke2() {
  kex 2 "$@"
}
# execute a command on the third most recent pod whose name matches the first parameter
ke3() {
  kex 3 "$@"
}
# execute a command on the most recent pod whose name/container matches the first parameter
kec() {
  local name=$1 && shift
  kex 1 $name -c $name "$@"
}
# execute a command on the second most recent pod whose name/container matches the first parameter
kec2() {
  local name=$1 && shift
  kex 2 $name -c $name "$@"
}
# execute a command on the third most recent pod whose name/container matches the first parameter
kec3() {
  local name=$1 && shift
  kex 3 $name -c $name "$@"
}
# execute a command on the nth most recent pod whose name matches the first parameter
kex() {
  checkconfig
  local nth=$1
  shift
  checkarg "$1" "Parts of pod name is required"
  local a1=$1
  shift
  local name=`podname $a1 $nth $@`
  k exec -it ${name:?No pod matched} $@
}
# view and follow log of the most recent pod whose name matches the first parameter
kl() {
  klx 1 "$@"
}
# view and follow log of the second most recent pod whose name matches the first parameter
kl2() {
  klx 2 "$@"
}
# view and follow log of the third most recent pod whose name matches the first parameter
kl3() {
  klx 3 "$@"
}
# view and follow log of the nth most recent pod whose name matches the first parameter
klx() {
  checkconfig
  local nth=$1
  shift
  checkarg "$1" "Parts of pod name is required"
  local a1=$1
  shift
  local name=`podname $a1 $nth $@`
  k logs -f ${name:?No pod matched} --tail=2000 "$@"
}
# view and follow logs of the container with same name as first parameter
klc() {
  local name=$1 && shift
  klx 1 $name -c $name "$@"
}
klc2() {
  local name=$1 && shift
  klx 2 $name -c $name "$@"
}
klc3() {
  local name=$1 && shift
  klx 3 $name -c $name "$@"
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
kst() {
  local type=$1
  shift
  local repl=1
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    local repl=$1
    shift
  fi  
  k scale --replicas=$repl $type $@
}

ks() {
  kst deploy "$@"
}

kss() {
  kst statefulset "$@"
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

ksecrets() {
  local namespace
  if [[ -z $KUBENAMESPACE ]]; then
    read -p "Namespace: " namespace
  fi
  k get secret ${KUBENAMESPACE:-$namespace} -n ${KUBENAMESPACE:-$namespace} -ojson | jq -r '.data | map_values(@base64d)'
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
  local command
  command=( terraform plan )
  for t in "$@"; do
    command+=( -target="$t" )
  done
  "${command[@]}"
}
tat() {
  local command
  command=( terraform apply )
  for t in "$@"; do
    command+=( -target="$t" )
  done
  "${command[@]}"
}
taty() {
  local command
  command=( terraform apply -auto-approve )
  for t in "$@"; do
    command+=( -target="$t" )
  done
  "${command[@]}"
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
    local PASS=`openssl rand -base64 17`
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
    local PASS=`randompasswordstring`
  else
    echo 'Hashing given base64 password...'
    local PASS=`echo -n $1 | base64 -d`
  fi

  hashpassword $PASS
}
randompasswords() {
  for i in {1..10}; do
    local PASS=`randompasswordstring`
    echo -n "$i. "
    echo -n $PASS | base64 -w0
    echo
  done
}

# erase all duplicate commands in bash history
erasedups() {
  [[ ! -f $HISTFILE.`date +'%Y%m%d%H'` ]] && cp $HISTFILE $HISTFILE.`date +'%Y%m%d%H'`
  tac $HISTFILE | awk '!x[$0]++' | tac | grep -vP '^(.+[ \t]|(ll|ls|mv|cd|cp|rm|mkdir|echo|cat|kdpf|vi|php|grep|alias|export) .+|(exit|history).*)$' | sponge $HISTFILE
}

json2yaml() {
  yq eval -P <(echo ${1:?required})
}

mysql_proxy_connect() {
  user=${1:?Username required}
  shift
  MYSQL_PWD=`gcloud auth print-access-token` mysql -h 127.0.0.1 --enable-cleartext-plugin -A -u "$user" "$@"
}

postgres_proxy_connect() {
  local db user
  [[ "$@" == *" -d "* || "$@" == *" --dbname"* ]] || db=postgres
  user=${1:?Username required}
  shift
  PGPASSWORD=`gcloud sql generate-login-token` psql -h 127.0.0.1 -U "$user" "$@" $db
}