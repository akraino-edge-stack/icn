pipeline {
    agent any
    options {
        skipDefaultCheckout()
    }
    environment {
        changeBranch = "change-${GERRIT_CHANGE_NUMBER}-${GERRIT_PATCHSET_NUMBER}"
    }
    stages {
        stage("Build ISO Image") {
            steps {
                sh "sudo rm -rf icn build/ubuntu"
                sh "git clone https://gerrit.akraino.org/r/icn"
                dir("icn") {
                    sh "git fetch origin ${GERRIT_REFSPEC}:${changeBranch}"
                    sh "git checkout ${changeBranch}"
                    sh "git rebase origin/${GERRIT_BRANCH}"
                }
                sh "sudo icn/tools/setup_build_machine.sh"
                // sh "sudo icn/tools/collect.sh"
                sh "sudo icn/tools/create_usb_bootable.sh"
            }
        }
    }
    post {
        always {
            archiveArtifacts artifacts: "icn-ubuntu-18.04.iso", onlyIfSuccessful: true
        }
    }
}
