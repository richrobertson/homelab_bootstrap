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
                    git branch: env.BRANCH_NAME,
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
        stage('Terraform Workspace (if not main)') {
            when {
                expression {
                    return env.BRANCH_NAME != 'main';
                }
            }
            steps {
                sh 'cd terraform && terraform workspace select -or-create ' + env.BRANCH_NAME + ' && terraform init'
            }
        }
        stage('Terraform plan') {
            steps {
                script {
                    def tf_plan = sh(script: 'cd terraform && terraform plan -input=false -out=tfplan', returnStdout: true).trim()
                    echo "${tf_plan}"
                }
            }
        }
        stage('Post plan status') {
            when {
                // This stage will only run if it's a pull request
                // env.CHANGE_ID is a variable available in Multibranch Pipelines for PRs
                expression { return env.CHANGE_ID != null } 
            }
            steps {
                script {
                    // Post the plan output as a comment on the PR
                    def tf_plan = sh(script: 'cd terraform && terraform show -no-color tfplan', returnStdout: true).trim()
                    def comment_body = "### Terraform Plan for branch `${env.BRANCH_NAME}`\n```\n${tf_plan}\n```"
                    githubPRComment(comment: { content: comment_body } )
                }
            }
        }
        stage('Approval') {
            when {
                // This stage will only run if it's a pull request
                // env.CHANGE_ID is a variable available in Multibranch Pipelines for PRs
                expression { return env.CHANGE_ID == null } 
            }
            steps {
                script {
 
                    // Wait for approval
                    input message: 'Do you approve this deployment?'
                }
            }
        }
        stage('Terraform apply') {
            when {
                // This stage will only run if it's a pull request
                // env.CHANGE_ID is a variable available in Multibranch Pipelines for PRs
                expression { return env.CHANGE_ID == null } 
            }
            steps {
                sh 'cd terraform && terraform apply -input=false -auto-approve tfplan'
            }
        }
    }
}