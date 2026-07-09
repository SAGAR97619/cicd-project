# CI/CD Automation Pipeline for Application Deployment

End-to-end **Jenkins + GitHub + Docker** pipeline that automatically builds,
tests, containerizes, and deploys a sample web app to an **AWS EC2** instance
whenever code is pushed to GitHub.

## Architecture

```
Developer Push (GitHub)
        │
        ▼  (webhook)
   Jenkins Server
        │
        ├─ 1. Checkout code (GitHub plugin)
        ├─ 2. Install deps + run unit tests (pytest)
        ├─ 3. Build Docker image (multi-stage Dockerfile)
        ├─ 4. Push image to Docker Hub
        ├─ 5. SSH into EC2 → pull image → zero-downtime restart
        └─ 6. Post-deploy health check (rollback on failure)
        │
        ▼
   AWS EC2 Instance
   ┌─────────────────────────────┐
   │  Docker Engine               │
   │  ┌────────────┐ ┌─────────┐ │
   │  │ nginx (80)  │→│app(5000)│ │
   │  └────────────┘ └─────────┘ │
   └─────────────────────────────┘
```

## Repo structure

```
cicd-project/
├── app/
│   ├── app.py              # Flask app (home + /health endpoints)
│   ├── test_app.py         # Unit tests run in CI
│   └── requirements.txt
├── nginx/
│   └── default.conf        # Reverse proxy config
├── scripts/
│   ├── setup_ec2.sh        # One-time EC2 provisioning (installs Docker)
│   └── deploy.sh           # Runs on EC2 via SSH: pull + zero-downtime restart + rollback
├── Dockerfile               # Multi-stage build, non-root user, HEALTHCHECK
├── docker-compose.yml       # For local dev / manual EC2 run
├── Jenkinsfile               # Declarative pipeline definition
└── .gitignore
```

## Prerequisites

- A GitHub repo containing this code
- A Jenkins server (EC2, local VM, or Jenkins Docker container) with plugins:
  `Git`, `Pipeline`, `SSH Agent`, `Docker Pipeline`, `Credentials Binding`
- A Docker Hub account
- An AWS EC2 instance (Amazon Linux 2023 or Ubuntu, t2.micro is enough for a demo)

## Setup — step by step

### 1. Launch & prepare the EC2 instance
- Launch an EC2 instance, open a Security Group with inbound rules:
  `22 (SSH)`, `80 (HTTP)`, `5000 (app, optional if only using nginx)`
- SSH in and run:
  ```bash
  scp scripts/setup_ec2.sh ec2-user@<EC2_IP>:~
  ssh ec2-user@<EC2_IP> "bash setup_ec2.sh"
  ```

### 2. Configure Jenkins credentials
In **Jenkins → Manage Jenkins → Credentials**, add:
| ID | Type | Value |
|---|---|---|
| `dockerhub-creds` | Username/Password | Your Docker Hub username + access token |
| `ec2-ssh-key` | SSH Username with private key | `ec2-user` + your `.pem` private key |

### 3. Create the Jenkins pipeline job
- New Item → Pipeline → "Pipeline script from SCM" → point to your GitHub repo, script path `Jenkinsfile`
- Edit the `Jenkinsfile` env block: set `DOCKERHUB_USER` and `EC2_HOST` to your values.

### 4. Set up the GitHub webhook (auto-trigger on push)
- GitHub repo → Settings → Webhooks → Add webhook
- Payload URL: `http://<JENKINS_IP>:8080/github-webhook/`
- Content type: `application/json`, event: `Just the push event`
- In the Jenkins job config, check **"GitHub hook trigger for GITScm polling"**

### 5. Push code → pipeline runs automatically
```bash
git add .
git commit -m "trigger pipeline"
git push origin main
```
Jenkins picks up the webhook, runs all stages, and the app becomes reachable at
`http://<EC2_PUBLIC_IP>/` (via nginx) or `http://<EC2_PUBLIC_IP>:5000/` (direct).

## Local testing (before pushing)

```bash
cd app && pip install -r requirements.txt && python -m pytest test_app.py -v
docker build -t myapp:local .
docker run -p 5000:5000 myapp:local
curl http://localhost:5000/health
```

## Key design decisions

- **Multi-stage Dockerfile** — keeps the final image small by not shipping build tools.
- **Non-root container user** — reduces blast radius if the container is compromised.
- **HEALTHCHECK + deploy.sh rollback** — new container must pass `/health` before the
  old one is removed; if it fails, the previous container is restored automatically.
- **Docker Hub as the artifact registry** — EC2 only ever pulls a versioned, tested image,
  never builds from source — keeping the production host lean and consistent.
- **Nginx reverse proxy** — decouples the public port (80) from the app port (5000),
  making it easy to add TLS/load balancing later without touching the app.

## Possible extensions (mentioned in interview answers below)

- Swap manual EC2 for an Auto Scaling Group / ECS / EKS
- Add SonarQube or Trivy for code quality & image vulnerability scanning
- Add Terraform to provision the EC2 instance + security groups as code
- Blue-green or canary deployment instead of single-host rolling restart
- Centralized logging (CloudWatch) and monitoring (Prometheus/Grafana)
