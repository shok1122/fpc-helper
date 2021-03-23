#!/bin/sh

set -e

BRANCH_LINUX_SGX_DRIVER="${1:-sgx_driver_2.11}"
BRANCH_LINUX_SGX="${2:-sgx_2.11}"
BRANCH_LINUX_SGX_SSL="${3:-lin_2.13_1.1.1i}"

CODENAME="$(lsb_release -c | cut -f 2)"

PATH_SGX_DRIVER="/lib/modules/$(uname -r)/kernel/drivers/intel/sgx"

OPENSSL_VERSION="1.1.1i"

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

if [ -f ./cache/profile-sgx.sh ]; then
    . ./cache/profile-sgx.sh
fi

if [ -n "$(dmesg | grep -i "secureboot" | grep enabled)" ]; then
    echo "Secure Boot is enable. Turn off the Secure Boot option in the BIOS."
    exit 0
fi

banner "Installing linux headers"
apt install -y linux-headers-$(uname -r)

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

if ! type python > /dev/null 2>&1; then
    ln -s "$(which python3)" /usr/local/bin/python
fi

banner "Cloning linux-sgx-driver ($BRANCH_LINUX_SGX_DRIVER)"
if [ ! -d linux-sgx-driver ]; then
    git clone https://github.com/intel/linux-sgx-driver.git -b $BRANCH_LINUX_SGX_DRIVER --depth 1
else
    echo "DONE."
fi

RET=0
/sbin/modinfo isgx > /dev/null 2>&1 || RET=1
banner "Installing linux-sgx-driver ($BRANCH_LINUX_SGX_DRIVER)"
if [ 1 = $RET ]; then
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
fi
/sbin/modinfo isgx

banner "Cloning linux-sgx ($BRANCH_LINUX_SGX)"
if [ ! -d linux-sgx ]; then
    git clone https://github.com/intel/linux-sgx.git -b $BRANCH_LINUX_SGX --depth 1
else
    echo "DONE."
fi

banner "Compiling linux-sgx ($BRANCH_LINUX_SGX)"
if [ ! -d linux-sgx/external/toolset ]; then
    (
        cd linux-sgx
        make preparation
    )
else
    echo "DONE."
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
        cp external/toolset/$DISTRO/as      /usr/local/bin/
        cp external/toolset/$DISTRO/ld      /usr/local/bin/
        cp external/toolset/$DISTRO/ld.gold /usr/local/bin/
        cp external/toolset/$DISTRO/objdump /usr/local/bin/
    )
    DISTRO="$(cat cache/distro)"
else
    DISTRO="$(cat cache/distro)"
    banner "Overwriting toolset (distro:$DISTRO)"
    (
        cd linux-sgx
        cp external/toolset/$DISTRO/as      /usr/local/bin/
        cp external/toolset/$DISTRO/ld      /usr/local/bin/
        cp external/toolset/$DISTRO/ld.gold /usr/local/bin/
        cp external/toolset/$DISTRO/objdump /usr/local/bin/
    )
fi
md5sum $PWD/linux-sgx/external/toolset/$DISTRO/as      /usr/local/bin/as
md5sum $PWD/linux-sgx/external/toolset/$DISTRO/ld      /usr/local/bin/ld
md5sum $PWD/linux-sgx/external/toolset/$DISTRO/ld.gold /usr/local/bin/ld.gold
md5sum $PWD/linux-sgx/external/toolset/$DISTRO/objdump /usr/local/bin/objdump

RET=0
ls linux-sgx/linux/installer/bin/sgx_linux_*.bin > /dev/null 2>&1 || RET=1
banner "Compiling linux-sgx sdk"
if [ 1 = $RET ]; then
    (
        cd linux-sgx
        make sdk
        make sdk_install_pkg
    )
else
    echo "DONE."
fi

PATH_SGX_SDK_INSTALLER=$(ls $PWD/linux-sgx/linux/installer/bin/sgx_linux_*.bin)
banner "Installing linux-sgx sdk"
if [ ! -d /opt/intel/sgxsdk ] || [ -z "$(ls /opt/intel)" ]; then
    (
        mkdir -p /opt/intel
        cd /opt/intel
        bash $PATH_SGX_SDK_INSTALLER
    )
    echo '# sgxsdk' > ./cache/profile-sgx.sh
    '. /opt/intel/sgxsdk/environment' >> ./cache/profile-sgx.sh
    . ./cache/profile-sgx.sh
else
    echo "DONE."
fi

PATH_SGX_REPO="$PWD/linux-sgx/linux/installer/deb/sgx_debian_local_repo"
banner "Compiling linux-sgx psw"
if [ ! -d $PATH_SGX_REPO ]; then
    (
        cd linux-sgx
        make psw
        make deb_psw_pkg
        make deb_local_repo
    )
else
    echo "DONE."
fi

RET=0
systemctl status aesmd > /dev/null 2>&1 || RET=1
banner "Installing linux-sgx psw"
if [ 1 = $RET ]; then
    grep "sgx_debian_local_repo" /etc/apt/sources.list || cat << _EOT_ >> /etc/apt/sources.list

# SGX
deb [trusted=yes arch=amd64] file:$PATH_SGX_REPO $CODENAME main
_EOT_
    apt update
    apt install -y \
        libsgx-dcap-ql \
        libsgx-epid \
        libsgx-launch \
        libsgx-quote-ex \
        libsgx-urts
else
    echo "DONE."
fi

banner "Checking aesmd service"
systemctl status aesmd

banner "Cloning linux-sgx ssl ($BRANCH_LINUX_SGX_SSL)"
if [ ! -d intel-sgx-ssl ]; then
    git clone https://github.com/intel/intel-sgx-ssl.git -b $BRANCH_LINUX_SGX_SSL --depth 1
else
    echo "DONE."
fi

banner "Compiling linux-sgx ssl ($BRANCH_LINUX_SGX_SSL)"
if [ ! -d /opt/intel/sgxssl ]; then
    wget -P intel-sgx-ssl/openssl_source https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
    (
        cd intel-sgx-ssl/Linux
        SGX_MODE=HW DESTDIR=/opt/intel/sgxssl make all test
        make install
    )
else
    echo "DONE."
fi


