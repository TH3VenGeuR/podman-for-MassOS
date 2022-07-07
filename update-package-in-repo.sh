#!/bin/bash
set -x
export today=$(date '+%Y%m%d')

#create_packages (name, method, project_home, git_url, api_option, api_filter, depandancies, description, pre_install, post_install, pre_remove, post_remove, pre_upgrade, post_upgrade) 
create_packages () {
  export VARMAINTAINER="adrien@vgr.pw"
  export VARPKGARCH=x86_64
  export VARPKGNAME="$1"
  method="$2"
  export VARPKGHOMEPAGE="$3"
  git_url="$4"
  api_option="$5"
  api_filter="$6"
  if [[ $7 == "none" ]];then
    export VARDEPS=" "
  else
    export VARDEPS="$7"
  fi
  export VARPKGDESCRIPTION="$8"
  pre_install=$9
  post_install=$10
  pre_remove=$11
  post_remove=$12
  pre_upgrade=$13
  post_upgrade=$14

  export VARPKGVER=`curl https://api.github.com/repos/$api_option/releases/latest | grep tag_name | awk '{print $2}' | tr -d '"'  | tr -d ','` 
  envsubst < templates/manifest.tpl > /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest

  if [[ $pre_install != "none" ]];then
    echo "pre_install () {" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "$pre_install" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ post_install != "none" ]];then
    echo "post_install () {" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "$post_install" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ pre_remove != "none" ]];then
    echo "pre_remove () {" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "$pre_remove" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ post_remove != "none" ]];then
    echo "post_remove () {" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "$post_remove" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest  
  fi
  if [[ pre_upgrade != "none" ]];then
    echo "pre_upgrade () {" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "$pre_upgrade" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest  
  fi
  if [[ post_upgrade != "none" ]];then
    echo "post_upgrade () {" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "$post_upgrade" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    echo "}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  mkdir -p /tmp/$VARPKGNAME-$today/usr/local
  if [[ $method == "git" ]];then
    if [[ $VARPKGNAME == "podman-rootless" ]];then
      export WORKDIR="podman"
      export VARBUILDTAGS="BUILDTAGS=seccomp apparmor systemd"
    else
      export WORKDIR=$VARPKGNAME
      export VARBUILDTAGS=""
    fi
    export GOVERSION=$(curl -s https://go.dev/dl/?mode=json | jq -r '.[0].version' | tr -d 'go')
    cd /tmp/$VARPKGNAME-$today/
    podman run --name gobuilder -d golang:$GOVERSION-bullseye sleep 3600
    podman exec -it gobuilder apt update
    podman exec -it gobuilder apt install git make libseccomp-dev libsystemd-dev libbtrfs-dev libdevmapper-dev libgpgme-dev libglib2.0-dev -y
    podman exec -it gobuilder git clone $git_url
    podman exec --workdir /go/$WORKDIR -it gobuilder git checkout $VARPKGVER
    podman exec --workdir /go/$WORKDIR -it gobuilder /usr/bin/make "$VARBUILDTAGS"
    podman cp gobuilder:/go/$WORKDIR/bin/ usr/local/
    tar -cJf $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz *
    cp $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/
    podman rm -f gobuilder
    cd -
  elif [[ $method == "std" ]];then
    export VARDOWNLOAD=`curl https://api.github.com/repos/$api_option/releases/latest | grep browser_download_url | grep -m1 $api_filter | awk '{print $2}'| tr -d '"'`
    mkdir /tmp/$VARPKGNAME-$today/usr/local/bin/
    curl $VARDOWNLOAD -o /tmp/$VARPKGNAME-$today/usr/local/bin/$VARPKGNAME
    cd /tmp/$VARPKGNAME-$today/
    tar -cJf $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz *
    cp $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/  
    cd -
  fi
}

create_packages "crun" "std" "https://github.com/containers/crun/" "unused" "containers/crun" "amd64" "none" "Crun is a container runtime written C" "none" "none" "none" "none" "none" "none" 
create_packages "slirp4netns" "std" "https://github.com/rootless-containers/slirp4netns/" "unused" "rootless-containers/slirp4netns" "x86_64" "none" "Slirp4netns network layer for rootless container" "none" "none" "none" "none" "none" "none" 
create_packages "podman-rootless" "git" "https://podman.io" "https://github.com/containers/podman.git" "containers/podman" "unused" "slirp4netns crun" "Podman is container engine, installed rootless" "none" "echo \"user.max_user_namespaces=16384\" > /etc/sysctl.d/podman.conf \n echo \"$SUDO_USER:100000:65536\" > /etc/subgid \n echo \"$SUDO_USER:100000:65536\" > /etc/subuid \n echo '{"default": [{"type": "insecureAcceptAnything"}]}' > /etc/containers/policy.json \n echo \"runtime = crun\n[runtimes]\ncrun =  [\n    \"/usr/local/bin/crun\"\n]\"" "none" "none" "none" "none" 
create_packages "conmon" "git" "https://github.com/containers/conmon" "https://github.com/containers/conmon.git" "containers/conmon" "unused" "none" "Conmon is a monitoring program and communication tool between a container manager and an OCI runtime" "none" "none" "none" "none" "none" "none" 

