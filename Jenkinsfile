pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = withCredentials([string(credentialsId: 'aws_access_key', variable: 'access_key')]) {}
        AWS_SECRET_ACCESS_KEY = withCredentials([string(credentialsId: 'aws_secret_key', variable: 'secret_key')]) {}
    }

    stages {
        stage('Terraform init') {
            steps {
                echo $AWS_ACCESS_KEY_ID
            }
        }
        // stage('Build') {
        //     steps {
        //         echo 'Building..'
        //     }
        // }
        // stage('Test') {
        //     steps {
        //         echo 'Testing..'
        //     }
        // }
        // stage('Deploy') {
        //     steps {
        //         echo 'Deploying....'
        //     }
        // }
    }
}