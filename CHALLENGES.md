# Challenges & Resolutions

During the implementation of the infrastructure and CI/CD pipelines, several technical hurdles were encountered and resolved.

## 1. Automated Pipeline Triggering Failure (GitHub Actions)
**Issue:** The `pr.yml` workflow successfully tested and automatically merged Pull Requests using the `GITHUB_TOKEN`. However, the downstream `deploy.yml` workflow (which is set to run `on: push: branches: master`) would refuse to trigger after the merge.
**Root Cause:** GitHub intentionally restricts the default `GITHUB_TOKEN` from triggering downstream workflows to prevent accidental infinite recursion loops (a bot triggering a bot).
**Resolution:** Generated a Personal Access Token (PAT) with `repo` permissions and saved it as a repository secret (`PAT_TOKEN`). The `automerge` job was refactored to authenticate using this PAT instead of the default token, successfully enabling the deployment pipeline to trigger.

## 2. Environment Secrets Scope Restrictions
**Issue:** The deployment pipeline failed with `Error: Credentials could not be loaded` during the `configure-aws-credentials` step, despite the secrets existing in the repository.
**Root Cause:** The `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` were correctly stored within GitHub **Environments** (e.g., `staging`), but the deployment job lacked an explicit environment declaration.
**Resolution:** Added `environment: staging` to the `build` job in `deploy.yml`. This granted the GitHub Actions runner the correct context to retrieve and utilize the scoped secrets.

## 3. Application Load Balancer Health Check Failures
**Issue:** After successful deployment to ECS, the application containers were repeatedly spinning up and then immediately being terminated by the Application Load Balancer (ALB).
**Root Cause:** The Terraform ALB target group was configured to ping the `/health` path to determine container health. However, the legacy Flask application did not actually have a `/health` route defined, returning a `404 Not Found`. This caused the ALB to mark the instances as unhealthy and drain them.
**Resolution:** Modified the Flask application code (`app/flaskr/__init__.py`) to explicitly include a `/health` endpoint that returns a `200 OK` status code.

## 4. Database Initialization Blockers
**Issue:** The application would crash on startup or first request because the AWS RDS PostgreSQL database did not have the required tables (`user`, `post`).
**Root Cause:** The original Flask tutorial application expects a user to run `flask init-db` locally. In an automated ECS environment, there is no manual intervention phase.
**Resolution:** Refactored the `schema.sql` script to replace destructive `DROP TABLE` commands with safe `CREATE TABLE IF NOT EXISTS` commands. Modified the Dockerfile `CMD` instruction to run `flask --app flaskr init-db` dynamically right before starting the Gunicorn web server, ensuring full automation without data loss.

