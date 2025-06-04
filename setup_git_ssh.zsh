#!/usr/bin/env zsh

# Git SSH Setup Script for Multiple Accounts
# Supports GitHub, GitLab (cloud & self-hosted)
# Compatible with Linux and macOS

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"
BACKUP_DIR="$SSH_DIR/backups"
LOG_FILE="$SSH_DIR/git-ssh-setup.log"

# Initialize SSH directory first
init_ssh_directory() {
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$LOG_FILE" 2>/dev/null || true
}

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO") echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") echo -e "${BLUE}[DEBUG]${NC} $message" ;;
        "SUCCESS") echo -e "${PURPLE}[SUCCESS]${NC} $message" ;;
    esac
    
    # Also log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
}

# Check if running on supported OS
check_os() {
    if [[ "$OSTYPE" != "linux-gnu"* && "$OSTYPE" != "darwin"* ]]; then
        log "ERROR" "This script only supports Linux and macOS"
        exit 1
    fi
}

# Check for required commands
check_dependencies() {
    local missing_deps=()
    
    for cmd in ssh-keygen ssh-add git; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing required dependencies: ${missing_deps[*]}"
        log "INFO" "Please install them and run the script again"
        exit 1
    fi
}

# Create backup of existing configuration
create_backup() {
    if [[ -f "$SSH_CONFIG" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup_file="$BACKUP_DIR/config_$(date +%Y%m%d_%H%M%S)"
        cp "$SSH_CONFIG" "$backup_file"
        log "INFO" "Backup created: $backup_file"
    fi
}

# Initialize SSH directory and config
init_ssh_setup() {
    if [[ ! -f "$SSH_CONFIG" ]]; then
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
        log "INFO" "Created new SSH config file"
    fi
}

# Check if this is first time setup
is_first_time_setup() {
    if [[ ! -f "$SSH_CONFIG" ]] || [[ ! -s "$SSH_CONFIG" ]]; then
        return 0  # First time
    fi
    
    # Check if there are any Host entries for git services
    if grep -q "^Host.*\(github\|gitlab\)" "$SSH_CONFIG" 2>/dev/null; then
        return 1  # Not first time
    fi
    
    return 0  # First time
}

# Get user input with validation
get_input() {
    local prompt="$1"
    local var_name="$2"
    local validation_func="${3:-}"
    local default_value="${4:-}"
    
    while true; do
        if [[ -n "$default_value" ]]; then
            echo -n -e "${BLUE}$prompt [$default_value]: ${NC}"
        else
            echo -n -e "${BLUE}$prompt: ${NC}"
        fi
        
        read -r input
        
        # Use default if input is empty
        if [[ -z "$input" && -n "$default_value" ]]; then
            input="$default_value"
        fi
        
        # Check for empty input when no default provided
        if [[ -z "$input" && -z "$default_value" ]]; then
            log "ERROR" "Input cannot be empty"
            continue
        fi
        
        # Validate input if validation function provided
        if [[ -n "$validation_func" ]]; then
            if $validation_func "$input"; then
                eval "$var_name='$input'"
                break
            fi
        else
            eval "$var_name='$input'"
            break
        fi
    done
}

# Validation functions
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 0
    else
        log "ERROR" "Invalid email format"
        return 1
    fi
}

validate_hostname() {
    local hostname="$1"
    if [[ "$hostname" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        return 0
    else
        log "ERROR" "Invalid hostname format"
        return 1
    fi
}

validate_account_name() {
    local name="$1"
    if [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        # Check if account already exists
        if grep -q "^Host $name$" "$SSH_CONFIG" 2>/dev/null; then
            log "ERROR" "Account name '$name' already exists"
            return 1
        fi
        return 0
    else
        log "ERROR" "Account name must contain only letters, numbers, hyphens, and underscores"
        return 1
    fi
}

validate_menu_choice() {
    local choice="$1"
    if [[ "$choice" =~ ^[1-6]$ ]]; then
        return 0
    else
        log "ERROR" "Invalid option. Please select 1-6."
        return 1
    fi
}

# Generate SSH key
generate_ssh_key() {
    local email="$1"
    local key_name="$2"
    local key_path="$SSH_DIR/$key_name"
    
    if [[ -f "$key_path" ]]; then
        log "WARN" "SSH key already exists: $key_path"
        echo -n -e "${YELLOW}Do you want to overwrite it? (y/N): ${NC}"
        read -r overwrite
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            return 1
        fi
    fi
    
    log "INFO" "Generating SSH key: $key_path"
    ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
    
    if [[ $? -eq 0 ]]; then
        chmod 600 "$key_path"
        chmod 644 "$key_path.pub"
        log "SUCCESS" "SSH key generated successfully"
        return 0
    else
        log "ERROR" "Failed to generate SSH key"
        return 1
    fi
}

# Add SSH key to ssh-agent
add_to_ssh_agent() {
    local key_path="$1"
    
    # Start ssh-agent if not running
    if ! pgrep -u "$USER" ssh-agent > /dev/null; then
        eval "$(ssh-agent -s)"
    fi
    
    # Add key to ssh-agent
    ssh-add "$key_path" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        log "SUCCESS" "SSH key added to ssh-agent"
        
        # For macOS, also add to keychain
        if [[ "$OSTYPE" == "darwin"* ]]; then
            ssh-add --apple-use-keychain "$key_path" 2>/dev/null || true
        fi
    else
        log "WARN" "Failed to add SSH key to ssh-agent"
    fi
}

# Update SSH config
update_ssh_config() {
    local account_name="$1"
    local hostname="$2"
    local username="$3"
    local key_path="$4"
    local port="${5:-22}"
    
    local config_entry="
# $account_name account
Host $account_name
    HostName $hostname
    User $username
    IdentityFile $key_path
    Port $port
    IdentitiesOnly yes
    AddKeysToAgent yes"
    
    # Add macOS keychain support
    if [[ "$OSTYPE" == "darwin"* ]]; then
        config_entry="$config_entry
    UseKeychain yes"
    fi
    
    echo "$config_entry" >> "$SSH_CONFIG"
    log "SUCCESS" "SSH config updated for $account_name"
}

# Display public key
display_public_key() {
    local key_path="$1"
    local service="$2"
    
    echo
    log "INFO" "Public key for $service:"
    echo -e "${GREEN}$(cat "$key_path.pub")${NC}"
    echo
    log "INFO" "Copy the above public key and add it to your $service account"
    
    # Provide specific instructions based on service
    case "$service" in
        *github*)
            echo -e "${BLUE}GitHub: Settings → SSH and GPG keys → New SSH key${NC}"
            ;;
        *gitlab*)
            echo -e "${BLUE}GitLab: Settings → SSH Keys → Add new key${NC}"
            ;;
    esac
}

# Test SSH connection
test_ssh_connection() {
    local host="$1"
    local service="$2"
    
    log "INFO" "Testing SSH connection to $service..."
    
    # Test the connection with better error handling
    local ssh_output
    ssh_output=$(ssh -T "$host" 2>&1)
    local ssh_exit_code=$?
    
    # Check for successful authentication patterns
    if echo "$ssh_output" | grep -qE "(successfully authenticated|Hi [a-zA-Z0-9_-]+!|Welcome to GitLab)"; then
        log "SUCCESS" "SSH connection to $service successful!"
        echo -e "${GREEN}$ssh_output${NC}"
        return 0
    elif echo "$ssh_output" | grep -q "Permission denied"; then
        log "ERROR" "SSH connection failed - Permission denied"
        log "INFO" "Make sure you've added the public key to your $service account"
        return 1
    else
        log "WARN" "SSH connection test inconclusive. Output:"
        echo "$ssh_output"
        return 1
    fi
}

# Setup GitHub account
setup_github_account() {
    log "INFO" "Setting up GitHub account"
    
    local email username account_name key_name host_alias
    
    get_input "Enter your GitHub email" email validate_email
    get_input "Enter your GitHub username" username
    get_input "Enter account name (for SSH config)" account_name validate_account_name "$username-github"
    
    key_name="id_ed25519_${account_name}"
    host_alias="$account_name"
    
    if generate_ssh_key "$email" "$key_name"; then
        add_to_ssh_agent "$SSH_DIR/$key_name"
        update_ssh_config "$host_alias" "github.com" "git" "$SSH_DIR/$key_name"
        display_public_key "$SSH_DIR/$key_name" "GitHub"
        
        echo -n -e "${YELLOW}Press Enter after adding the public key to GitHub...${NC}"
        read -r
        
        test_ssh_connection "$host_alias" "GitHub"
        
        echo
        log "INFO" "Example clone command: git clone git@$host_alias:username/repository.git"
        log "INFO" "To use this account, clone with: git clone git@$host_alias:zainbits/repo-name.git"
    fi
}

# Setup GitLab account (cloud or self-hosted)
setup_gitlab_account() {
    log "INFO" "Setting up GitLab account"
    
    local email username hostname account_name key_name host_alias port
    
    get_input "Enter your GitLab email" email validate_email
    get_input "Enter your GitLab username" username
    get_input "Enter GitLab hostname" hostname validate_hostname "gitlab.com"
    get_input "Enter account name (for SSH config)" account_name validate_account_name "$username-gitlab"
    get_input "Enter SSH port" port "" "22"
    
    key_name="id_ed25519_${account_name}"
    host_alias="$account_name"
    
    if generate_ssh_key "$email" "$key_name"; then
        add_to_ssh_agent "$SSH_DIR/$key_name"
        update_ssh_config "$host_alias" "$hostname" "git" "$SSH_DIR/$key_name" "$port"
        display_public_key "$SSH_DIR/$key_name" "GitLab ($hostname)"
        
        echo -n -e "${YELLOW}Press Enter after adding the public key to GitLab...${NC}"
        read -r
        
        test_ssh_connection "$host_alias" "GitLab ($hostname)"
        
        echo
        log "INFO" "Example clone command: git clone git@$host_alias:username/repository.git"
    fi
}

# List existing accounts
list_accounts() {
    if [[ ! -f "$SSH_CONFIG" ]]; then
        log "INFO" "No SSH config found"
        return
    fi
    
    echo -e "${BLUE}Existing SSH accounts:${NC}"
    local accounts
    accounts=$(grep "^Host " "$SSH_CONFIG" | grep -v "Host \*" | sed 's/Host /  - /' 2>/dev/null)
    
    if [[ -n "$accounts" ]]; then
        echo "$accounts"
    else
        log "INFO" "No accounts configured"
    fi
}

# Main menu
show_menu() {
    echo
    echo -e "${PURPLE}=== Git SSH Setup for Multiple Accounts ===${NC}"
    echo
    echo "1) Setup GitHub account"
    echo "2) Setup GitLab account (cloud or self-hosted)"
    echo "3) List existing accounts"
    echo "4) Test SSH connection"
    echo "5) View SSH config"
    echo "6) Exit"
    echo
}

# Test existing connection - FIXED VERSION
test_existing_connection() {
    list_accounts
    echo
    
    # Check if there are any accounts (excluding wildcard hosts)
    local account_count
    account_count=$(grep "^Host " "$SSH_CONFIG" 2>/dev/null | grep -v "Host \*" | wc -l)
    
    if [[ "$account_count" -eq 0 ]]; then
        log "INFO" "No accounts configured to test"
        return
    fi
    
    get_input "Enter account name to test" account_name
    
    if grep -q "^Host $account_name$" "$SSH_CONFIG"; then
        local hostname=$(grep -A 5 "^Host $account_name$" "$SSH_CONFIG" | grep "HostName" | awk '{print $2}')
        test_ssh_connection "$account_name" "$hostname"
    else
        log "ERROR" "Account '$account_name' not found"
    fi
}

# View SSH config
view_ssh_config() {
    if [[ -f "$SSH_CONFIG" && -s "$SSH_CONFIG" ]]; then
        echo -e "${BLUE}Current SSH config:${NC}"
        cat "$SSH_CONFIG"
    else
        log "INFO" "No SSH config found or file is empty"
    fi
}

# Main function
main() {
    # Initialize SSH directory first
    init_ssh_directory
    
    log "INFO" "Starting Git SSH setup script"
    
    check_os
    check_dependencies
    init_ssh_setup
    
    # Check if first time setup
    if is_first_time_setup; then
        log "INFO" "First time Git SSH setup detected"
    else
        log "INFO" "Existing Git SSH configuration found"
        list_accounts
    fi
    
    create_backup
    
    while true; do
        show_menu
        get_input "Select an option (1-6)" choice validate_menu_choice
        
        case "$choice" in
            1) setup_github_account ;;
            2) setup_gitlab_account ;;
            3) list_accounts ;;
            4) test_existing_connection ;;
            5) view_ssh_config ;;
            6) 
                log "SUCCESS" "Git SSH setup completed!"
                exit 0
                ;;
        esac
        
        echo
        echo -n -e "${YELLOW}Press Enter to continue...${NC}"
        read -r
    done
}

# Cleanup function
cleanup() {
    log "INFO" "Script interrupted. Cleaning up..."
    exit 1
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Run main function
main "$@"