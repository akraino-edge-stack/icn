#!/usr/bin/env bash
set -eux -o pipefail

SCRIPT_DIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"

WITH_VAGRANT="${WITH_VAGRANT:-yes}"
JENKINS_HOSTNAME="${JENKINS_HOSTNAME:-localhost}"
JENKINS_ADMIN_USERNAME="${JENKINS_ADMIN_USERNAME:-admin}"
JENKINS_ADMIN_PASSWORD="${JENKINS_ADMIN_PASSWORD:-admin}"
JENKINS_LFTOOLS_USERNAME="${JENKINS_LFTOOLS_USERNAME:-icn.jenkins}"
JENKINS_SSH_USERNAME="${JENKINS_SSH_USERNAME:-icn.jenkins}"
CLUSTER_MASTER_IP="${CLUSTER_MASTER_IP:-localhost}"
CLUSTER_SSH_USER="${CLUSTER_SSH_USER:-root}"

BUILD_DIR=${SCRIPT_DIR/icn/icn/build}
mkdir -p ${BUILD_DIR}

ICN_DIR="${SCRIPT_DIR}/.."
# The ci-management repo must be a sibling of the icn repo
CI_MANAGEMENT_DIR="${ICN_DIR}/../ci-management"
JJB_PATH="${CI_MANAGEMENT_DIR}/jjb:${ICN_DIR}/ci/jjb"

# Workaround for KuD installer which messes with /etc/environment
function cleanup_after_kud {
    sed -i -e '/ANSIBLE_CONFIG/d' /etc/environment
}

function install_jenkins {
    # Prerequisites
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ca-certificates python3-pip
    pip3 install ansible jenkins-job-builder lftools

    # Jenkins
    ansible-galaxy install -r ${SCRIPT_DIR}/galaxy-requirements.yaml --roles-path /etc/ansible/roles
    ansible-playbook ${SCRIPT_DIR}/site_jenkins.yaml --extra-vars "@${SCRIPT_DIR}/vars.yaml" -v

    # The Bluval job requires docker access
    usermod -aG docker jenkins

    # Restart Jenkins to take into account any group changes above
    systemctl restart jenkins

    # Jenkins jobs
    mkdir -p ${HOME}/.config/jenkins_jobs
    cp ${SCRIPT_DIR}/jenkins_jobs.ini ${HOME}/.config/jenkins_jobs/jenkins_jobs.ini
    git clone --recursive https://gerrit.akraino.org/r/ci-management "${CI_MANAGEMENT_DIR}"

    # TODO Figure out how to automate this, it doesn't appear to be exposed with jenkins-cli.jar
    cat <<EOF
Git plugin 4.4 removes the second fetch operation in most cases. This
prevents the CI jobs from checking out the correct version.

To enable the second fetch, check the following in the Jenkins web UI:
  Manage Jenkins -> Configure System -> [X] Preserve second fetch during checkout
EOF
}

function install_credentials {
    if [[ ! -f ${JENKINS_SSH_PRIVATE_KEY} ]]; then
        echo "JENKINS_SSH_PRIVATE_KEY must be set to the path of the private key of ${JENKINS_SSH_USERNAME}"
        exit 1
    fi

    wget http://${JENKINS_HOSTNAME}:8080/jnlpJars/jenkins-cli.jar -O ${BUILD_DIR}/jenkins-cli.jar
    cat <<EOF >${BUILD_DIR}/jenkins-ssh-credential.xml
<com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials@1.13">
  <scope>GLOBAL</scope>
  <id>jenkins-ssh</id>
  <description></description>
  <username>${JENKINS_SSH_USERNAME}</username>
  <privateKeySource class="com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\$DirectEntryPrivateKeySource">
    <privateKey>$(cat ${JENKINS_SSH_PRIVATE_KEY})</privateKey>
  </privateKeySource>
</com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>
EOF
    java -jar ${BUILD_DIR}/jenkins-cli.jar -auth ${JENKINS_ADMIN_USERNAME}:${JENKINS_ADMIN_PASSWORD} -s http://${JENKINS_HOSTNAME}:8080/ create-credentials-by-xml system::system::jenkins _  <${BUILD_DIR}/jenkins-ssh-credential.xml
}

