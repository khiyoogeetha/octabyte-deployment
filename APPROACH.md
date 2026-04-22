# Technical Approach & Architecture Rationale

This document outlines the high-level design decisions made during the infrastructure provisioning and deployment automation of the Flask application.

## 1. Infrastructure as Code (Terraform Modularity)
Instead of a monolithic Terraform state file, the infrastructure is heavily modularized (VPC, IAM, Security Groups, RDS, ECS, CloudWatch) and separated into distinct environment directories (`environments/staging` and `environments/prod`).
- **Rationale:** This drastically reduces blast radius. Modularity allows us to reuse the exact same infrastructure definitions across multiple environments, ensuring staging is an identical replica of production, which is a core tenet of modern DevOps.

## 2. Compute Selection: AWS ECS Fargate
Instead of provisioning traditional EC2 instances or maintaining an EKS cluster, the application is deployed on AWS ECS using the Fargate launch type.
- **Rationale:** Fargate abstracts the underlying server management away. As a serverless compute engine, we do not need to worry about OS patching, AMI management, or cluster scaling at the EC2 level. This significantly reduces operational overhead. 

## 3. Database & State Management
The database is hosted on Amazon RDS (PostgreSQL).
- **Automated Initialization:** The application logic was modified so that the database schema is automatically initialized upon container startup. This removes the need for manual database migrations or standalone Terraform DB initialization scripts.
- **Backup Strategy:** Automated backups are explicitly enabled via Terraform with a `backup_retention_period` of 7 days and a defined daily backup window. This fulfills enterprise compliance requirements for disaster recovery without requiring custom cron jobs.

## 4. Centralized Logging
- **Application Logs:** Pushed directly from the Docker container `stdout/stderr` to CloudWatch Logs using the native `awslogs` log driver configured in the ECS Task Definition.
- **System Logs:** Fargate manages the underlying OS, so traditional `/var/log/syslog` metrics do not apply. However, system-level metrics and container health are captured via **ECS Container Insights**, which we explicitly enabled at the cluster level. Furthermore, RDS PostgreSQL system logs and upgrade logs are directly exported to CloudWatch.
- **Access Logs:** Application Load Balancer access logs are enabled and routed to a dedicated S3 Bucket governed by strict IAM Bucket Policies.

## 5. Deployment Trigger Security
Instead of using the default `GITHUB_TOKEN` to merge Pull Requests, a classic Personal Access Token (`PAT_TOKEN`) is utilized.
- **Rationale:** GitHub explicitly blocks actions triggered by the default `GITHUB_TOKEN` from triggering downstream workflows to prevent infinite recursion loops. Using a PAT ensures that our automated PR merge cleanly triggers the `deploy.yml` pipeline.
