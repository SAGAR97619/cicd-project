pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')      // Jenkins credential ID (username+password)
        DOCKERHUB_USER        = 'sagarsaini9761'
        IMAGE_NAME            = "${DOCKERHUB_USER}/myapp"
        IMAGE_TAG             = "${env.BUILD_NUMBER}"
        EC2_SSH_CRED          = 'ec2-ssh-key'                       // Jenkins credential ID (SSH private key)
        EC2_HOST              = 'ubuntu@13.61.114.203'
    }

    stages {

        stage('Checkout') {
            steps {
                echo "Pulling latest code from GitHub..."
                checkout scm
            }
        }

        stage('Install & Unit Test') {
            steps {
                echo "Setting up virtualenv and running tests..."
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --no-cache-dir -r app/requirements.txt
                    pip install --no-cache-dir pytest
                    cd app && python -m pytest test_app.py -v
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}..."
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo "Pushing image to Docker Hub..."
                sh '''
                    echo "$DOCKERHUB_CREDENTIALS_PSW" | docker login -u "$DOCKERHUB_CREDENTIALS_USR" --password-stdin
                    docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    docker push ${IMAGE_NAME}:latest
                '''
            }
        }

        stage('Deploy to EC2') {
            steps {
                echo "Deploying container to AWS EC2..."
                sshagent(credentials: [EC2_SSH_CRED]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${EC2_HOST} \
                        "IMAGE_TAG=${IMAGE_TAG} DOCKERHUB_USER=${DOCKERHUB_USER} bash -s" < scripts/deploy.sh
                    '''
                }
            }
        }

        stage('Post-Deploy Health Check') {
            steps {
                echo "Verifying deployment health..."
                sshagent(credentials: [EC2_SSH_CRED]) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no ${EC2_HOST} \
                        "curl -sf http://localhost/health || exit 1"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline succeeded. Deployed ${IMAGE_NAME}:${IMAGE_TAG} to EC2."
        }
        failure {
            echo "❌ Pipeline failed. Check logs above for the failing stage."
        }
        always {
            sh 'docker logout || true'
            cleanWs()
        }
    }
}
