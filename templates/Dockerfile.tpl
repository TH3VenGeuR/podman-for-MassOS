FROM golang:1.18.3-bullseye
WORKDIR /opt
RUN apt install make git -y
RUN git clone $VARPODMANDOWNLOAD
RUN git clone $VARCONMONDOWNLOAD
RUN cd podman 
RUN make BUILDTAGS="apparmor seccomp systemd"
RUN make install
RUN cd ../conmon
RUN make
RUN make install
CMD ["/bin/sleep","60"]
