#!/bin/sh

WORKSPACE=/opt/hyperledger

banner()
{
    echo "+----------------------------------------------------+"
    printf "| %-50s |\n" "$@"
    echo "+----------------------------------------------------+"
}

rm -rf $WORKSPACE
mkdir -p $WORKSPACE

cd $WORKSPACE

banner 'Cloning fabric-private-chaincode'
git clone https://github.com/hyperledger-labs/fabric-private-chaincode -b v1.0-rc1

# setup SPID
banner 'Setup SGX Attestation Service'
PATH_API_KEY=$WORKSPACE/fabric-private-chaincode/config/ias/api_key.txt
if [ ! -f "$PATH_API_KEY" ];
    echo -n "API_KEY: "
    read API_KEY
    echo "$API_KEY" > $PATH_API_KEY
fi
echo $PATH_API_KEY
echo -n "> "
cat  $PATH_API_KEY

PATH_SPID=$WORKSPACE/fabric-private-chaincode/config/ias/spid.txt
if [ ! -f "$PATH_SPID" ];
    echo -n "SPID: "
    read SPID
    echo "$SPID" > $PATH_SPID
fi
echo $PATH_SPID
echo -n "> "
cat  $PATH_SPID

PATH_SPID_TYPE=$WORKSPACE/fabric-private-chaincode/config/ias/spid_type.txt
if [ ! -f "$PATH_SPID_TYPE" ];
    echo "epid-unlinkable" > $WORKSPACE/fabric-private-chaincode/config/ias/spid_type.txt
fi
echo $PATH_SPID_TYPE
echo -n "> "
cat  $PATH_SPID_TYPE

# creation of docker images
