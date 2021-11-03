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

1. If deploying the Jenkins server on a machine configured with KuD
   (i.e. an ICN jump server), first remove the `ANSIBLE_CONFIG` line
   from `/etc/environment` and login again.

   ``` shell
   ./ci.sh cleanup-after-kud
   logout
   ```

2. Install the Jenkins server into the machine. If the VM verifier
   Jenkins job will not be added later, set `WITH_VAGRANT=no` in the
   environment before running the install step.

   ``` shell
   # Use one of the following
   WITH_VAGRANT=no ./ci.sh install-jenkins
   ./ci.sh install-jenkins
   ```

   After the script has completed, the Jenkins server can be visited
   at http://<listen_address>:8080.

3. Add the Gerrit ssh key as Jenkins credential, so that the jobs can
   pull code from Gerrit. `JENKINS_SSH_PRIVATE_KEY` is the path to the
   private key file of the `icn.jenkins` Gerrit account.

   ``` shell
   JENKINS_SSH_PRIVATE_KEY="path/to/icn.jenkins/id_rsa"
   ./ci.sh install-credentials
   ```

  To use a different account, edit `git-url` in `jjb/defaults.yaml`
  with the account name and execute the above command with the
  username specified.

   ``` shell
   JENKINS_SSH_USERNAME="username"
   JENKINS_SSH_PRIVATE_KEY="path/to/username/id_rsa"
   ./ci.sh install-credentials
   ```

3. To push the logs to Akraino Nexus server, we need to create the
   authentication file for lftools.  The file should be owned by the
   `jenkins` user. The file path is `/var/lib/jenkins/.netrc` and the
   content should be one line `machine nexus.akraino.org login
   the_name password the_pass`

4. Add the ICN Jenkins jobs to Jenkins. The script adds only a subset
   of the available jobs; review the script for information about
   other jobs.

   ``` shell
   ./ci.sh update-jobs
   ```

## Job specific instructions

### icn-bluval

The Bluval job requires that Jenkins ssh into the cluster control
plane. The script can be used to create a new keypair for the
`jenkins` user and install the credentials into an existing cluster.

For example, where the control plane endpoint is at `192.168.151.254`
and there exists `/home/ubuntu/.kube/config`:

``` shell
CLUSTER_MASTER_IP=192.168.151.254
CLUSTER_SSH_USER=root
./ci.sh install-jenkins-id
```

The same values of `CLUSTER_MASTER_IP` and `CLUSTER_SSH_USER` should
be provided to the icn-bluval job in Jenkins. Note that
`CLUSTER_SSH_USER` must be `root` for the Bluval Lynis testing to
succeed.
