#!/bin/bash

set -e

### variables ###
KEY_LOG="~/logs/key.log"
GIT_LOG="~/logs/git.log"
BUILD_LOG="~/logs/build.log"
FLAVOR=(${FLAVOR_WS} ${FLAVOR_GW})

### functions ###
timestamp() { echo -e "\n${1} Time: $(date +'%H:%M:%S')\n" >> ${2}; }
build_cmd() { for ((i=0;i<${1};i++)); do timestamp 'Build Start' ${2}; ${3}; done; }
FUNC_1=$(declare -f timestamp)
FUNC_2=$(declare -f build_cmd)

### if APT_ONION true ###
${APT_ONION} && ONION="--connection onion" && mv /50_user.conf /lib/systemd/system/apt-cacher-ng.service.d/50_user.conf && \
{ cat >> /etc/apt-cacher-ng/acng.conf << EOF
PassThroughPattern: .*
BindAddress: localhost
SocketPath: /run/apt-cacher-ng/socket
Port:3142
Proxy: http://127.0.0.1:3142
AllowUserPorts: 0
EOF
} && echo "Acquire::BlockDotOnion \"false\";" > /etc/apt/apt.conf.d/30user && \
systemctl daemon-reload && systemctl start tor.service && \
systemctl restart apt-cacher-ng.service && sleep 1

### start dnscrypt service ###
sudo -u user /bin/bash -c '{ mkdir -p ~/logs && sudo systemctl start dnscrypt-proxy.service; sleep 1; }'

### start whonix build ###
sudo -u user /bin/bash -c "$FUNC_1; $FUNC_2; [ -f ~/derivative.asc ] || { wget https://www.whonix.org/keys/derivative.asc -O ~/derivative.asc && \
gpg --keyid-format long --import --import-options show-only --with-fingerprint ~/derivative.asc && \
gpg --import ~/derivative.asc && gpg --check-sigs 916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA; } &> ${KEY_LOG}; \

timestamp 'Git Start' ${GIT_LOG}; [ -d ~/${WHONIX_TAG} ] || { cd ~/ && git clone --depth=1 --branch ${WHONIX_TAG} \
--jobs=4 --recurse-submodules --shallow-submodules https://github.com/Whonix/derivative-maker.git ${WHONIX_TAG} &>> ${GIT_LOG}; }; \

{ cd ~/${WHONIX_TAG}; git pull && git verify-tag ${WHONIX_TAG} && \
git verify-commit ${WHONIX_TAG}^{commit} && git checkout --recurse-submodules ${WHONIX_TAG} && \
git describe && git status; } &>> ${GIT_LOG} && timestamp 'Git End' ${GIT_LOG} && \

[ -d ~/derivative-binary ] && { ${CLEAN} && rm -r ~/derivative-binary; }; \
tbb_version=${TBB_VERSION}; build_cmd ${#FLAVOR[@]} ${BUILD_LOG} '/home/user/${WHONIX_TAG}/derivative-maker --flavor ${FLAVOR[i]} 
--target ${TARGET} --arch ${ARCH} --repo ${REPO} --type ${TYPE} ${ONION} ${OPTS}' &>> ${BUILD_LOG}"
