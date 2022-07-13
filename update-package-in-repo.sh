#!/bin/bash
set -x
export today=$(date '+%Y%m%d')
export MASSOSLASTVER=`curl https://api.github.com/repos/MassOS-Linux/MassOS/releases/latest | grep tag_name | awk '{print $2}' | tr -d '"'  | tr -d ','` 
export MASSOSLASTVERURL=`curl https://api.github.com/repos/MassOS-Linux/MassOS/releases/latest | grep browser_download_url | grep -m1 .tar.xz | awk '{print $2}'| tr -d '"'`

build_massos_container () {
  massbuilderimage=`docker image ls | grep massbuilder | awk '{print $1":"$2}'`  
  if [[ $massbuilderimage == "" ]];then
    echo "no massos build found. Building..."
    docker import $MASSOSLASTVERURL massbuilder:$MASSOSLASTVER
  elif [[ $massbuilderimage != "massbuilder:$MASSOSLASTVER" ]];then
    echo "old massos build found. Removing it and building a new..."
    docker rmi -f $massbuilderimage
    docker import $MASSOSLASTVERURL massbuilder:$MASSOSLASTVER
  elif [[ $massbuilderimage == "massbuilder:$MASSOSLASTVER" ]];then
    echo "already last version of massos in use"
  fi
}

#create_packages (name, method, project_home, git_url, api_option, api_filter, depandancies, description, pre_install, post_install, pre_remove, post_remove, pre_upgrade, post_upgrade) 
create_packages () {
  export VARMAINTAINER="adrien@vgr.pw"
  export VARPKGARCH=x86_64
  export VARPKGNAME="${1}"
  method="${2}"
  export VARPKGHOMEPAGE="${3}"
  git_url="${4}"
  api_option="${5}"
  api_filter="${6}"
  if [[ ${7} == "none" ]];then
    export VARDEPS=" "
  else
    export VARDEPS="${7}"
  fi
  export VARPKGDESCRIPTION="${8}"
  pre_install="${9}"
  post_install="${10}"
  pre_remove="${11}"
  post_remove="${12}"
  pre_upgrade="${13}"
  post_upgrade="${14}"
  export VARBUILDTAGS="${15}"
  export VARPKGVER=`curl https://api.github.com/repos/$api_option/releases/latest | grep tag_name | awk '{print $2}' | tr -d '"'  | tr -d ','` 
  envsubst < templates/manifest.tpl > /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest

  if [[ $pre_install != "none" ]];then
    printf "pre_install() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$pre_install" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ $post_install != "none" ]];then
    printf "post_install() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$post_install" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ $pre_remove != "none" ]];then
    printf "pre_remove() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$pre_remove" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ $post_remove != "none" ]];then
    printf "post_remove() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$post_remove" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest  
  fi
  if [[ $pre_upgrade != "none" ]];then
    printf "pre_upgrade() {" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$pre_upgrade" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest  
  fi
  if [[ $post_upgrade != "none" ]];then
    printf "post_upgrade() {\n" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "$post_upgrade" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
    printf "\n}" >> /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  fi
  if [[ $VARPKGNAME == "podman-rootless" ]];then
    export WORKDIR="podman"
  else
    export WORKDIR=$VARPKGNAME
  fi
  mkdir -p /tmp/$VARPKGNAME-$today/usr/local
  if [[ $method == "git" ]];then
    export GOVERSION=$(curl -s https://go.dev/dl/?mode=json | jq -r '.[0].version')
    cd /tmp/$VARPKGNAME-$today/
    docker run --name massbuilder -d massbuilder:$MASSOSLASTVER sleep 3600 
    docker exec massbuilder wget https://go.dev/dl/$GOVERSION.linux-amd64.tar.gz
    docker exec massbuilder tar -C /usr/local -xzf go1.18.4.linux-amd64.tar.gz
    docker exec --workdir /opt massbuilder git clone $git_url
    docker exec --workdir /opt/$WORKDIR massbuilder git checkout $VARPKGVER
    if [[ $VARBUILDTAGS != "none" ]];then 
      docker exec -e "PATH=$PATH:/usr/local/go/bin" --workdir /opt/$WORKDIR massbuilder /usr/bin/make "$VARBUILDTAGS"
    else
      docker exec --workdir /opt/$WORKDIR massbuilder /usr/bin/make
    fi
    docker cp massbuilder:/opt/$WORKDIR/bin/ usr/local/
    chmod -R +x /tmp/$VARPKGNAME-$today/usr/local/
    tar -cJf $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz *
    cp $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/
    docker rm -f massbuilder
    cd -
  elif [[ $method == "std" ]];then
    export VARDOWNLOAD=`curl https://api.github.com/repos/$api_option/releases/latest | grep browser_download_url | grep -m1 $api_filter | awk '{print $2}'| tr -d '"'`
    mkdir -p /tmp/$VARPKGNAME-$today/usr/local/bin/
    wget $VARDOWNLOAD -O /tmp/$VARPKGNAME-$today/usr/local/bin/$VARPKGNAME
    chmod -R +x /tmp/$VARPKGNAME-$today/usr/local/
    cd /tmp/$VARPKGNAME-$today/
    tar -cJf $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz *
    cp $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/
    cd -
  fi
  rm -r /tmp/$VARPKGNAME-$today/
}

