#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE='MamboCoin.conf'
CONFIGFOLDER='/root/.MamboCoin'
COIN_DAEMON='mambocoind'
COIN_CLI='mambocoind'
COIN_PATH='/usr/local/bin/'
COIN_REPO='https://github.com/MamboCoin/MamboCoin.git'
SENTINEL_REPO='N/A'
COIN_NAME='MamboCoin'
COIN_PORT=21410
RPC_PORT=21411
TMP_FOLDER=$(mktemp -d)
SWAPFILE='/SWAP.SWAP'
MADE_SWAP=0
NODEIP=$(curl -s4 icanhazip.com)
PRECOMPILED='https://github.com/oldskooltek/mambo_masternode/raw/master/mambocoind.gz'

BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
PURPLE="\033[0;35m"
RED='\033[0;31m'
GREEN="\033[0;32m"
NC='\033[0m'
MAG='\e[1;35m'

# Prompt the user for a port
port_prompt() {

	# Ask nicely
	read -p "What port do you want $COIN_NAME to listen on? Leave blank for $COIN_PORT. " COIN_PORT
	
	# If we get nothing, set default
	if [ -z $COIN_PORT ]; then
		COIN_PORT=21410
	fi
}

purgeOldInstallation() {
	echo -e "${GREEN}Searching and removing old $COIN_NAME files and configurations${NC}"
	
	#kill wallet daemon	
	sudo killall $COIN_CLI > /dev/null 2>&1
	
	#remove old ufw port allow
	sudo ufw delete allow $COIN_PORT/tcp > /dev/null 2>&1
	
	#remove old files
	if [ -d "~/.MamboCoin" ]; then
		sudo rm -rf $CONFIGFOLDER > /dev/null 2>&1
	fi
	
	#remove binaries and MamboCoin utilities
	cd /usr/local/bin && sudo rm MamboCoin-cli MamboCoin-tx mambocoind > /dev/null 2>&1 && cd
	echo -e "${GREEN}* Done${NONE}";
}
#Option to use precompile
function choose_build() {
	echo -e "${CYAN}Please choose...1 or 2 ${NC}"
	echo -e "${CYAN}Choice 1 = precompiled${NC}"
	echo -e "${CYAN}Choice 2 you compile (takes longer) ${NC}"
	read ANSWER

	#case statement
	case $ANSWER in 
	[1]*)
		precompile
		;;

	*)
		compile_mambocoin
		;;
	esac
}

function precompile() {
	cd $COIN_PATH
	rm mambocoind.gz >/dev/null 2>&1
	wget $PRECOMPILED
	gunzip mambocoind.gz
	chmod +x mambocoind
}






# Based on MMBcoin WIKI
function compile_mambocoin() {

	cd $TMP_FOLDER
	echo -e "${GREEN}Cloning git repo...${NC}"
	git clone $COIN_REPO
	cd MamboCoin/src/
	
	echo -e "${GREEN}Compiling. This may take some time...${NC}"
	make -f makefile.unix
	compile_error MamboCoin

	echo -e "${GREEN}Copying files...${NC}"
	cp -a $COIN_DAEMON $COIN_PATH
	clear
}


