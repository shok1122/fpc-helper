#!/bin/sh

WORKSPACE=~/hyperledger

cd

rm -rf $WORKSPACE
mkdir -p $WORKSPACE

cd $WORKSPACE

echo 'Cloning play-with-sgx'
git clone https://github.com/shok1122/play-with-sgx
echo 'Cloning linux-sgx-driver'
git clone https://github.com/intel/linux-sgx-driver -b sgx_driver_2.11
echo 'Cloning fabric-private-chaincode'
git clone https://github.com/hyperledger-labs/fabric-private-chaincode -b v1.0-rc1

# installing sgx
./play-with-sgx/install-linux-sgx.sh ./linux-sgx-driver

# setup SPID
echo -n "API_KEY: "
read API_KEY
echo -n "SPID: "
read SPID
echo -n "SPID_TYPE(epid-unlinkable): "
read SPID_TYPE
SPID_TYPE=${SPID_TYPE:-epid-unlinkable}

echo "$API_KEY"   > $WORKSPACE/fabric-private-chaincode/config/ias/api_key.txt
echo "$SPID"      > $WORKSPACE/fabric-private-chaincode/config/ias/spid.txt
echo "$SPID_TYPE" > $WORKSPACE/fabric-private-chaincode/config/ias/spid_type.txt

# creation of docker images
