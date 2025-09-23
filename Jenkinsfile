pipeline {
    agent any
    stages {
        stage('Git Checkout') {
            steps {
                script {
                    git branch: 'main',
                        credentialsId: 'c74b96b5-fb04-49f3-ab91-aeea0bddca35',
                        url: 'https://github.com/richrobertson/homelab_bootstrap.git'
                }
            }
        }
        stage('hello') {
            steps {
                sh 'echo Hello Jenkins!'
            }
        }
    }
}