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
                echo "refspec: ${GERRIT_REFSPEC}, branch: ${GERRIT_BRANCH}"
            }
        }
    }
}
