# aliases
Useful bash aliases

## Installation

Place in ~/.bash_aliases and open new terminal or reload with `. ~/.bash_aliases`.
The following command will replace ~/.bash_aliases with the latest copy from this repo.

```bash
curl https://raw.githubusercontent.com/coolersport/aliases/master/.bash_aliases > ~/.bash_aliases
```

Combining these aliases with .inputrc tweak will probably improve your productivity.

```
curl https://raw.githubusercontent.com/coolersport/aliases/master/.inputrc > ~/.inputrc
```

Once ~/.inputrc is created and console is relaunched, type first part of the command then traverse history with up/down arrows.

### Docker aliases

```bash
# stop and remove one or more containers
drm container1 container2 ...
# stop and remove all containers
drm
# run maven command
maven -version
# docker command
d version
# see all images
di ls
# build docker
db -t image-name .
# run an image
dr image-name command
# execute a command in a running container
de container-name command
# view logs
dl container-name
# ... more in the file
```

### Kubectl aliases

```bash
# setup your context first, below is just a sample
export KUBECONFIG=~/.kube/config KUBENAMESPACE=default

# view all pods in $KUBENAMESPACE
kp
# watch all pods in $KUBENAMESPACE
kpw
# view first matching pod logs
kl part-of-pod-name
# view second matching pod logs
kl2 part-of-pod-name
# view third matching pod logs
kl3 part-of-pod-name
# execute command on the first matching pod
ke part-of-pod-name bash
ke part-of-pod-name -- ls -al /home
# execute command on the second matching pod
ke2 part-of-pod-name bash
ke2 part-of-pod-name -- ls -al /home
# execute command on the third matching pod
ke3 part-of-pod-name bash
ke3 part-of-pod-name -- ls -al /home
# ... more in the file
```

### Other aliases

```bash
# hash password using different methods
hashpassword yourpass
# generate a random password using openssl
randompassword
```
