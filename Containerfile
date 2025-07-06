FROM ghcr.io/archlinux/archlinux@sha256:d6c8e168a5f7728d667f00c7d5ae42527837c938dfccc5ebccfbbc8f8191d4c9

COPY *.sh /
COPY prepare_build_test.sh /prepare_build.sh

RUN \
  chmod 755 /*.sh && \
  pacman -Syyu --noconfirm --needed \
      archlinux-keyring \
      base-devel \
      cmake \
      sudo \
      python \
      binutils \
      fakeroot \
      git \
      gnupg \
      rsync && \
  useradd -m builder && \
  echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder && \
  rm -Rf /var/cache/pacman/pkg/ && \
  rm -rf ~/.cache/*

USER builder
WORKDIR /home/builder

WORKDIR /build
ENTRYPOINT ["/bin/bash"]
CMD ["/run.sh"]

