#!/bin/bash

WORKSPACE=/opt/hyperledger

GO_VERSION='1.15.10'
DOCKER_VERSION='5:20.10.5~3-0~ubuntu-bionic'
DOCKER_COMPOSE_VERSION='1.28.5'
PROTOC_VERSION='3.11.4'

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

banner 'Installing packages'
apt install -y \
    cmake \
    apt-transport-https \
    ca-certificates \
    gpupg \
    curl \
    lsb-release

RET=0
which go > /dev/null || RET=1
banner "Installing golang ($GO_VERSION)"
if [ 1 = $RET ]; then
    wget -O /tmp/go.linux-amd64.tar.gz https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz
    tar zxf /tmp/go.linux-amd64.tar.gz -C /usr/local
    echo '# golang' > ./cache/profile-fpc.sh
    echo 'export PATH=/usr/local/go/bin:$PATH' >> ./cache/profile-fpc.sh
    echo 'export GOROOT=/usr/local/go' >> ./cache/profile-fpc.sh
    echo 'export GOPATH=/opt/go' >> ./cache/profile-fpc.sh
else
    echo "DONE."
fi

RET=0
which docker > /dev/null || RET=1
banner "Installing docker ($DOCKER_VERSION)"
if [ 1 = $RET ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
        "deb [arch=amd64 signed-by=/usr/share/eyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/ocker.list
    apt update
    apt install -y \
        docker-ce=${DOCKER_VERSION} \
        docker-ce-cli=${DOCKER_VERSION} \
        containerd.io
else
    echo "DONE."
fi

RET=0
which docker-compose > /dev/null || RET=1
banner "Installing docker-compose ($DOCKER_COMPOSE_VERSION)"
if [ 1 = $RET ]; then
    curl -L \
        "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "DONE."
fi

banner "Installing yq (v3)"
if [ ! -d $GOPATH/pkg/mod/github.com/mikefarah/yq ] || [ ! -f $GOPATH/bin/yq ]; then
    GO111MODULE=on go get github.com/mikefarah/yq/v3
else
    echo "DONE."
fi

banner "Installing nanopb"
if [ -z "$NANOPB_PATH" ] || [ ! -f $NANOPB_PATH/generator/proto/nanopb_pb2.py ]; then
    echo '' >> ./cache/profile-fpc.sh
    echo '# nanopb' >> ./cache/profile-fpc.sh
    echo 'export NANOPB_PATH=/opt/nanopb' >> ./cache/profile-fpc.sh
    . ./cache/profile-fpc.sh
    (
        rm -rf $NANOPB_PATH
        mkdir -p $NANOPB_PATH
        cd $NANOPB_PATH
        pwd
        git clone https://github.com/nanopb/nanopb.git -b nanopb-0.4.3 $NANOPB_PATH
        cd generator/proto
        make
    )
else
    echo "DONE."
fi

banner "Installing protoc"
if [ ! -f /usr/local/proto3/bin/protoc ]; then
    echo '' >> ./cache/profile-fpc.sh
    echo '# proto3' >> ./cache/profile-fpc.sh
    echo 'export PROTOC_CMD=/usr/local/proto3/bin/protoc' >> ./cache/profile-fpc.sh
    wget -O /tmp/protoc-linux-x86_64.zip https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip
    unzip /tmp/protoc-linux-x86_64.zip -d /usr/local/proto3
else
    echo "DONE."
fi

exit 0

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
