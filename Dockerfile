## Parent image
FROM python:3.10-slim

## Essential environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

## Work directory inside the docker container
WORKDIR /app

## Installing system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

## Copy requirements first for better caching
COPY requirements.txt .
COPY setup.py .

## Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir -e .

## Copy application code
COPY app/ ./app/

## COPY CRITICAL - Vector database and data for RAG
COPY vectorstore/ ./vectorstore/
COPY data/ ./data/

## Verify the vectorstore is present (essential check)
RUN echo "=== VERIFYING RAG DATABASE ===" && \
    if [ -d "vectorstore" ] && [ "$(ls -A vectorstore)" ]; then \
        echo "✓ Vectorstore directory found with files:" && \
        ls -la vectorstore/ && \
        echo "Total files: $(find vectorstore/ -type f | wc -l)"; \
    else \
        echo "❌ ERROR: Vectorstore directory missing or empty!" && \
        echo "Current directory content:" && \
        ls -la && \
        exit 1; \
    fi

## Verify data directory
RUN if [ -d "data" ]; then \
        echo "✓ Data directory found with $(find data/ -type f | wc -l) files"; \
    else \
        echo "⚠️  Warning: Data directory not found"; \
    fi

## Health check for Flask app
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/ || exit 1

## Expose only flask port
EXPOSE 5000

## Run the Flask app
CMD ["python", "app/application.py"]