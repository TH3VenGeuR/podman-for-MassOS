FROM golang:1.18.3-bullseye
WORKDIR /opt
RUN apt install git make libseccomp-dev libsystemd-dev libbtrfs-dev libdevmapper-dev libgpgme-dev libglib2.0-dev -y
RUN git clone $VARPODMANDOWNLOAD
RUN git clone $VARCONMONDOWNLOAD
RUN cd podman 
RUN make BUILDTAGS="apparmor seccomp systemd"
RUN cd ../conmon
RUN make
CMD ["/bin/sleep","60"]
