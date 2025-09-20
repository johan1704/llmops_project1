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
            [$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-token'],
            sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
            string(credentialsId: 'groq-api-key', variable: 'GROQ_API_KEY')
        ]) {
            script {
                def accountId = sh(script: "aws sts get-caller-identity --query Account --output text", returnStdout: true).trim()
                def ecrUrl = "${accountId}.dkr.ecr.${env.AWS_REGION}.amazonaws.com/${env.ECR_REPO}"
                def imageFullTag = "${ecrUrl}:${IMAGE_TAG}"

                echo "Deploying to EC2 instance: ${env.EC2_INSTANCE_IP}"

                sh """
                #!/bin/bash
                # Nettoyer les ressources Docker existantes sur EC2
                ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${env.EC2_SSH_USER}@${env.EC2_INSTANCE_IP} << 'EOF'
                
                # Nettoyer les anciens conteneurs et images
                sudo docker stop ${env.SERVICE_NAME} || true
                sudo docker rm ${env.SERVICE_NAME} || true
                sudo docker system prune -a -f || true
                
                # Se connecter à ECR
                export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
                export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
                export AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}
                aws ecr get-login-password --region ${env.AWS_REGION} | sudo docker login --username AWS --password-stdin ${ecrUrl}
                
                # Pull et run la nouvelle image avec la variable d'environnement
                sudo docker pull ${imageFullTag}
                sudo docker run -d \\
                    --name ${env.SERVICE_NAME} \\
                    -p 80:5000 \\
                    --restart unless-stopped \\
                    -e GROQ_API_KEY=${GROQ_API_KEY} \\
                    ${imageFullTag}
                
                # Vérifier le déploiement
                echo "Deployment completed. Container status:"
                sudo docker ps | grep ${env.SERVICE_NAME}
                
                # Vérifier que la variable d'environnement est bien définie
                sudo docker exec ${env.SERVICE_NAME} printenv GROQ_API_KEY
                
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