function install_lftools_credentials {
    cat <<EOF >/var/lib/jenkins/.netrc
machine nexus.akraino.org login ${JENKINS_LFTOOLS_USERNAME} password ${JENKINS_LFTOOLS_PASSWORD}
EOF
    chown jenkins:jenkins /var/lib/jenkins/.netrc
    chmod 0600 /var/lib/jenkins/.netrc
}

function update_jobs {
    # TODO Find a better way to do this without touching files under
    # source control
    sed -i -e "s!git-url: .*!git-url: 'ssh://${JENKINS_SSH_USERNAME}@gerrit.akraino.org:29418'!" ${SCRIPT_DIR}/jjb/defaults.yaml
    sed -i -e "s!bluval-cluster-master-ip: .*!bluval-cluster-master-ip: ${CLUSTER_MASTER_IP}!" ${SCRIPT_DIR}/jjb/defaults.yaml
    sed -i -e "s!bluval-cluster-ssh-user: .*!bluval-cluster-ssh-user: ${CLUSTER_SSH_USER}!" ${SCRIPT_DIR}/jjb/defaults.yaml

    # This will create all 344 jobs:
    # jenkins-jobs update ${JJB_PATH}:${ICN_DIR}/ci/jjb/project.yaml

    # These are the ICN jobs we are interested in
    if [[ ${WITH_VAGRANT} == "yes" ]]; then
        jenkins-jobs update ${JJB_PATH} icn-master-vagrant-verify-verifier
    fi
    jenkins-jobs update ${JJB_PATH} icn-master-bm-verify-bm_verifier
    jenkins-jobs update ${JJB_PATH} icn-bluval-daily-master
    #jenkins-jobs update ${JJB_PATH} icn-master-verify

    # These are additional ICN jobs:
    # if [[ ${WITH_VAGRANT} == "yes" ]]; then
    #     jenkins-jobs update ${JJB_PATH} icn-master-vagrant-verify-verify_nestedk8s
    # fi
}

function install_jenkins_id {
    # Create a new key if one does not exist
    ssh-keygen -q -t rsa -N '' -f /var/lib/jenkins/jenkins-rsa -C jenkins@$(hostname) <<<n >/dev/null 2>&1 || true
    ssh-copy-id -i /var/lib/jenkins/jenkins-rsa -f ${CLUSTER_SSH_USER}@${CLUSTER_MASTER_IP}
    chown jenkins:jenkins /var/lib/jenkins/jenkins-rsa*
    chmod 600 /var/lib/jenkins/jenkins-rsa*
}

case $1 in
    "cleanup-after-kud") cleanup_after_kud ;;
    "install-credentials") install_credentials ;;
    "install-jenkins") install_jenkins ;;
    "install-jenkins-id") install_jenkins_id ;;
    "install-lftools-credentials") install_lftools_credentials ;;
    "update-jobs") update_jobs ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  cleanup-after-kud            - Cleanup after KuD install
  install-credentials          - Install credentials into Jenkins
  install-jenkins              - Install Jenkins
  install-jenkins-id           - Install Jenkins ID into test cluster
  install-lftools-credentials  - Install lftools credentials
  update-jobs                  - Install or update ICN jobs into Jenkins

Environment variables used by the commands:
  WITH_VAGRANT=[yes|no]    - Install components needed to run the VM
                             verifier job
  JENKINS_HOSTNAME         - jenkins_hostname in vars.yaml
  JENKINS_ADMIN_USERNAME   - jenkins_admin_username in vars.yaml
  JENKINS_ADMIN_PASSWORD   - jenkins_admin_password in vars.yaml
  JENKINS_LFTOOLS_USERNAME - The .netrc login
  JENKINS_LFTOOLS_PASSWORD - The .netrc password
  JENKINS_SSH_USERNAME     - The gerrit account username
  JENKINS_SSH_PRIVATE_KEY  - The gerrit account private key file
  CLUSTER_MASTER_IP        - The cluster under test
  CLUSTER_SSH_USER         - The cluster account username
EOF
       ;;
esac