build_massos_container
#create_packages name method project_home git_url api_option api_filter depandancies description pre_install_cmd post_install_cmd pre_remove_cmd post_remove_cmd pre_upgrade_cmd post_upgrade_cmd buildargs
create_packages "crun" "std" "https://github.com/containers/crun/" "unused" "containers/crun" "amd64" "none" "Crun is a container runtime written C" "none" "none" "none" "none" "none" "none" "none"
create_packages "slirp4netns" "std" "https://github.com/rootless-containers/slirp4netns/" "unused" "rootless-containers/slirp4netns" "x86_64" "none" "Slirp4netns network layer for rootless container" "none" "none" "none" "none" "none" "none" "none"
create_packages "podman-rootless" "git" "https://podman.io" "https://github.com/containers/podman.git" "containers/podman" "unused" "slirp4netns crun conmon" "Podman is container engine, installed rootless" "none" "  mkdir -p /etc/containers/ \n if [[ ! -f /etc/sysctl.d/podman.conf ]];then echo \"user.max_user_namespaces=16384\" > /etc/sysctl.d/podman.conf \n fi \n  echo '{\"default\": [{\"type\": \"insecureAcceptAnything\"}]}' > /etc/containers/policy.json \n  printf 'runtime = crun\n[runtimes]\ncrun =  [\n    \"/usr/local/bin/crun\"\n]' > /etc/containers/libpod.conf \n sysctl -p /etc/sysctl.d/podman.conf \n if [[ ! -f /usr/lib/libdevmapper.so.1.02.1 ]];then \n ln -s /usr/lib/libdevmapper.so.1.02 /usr/lib/libdevmapper.so.1.02.1 \n fi \n UIDMIN=\`grep ^UID_MIN /etc/login.defs | awk '{print \$2}'\` \n UIDMAX=\`grep ^UID_MAX /etc/login.defs | awk '{print \$2}'\` \n for i in \`awk -F : '\$3 >= 1000 {print \$1}' /etc/passwd\`; do if ! grep -q \$i /etc/subuid;then echo \"\$i:10000:\$UIDMAX\" >> /etc/subuid; fi; if ! grep -q \$i /etc/subgid;then echo \"\$i:10000:\$UIDMAX\" >> /etc/subgid; fi ;done \n " "none" "none" "none" "none" "BUILDTAGS=seccomp apparmor systemd" 
create_packages "conmon" "git" "https://github.com/containers/conmon" "https://github.com/containers/conmon.git" "containers/conmon" "unused" "none" "Conmon is a monitoring program and communication tool between a container manager and an OCI runtime" "none" "none" "none" "none" "none" "none" "none"
