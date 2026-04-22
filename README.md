# OctaByte DevOps Assignment: Flask CI/CD & AWS Infrastructure

This repository contains a fully automated, production-ready DevOps implementation for a Python Flask application. It utilizes **Terraform** for Infrastructure as Code (IaC), **GitHub Actions** for CI/CD automation, and **AWS** for highly available cloud hosting.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [How to Set Up and Run](#how-to-set-up-and-run)
- [Security Considerations](#security-considerations)
- [Cost Optimization Measures](#cost-optimization-measures)
- [Backup & Secrets Strategy](#backup--secrets-strategy)
- [Future Improvements](#future-improvements)

---

## Architecture Overview

The infrastructure relies on a modern, serverless container approach to minimize operational overhead while maximizing scalability.

- **Compute:** AWS ECS (Elastic Container Service) running on Fargate. No underlying EC2 instances are managed, abstracting OS maintenance.
- **Networking:** A dedicated VPC with 2 Public Subnets (for the Application Load Balancer) and 2 Private Subnets (for the ECS Tasks and RDS Database).
- **Database:** Amazon RDS (PostgreSQL).
- **Monitoring & Logging:** CloudWatch Dashboards track Infra/App metrics. Centralized logging handles Application logs (via `awslogs` driver), System logs (via ECS Container Insights & Postgres exports), and Access logs (via dedicated S3 Bucket).
- **CI/CD:** GitHub Actions with Trunk-Based Development. PRs are tested and auto-merged. Pushes to `master` trigger vulnerability scanning (Trivy), Docker builds, and zero-downtime rolling ECS deployments.

For detailed rationale on these technical choices, see [APPROACH.md](./APPROACH.md).
For a breakdown of the CI/CD Pipeline, see [PIPELINE.md](./PIPELINE.md).
For issues faced during implementation, see [CHALLENGES.md](./CHALLENGES.md).

---

## How to Set Up and Run

### Prerequisites
1. AWS CLI installed and configured.
2. Terraform (`>=1.5.0`) installed.
3. GitHub Repository Secrets configured:
   - `PAT_TOKEN` (Classic Personal Access Token with `repo` scope).
   - `SLACK_WEBHOOK` (For pipeline failure alerts).
4. GitHub Environment Secrets (`staging` and `production` environments):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

### 1. Provision Infrastructure
Initialize backend by navigating to bootstrap directory and apply the Terraform configuration::
```bash
cd terraform/bootstrap
terraform init
terraform plan
terraform apply --auto-approve
```

Navigate to the desired environment directory and apply the Terraform configuration:
```bash
cd terraform/environments/staging
terraform init
terraform plan
terraform apply --auto-approve
```
*Note: You must provision the ECR repository via Terraform before the first CI/CD run can succeed.*

### 2. Deploy the Application
Once the infrastructure is up, simply commit your code to a feature branch and open a Pull Request against `master`. 
1. `pr.yml` will run Python tests. If successful, it automatically merges the PR using your `PAT_TOKEN`.
2. `deploy.yml` will trigger automatically, build the Docker image, run Trivy security scans, and deploy the new image to the ECS cluster.

   <img width="790" height="302" alt="image" src="https://github.com/user-attachments/assets/bb3c294c-4d0b-4832-ad14-ad3d9bf97c4f" />


---

## Security Considerations
- **Network Isolation:** ECS Tasks and the RDS database reside exclusively in Private Subnets. They are completely inaccessible from the public internet. The only entry point is via the Application Load Balancer sitting in the Public Subnets.
- **Principle of Least Privilege:** Security Groups strictly restrict lateral movement. The RDS SG only accepts traffic from the ECS SG. The ECS SG only accepts traffic from the ALB SG.
- **Vulnerability Scanning:** The `deploy.yml` pipeline utilizes Aqua Security's `Trivy` to scan the raw filesystem *and* the compiled Docker image for `HIGH` and `CRITICAL` vulnerabilities. The build fails if vulnerabilities are detected.
- **Scoped Credentials:** AWS credentials are not stored globally. They are isolated inside GitHub **Environments** (`staging` vs `production`) to prevent lateral credential exposure.

## Cost Optimization Measures
- **Compute Sizing:** ECS Tasks are right-sized using fractional CPU allocations (`256 CPU units` / `512 MB RAM` for staging, scalable for production) to avoid over-provisioning Fargate costs.
- **Database Sizing:** The RDS instance utilizes `db.t3.micro` instance classes, ensuring it remains highly capable but sits well within the AWS Free Tier limitations where applicable.
- **Storage Classes:** Utilizing standard GP3 storage instead of more expensive Provisioned IOPS.
- **Nat Gateway:** Uses a `single_nat_gateway` configuration for development/staging environments to cut down on hourly NAT gateway fees.

## Backup & Secrets Strategy
- **Backup Strategy:** The AWS RDS Terraform module is explicitly configured with a `backup_retention_period` of 7 days and a defined daily automated backup window. This ensures point-in-time recovery is fully automated.
- **Secret Management:** Application secrets (like the Database Password and Flask `SECRET_KEY`) are dynamically injected into the container environment variables at runtime by ECS. The deployment pipeline pulls these from securely encrypted GitHub Secrets.

## Future Improvements & Good Practices
If this project were to scale significantly, the following extra code/architectural changes would be beneficial:
1. **AWS Secrets Manager:** Rather than passing secrets via plain environment variables in the ECS Task Definition, we should reference ARNs from AWS Secrets Manager using the `secrets` block in the container definition for enhanced security.
2. **Auto-Scaling:** Implement AWS Application Auto Scaling policies to dynamically increase the `desired_count` of ECS Fargate tasks based on CloudWatch CPU/Memory alarms.
3. **WAF Integration:** Attach an AWS Web Application Firewall (WAF) to the Application Load Balancer to protect against common web exploits (e.g., SQL injection, XSS).