function configure_systemd() {

	echo -e "${GREEN}Creating systemd service file...${NC}"
	cat << EOF > /etc/systemd/system/$COIN_NAME.service
[Unit]
Description=$COIN_NAME service
After=network.target

[Service]
User=root
Group=root

Type=forking
#PIDFile=$CONFIGFOLDER/$COIN_NAME.pid

ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER/$CONFIG_FILE -datadir=$CONFIGFOLDER stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

	
	systemctl daemon-reload
	sleep 3
	
	
	cd $CONFIGFOLDER
	rm bootstrap.zip >/dev/null 2>&1
	wget http://140.82.45.95/bootstrap.zip
	unzip -o bootstrap.zip 
	
	echo -e "${GREEN}Starting $COIN_NAME.service${NC}"
	#echo -e "${GREEN}systemctl start $COIN_NAME.service${NC}"
	systemctl start $COIN_NAME.service
	
	echo -e "${GREEN}Setting $COIN_NAME.service to start at boot${NC}"
	#echo -e "${GREEN}systemctl enable $COIN_NAME.service${NC}"
	systemctl enable $COIN_NAME.service >/dev/null 2>&1

	if [[ -z "$(ps axo cmd:100 | egrep $COIN_DAEMON)" ]]; then
		echo -e "${RED}$COIN_NAME is not running${NC}, please investigate. You should start by running the following commands as root:"
		echo -e "${GREEN}systemctl start $COIN_NAME.service"
		echo -e "systemctl status $COIN_NAME.service"
		echo -e "less /var/log/syslog${NC}"
		exit 1
	fi
}


function create_config() {
	echo -e "${GREEN}Creating initial configuarion file in $CONFIGFOLDER/$CONFIG_FILE${NC}"
	
	mkdir $CONFIGFOLDER >/dev/null 2>&1
	RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
	RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
	cat << EOF > $CONFIGFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
port=$COIN_PORT
EOF
}

function create_key() {

	# Prompt for key
	echo -e "${YELLOW}Enter your ${RED}$COIN_NAME Masternode GEN Key${NC}. Leave this blank to generate a new key:"
	read -e COINKEY 
	
	# If we didn't get a key
	if [[ -z "$COINKEY" ]]; then
		$COIN_PATH$COIN_DAEMON -daemon
		sleep 30
		if [ -z "$(ps axo cmd:100 | grep $COIN_DAEMON)" ]; then
		echo -e "${RED}$COIN_NAME server couldn not start. Check /var/log/syslog for errors.{$NC}"
		exit 1
		fi
		COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
		if [ "$?" -gt "0" ];
			then
			echo -e "${RED}Wallet not fully loaded. Let us wait and try again to generate the GEN Key${NC}"
			sleep 30
			COINKEY=$($COIN_PATH$COIN_CLI masternode genkey)
		fi
		$COIN_PATH$COIN_CLI stop
	fi
	clear
}

function update_config() {
	sed -i 's/daemon=1/daemon=0/' $CONFIGFOLDER/$CONFIG_FILE
	cat << EOF >> $CONFIGFOLDER/$CONFIG_FILE
logintimestamps=1
maxconnections=256
#bind=$NODEIP
masternode=1
externalip=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY

#Addnodes



EOF
}


function enable_firewall() {
	echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$COIN_PORT${NC}"
	ufw allow $COIN_PORT/tcp comment "$COIN_NAME MN port" >/dev/null
	ufw allow ssh comment "SSH" >/dev/null 2>&1
	ufw limit ssh/tcp >/dev/null 2>&1
	ufw default allow outgoing >/dev/null 2>&1
	echo "y" | ufw enable >/dev/null 2>&1
}


