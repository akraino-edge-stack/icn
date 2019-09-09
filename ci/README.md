# Setup a private Jenkins server from a refresh ubuntu



**Note:** As we don't support that downloading packages in sandbox for now,
it means that the packages are all downloaded directely from the jenkins
server. So that the jenkins server must have the same OS version with ICN
nodes. Currently, it's ubuntu 18.04 with kernel version 4.15.0-45-generic.

## How to setup jenkins server

Put the gerrit ssh key under `icn/ci/gerrit.key`

```bash
git clone "https://gerrit.akraino.org/r/icn" # may need to switch the branch based on your case
cd icn/ci
sudo ./setup_jenkins.sh
sudo ansible-playbook site_jenkins.yaml -v
```
