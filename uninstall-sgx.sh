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

PATH_SGX_DRIVER="/lib/modules/$(uname -r)/kernel/drivers/intel/sgx"

banner "Stopping an aesmd service"
systemctl stop aesmd

banner "Disabling an aesmd service"
systemctl disable aesmd

banner "Removing an isgx module"
/sbin/modprobe --remove isgx
rm -rf $PATH_SGX_DRIVER
sed -i '/^isgx$/d' /etc/modules
/sbin/depmod

banner "Removing a linux-sgx-driver repository"
rm -rf linux-sgx-driver

banner "Removing a sgx sdk"
rm -rf /opt/intel
sed -i '/^source \/opt\/intel\/sgxsdk\/environment$/d' ~/.bashrc

banner "Removing a linux-sgx repository"
rm -rf linux-sgx
rm -f /lib/systemd/system/aesmd.service
sed -i '/sgx_debian_local_repo/d' /etc/apt/sources.list

banner "Uninstalling linux-sgx psw"
apt remove --purge -y \
    libsgx-*
apt autoremove

banner "Removing a distro file"
rm -f cache/distro

banner "Removing toolsets"
rm -f /usr/local/bin/as
rm -f /usr/local/bin/ld
rm -f /usr/local/bin/ld.gold
rm -f /usr/local/bin/objdump