function get_ip() {
	declare -a NODE_IPS
	for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
	do
	NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
	done

if [ ${#NODE_IPS[@]} -gt 1 ]
	then
	echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
	INDEX=0
	for ip in "${NODE_IPS[@]}"
	do
		echo ${INDEX} $ip
		let INDEX=${INDEX}+1
	done
	read -e choose_ip
	NODEIP=${NODE_IPS[$choose_ip]}
	else
		NODEIP=${NODE_IPS[0]}
fi
}


function compile_error() {
	if [ "$?" -gt "0" ]; then
		echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
		exit 1
	fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
	echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
	exit 1
fi

if [[ $EUID -ne 0 ]]; then
	echo -e "${RED}$0 must be run as root.${NC}"
	exit 1
fi

if [ -n "$(pidof $COIN_DAEMON)" ] || [ -e "$COIN_DAEMOM" ] ; then
	echo -e "${RED}$COIN_NAME is already installed.${NC}"
	exit 1
fi
}

function prepare_system() {

	echo -e "Preparing the VPS for a ${CYAN}$COIN_NAME${NC} ${RED}Masternode${NC}"
	apt-get update >/dev/null 2>&1
	DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
	DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
	apt install -y software-properties-common >/dev/null 2>&1

	echo -e "${PURPLE}Adding bitcoin PPA repository"
	apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1

	echo -e "Installing required packages, this may take some time to finish.${NC}"
	apt-get update >/dev/null 2>&1
	apt-get upgrade -y >/dev/null 2>&1
	apt-get install libzmq3-dev -y >/dev/null 2>&1
	apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
	build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
	libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
	libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev  libdb5.3++ unzip libzmq5 >/dev/null 2>&1

	if [ "$?" -gt "0" ]; then
		echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
		echo "apt-get update"
		echo "apt -y install software-properties-common"
		echo "apt-add-repository -y ppa:bitcoin/bitcoin"
		echo "apt-get update"
		echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
		libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git curl libdb4.8-dev \
		bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw pkg-config libevent-dev libdb5.3++ unzip libzmq5"
		exit 1
	fi
	clear
	
	echo -e "Checking if swap space is needed."
	PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
	if [ "$PHYMEM" -lt "2" ]; then
		echo -e "${GREEN}Server is running with less than 2G of RAM, creating 2G swap file.${NC}"
		dd if=/dev/zero of=$SWAPFILE bs=1024 count=2M
		chmod 600 $SWAPFILE
		mkswap $SWAPFILE
		swapon -a $SWAPFILE
		MADE_SWAP=1
	else
		echo -e "${GREEN}Server running with at least 2G of RAM, no swap needed.${NC}"
	fi
}

function cleanswap() {
	
	# remove swapfile
	swapoff $SWAPFILE		
	rm $SWAPFILE
					
}


function important_information() {
	echo
	echo -e "${BLUE}================================================================================================================================${NC}"
	echo -e "${BLUE}================================================================================================================================${NC}"
	echo -e "${GREEN}$COIN_NAME Masternode is up and running listening on port ${NC}${PURPLE}$COIN_PORT${NC}."
	echo -e "${GREEN}Configuration file is: ${NC}${RED}$CONFIGFOLDER/$CONFIG_FILE${NC}"
	echo -e "${GREEN}Start: ${NC}${RED}systemctl start $COIN_NAME.service${NC}"
	echo -e "${GREEN}Stop: ${NC}${RED}systemctl stop $COIN_NAME.service${NC}"
	echo -e "${GREEN}IP: ${NC}${PURPLE}$NODEIP:$COIN_PORT${NC}"
	echo -e "${GREEN}MASTERNODE GENKEY is: ${NC}${PURPLE}$COINKEY${NC}"
	echo -e "${BLUE}================================================================================================================================${NC}"
	echo -e "${CYAN}Ensure Node is fully SYNCED with BLOCKCHAIN.${NC}"
	echo -e "${BLUE}================================================================================================================================${NC}"
	echo -e "${GREEN}Usage Commands.${NC}"
	echo -e "${GREEN}mambocoind masternode status${NC}"
	echo -e "${GREEN}mambocoind getinfo${NC}"
	echo -e "${GREEN}mambocoind getblockcount${NC}"
	echo -e "${BLUE}================================================================================================================================${NC}"
	echo -e "${BLUE}Donations MamboCoin (MMB) mXmcp6KvqQK8VAnHXNd5j8kB62VoFVj2cS${NC}"
	echo -e "${BLUE}================================================================================================================================${NC}"
}

function setup_node() {
	get_ip
	create_config
	create_key
	update_config
	enable_firewall
	configure_systemd
	important_information
}


##### Main #####
clear

purgeOldInstallation
checks
prepare_system
#compile_mambocoin
choose_build
port_prompt
setup_node
cleanswap

