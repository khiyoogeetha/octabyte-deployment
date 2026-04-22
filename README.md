# Octa Byte DevOps Assignment

Welcome to my submission for the DevOps assignment. This repo contains a fully containerized Flask application backed by PostgreSQL, with infrastructure provisioned via Terraform and CI/CD handled through GitHub Actions.
Note:Checkout main branch with all latest updates.

## Setting Up and Running the Infrastructure

To deploy this environment, you'll need AWS credentials and Terraform installed locally. Follw the following steps:

1. **Clone the Repo:**
   ```bash
   git clone <repo-url>
   cd project1_flaskrapp
   ```

2. **Configure AWS Credentials:**
   Ensure you have configured your AWS CLI or set the environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

3. **Provision the Terraform Backend:**
   Before applying the main infrastructure, you need to create the S3 bucket used to store the Terraform state. We use Terraform's native S3 state locking so a DynamoDB table is no longer required.
   ```bash
   cd terraform/bootstrap
   terraform init
   terraform apply -auto-approve
   cd ../..
   ```

4. **Deploy Infrastructure by Environment:**
   This project is set up to deploy separate environments (`dev`, `staging`, `prod`) using a modular structure. 
   Navigate to the specific environment directory to initialize and apply:
   ```bash
   # Deploy Dev Environment
   cd terraform/environments/dev
   terraform init
   terraform apply -var="db_password=YourDevPassword123!"

   # Deploy Staging Environment
   cd ../staging
   terraform init
   terraform apply -var="db_password=YourStagingPassword123!"

   # Deploy Production Environment
   cd ../prod
   terraform init
   terraform apply -var="db_password=YourProdPassword123!"
   ```
   Review the plan and type `yes`. Terraform will output the Application Load Balancer DNS name once it finishes.

## CI/CD Pipeline & Environments

The deployment is managed by GitHub Actions (`.github/workflows/deploy.yml`):
1. **Build & Push**: Builds the Docker image, scans it with Trivy, and pushes it to an ECR repository.
2. **Deploy to Staging**: Automatically updates the `staging` ECS cluster.
3. **Deploy to Production (Manual Approval)**: Triggers only after staging completes. This uses GitHub Actions **Environments**. 

**Important:** To test the manual approval gate, you must go to your GitHub Repository Settings > Environments. Create a new environment named `production`, check the "Required reviewers" box, and add yourself.

## Architecture Decisions & Challenges
I've split out the detailed architectural rationale and the issues I ran into while building this out into separate files to keep this readme clean:
- [Read the Architectural Approach](APPROACH.md)
- [Read the Challenges & Resolutions](CHALLENGES.md)

## Security Considerations

Security was a primary focus when designing this stack:
- **Private Subnets:** The RDS instance and the ECS Fargate tasks sit in private subnets. They cannot be reached directly from the internet.
- **Strict Security Groups:** The ALB is the only component open to `0.0.0.0/0` on port 80. The ECS tasks only accept traffic from the ALB security group, and the RDS instance only accepts traffic from the ECS security group on port 5432.
- **Secret Management (12-Factor App):** The application does not store secrets in the codebase. Database credentials and the Flask `SECRET_KEY` are passed via environment variables managed by Terraform and injected directly into the ECS Task Definition.

## Cost Optimization Measures

Running cloud infrastructure can get expensive fast, so I've optimized a few things:
- **Free-tier Eligible Database:** I opted for a `db.t3.micro` instance class for the RDS database.
- **Single NAT Gateway:** To allow ECS tasks in the private subnet to pull images from ECR, a NAT Gateway is required. Instead of deploying one per Availability Zone (which is best practice for production but costly), I deployed a single NAT gateway to save on hourly charges.
- **Fargate Right-Sizing:** The ECS tasks are allocated minimal CPU (256) and Memory (512) since it's just a lightweight Python web service.

## Backup Strategy

The RDS module is configured to automatically handle database backups. 
- **Automated Snapshots:** AWS takes daily automated snapshots during a specified backup window (`03:00-04:00` UTC).
- **Retention:** Backups are retained for 7 days, allowing for easy point-in-time recovery if someone accidentally drops a table or messes up the data.
