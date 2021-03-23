#!/bin/sh

banner()
{
    echo "+----------------------------------------------------+"
    printf "| %-50s |\n" "$@"
    echo "+----------------------------------------------------+"
}

if [ "root" != "$USER" ]; then
    echo "Permission denied"
    exit 0
fi

if [ -f ./cache/profile-fpc.sh ]; then
    . ./cache/profile-fpc.sh
fi

banner "Uninstalling golang"
rm -rf /usr/local/go

banner "Uninstalling docker"
rm -f /usr/share/keyrings/docker-archive-keyring.gpg
rm -f /etc/apt/sources.list.d/docker.list
apt remove --purge -y \
    docker-ce-* \
    containerd.io
apt autoremove -y

banner "Uninstalling nanopb"
rm -f /usr/local/bin/docker-compose

if [ -n "$NANOPB_PATH" ]; then
    banner "Installing nanopb"
    rm -rf $NANOPB_PATH
fi

banner "Uninstalling protoc"
rm -rf /usr/local/proto3

banner "Deleting profile-fpc"
rm -f ./cache/profile-fpc.sh

