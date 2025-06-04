#!/usr/bin/env zsh

# GitLab Docker Manager Script
# Compatible with Linux and macOS
# Author: GitLab Manager
# Version: 1.0

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly GITLAB_HOME="${GITLAB_HOME:-$HOME/gitlab_docker}"
readonly GITLAB_HOSTNAME="${GITLAB_HOSTNAME:-gitlab.local}"
readonly LOG_FILE="${GITLAB_HOME}/gitlab-manager.log"
readonly BACKUP_DIR="${GITLAB_HOME}/backups"
readonly COMPOSE_FILE="${GITLAB_HOME}/docker-compose.yml"

# OS Detection
detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

readonly OS="$(detect_os)"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}ℹ${NC} $*"
    log "INFO" "$*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
    log "SUCCESS" "$*"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $*"
    log "WARNING" "$*"
}

error() {
    echo -e "${RED}✗${NC} $*" >&2
    log "ERROR" "$*"
}

fatal() {
    error "$*"
    exit 1
}

# Progress indicator
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Dependency checks
check_dependencies() {
    info "Checking dependencies..."
    
    local deps=("docker" "docker-compose")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}"
        info "Please install the missing dependencies and try again."
        
        if [[ "$OS" == "macos" ]]; then
            info "On macOS, you can install Docker Desktop from: https://docs.docker.com/desktop/mac/install/"
        elif [[ "$OS" == "linux" ]]; then
            info "On Linux, install Docker using your package manager or from: https://docs.docker.com/engine/install/"
        fi
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        fatal "Docker daemon is not running. Please start Docker and try again."
    fi
    
    success "All dependencies are satisfied"
}

# Network configuration
setup_hosts_entry() {
    local ip="${1:-127.0.0.1}"
    local hostname="$GITLAB_HOSTNAME"
    
    info "Setting up hosts entry for $hostname..."
    
    if [[ "$OS" == "macos" ]]; then
        local hosts_file="/etc/hosts"
    else
        local hosts_file="/etc/hosts"
    fi
    
    # Check if entry already exists
    if grep -q "$hostname" "$hosts_file" 2>/dev/null; then
        warning "Hosts entry for $hostname already exists"
        return 0
    fi
    
    # Add hosts entry
    if [[ $EUID -eq 0 ]]; then
        echo "$ip $hostname" >> "$hosts_file"
    else
        echo "$ip $hostname" | sudo tee -a "$hosts_file" >/dev/null
    fi
    
    success "Hosts entry added: $ip $hostname"
}

