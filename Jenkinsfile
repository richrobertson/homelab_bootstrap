pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws_homelab_access_key')
        AWS_SECRET_ACCESS_KEY = credentials('aws_homelab_secret_access_key')
        VAULT_SKIP_VERIFY     = true
        VAULT_ADDR            = 'https://vault.myrobertson.net:8200'
        VAULT_TOKEN           = credentials('vault_token')
        TERRAFORM_PLAN_OUTPUT = ''
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
                    try {
                        //sh(script: 'cd terraform && terraform plan -input=false -detailed-exitcode -out=tfplan', returnStdout: true).trim()
                    
                        sh 'cd terraform && terraform plan -detailed-exitcode -out=tfplan.out'
                        // If plan exits with 0 (no changes) or 1 (error), we handle it here.
                        // If it exits with 2 (changes), the try-catch block will not execute this part.
                        env.TERRAFORM_PLAN_HAS_CHANGES = 'false'

                    } catch (Exception e) {
                        // If terraform plan exits with 2 (changes), it will throw an exception in Jenkins,
                        // as Jenkins treats non-zero exit codes as failures by default.
                        // We catch it and set a flag to indicate changes.
                        if (e.getMessage().contains("exit code 2")) {
                            env.TERRAFORM_PLAN_HAS_CHANGES = 'true'
                            sh 'cd terraform && terraform show -no-color tfplan.out > plan_output.txt'
                            env.TERRAFORM_PLAN_OUTPUT = readFile('plan_output.txt').trim()
                            env.TERRAFORM_PLAN_SUMMARY = sh(script: 'echo "' + env.TERRAFORM_PLAN_OUTPUT  + '" | grep "Plan: " ', returnStdout: true).trim()
                            echo "Terraform Plan Summary: ${env.TERRAFORM_PLAN_SUMMARY}"
                        } else {
                            // Handle other errors or re-throw if it's a critical failure
                            error "Terraform plan failed unexpectedly: ${e.getMessage()}"
                        }
                    }
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
                    def comment_body = "### Terraform Plan for branch `${env.BRANCH_NAME}`\n```\n${env.TERRAFORM_PLAN_SUMMARY}\n```"
                    githubPRComment(comment: gitHubPRMessage( content: comment_body ) )
                }
            }
        }
        stage('No Changes Detected') {
            when {
                expression { return env.TERRAFORM_PLAN_HAS_CHANGES == 'false' }
            }
            steps {
                echo 'No changes detected by Terraform plan. Skipping apply stage.'
            }
        }
        stage('Approval') {
            when {
                // This stage will only run if it's a pull request
                // env.CHANGE_ID is a variable available in Multibranch Pipelines for PRs
                expression { return env.CHANGE_ID == null && env.TERRAFORM_PLAN_HAS_CHANGES == 'true' } 
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
                expression { return env.CHANGE_ID == null && env.TERRAFORM_PLAN_HAS_CHANGES == 'true' } 
            }
            steps {
                sh 'cd terraform && terraform apply -input=false -auto-approve tfplan'
            }
        }
    }
}