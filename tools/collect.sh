#!/usr/bin/env bash

ICN_PATH=$1
if [ -z "$ICN_PATH" ]
then
  echo "lack ICN_PATH"
  exit 1
fi

apt update
apt-get install -y --download-only \
	crudini \
	curl \
	dnsmasq \
	figlet \
	golang \
	nmap \
	patch \
	psmisc \
	python-pip \
	python-requests \
	python-setuptools \
	vim \
	wget

mkdir -p $ICN_PATH/apt/deb/
cp /var/cache/apt/archives/*.deb  $ICN_PATH/apt/deb/