# Directory setup
setup_directories() {
    info "Setting up GitLab directories..."
    
    local dirs=(
        "$GITLAB_HOME"
        "$GITLAB_HOME/config"
        "$GITLAB_HOME/logs"
        "$GITLAB_HOME/data"
        "$BACKUP_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            info "Created directory: $dir"
        fi
    done
    
    success "Directory structure created"
}

# Docker Compose file generation
generate_compose_file() {
    info "Generating docker-compose.yml..."
    
    cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'

services:
  gitlab:
    image: gitlab/gitlab-ce:latest
    container_name: gitlab-server
    restart: unless-stopped
    hostname: 'gitlab.local'
    environment:
      GITLAB_OMNIBUS_CONFIG: |
        external_url 'http://gitlab.local'
        gitlab_rails['gitlab_shell_ssh_port'] = 2222
        # Performance optimization
        puma['worker_processes'] = 2
        sidekiq['max_concurrency'] = 10
        prometheus_monitoring['enable'] = false
        # Container registry
        registry_external_url 'http://gitlab.local:5050'
        gitlab_rails['registry_enabled'] = true
        # Backup settings
        gitlab_rails['backup_keep_time'] = 604800
        gitlab_rails['backup_path'] = '/var/opt/gitlab/backups'
        # Email settings (optional)
        gitlab_rails['smtp_enable'] = false
        # Time zone
        gitlab_rails['time_zone'] = 'UTC'
    ports:
      - '80:80'
      - '443:443'
      - '2222:22'
      - '5050:5050'
    volumes:
      - './config:/etc/gitlab'
      - './logs:/var/log/gitlab'
      - './data:/var/opt/gitlab'
      - './backups:/var/opt/gitlab/backups'
    networks:
      - gitlab-network
    shm_size: '256m'
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/-/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

networks:
  gitlab-network:
    driver: bridge
EOF
    
    success "Docker Compose file generated"
}

# GitLab operations
start_gitlab() {
    info "Starting GitLab server..."
    
    cd "$GITLAB_HOME"
    
    if docker-compose ps | grep -q "gitlab-server.*Up"; then
        warning "GitLab is already running"
        return 0
    fi
    
    docker-compose up -d
    
    info "Waiting for GitLab to become healthy..."
    local timeout=300  # 5 minutes
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if docker-compose ps | grep -q "gitlab-server.*healthy"; then
            break
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        info "Waiting... ($elapsed/$timeout seconds)"
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        warning "GitLab took longer than expected to start. Check logs with: $0 logs"
    else
        success "GitLab started successfully"
        info "Access GitLab at: http://$GITLAB_HOSTNAME"
        info "Get initial root password with: $0 password"
    fi
}

stop_gitlab() {
    info "Stopping GitLab server..."
    
    cd "$GITLAB_HOME"
    
    if ! docker-compose ps | grep -q "gitlab-server"; then
        warning "GitLab is not running"
        return 0
    fi
    
    docker-compose down
    success "GitLab stopped successfully"
}

restart_gitlab() {
    info "Restarting GitLab server..."
    stop_gitlab
    sleep 5
    start_gitlab
}

get_initial_password() {
    info "Retrieving initial root password..."
    
    cd "$GITLAB_HOME"
    
    if ! docker-compose ps | grep -q "gitlab-server.*Up"; then
        fatal "GitLab is not running. Start it first with: $0 start"
    fi
    
    local password
    password=$(docker-compose exec -T gitlab cat /etc/gitlab/initial_root_password 2>/dev/null | grep 'Password:' | awk '{print $2}' || echo "")
    
    if [[ -n "$password" ]]; then
        success "Initial root password: $password"
        warning "Please change this password after first login!"
    else
        warning "Could not retrieve initial password. It may have been reset already."
        info "If you've already changed the password, use your custom password."
        info "If you need to reset it, use: $0 reset-password"
    fi
}

# Backup operations
create_backup() {
    info "Creating GitLab backup..."
    
    cd "$GITLAB_HOME"
    
    if ! docker-compose ps | grep -q "gitlab-server.*Up"; then
        fatal "GitLab is not running. Start it first with: $0 start"
    fi
    
    # Create GitLab backup
    docker-compose exec -T gitlab gitlab-backup create
    
    # Archive the entire gitlab directory
    local backup_name="gitlab-full-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$HOME/${backup_name}.tar.gz"
    
    info "Creating full backup archive..."
    tar -czf "$backup_path" -C "$(dirname "$GITLAB_HOME")" "$(basename "$GITLAB_HOME")"
    
    success "Backup created: $backup_path"
    info "You can restore this backup on any machine with: $0 restore $backup_path"
}

list_backups() {
    info "Available backups:"
    
    # List GitLab internal backups
    if [[ -d "$BACKUP_DIR" ]]; then
        echo -e "\n${CYAN}GitLab internal backups:${NC}"
        ls -la "$BACKUP_DIR"/*.tar 2>/dev/null || info "No internal backups found"
    fi
    
    # List full backup archives
    echo -e "\n${CYAN}Full backup archives in $HOME:${NC}"
    ls -la "$HOME"/gitlab-full-backup-*.tar.gz 2>/dev/null || info "No full backup archives found"
}

restore_backup() {
    local backup_file="$1"
    
    if [[ -z "$backup_file" ]]; then
        fatal "Please specify a backup file to restore"
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        fatal "Backup file not found: $backup_file"
    fi
    
    warning "This will completely replace your current GitLab installation!"
    echo -n "Are you sure you want to continue? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Restore cancelled"
        return 0
    fi
    
    info "Stopping GitLab..."
    stop_gitlab 2>/dev/null || true
    
    info "Backing up current installation..."
    local current_backup="$HOME/gitlab-pre-restore-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$current_backup" -C "$(dirname "$GITLAB_HOME")" "$(basename "$GITLAB_HOME")" 2>/dev/null || true
    
    info "Removing current installation..."
    rm -rf "$GITLAB_HOME"
    
    info "Restoring from backup..."
    tar -xzf "$backup_file" -C "$(dirname "$GITLAB_HOME")"
    
    info "Setting up hosts entry..."
    setup_hosts_entry
    
    info "Starting GitLab..."
    start_gitlab
    
    success "Restore completed successfully"
    info "Pre-restore backup saved to: $current_backup"
}

# Migration operations
prepare_migration() {
    info "Preparing GitLab for migration..."
    
    # Create migration package
    local migration_name="gitlab-migration-$(date +%Y%m%d-%H%M%S)"
    local migration_path="$HOME/${migration_name}.tar.gz"
    
    # Stop GitLab
    stop_gitlab
    
    # Create migration archive
    info "Creating migration package..."
    tar -czf "$migration_path" -C "$(dirname "$GITLAB_HOME")" "$(basename "$GITLAB_HOME")"
    
    # Create migration script
    local migration_script="$HOME/${migration_name}-install.sh"
    cat > "$migration_script" << EOF
#!/usr/bin/env zsh
# GitLab Migration Install Script
# Generated on $(date)

set -euo pipefail

GITLAB_HOME="\$HOME/gitlab_docker"
ARCHIVE_NAME="$migration_name.tar.gz"

echo "🚀 GitLab Migration Installer"
echo "=============================="

# Check if archive exists
if [[ ! -f "\$ARCHIVE_NAME" ]]; then
    echo "❌ Migration archive not found: \$ARCHIVE_NAME"
    echo "Please ensure the archive is in the current directory."
    exit 1
fi

# Extract archive
echo "📦 Extracting GitLab installation..."
tar -xzf "\$ARCHIVE_NAME" -C "\$HOME"

# Setup hosts entry
echo "🌐 Setting up hosts entry..."
if [[ "\$(uname -s)" == "Darwin" ]]; then
    echo "127.0.0.1 $GITLAB_HOSTNAME" | sudo tee -a /etc/hosts
else
    echo "127.0.0.1 $GITLAB_HOSTNAME" | sudo tee -a /etc/hosts
fi

# Start GitLab
echo "🚀 Starting GitLab..."
cd "\$GITLAB_HOME"
docker-compose up -d

echo "✅ GitLab migration completed!"
echo "📍 Access GitLab at: http://$GITLAB_HOSTNAME"
echo "🔑 Get root password with: ./gitlab-manager.sh password"
EOF
    
    chmod +x "$migration_script"
    
    success "Migration package created:"
    info "  Archive: $migration_path"
    info "  Installer: $migration_script"
    info ""
    info "To migrate to another machine:"
    info "  1. Copy both files to the target machine"
    info "  2. Run: ./${migration_name}-install.sh"
}

# Maintenance operations
update_gitlab() {
    info "Updating GitLab..."
    
    cd "$GITLAB_HOME"
    
    # Create backup before update
    warning "Creating backup before update..."
    create_backup
    
    # Pull latest image
    docker-compose pull gitlab
    
    # Restart with new image
    docker-compose up -d
    
    success "GitLab update completed"
}

show_logs() {
    local lines="${1:-100}"
    
    cd "$GITLAB_HOME"
    
    if ! docker-compose ps | grep -q "gitlab-server"; then
        fatal "GitLab is not running"
    fi
    
    docker-compose logs --tail="$lines" -f gitlab
}

show_status() {
    info "GitLab Status"
    echo "=============="
    
    cd "$GITLAB_HOME"
    
    # Docker status
    echo -e "\n${CYAN}Docker Status:${NC}"
    if docker-compose ps | grep -q "gitlab-server"; then
        docker-compose ps
    else
        warning "GitLab container not found"
    fi
    
    # Service status
    if docker-compose ps | grep -q "gitlab-server.*Up"; then
        echo -e "\n${CYAN}GitLab Services:${NC}"
        docker-compose exec -T gitlab gitlab-ctl status 2>/dev/null || warning "Could not get service status"
    fi
    
    # Disk usage
    echo -e "\n${CYAN}Disk Usage:${NC}"
    du -sh "$GITLAB_HOME"/* 2>/dev/null || true
    
    # Network info
    echo -e "\n${CYAN}Network:${NC}"
    info "GitLab URL: http://$GITLAB_HOSTNAME"
    if command -v ifconfig >/dev/null 2>&1; then
        local ip=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -n1 | awk '{print $2}')
        if [[ -n "$ip" ]]; then
            info "Local network access: http://$ip"
        fi
    fi
}

reset_password() {
    info "Resetting GitLab root password..."
    
    cd "$GITLAB_HOME"
    
    if ! docker-compose ps | grep -q "gitlab-server.*Up"; then
        fatal "GitLab is not running. Start it first with: $0 start"
    fi
    
    echo -n "Enter new password for root user: "
    read -s new_password
    echo
    
    if [[ ${#new_password} -lt 8 ]]; then
        fatal "Password must be at least 8 characters long"
    fi
    
    docker-compose exec -T gitlab gitlab-rails runner "
        user = User.find_by(username: 'root')
        user.password = '$new_password'
        user.password_confirmation = '$new_password'
        user.save!
        puts 'Root password updated successfully'
    "
    
    success "Root password updated successfully"
}

# Cleanup operations
cleanup() {
    info "Cleaning up GitLab resources..."
    
    cd "$GITLAB_HOME"
    
    # Stop and remove containers
    docker-compose down --volumes --remove-orphans
    
    # Remove GitLab images
    docker images | grep gitlab | awk '{print $3}' | xargs -r docker rmi
    
    # Clean up docker system
    docker system prune -f
    
    success "Cleanup completed"
}

uninstall() {
    warning "This will completely remove GitLab and all data!"
    echo -n "Are you sure you want to continue? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        info "Uninstall cancelled"
        return 0
    fi
    
    info "Creating final backup..."
    create_backup 2>/dev/null || true
    
    info "Stopping GitLab..."
    cleanup
    
    info "Removing GitLab directory..."
    rm -rf "$GITLAB_HOME"
    
    info "Removing hosts entry..."
    if [[ "$OS" == "macos" ]]; then
        sudo sed -i '' "/$GITLAB_HOSTNAME/d" /etc/hosts
    else
        sudo sed -i "/$GITLAB_HOSTNAME/d" /etc/hosts
    fi
    
    success "GitLab uninstalled successfully"
}

# Help and usage
show_help() {
    cat << EOF
${CYAN}GitLab Docker Manager${NC}
====================

${YELLOW}Usage:${NC} $0 [COMMAND] [OPTIONS]

${YELLOW}Commands:${NC}
  ${GREEN}setup${NC}              Initial setup of GitLab
  ${GREEN}start${NC}              Start GitLab server
  ${GREEN}stop${NC}               Stop GitLab server
  ${GREEN}restart${NC}            Restart GitLab server
  ${GREEN}status${NC}             Show GitLab status
  ${GREEN}logs${NC} [lines]       Show GitLab logs (default: 100 lines)
  ${GREEN}password${NC}           Get initial root password
  ${GREEN}reset-password${NC}     Reset root password
  
  ${GREEN}backup${NC}             Create full backup
  ${GREEN}restore${NC} <file>     Restore from backup
  ${GREEN}list-backups${NC}       List available backups
  
  ${GREEN}migrate${NC}            Prepare migration package
  ${GREEN}update${NC}             Update GitLab to latest version
  
  ${GREEN}cleanup${NC}            Clean up Docker resources
  ${GREEN}uninstall${NC}          Completely remove GitLab
  
  ${GREEN}help${NC}               Show this help message

${YELLOW}Examples:${NC}
  $0 setup                    # Initial setup
  $0 start                    # Start GitLab
  $0 backup                   # Create backup
  $0 migrate                  # Prepare for migration
  $0 restore backup.tar.gz    # Restore from backup
  $0 logs 50                  # Show last 50 log lines

${YELLOW}Configuration:${NC}
  GitLab Home: $GITLAB_HOME
  Hostname: $GITLAB_HOSTNAME
  Log File: $LOG_FILE
  OS: $OS

${YELLOW}URLs:${NC}
  GitLab: http://$GITLAB_HOSTNAME
  Registry: http://$GITLAB_HOSTNAME:5050

For more information, visit: https://docs.gitlab.com/
EOF
}

# Interactive menu
interactive_menu() {
    while true; do
        echo -e "\n${CYAN}GitLab Docker Manager${NC}"
        echo "====================="
        echo "1. Setup GitLab"
        echo "2. Start GitLab"
        echo "3. Stop GitLab"
        echo "4. Restart GitLab"
        echo "5. Show Status"
        echo "6. Show Logs"
        echo "7. Get Root Password"
        echo "8. Create Backup"
        echo "9. Prepare Migration"
        echo "10. Update GitLab"
        echo "0. Exit"
        echo
        echo -n "Select an option [0-10]: "
        
        read -r choice
        
        case $choice in
            1) setup_gitlab ;;
            2) start_gitlab ;;
            3) stop_gitlab ;;
            4) restart_gitlab ;;
            5) show_status ;;
            6) show_logs ;;
            7) get_initial_password ;;
            8) create_backup ;;
            9) prepare_migration ;;
            10) update_gitlab ;;
            0) info "Goodbye!"; exit 0 ;;
            *) warning "Invalid option. Please try again." ;;
        esac
        
        echo -e "\nPress Enter to continue..."
        read -r
    done
}

# Main setup function
setup_gitlab() {
    info "Setting up GitLab Docker environment..."
    
    check_dependencies
    setup_directories
    generate_compose_file
    setup_hosts_entry
    
    success "GitLab setup completed!"
    info "Next steps:"
    info "  1. Start GitLab: $0 start"
    info "  2. Wait for startup (2-5 minutes)"
    info "  3. Get password: $0 password"
    info "  4. Access: http://$GITLAB_HOSTNAME"
}

# Main function
main() {
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Handle arguments
    case "${1:-}" in
        "setup")
            setup_gitlab
            ;;
        "start")
            start_gitlab
            ;;
        "stop")
            stop_gitlab
            ;;
        "restart")
            restart_gitlab
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "${2:-100}"
            ;;
        "password")
            get_initial_password
            ;;
        "reset-password")
            reset_password
            ;;
        "backup")
            create_backup
            ;;
        "restore")
            restore_backup "${2:-}"
            ;;
        "list-backups")
            list_backups
            ;;
        "migrate")
            prepare_migration
            ;;
        "update")
            update_gitlab
            ;;
        "cleanup")
            cleanup
            ;;
        "uninstall")
            uninstall
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "")
            interactive_menu
            ;;
        *)
            error "Unknown command: $1"
            info "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Trap signals for graceful shutdown
trap 'error "Script interrupted"; exit 130' INT TERM

# Run main function
main "$@"