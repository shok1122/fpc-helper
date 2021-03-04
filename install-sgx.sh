#!/bin/sh

set -e

BRANCH_LINUX_SGX_DRIVER="${1:-sgx_driver_2.11}"
BRANCH_LINUX_SGX="${2:-sgx_2.11}"

PATH_SGX_DRIVER="/lib/modules/$(uname -r)/kernel/drivers/intel/sgx"

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

banner "Installing linux headers"
apt install linux-headers-$(uname -r)

banner "Installing packages"
apt install -y \
    autoconf \
    automake \
    build-essential \
    cmake \
    debhelper \
    libcurl4-openssl-dev \
    libprotobuf-dev \
    libssl-dev \
    libtool \
    ocaml \
    ocamlbuild \
    perl \
    protobuf-compiler \
    python3 \
    reprepro \
    unzip \
    wget

if [ ! -d linux-sgx-driver ]; then
    banner "Cloning linux-sgx-driver ($BRANCH_LINUX_SGX_DRIVER)"
    git clone https://github.com/intel/linux-sgx-driver.git -b $BRANCH_LINUX_SGX_DRIVER --depth 1
fi

RET=0
/sbin/modinfo isgx > /dev/null 2>&1 || RET=1
if [ 1 = $RET ]; then
    banner "Installing linux-sgx-driver ($BRANCH_LINUX_SGX_DRIVER)"
    (
        cd linux-sgx-driver
        make
        test -f isgx.ko || exit 1
        mkdir -p $PATH_SGX_DRIVER
        cp isgx.ko $PATH_SGX_DRIVER
        grep -Fxq isgx /etc/modules || echo isgx >> /etc/modules
    )
    /sbin/depmod
    /sbin/modprobe isgx
    /sbin/modinfo sgx
else
    banner "Installed linux-sgx-driver ($BRANCH_LINUX_SGX_DRIVER)"
    /sbin/modinfo isgx
fi

if [ ! -d linux-sgx ]; then
    banner "Cloning linux-sgx ($BRANCH_LINUX_SGX)"
    git clone https://github.com/intel/linux-sgx.git -b $BRANCH_LINUX_SGX --depth 1
fi

if [ ! -d linux-sgx/external/toolset ]; then
    banner "Installing linux-sgx ($BRANCH_LINUX_SGX)"
    (
        cd linux-sgx
        make preparation
    )
fi

if [ ! -f cache/distro ]; then
    banner "Copying toolset"
    (
        cd linux-sgx
        echo "Choose toolset:"
        for x in $(ls external/toolset); do
            echo "  - $x"
        done
        echo -n "--> "
        read DISTRO
        echo $DISTRO > ../cache/distro
        cp external/toolset/$DISTRO/{as,ld,ld.gold,objdump} /usr/local/bin
    )
fi
