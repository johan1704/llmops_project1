pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-2'
        ECR_REPO = 'my-repo'
        IMAGE_TAG = 'latest'
        SERVICE_NAME = 'llmops-medical-service'
        EC2_INSTANCE_IP = '3.142.238.25' // Remplacez par votre IP EC2
        EC2_SSH_USER = 'ubuntu' // 'ec2-user' pour Amazon Linux
        GROQ_API_KEY = credentials('groq-api-key') // Référence au credential Jenkins
    }
    
    stages {
        stage('Clone GitHub Repo') {
            steps {
                script {
                    echo 'Cloning GitHub repo to Jenkins...'    
                    checkout scmGit(branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[credentialsId: 'github-token', url: 'https://github.com/johan1704/llmops_project1.git']])             
                }
            }
        }

        stage('Build, Scan, and Push Docker Image to ECR') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-token']]) {
                    script {
                        def accountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
                        def ecrUrl = "${accountId}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}"
                        def imageFullTag = "${ecrUrl}:${IMAGE_TAG}"

                        sh """
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ecrUrl}
                        docker build -t ${env.ECR_REPO}:${IMAGE_TAG} .
                        trivy image --severity HIGH,CRITICAL --format json -o trivy-report.json ${env.ECR_REPO}:${IMAGE_TAG} || true
                        docker tag ${env.ECR_REPO}:${IMAGE_TAG} ${imageFullTag}
                        docker push ${imageFullTag}
                        """

                        archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                    }
                }
            }
        }
        
       
        stage('Deploy to EC2 Instance') {
    steps {
        withCredentials([
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-ec2-token'],
            sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
            string(credentialsId: 'groq-api-key', variable: 'GROQ_API_KEY')
        ]) {
            script {
                echo "Deploying to EC2 instance: ${env.EC2_INSTANCE_IP}"

                sh """
                ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${env.EC2_SSH_USER}@${env.EC2_INSTANCE_IP} << 'EOF'
                
                # Étape 1: Vérifier l'identité AWS
                aws sts get-caller-identity
                
                # Récupérer l'account ID pour construire l'URI ECR
                ACCOUNT_ID=\$(aws sts get-caller-identity --query Account --output text)
                ECR_URI="\$ACCOUNT_ID.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                IMAGE_URI="\$ECR_URI/${env.ECR_REPO}:${env.IMAGE_TAG}"
                
                echo "ECR URI: \$ECR_URI"
                echo "Image URI: \$IMAGE_URI"
                
                # Étape 2: Se connecter à ECR
                aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin \$ECR_URI
                
                # Nettoyer les anciens conteneurs
                docker stop ${env.SERVICE_NAME} || true
                docker rm ${env.SERVICE_NAME} || true
                
                # Étape 3: Pull de l'image
                docker pull \$IMAGE_URI
                
                # Étape 4: Run du conteneur
                docker run -d \\
                    --name ${env.SERVICE_NAME} \\
                    -p 80:5000 \\
                    --restart unless-stopped \\
                    -e GROQ_API_KEY=${GROQ_API_KEY} \\
                    \$IMAGE_URI
                
                # Vérification
                echo "Deployment completed. Container status:"
                docker ps | grep ${env.SERVICE_NAME}
                
EOF
                """
                
                echo "Deployment to EC2 instance completed successfully!"
            }
        }
    }
}
        stage('Verify Deployment') {
            steps {
                script {
                    echo "Verifying deployment on EC2 instance..."
                    
                    // Attendre quelques secondes que l'application démarre
                    sleep(30)
                    
                    // Test HTTP pour vérifier que l'application répond
                    sh """
                        response_code=\$(curl -s -o /dev/null -w "%{http_code}" http://${env.EC2_INSTANCE_IP})
                        echo "HTTP Response Code: \$response_code"
                        if [ "\$response_code" = "200" ]; then
                            echo "Application is running successfully!"
                        else
                            echo "Application may have issues. Response code: \$response_code"
                            exit 1
                        fi
                    """
                    
                    echo "Verification completed. Check http://${env.EC2_INSTANCE_IP} in your browser."
                }
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully! Application deployed to EC2: http://${env.EC2_INSTANCE_IP}"
        }
        failure {
            echo "Pipeline failed! Check the logs for details."
        }
    }
}
