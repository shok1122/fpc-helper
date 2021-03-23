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

banner "Stopping aesmd service"
systemctl stop aesmd

banner "Disabling aesmd service"
systemctl disable aesmd

banner "Removing isgx module"
/sbin/modprobe --remove isgx
