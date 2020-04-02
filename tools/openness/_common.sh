# _install_go() - Install GoLang package
function _install_go {
    local tarball=go1.12.5.linux-amd64.tar.gz

    #gcc is required for go apps compilation
    if ! which gcc; then
        sudo apt-get install -y gcc
    fi

    if $(go version &>/dev/null); then
        return
    fi

    wget https://dl.google.com/go/$tarball
    sudo tar -C /usr/local -xzf $tarball
    rm $tarball

    export PATH=$PATH:/usr/local/go/bin
    sudo sed -i "s|^PATH=.*|PATH=\"$PATH\"|" /etc/environment
}

# _install_docker() - Download and install docker-engine
function _install_docker {
    sudo apt-get install -y apt-transport-https ca-certificates curl
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce

    sudo mkdir -p /etc/systemd/system/docker.service.d
    sudo systemctl daemon-reload
    if [[ -z $(groups | grep docker) ]]; then
        sudo usermod -aG docker $USER
    fi

    sudo systemctl restart docker
    sleep 10
}
