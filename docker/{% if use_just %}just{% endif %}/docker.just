# Run the service, rebuilding the image when src/ or the lockfile changes.
up:
    docker compose up --watch

# Stop it and remove the containers.
down:
    docker compose down

# Follow the service logs.
logs:
    docker compose logs -f
