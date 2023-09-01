pipeline {
    agent any 
     environment {
        AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    }
    stages {
        stage('git_checkout') {
            steps {
               git branch: 'main', url: 'https://github.com/vrthamizharasan/terraform_pipeline.git'
            }
        }
        stage('terraform_version'){
            steps {
                sh "terraform --version"
            }
        }
        stage('terraform_init') {
            steps {
                sh "terraform init"
            }
        }
        stage('terraform_plan') {
            steps {
                sh "pwd; cd /var/lib/jenkins/workspace/terraform_pipeline/ ; terraform plan"
            }
        }
        stage('terraform_apply') {
            steps {
                sh "pwd; cd /var/lib/jenkins/workspace/terraform_pipeline/ ; terraform apply --auto-approve"
            }
        }
    }
}
