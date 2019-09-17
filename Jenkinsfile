pipeline {
    agent any
    stages {
        stage('Build ISO Image') {
            steps {
                sh 'sudo icn/tools/setup_build_machine.sh'
                // sh 'sudo icn/tools/collect.sh'
                sh 'sudo icn/tools/create_usb_bootable.sh'

            }
        }
    }
    post {
        always {
            archiveArtifacts artifacts: 'icn-ubuntu-18.04.iso', onlyIfSuccessful: true
        }
    }
}
