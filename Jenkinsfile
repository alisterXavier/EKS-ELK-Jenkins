pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID = credentials('aws_access_key')
        AWS_SECRET_ACCESS_KEY = credentials('aws_secret_key')
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_ACC_ID = credentials('aws_acc_id')
        LICENCE_KEY = credentials('licence_key')
        KSM_IMAGE_VERSION="v2.10.0" 
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

        stage ('Terraform state account check'){
            steps{
                script{
                    echo "Retrieving current state..."
                    sh 'terraform state pull > tfstate.json'
                    
                    def arn = sh(script: "jq -r '.resources[0].instances[0].attributes.arn' tfstate.json", returnStdout: true).trim()

                    if (arn) {
                        def stateAccountId = arn.split(':')[4]

                        if (stateAccountId != env.AWS_ACC_ID) {
                            echo "State account ID does not match. Deleting previous state..."
                            sh 'rm -rf terraform.tfstate'
                        } else {
                            echo "State account ID matches. Proceeding..."
                        }
                    } else {
                        echo "No resources found in state. Skipping further checks."
                    }
                }
            }
        }

        stage('Terraform init & apply') {
            steps {
                script {
                    if(fileExists(".terraform")){
                        echo "Detected existing terraform resources. Verifying if reinitialization is needed..."
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
                    EFS_HANDLER = sh(script: "terraform output -raw efs_id", returnStdout: true).trim() 
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
                script{
                    echo 'Updating local kubeconfig...'
                sh 'aws eks update-kubeconfig --name=thunder'
                
                echo 'Creating service accounts...'
                sh "sed 's|<ACC_ID>|${AWS_ACC_ID}|g' k8s/service-account.yaml | kubectl apply -f -"

                echo 'Creating namespace...'
                sh 'kubectl apply -f k8s/namespace.yaml'

                echo 'Creating deployments...'
                sh 'kubectl apply -f k8s/deployments.yaml'

                echo 'Creating services...'
                sh 'kubectl apply -f k8s/services.yaml'

                echo 'Creating ingress...'
                publicSubnetsString = PUBLIC_SUBNETS.join(",")
                echo "$publicSubnetsString"
                sh "sed 's|<PUBLIC_SUBNETS>|${publicSubnetsString}|g' k8s/ingress.yaml | kubectl apply -f -"

                echo "Creating pv and pvc..."
                sh "sed 's|<EFS_HANDLER>|${EFS_HANDLER}|g' k8s/pv.yaml | kubectl apply -f -"
                
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
                
                echo 'Installing auto scaler controller...'
                sh """
                    helm install aws-auto-scaler-controller autoscaler/cluster-autoscaler \
                    --set autoDiscovery.clusterName=thunder \
                    --set rbac.serviceAccount.name=cluster-autoscaler-controller \
                    --set rbac.serviceAccount.create=false \
                    --set awsRegion=us-east-1 -n kube-system
                """

                echo 'Installing load balancer controller...'
                sh """
                    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
                    --set clusterName=thunder \
                    --set serviceAccount.create=false \
                    --set region=us-east-1 \
                    --set vpcId="vpc-0d43997db3669626a" \
                    --set serviceAccount.name="aws-load-balancer-controller" \
                    -n kube-system
                """

                }
            }
        }

        stage('New relic setup'){
            steps{

                echo "Setting up new relic..."
                sh """
                    helm repo add newrelic https://helm-charts.newrelic.com && \
                    helm repo update ; \
                    helm upgrade --install newrelic-bundle newrelic/nri-bundle \
                    --set global.licenseKey=${LICENCE_KEY} \
                    --set global.cluster=thunder --namespace=monitoring \
                    --set newrelic-infrastructure.privileged=true \
                    --set global.lowDataMode=true --set kube-state-metrics.image.tag=${KSM_IMAGE_VERSION} \
                    --set kube-state-metrics.enabled=true --set kubeEvents.enabled=true \
                    --set newrelic-prometheus-agent.enabled=true --set newrelic-prometheus-agent.lowDataMode=true \
                    --set newrelic-prometheus-agent.config.kubernetes.integrations_filter.enabled=false \
                    --set k8s-agents-operator.enabled=true --set logging.enabled=true --set newrelic-logging.lowDataMode=true
                    """
            }
        }
    }
}