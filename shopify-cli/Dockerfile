# Use the official Ubuntu base image
FROM ubuntu:latest

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential packages and Ruby
RUN apt-get update && \
    apt-get install -y \
        curl \
        wget \
        build-essential \
        git \
        libssl-dev \
        libreadline-dev \
        zlib1g-dev \
        ruby-full \
        xdg-utils

# Install Node.js directly using NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

# Verify Node.js and NPM installation
RUN node -v
RUN npm -v

# Install global npm packages
RUN npm install -g @shopify/cli @shopify/theme

# Set the working directory
WORKDIR /work

# Expose the required port
EXPOSE 9292

# Default command to keep the container running
CMD ["bash"]