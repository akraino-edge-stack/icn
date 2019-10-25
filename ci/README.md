# Setup a private Jenkins server from a refresh ubuntu 18.04

Akraino community has a publich jenkins cluster, we run CI jobs there.
But the CD jobs, we need to run them in our private Jenkins cluster.
For now, we support only one node private jenkins deployment.
The only supported OS is ubuntu 18.04

## How to setup jenkins server

We define vars in `vars.yaml` to customize the deployment.
The default listening address is the default ip address of the Jenkins server.
To override the listening address/domain name, please set `jenkins_hostname`.
The default Jenkins username/password is `admin/admin`. To overrides it, please set
`jenkins_admin_username` and `jenkins_admin_password`.

```bash
git clone "https://gerrit.akraino.org/r/icn" # may need to switch the branch based on your case
cd icn/ci
sudo ./install_ansible.sh
sudo ansible-playbook site_jenkins.yaml --extra-vars "@vars.yaml" -v
```

Once the playbook is successful, we can visite the jenkins server at http://<listen_address>:8080.

## What to do next

1. Add the gerrit ssh key as jenkins credential, so that our jobs can pull code from the gerrit.
The credential ID field must be `jenkins-ssh`. As this is hard coded in the jobs.
2. To push the logs to Akraino Nexus server, we need to create the authentication file for lftools.
The file path is `/var/lib/jenkins/.netrc` and the content should be one line
`machine nexus.akraino.org login the_name password the_pass`
3. The last step is to deploy our CD jobs by jenkins-job-builder tool.

```
git clone "https://gerrit.akraino.org/r/ci-management"
git clone "https://gerrit.akraino.org/r/icn"
# create the jjb config file before moving on
# https://docs.releng.linuxfoundation.org/en/latest/jenkins-sandbox.html
jenkins-jobs test ci-management/jjb:icn/ci/jjb icn-master-verify
jenkins-jobs update ci-management/jjb:icn/ci/jjb icn-master-verify
```
