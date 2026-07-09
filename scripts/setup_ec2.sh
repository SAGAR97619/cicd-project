#!/bin/bash
# scripts/setup_ec2.sh
# Run ONCE on a fresh EC2 instance (Amazon Linux 2023 / Ubuntu) to prepare it
# as a Docker deployment target for the Jenkins pipeline.

set -euo pipefail

echo ">> Updating packages"
sudo yum update -y 2>/dev/null || sudo apt-get update -y

echo ">> Installing Docker"
if command -v yum &> /dev/null; then
    sudo yum install -y docker
    sudo systemctl enable docker
    sudo systemctl start docker
else
    sudo apt-get install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
fi

echo ">> Adding ec2-user to docker group (avoids needing sudo for docker commands)"
sudo usermod -aG docker ec2-user || sudo usermod -aG docker ubuntu

echo ">> Installing curl (used for health checks) and git"
sudo yum install -y curl git 2>/dev/null || sudo apt-get install -y curl git

echo ">> Confirming Docker version"
docker --version

cat <<'EOF'

Next manual steps:
1. Log out and back in (or run `newgrp docker`) so the docker group takes effect.
2. On Jenkins server: add this EC2 host's SSH private key as a credential (ID: ec2-ssh-key).
3. Open inbound port 5000 (app) and 80 (nginx, if used) and 22 (SSH) in the EC2 Security Group.
4. Update Jenkinsfile's EC2_HOST env var to ec2-user@<this-instance-public-ip>.

EOF
