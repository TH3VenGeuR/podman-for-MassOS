#!/bin/bash
export today=$(date '+%Y%m%d')

#create_packages (name, method, project_home, git_url, api_option, api_filter, depandancies, description) 
create_packages () {
  export VARMAINTAINER="adrien@vgr.pw"
  export VARPKGARCH=x86_64
  export VARPKGNAME="$1"
  method="$2"
  export VARPKGHOMEPAGE="$3"
  git_url="$4"
  api_option="$5"
  api_filter="$6"
  export VARDEPS="$7"
  export VARPKGDESCRIPTION="$8"
  export VARPKGVER=`curl https://api.github.com/repos/$api_option/releases/latest | grep tag_name | awk '{print $2}' | tr -d '"'  | tr -d ','` 
  envsubst < templates/manifest.tpl > /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  mkdir -p /tmp/$VARPKGNAME-$today/usr/local
  if [[ $method == "git" ]];then
    if [[ $VARPKGNAME == "podman-rootless" ]];then
      export WORKDIR="podman"
      export VARBUILDTAGS="BUILDTAGS='apparmor seccomp systemd'"
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
    podman exec --workdir /go/$WORKDIR -it gobuilder make $VARBUILDTAGS
    podman cp gobuilder:/go/$WORKDIR/bin/ usr/local/
    cd /tmp/$VARPKGNAME-$today/
    tar -cJf $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz *
    cp $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/
    podman rm -f gobuilder
    cd -
  elif [[ $method == "std" ]];then
    export VARDOWNLOAD=`curl https://api.github.com/repos/$api_option/releases/latest | grep browser_download_url | grep -m1 $filter | awk '{print $2}'| tr -d '"'`
    curl $VARDOWNLOAD -o /tmp/$VARPKGNAME-$today/usr/local/$VARPKGNAME
    cd /tmp/$VARPKGNAME-$today/
    tar -cJf $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz *
    cp $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/  
    cd -
  fi
}

create_packages "crun" "std" "https://github.com/containers/crun/" "" "containers/crun" "amd64" "" "Crun is a container runtime written C"
create_packages "slirp4netns" "std" "https://github.com/rootless-containers/slirp4netns/" "" "rootless-containers/slirp4netns" "x86_64" "" "Slirp4netns network layer for rootless container" 
create_packages "podman-rootless" "git" "https://podman.io" "https://github.com/containers/podman.git" "containers/podman" "" "slirp4netns crun" "Podman is container engine, istalled rootless" 
create_packages "conmon" "git" "https://github.com/containers/conmon" "https://github.com/containers/conmon.git" "containers/conmon" "" "" "Conmon is a monitoring program and communication tool between a container manager and an OCI runtime"
