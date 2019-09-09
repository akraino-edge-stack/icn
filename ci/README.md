# Setup a private Jenkins server from a refresh ubuntu


**Note:** As we don't support that downloading packages in sandbox for now,
it means that the packages are all downloaded directely from the jenkins
server. So that the jenkins server must have the same OS version with ICN
nodes. Currently, it's ubuntu 18.04 with kernel version 4.15.0-45-generic.

## How to setup jenkins server

Put the gerrit ssh key under `icn/ci/gerrit.key`
The default listening address is the default ip address of the Jenkins server.
To override the listening address/domain name, use variable `jenkins_hostname`.
The default Jenkins username/password is `admin/admin`. To overrides it, use variables
`jenkins_admin_username` and `jenkins_admin_password`.

```bash
git clone "https://gerrit.akraino.org/r/icn" # may need to switch the branch based on your case
cd icn/ci
sudo ./setup_jenkins.sh
sudo ansible-playbook site_jenkins.yaml -v
```

Once the playbook is successful, we can visite the jenkins server at http://<listen_address>:8080.
