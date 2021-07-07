# Setup a private Jenkins server from a fresh Ubuntu 18.04

Akraino community has a public Jenkins cluster, we run CI jobs there.
But the CD jobs, we need to run them in our private Jenkins cluster.
For now, we support only one node private Jenkins deployment.  The
only supported OS is Ubuntu 18.04.

## How to setup Jenkins server

We define vars in `vars.yaml` to customize the deployment.  The
default listening address is the default IP address of the Jenkins
server.  To override the listening address/domain name, please set
`jenkins_hostname`.  The default Jenkins username/password is
`admin/admin`. To override it, please set `jenkins_admin_username` and
`jenkins_admin_password`.

1. Fetch the source for ICN and Akraino CI management.The ICN jenkins
job macros require that the the icn and ci-management directories are
peers.

** Note: Switch the branch of the repositories below as needed.**

``` shell
git clone https://gerrit.akraino.org/r/icn
git clone --recursive https://gerrit.akraino.org/r/ci-management
```

2. Install Jenkins.

```shell
cd icn/ci
sudo -H ./install_ansible.sh
sudo -H ansible-playbook site_jenkins.yaml --extra-vars "@vars.yaml" -v
```

Once the playbook is successful, we can visit the Jenkins server at
http://<listen_address>:8080.

## What to do next

1. Add the gerrit ssh key as Jenkins credential, so that our jobs can
pull code from the gerrit.  The credential ID field must be
`jenkins-ssh`, as this is hard coded in the jobs. The type should be
private key. The user name is the gerrit account name.

2. To push the logs to Akraino Nexus server, we need to create the
authentication file for lftools.  The file should be owned by Jenkins
user. The file path is `/var/lib/jenkins/.netrc` and the content
should be one line `machine nexus.akraino.org login the_name password
the_pass`

3. The last step is to deploy our CD jobs by jenkins-job-builder tool.

Basic Jenkins Job Builder (JJB) configuration using admin/admin
credentials.

``` shell
mkdir -p ~/.config/jenkins_jobs
cat << EOF | tee ~/.config/jenkins_jobs/jenkins_jobs.ini
[job_builder]
ignore_cache=True
keep_descriptions=False
recursive=True
retain_anchors=True
update=jobs

[jenkins]
user=admin
password=admin
url=http://localhost:8080
EOF
```

Install jenkins-job-builder.

``` shell
sudo -H pip3 install jenkins-job-builder
```

Install the job into Jenkins. The test command displays the output of
the job builder that will be installed into Jenkins; it is optional.

``` shell
jenkins-jobs test ci-management/jjb:icn/ci/jjb icn-master-verify
jenkins-jobs update ci-management/jjb:icn/ci/jjb icn-master-verify
```
