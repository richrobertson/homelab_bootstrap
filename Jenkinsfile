pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws_homelab_access_key')
        AWS_SECRET_ACCESS_KEY = credentials('aws_homelab_secret_access_key')
        VAULT_SKIP_VERIFY     = true
        VAULT_ADDR            = 'https://vault.myrobertson.net:8200'
        VAULT_TOKEN           = credentials('vault_token')
    }
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
        stage('Terraform Init') {
            steps {
                sh 'cd terraform && terraform init'
            }
        }
    }
}