pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('aws_access_key')
        AWS_SECRET_ACCESS_KEY = credentials('aws_secret_key')
        AWS_DEFAULT_REGION = "us-east-1"
        AWS_ACC_ID = credentials('aws_acc_id')
        NEW_RELIC_API_KEY = credentials('new_relic_api_key')
        NEW_RELIC_ACC_ID = credentials('new_relic_acc_id')
    }

    stages {

        // stage('Verifying packages'){
        //     steps{
        //         echo "Verifying is packages are installed..."
        //         aws-cli, gettext, helm, kubectl, terraform, jq

        //         script{
        //             def tools = ['aws', 'gettext', 'helm', 'kubectl', 'terraform', 'jq']
        //             tools.each { tool ->
        //                 def command = "which ${tool}".execute()
        //                 def output = 
        //                 if (command -v $tool &> /dev/null)
        //                     echo "$tool: installed"
        //                 } else{
        //                     echo "$tool: not installed"
        //                 }
        //             }
        //         }
        //     }
        // }

        stage('Aws setup'){
            steps{
                script{
                    def stsCheck = sh(script: 'aws sts get-caller-identity > /dev/null', returnStatus: true)

                    if(stsCheck != 0){
                        echo "Aws is not configured..."
                        
                        echo "Configuring aws..."
                        sh """
                            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                            aws configure set region $AWS_DEFAULT_REGION
                        """

                    }else{
                        echo "Aws is configured skipping aws configure..."
                    }
                }
            }
        }

        stage ('Terraform state check'){
            steps{
                script{
                    echo "Retrieving current state..."
                    sh 'terraform state pull > tfstate.json'
                    def arn = sh(script: "jq -r '.resources[0].instances[0].attributes.arn' tfstate.json", returnStdout: true).trim()

                    def stateAccountId = arn.split(':')[4]

                    if(stateAccountId != env.AWS_ACC_ID){
                        echo "Deleting preivous state..."
                        sh 'rm -rf terraform.tfstate'
                    }
                }
            }
        }

        stage('Terraform init & apply') {
            steps {
                script {

                    if(fileExists(".terraform")){
                        echo "Detected existing terraform resources. Verifying is reinitialization is needed..."
                        def initStatus = sh(script: "terraform init  -backend=false > /dev/null", returnStatus: true)

                        if(initStatus != 0){
                            echo "Terraform initialization required due to changes in the configuration. Running 'terraform init'..."
                            sh 'terraform init'
                        }
                        else{
                            echo "Terraform is already initialized and up-to-date."
                        }
                    }
                    else{
                        echo "No terraform resources detected. Running 'terraform init'..."
                        sh "terraform init"
                    }

                    def planStatus = sh(script: 'terraform plan -detailed-exitcode > /dev/null', returnStatus: true)
                    if(planStatus == 2){
                        echo "Detected new terraform resources. Running 'terraform apply'..."
                        sh 'terraform apply --auto-approve'
                    }else if(planStatus == 1){
                        echo "Error running terraform plan. Exiting..."
                        error("Terraform plan failed")
                    }
                    else{
                        echo "Terraform resources are up-to-date. Skipping 'terraform apply'..."
                    }
                }
            }
        }

        stage('Storing terraform outputs'){
            steps{
                script{
                    echo "Storing public subets id..."
                    PUBLIC_SUBNETS = sh(script: 'terraform output -json Public_Subnets', returnStdout: true).trim()
                    
                    echo "Storing vpc id..."
                    VPC_ID = sh(script: 'terraform output -raw Vpc_Id', returnStdout: true).trim()  

                    echo "Storing efs handle..."
                    EFS_ID = sh(script: 'terraform output -raw efs_id', returnStdout: true).trim()  
                }
            }
        }

        stage("Adding helm repos"){
            steps{
                echo "Adding AWS EKS Helm repository..."
                sh "helm repo add eks https://aws.github.io/eks-charts"
                
                echo "Adding Kubernetes Cluster Autoscaler Helm repository..."
                sh "helm repo add autoscaler https://kubernetes.github.io/autoscaler"
                
                echo "Adding Prometheus Helm repository..."
                sh "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts"

                echo "Adding EBS Driver Helm repository..."
                sh "helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver/"

                echo "Updating Helm repository index..."
                sh "helm repo update"
            }
        }
        
        stage('Eks setup') {
            steps {
                echo 'Updating local kubeconfig...'
                sh 'aws eks update-kubeconfig --name=thunder'

                echo 'Creating service accounts...'
                sh 'envsubst < k8s/service-account.yaml | kubectl apply -f -'

                echo 'Creating namespace...'
                sh 'kubectl apply -f k8s/namespace.yaml'

                echo 'Creating deployments...'
                sh 'kubectl apply -f k8s/deployments.yaml'

                echo 'Creating services...'
                sh 'kubectl apply -f k8s/services.yaml'

                echo 'Creating ingress...'
                sh 'envsubst < k8s/ingress.yaml | kubectl apply -f -'

                echo "Creating pv and pvc..."
                sh "envsubst < k8s/pv.yaml | kubectl apply -f -"

                echo "Installing ebs driver..."
                sh "helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver --namespace kube-system"

                echo 'Creating metric server...'
                sh "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
                
                echo "Installing prometheus server..."
                sh """
                    helm install prometheus prometheus-community/prometheus \
                    --namespace monitoring \
                    --set alertmanager.persistentVolume.storageClass="gp2" \
                    --set server.persistentVolume.storageClass="gp2"
                """

                echo 'Installing load balancer controller...'
                sh """
                    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                    --set clusterName=thunder \
                    --set serviceAccount.create=false \
                    --set region=us-east-1 \
                    --set vpcId="$VPC_ID" \
                    --set serviceAccount.name="aws-load-balancer-controller"
                """

                echo 'Installing auto scaler controller...'
                sh """
                    helm install aws-auto-scaler-controller autoscaler/cluster-autoscaler \
                    --set autoDiscovery.clusterName=thunder \
                    --set rbac.serviceAccount.name=cluster-autoscaler-controller \
                    --set rbac.serviceAccount.create=false \
                    --set awsRegion=us-east-1 -n kube-system
                """
            }
        }

        stage('New relic setup'){
            steps{

                echo "Setting up new relic..."
                sh """
                    curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh |
                    bash && NEW_RELIC_CLI_SKIP_CORE=1 \
                    NR_CLI_CLUSTERNAME=thunder \
                    NR_CLI_NAMESPACE=monitoring \
                    NR_CLI_LOW_DATA_MODE=true \
                    NR_CLI_KSM=true \
                    NR_CLI_KUBE_EVENTS=true \
                    NR_CLI_GKE_AUTOPILOT=false \
                    NR_CLI_PRIVILEGED=true \
                    NR_CLI_PROMETHEUS_AGENT=true \
                    NR_CLI_PROMETHEUS_AGENT_LOW_DATA_MODE=true \
                    NR_CLI_CURATED=false NR_CLI_AGENT_OPERATOR=true \
                    NR_CLI_LOGGING=true \
                    NR_CLI_LOGGING_LOW_DATA_MODE=true \
                    NEW_RELIC_API_KEY=$NEW_RELIC_API_KEY \
                    NEW_RELIC_ACCOUNT_ID=$NEW_RELIC_ACC_ID \
                    NEW_RELIC_REGION=EU /usr/local/bin/newrelic install -n kubernetes-open-source-integration"""

                echo "Applying new relic..."
                sh "kubectl apply -f k8s/instrumentation.yaml -n monitoring"
            }
        }
    }
}