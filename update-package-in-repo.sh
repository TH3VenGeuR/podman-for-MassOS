#!/bin/bash
export today=$(date '+%Y%m%d')

export VARPODMANVER=$(curl https://api.github.com/repos/containers/podman/releases/latest | grep tag_name) 
export VARCONMONVER=$(curl https://api.github.com/repos/containers/conmon/releases/latest | grep tag_name) 
export VARPODMANDOWNLOAD="https://github.com/containers/podman.git"
export VARCONMONDOWNLOAD="https://github.com/containers/conmon.git"
export VARPODMANNAME=podman-rootless
export VARCONMONNAME=conmon
export VARPODMANHOMEPAGE="https://github.com/containers/podman/"
export VARPODMANDEPS="slirp4netns crun"

for i in rootless-containers/slirp4netns containers/crun; do
    echo $i
    export VARPKGARCH=x86_64
    export VARMAINTAINER="adrien@vgr.pw"
  if [[ $i =~ "slirp4netns" ]];then
    export VARPKGVER=`curl https://api.github.com/repos/$i/releases/latest | grep tag_name | awk '{print $2}' | tr -d '"'  | tr -d ','`
    export VARDOWNLOAD=`curl https://api.github.com/repos/$i/releases/latest | grep browser_download_url | grep -m1 x86_64 | awk '{print $2}'| tr -d '"'`
    export VARPKGNAME=`echo $i | awk -F\/ '{print $2}'`
    export VARPKGHOMEPAGE="https://github.com/rootless-containers/slirp4netns/"
  elif [[ $i =~ "crun" ]];then
    export VARPKGVER=`curl https://api.github.com/repos/$i/releases/latest | grep tag_name | awk '{print $2}'  | tr -d '"'  | tr -d ','`
    export VARDOWNLOAD=`curl https://api.github.com/repos/$i/releases/latest | grep browser_download_url | grep -m1 amd64 | awk '{print $2}'  | tr -d '"' `
    export VARPKGNAME=`echo $i | awk -F\/ '{print $2}'`
    export VARPKGHOMEPAGE="https://github.com/containers/crun/"
  fi
  envsubst < templates/manifest.tpl > /var/www/massos-repo/x86_64/manifest/$VARPKGNAME.manifest
  mkdir -p /tmp/$VARPKGNAME-$today/usr/sbin/
  curl $VARDOWNLOAD -o /tmp/$VARPKGNAME-$today/usr/sbin/$VARPKGNAME
  cd /tmp/$VARPKGNAME-$today/
  tar -cJf $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz *
  cp $VARPKGNAME-$VARPKGVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/
  cd -
done

mkdir -p /tmp/$VARPODMANNAME-$today/usr/local/bin
mkdir -p /tmp/$VARPODMANNAME-$today/usr/local/libexec
mkdir -p /tmp/$VARCONMONNAME-$today/usr/local/libexec
envsubst < templates/manifest.tpl > /var/www/massos-repo/x86_64/manifest/$VARPODMANNAME.manifest
envsubst < templates/manifest.tpl > /var/www/massos-repo/x86_64/manifest/$VARCONMONNAME.manifest
envsubst < templates/Dockerfile.tpl > Dockerfile
podman build -t $VARPODMANNAME-$VARPODMANVER:$today .
podman run -d $VARPODMANNAME-$VARPODMANVER:$today --name $VARPODMANNAME-$VARPODMANVER-$today
podman cp $VARPODMANNAME-$VARPODMANVER-$today:/opt/podman/bin/rootlessport /tmp/$VARPODMANNAME-$today/usr/local/libexec/rootlessport
podman cp $VARPODMANNAME-$VARPODMANVER-$today:/opt/conmon/bin/conmon /tmp/$VARCONMONNAME-$today/usr/local/libexec/conmon
podman cp $VARPODMANNAME-$VARPODMANVER-$today:/opt/podman/bin/podman /tmp/$VARPODMANNAME-$today/usr/local/bin/podman

cd /tmp/$VARCONMONNAME-$today/
tar -cJf $VARCONMONNAME-$VARCONMONVER-$VARPKGARCH.tar.xz *
cp $VARCONMONNAME-$VARCONMONVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/
cd /tmp/$VARPODMANNAME-$today/
tar -cJf $VARPODMANNAME-$VARPODMANVER-$VARPKGARCH.tar.xz *
cp $VARPODMANNAME-$VARPODMANVER-$VARPKGARCH.tar.xz /var/www/massos-repo/x86_64/archives/
