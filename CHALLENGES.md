# Challenges and Resolutions

Working on this assignment brought up a few interesting challenges. Here's a quick rundown of what I ran into and how I solved it.

## 1. Migrating the Flask App to PostgreSQL
The original `flaskr` app was heavily tied to SQLite/MySQL syntax (using `AUTO_INCREMENT` and PyMySQL). 
- **Challenge:** Switching to PostgreSQL meant updating the schema. Also, the word `user` is a reserved keyword in PostgreSQL.
- **Resolution:** I swapped PyMySQL for `psycopg2-binary`. I updated `schema.sql` to use `SERIAL PRIMARY KEY` instead of `INTEGER PRIMARY KEY AUTO_INCREMENT`. To handle the reserved keyword issue without breaking the entire application logic, I quoted the table name as `"user"` in both the SQL schema and all Python query executions (`auth.py` and `blog.py`).

## 2. Handling Configuration and Secrets
- **Challenge:** The Flask tutorial app relies on an `instance/` folder for local config. When running in a docker container managed by ECS, managing local files for secrets is risky and hard to automate.
- **Resolution:** I rewrote the database connection logic in `db.py` to read from environment variables (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, etc.). Then, I configured the Terraform ECS module to map the output variables from the RDS module directly into the container's environment variables. This creates a clean handoff from Infrastructure to Application.

## 3. Container Scanning in CI/CD
- **Challenge:** Wanted to add a vulnerability scanner but needed one that is fast and reliable in GitHub Actions without needing an external SaaS subscription.
- **Resolution:** Decided to use `Trivy` from Aqua Security. It runs quickly right in the pipeline, scans the built image, and I configured it to only fail the build if it finds `HIGH` or `CRITICAL` vulnerabilities so we aren't blocked by minor issues.

