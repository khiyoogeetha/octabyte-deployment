# CI/CD Pipeline Overview

This repository utilizes GitHub Actions to fully automate the testing, security scanning, and multi-environment deployment of the Flask application using a trunk-based development workflow.

## Pipeline Architecture

The CI/CD process is split into two cascading workflows to enforce proper authorization and security controls:

### 1. Pull Request Workflow (`pr.yml`)
**Trigger:** Triggered automatically whenever a Pull Request is opened or updated against the `master` branch.
**Jobs:**
- **test:** Runs the Python `pytest` suite and checks code health.
- **automerge:** If tests pass, uses the GitHub CLI (`gh pr merge`) to automatically merge the Pull Request. This job uses a highly privileged Personal Access Token (`PAT_TOKEN`) to bypass branch protection rules and ensure that the merge event can trigger downstream deployment workflows.
- **notify:** Sends a Slack alert via Webhook if any job fails.

### 2. Deployment Workflow (`deploy.yml`)
**Trigger:** Triggered automatically by a `push` to `master` (which occurs immediately after `pr.yml` successfully merges the code) or via manual `workflow_dispatch`.
**Jobs:**
- **test:** Re-runs unit tests on the `master` codebase to ensure integration stability.
- **build:** 
  - Checks out the code.
  - Runs a **Trivy Vulnerability Scan** (`fs` mode) on the application source files.
  - Authenticates with AWS using short-lived environment secrets.
  - Builds the Docker image and pushes it to Amazon ECR.
  - Runs a second **Trivy Vulnerability Scan** on the compiled Docker image to check for OS and dependency vulnerabilities.
- **deploy-staging:**
  - Pulls the latest ECS Task Definition.
  - Injects the newly built Docker image hash.
  - Deploys the updated task to the `staging` ECS Fargate cluster.
- **deploy-production:**
  - Mirrors the staging process but targets the `production` ECS Fargate cluster.
  - *Note: In a true production environment, this step would require a manual approval gate configured via GitHub Environments.*<img width="947" height="410" alt="image" src="https://github.com/user-attachments/assets/da91b818-ada3-455c-9a47-f2a46f478eca" />

- **notify:** Sends a Slack alert to the engineering team if any stage of the deployment fails.

## Security Integrations
- **Environment Secrets:** AWS Credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) and Slack Webhooks are stored securely in GitHub Environments (`staging` and `production`) rather than globally, enforcing the principle of least privilege.
- **Trivy:** Fails the build immediately if `CRITICAL` or `HIGH` vulnerabilities are found.
