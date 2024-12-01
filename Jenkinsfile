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
                    def stsCheck = sh(script: 'aws sts get-caller-identity > /dev/null', returnStatus: true)

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

        // stage('Approval for Terraform') {
        //     steps {
        //         script {
        //             input message: 'Proceed with the Terraform?'
        //         }
        //     }
        // }

        stage ('Terraform state check'){
            steps{
                script{
                    sh 'terraform state pull > tfstate.json'
                    def arn = sh(script: "jq -r '.resources[0].instances[0].attributes.arn' tfstate.json", returnStdout: true).trim()

                    def stateAccountId = arn.split(':')[4]

                    if(stateAccountId != env.AWS_ACC_ID){
                        echo "DELETING PREVIOUS STATE"
                        sh 'rm -rf terraform.tfstate'
                    }
                }
            }
        }

        stage('TERRAFORM INIT & APPLY') {
            steps {
                script {
                    sh 'terraform init'
                    sh 'terraform apply --auto-approve'
                }
            }
        }

        stage('Storing terraform outputs'){
            steps{
                echo "Storing public subets id..."
                PUBLIC_SUBNETS = sh(script: 'terraform output -json Public_Subnets', returnStdout: true).trim()
                
                echo "Storing vpc id..."
                VPC_ID = sh(script: 'terraform output -raw Vpc_Id', returnStdout: true).trim()
            }
        }

        stage('Approval for EKS') {
            steps {
                script {
                    input message: 'Proceed with the EKS Setup?'
                }
            }
        }

        stage("ADDING HELM REPOS"){
            steps{
                echo "Adding AWS EKS Helm repository..."
                sh "helm repo add eks-charts https://aws.github.io/eks-charts"
                
                echo "Adding Kubernetes Cluster Autoscaler Helm repository..."
                sh "helm repo add autoscaler https://kubernetes.github.io/autoscaler"
                
                echo "Updating Helm repository index..."
                sh "helm repo update"
            }
        }

        stage('EKS SETUP') {
            steps {
                echo 'Updating local kubeconfig...'
                sh 'aws eks update-kubeconfig --name=thunder'

                echo 'Creating service accounts...'
                sh 'envsubst < service-account.yaml | kubectl apply -f -'

                echo 'Creating namespace...'
                sh 'kubectl apply -f k8s/namespace.yaml'

                echo 'Creating deployments...'
                sh 'kubectl apply -f k8s/deployments.yaml'

                echo 'Creating services...'
                sh 'kubectl apply -f k8s/services.yaml'

                echo 'Creating ingress...'
                sh 'envsubst < ingress.yaml | kubectl apply -f -'

                echo 'Installing load balancer controller...'
                sh """
                    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                    --set clusterName=thunder \
                    --set serviceAccount.create=false \
                    --set region=us-east-1 \
                    --set vpcId="$VPC_ID" \
                    --set serviceAccount.name """

                echo 'Installing auto scaler controller...'
                sh "helm install aws-auto-scaler-controller autoscaler/cluster-autoscaler \
                    --set autoDiscovery.clusterName=thunder \
                    --set rbac.serviceAccount.name=cluster-autoscaler-controller \
                    --set rbac.serviceAccount.create=false \
                    --set awsRegion=us-east-1 -n kube-system"
            }
        }
    }
}
