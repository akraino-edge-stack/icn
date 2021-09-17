#!/usr/bin/env bash
set -eux -o pipefail

# shellcheck disable=SC1091
source lib/logging.sh
# shellcheck disable=SC1091
source lib/common.sh

# Update to latest packages first
sudo apt -y update

# Install required packages

sudo apt -y install \
  crudini \
  curl \
  dnsmasq \
  figlet \
  golang \
  zlib1g-dev \
  libssl1.0-dev \
  nmap \
  patch \
  psmisc \
  python3-pip \
  wget

sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Install pyenv

if [[  $(cat ~/.bashrc) != *PYENV_ROOT* ]]; then
  if ! [ -d "$HOME/.pyenv" ] ; then
     git clone git://github.com/yyuu/pyenv.git ~/.pyenv
  fi
  # shellcheck disable=SC2016
  # shellcheck disable=SC2129
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
  # shellcheck disable=SC2016
  echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
  # shellcheck disable=SC2016
  echo -e 'if command -v pyenv 1>/dev/null 2>&1; then\n  eval "$(pyenv init -)"\nfi' >> ~/.bashrc
fi

if [[ $PATH != *pyenv* ]]; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  if command -v pyenv 1>/dev/null 2>&1; then
    eval "$(pyenv init -)"
  fi
fi

# There are some packages which are newer in the tripleo repos

# Setup yarn and nodejs repositories
#sudo curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
#curl -sL https://rpm.nodesource.com/setup_10.x | sudo bash -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

# Add this repository to install Golang 1.12
sudo add-apt-repository -y ppa:longsleep/golang-backports

# Update some packages from new repos
sudo apt -y update

# make sure additional requirments are installed

##No bind-utils. It is for host, nslookop,..., no need in ubuntu
sudo apt -y install \
  jq \
  libguestfs-tools \
  nodejs \
  qemu-kvm \
  libvirt-bin libvirt-clients libvirt-dev \
  golang-go \
  unzip \
  yarn \
  genisoimage

# Install python packages not included as rpms
sudo pip install \
  ansible==2.8.2 \
  lolcat \
  yq \
  virtualbmc==1.6.0 \
  python-ironicclient \
  python-ironic-inspector-client \
  lxml \
  netaddr \
  requests \
  setuptools \
  libvirt-python==5.7.0 \
