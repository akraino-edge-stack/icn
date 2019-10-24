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
