pipeline {
    agent any
    stages {
        stage('Checkout code') {
            steps {
                checkout scm
            }
        }
        stage('hello') {
            steps {
                sh 'echo Hello Jenkins!'
            }
        }
    }
}