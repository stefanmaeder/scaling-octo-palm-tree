# -------------------------------
# Update system packages and install required tools
# -------------------------------

sudo apt update -y
# Update the package lists from all repositories automatically

sudo apt install podman-docker podman-compose git jq -y
# Install Podman (container engine), Podman-Compose (docker-compose-like for Podman),
# Git (version control), and jq (JSON processor)
# The "-y" automatically confirms installation

# -------------------------------
# Configure Podman registries
# -------------------------------

sudo tee /etc/containers/registries.conf <<EOF
[registries.search]
registries = ["docker.io"]
EOF
# Create a Podman configuration file to set "docker.io" as the default registry for images

# -------------------------------
# Create a system user for Podman services
# -------------------------------

sudo useradd \
  --system \
  --create-home \
  podman-svc
# Create a system user "podman-svc" with a home directory

sudo bash -c 'echo "podman-svc:100000:65536" >> /etc/subuid'
sudo bash -c 'echo "podman-svc:100000:65536" >> /etc/subgid'
# Configure UID and GID subordinate mappings for rootless containers
# Important for Podman to run containers without root privileges

sudo loginctl enable-linger podman-svc
# Allows the user's systemd services to run even when the user is not logged in

# -------------------------------
# Adjust system parameters
# -------------------------------

sudo sysctl -w vm.max_map_count=1048575
# Set the maximum number of memory map areas a process may have
# Required by ElasticSearch

echo "vm.max_map_count=1048575" | sudo tee /etc/sysctl.d/99-max_map_count.conf
# Persist the setting in sysctl configuration

sudo sysctl --system
# Reload all sysctl settings including the new max_map_count

# -------------------------------
# As podman-svc user: Prepare OpenCTI environment
# -------------------------------

sudo -u podman-svc -i bash <<'EOF'
set -e
# Exit immediately if any command fails

cd /home/podman-svc
mkdir -p opencti && cd opencti
# Create working directory for OpenCTI

# -------------------------------
# Clone OpenCTI Docker repository
# -------------------------------

git clone https://github.com/OpenCTI-Platform/docker.git
cd docker

# -------------------------------
# Generate .env configuration file
# -------------------------------

cat > .env <<EOD
APP__ENCRYPTION_KEY=$(openssl rand -base64 32)
# Main encryption key for OpenCTI (32 bytes, base64)

CONNECTOR_ANALYSIS_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_EXPORT_FILE_CSV_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_EXPORT_FILE_STIX_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_EXPORT_FILE_TXT_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_HISTORY_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_IMPORT_DOCUMENT_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_IMPORT_FILE_STIX_ID=$(cat /proc/sys/kernel/random/uuid)
# UUIDs for connectors (unique per installation)

ELASTIC_MEMORY_SIZE=4G
# Allocate memory for ElasticSearch

MINIO_ROOT_PASSWORD=$(cat /proc/sys/kernel/random/uuid)
MINIO_ROOT_USER=$(cat /proc/sys/kernel/random/uuid)
# Credentials for MinIO (S3-compatible storage)

OPENCTI_ADMIN_EMAIL=admin@opencti.io
OPENCTI_ADMIN_PASSWORD=ChangeMePlease
OPENCTI_ADMIN_TOKEN=$(cat /proc/sys/kernel/random/uuid)
# Admin user and token for OpenCTI web interface

OPENCTI_BASE_URL=http://localhost:8080
OPENCTI_ENCRYPTION_KEY=$(cat /proc/sys/kernel/random/uuid)
OPENCTI_HEALTHCHECK_ACCESS_KEY=$(cat /proc/sys/kernel/random/uuid)
OPENCTI_HOST=http://localhost
OPENCTI_PORT=8080
# OpenCTI service URLs and access keys

RABBITMQ_DEFAULT_PASS=$(cat /proc/sys/kernel/random/uuid)
RABBITMQ_DEFAULT_USER=$(cat /proc/sys/kernel/random/uuid)
# credentials for RabbitMQ

SMTP_HOSTNAME=localhost
# SMTP server for email notifications
EOD

# -------------------------------
# Export variables from .env
# -------------------------------

export $(grep -v '^#' .env | xargs)
# Load all key/value pairs from .env into the shell environment

# -------------------------------
# Podman systemd socket setup
# -------------------------------

export XDG_RUNTIME_DIR=/run/user/$(id -u)
# Set the runtime directory for Podman systemd services

systemctl --user daemon-reexec
# Reload the systemd user manager

systemctl --user enable --now podman.socket
systemctl --user start --now podman.socket
systemctl --user start --now podman
# Enable and start the Podman socket and service under the user

# -------------------------------
# Start OpenCTI containers
# -------------------------------

podman-compose up
# Launch all containers defined in the Podman-Compose setup
EOF

# -------------------------------
# Secure podman-svc user after setup
# -------------------------------

sudo usermod -s /usr/sbin/nologin podman-svc
# Set the login shell to nologin to prevent direct login

sudo passwd -l podman-svc
# Lock the user password for additional security
