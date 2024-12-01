pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('aws_access_key')
        AWS_SECRET_ACCESS_KEY = credentials('aws_secret_key')
        AWS_DEFAULT_REGION = "us-east-1"
        AWS_ACC_ID = credentials('aws_acc_id')
    }

    stages {

        stage('AWS SETUP'){
            steps{
                script{
                    def stsCheck = sh(script: 'aws sts get-caller-identity', returnStatus: true)

                    if(stsCheck != 0){
                        echo "AWS IS NOT CONFIGURED"
                        
                        echo "CONFIGURING AWS"
                        sh """
                            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                            aws configure set region $AWS_DEFAULT_REGION
                        """

                    }else{
                        echo "AWS IS CONFIGURED, SKIPPING aws configure"
                    }
                }
            }
        }

        stage('Approval for Terraform') {
            steps {
                script {
                    input message: 'Proceed with the Terraform init?'
                }
            }
        }

        stage('TERRAFORM INIT & APPLY') {

            steps {
                script {
                    sh 'terraform init'
                    sh 'terraform apply --auto-approve'
                    PUBLIC_SUBNETS = sh(script: 'terraform output -json Public_Subnets', returnStdout: true).trim()
                    VPC_ID = sh(script: 'terraform output -raw Vpc_Id', returnStdout: true).trim()
                }
            }
        }

        stage('Approval for EKS') {
            steps {
                script {
                    input message: 'Proceed with the EKS Setup?'
                }
            }
        }
    
        stage('EKS SETUP') {
            steps {
                echo 'UPDATING LOCAL KUBECONFIG'
                sh 'aws eks update-kubeconfig --name=Flaming'

                echo 'CREATING SERVICE ACCOUNTS'
                sh"envsubst < service-account.yaml | kubectl apply -f -"

                echo 'CREATING NAMESPACE'
                sh 'kubectl apply -f k8s/namespace.yaml'

                echo 'CREATING DEPLOYMENTS'
                sh 'kubectl apply -f k8s/deployments.yaml'
                
                echo 'CREATING SERVICES'
                sh 'kubectl apply -f k8s/services.yaml'
                
                echo 'CREATING INGRESS'
                sh 'envsubst < ingress.yaml | kubectl apply -f -'

                echo 'INSTALLING LOAD BALANCER CONTROLLER'
                sh """
                    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                    --set clusterName=thunder \
                    --set serviceAccount.create=false \
                    --set region=us-east-1 \
                    --set vpcId="$VPC_ID" \
                    --set serviceAccount.name=aws-load-balancer-controller \
                    -n kube-system
                """
            }
        }
    }
}
