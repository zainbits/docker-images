# Use the official Ubuntu image as the base
FROM ubuntu:latest

# Install dependencies
RUN apt-get update && \
    apt-get install -y curl unzip jupyter-notebook && \
    rm -rf /var/lib/apt/lists/*

# Install Deno
RUN curl -fsSL https://deno.land/install.sh | sh

# Add Deno to the PATH
ENV DENO_INSTALL=/root/.deno
ENV PATH=$DENO_INSTALL/bin:$PATH

RUN deno jupyter --unstable --install

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . .

# Create a cache directory for Deno
RUN mkdir -p /deno_cache

# Pre-fetch Deno dependencies
RUN deno cache --unstable https://cdn.skypack.dev/dayjs

# Set the Deno cache location
ENV DENO_DIR=/deno_cache

# Expose port for Jupyter Notebook
EXPOSE 8888

# Start Jupyter Notebook
CMD ["jupyter", "notebook", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--allow-root"]
