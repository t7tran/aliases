# sync with https://github.com/coolersport/aliases

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
# execute a command inside a container
alias de='docker exec -it'
# view and follow log of a container
alias dl='docker logs -f'
# view stats of all running containers with name column
alias ds='docker stats $(docker ps --format={{.Names}})'

alias dc='docker-compose'
alias dcf='docker-compose -f'

alias bfg='java -jar /apps/bfg-1.12.16.jar'

# short-form of kubectl against current namespace
alias k='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE}'
# list all resources of the current namespace
alias ka='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get all'

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
    watch -cetn1 kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get pods -o wide --sort-by=.status.startTime
  else
    watch -cetn1 "kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} get pods -o wide --sort-by=.status.startTime | grep --color=always -E -- `echo $@ | tr ' ' '|'`"
  fi
}
# describe a resource
alias kd='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} describe'
# create/update resources described in one or more yaml files
alias kaf='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} apply -f'
# delete resources described in one or more yaml files
alias kdf='kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} delete -f'

# force delete one or more pods
kdpf() {
  k delete po --grace-period=0 --force $@
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
  k logs -f ${name:?No pod matched} $@
}
# view and follow log of the second most recent pod whose name matches the first parameter
kl2() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  a1=$1
  shift
  name=`podname $a1 2 $@`
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} logs -f ${name:?No pod matched} $@
}
# view and follow log of the third most recent pod whose name matches the first parameter
kl3() {
  checkconfig
  checkarg "$1" "Parts of pod name is required"
  a1=$1
  shift
  name=`podname $a1 3 $@`
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} logs -f ${name:?No pod matched} $@
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
  kubectl ${KUBENAMESPACE:+--namespace $KUBENAMESPACE} scale --replicas=$repl deploy $@
}

# scale one or more deployments to 0 replicas
alias ks0='ks 0'
# scale one or more deployments to 1 replica
alias ks1='ks 1'
# scale one or more deployments to 2 replicas
alias ks2='ks 2'

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
  echo 'Jetty OBF: '`docker run -it --rm coolersport/jetty bash -c 'java -cp lib/jetty-util-*.jar  org.eclipse.jetty.util.security.Password '$1' 2>&1 | grep OBF'`
}

# generate a random password with different hashing algorithms
randompassword() {
  if [ -z $1 ]; then
    echo 'Generating random password...'
    PASS=`openssl rand -base64 27`
    PASS=${PASS//=/k}
    PASS=${PASS//+/x}
    PASS=${PASS//\//y}
  else
    echo 'Hashing given base64 password...'
    PASS=`echo -n $1 | base64 -d`
  fi

  hashpassword $PASS
}

# erase all duplicate commands in bash history
erasedups() {
  tac $HISTFILE | awk '!x[$0]++' | tac | sponge $HISTFILE
}
