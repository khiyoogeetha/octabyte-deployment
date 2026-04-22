FROM python:3.9-slim

# Prevent python from writing pyc files and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Create a non-root user and group
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy the application code
COPY . .

# Install the application and gunicorn production server with no cache
RUN pip install --no-cache-dir . gunicorn

# Ensure the non-root user owns the /app directory
RUN chown -R appuser:appuser /app

# Switch to the non-root user
USER appuser

EXPOSE 5000

# Run the app with gunicorn
CMD ["sh", "-c", "flask --app flaskr init-db && exec gunicorn -w 4 -b 0.0.0.0:5000 'flaskr:create_app()'"]