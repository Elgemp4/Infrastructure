# Use a base image with a shell and the Docker CLI
# The official 'docker' image is a good choice as it has the CLI pre-installed
FROM alpine:3.22.1

# Set the working directory in the container
WORKDIR /app

# Install jq for JSON parsing
RUN apk add --no-cache jq bash docker-cli curl

# Copy your script into the container
COPY update-script.sh .

# Make the script executable
RUN chmod +x update-script.sh

# The entry point of the container
# This ensures your script is the primary process
ENTRYPOINT ["/app/update-script.sh"]