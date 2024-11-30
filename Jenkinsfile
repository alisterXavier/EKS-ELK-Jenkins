pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-credentials')
        AWS_SECRET_ACCESS_KEY = credentials('aws-credentials')
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