# Developer Environment Setup

Quick instructions to set up the Docker development environment for this project.

### Step 1: Update the `quicaccess` File

- Open the `quicaccess` file in the project root directory.
- Replace `YourProjectDirectory` with the path inside the **Docker container** where your project will reside (e.g., `/app/your_project_directory`).

### Step 2: Set `YOUR_PROJECT_DIRECTORY_AT_HOST`

- In the same `quicaccess` file, update `YOUR_PROJECT_DIRECTORY_AT_HOST` with the absolute path to your project directory on your **host machine** (e.g., `/home/your_username/projects/your_project_directory`).

### Step 3: Run Docker Compose

- Spin up the containers by running the following command:

  ```bash
  docker-compose up -d
  ```