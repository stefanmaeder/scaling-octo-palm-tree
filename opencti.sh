# -------------------------------
# Update system packages and install required tools
# -------------------------------

sudo apt update -y
# Update the package lists from all repositories automatically

sudo apt install docker-compose docker.io git jq -y
# Install Docker (container engine),
# Git (version control), and jq (JSON processor)
# The "-y" automatically confirms installation

# -------------------------------
# Adjust system parameters
# -------------------------------

sudo systemctl start docker.service

sudo sysctl -w vm.max_map_count=1048575
# Set the maximum number of memory map areas a process may have
# Required by ElasticSearch

echo "vm.max_map_count=1048575" | sudo tee /etc/sysctl.d/99-max_map_count.conf
# Persist the setting in sysctl configuration

sudo sysctl --system
# Reload all sysctl settings including the new max_map_count

sudo groupadd docker
sudo usermod -aG docker $USER

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
CONNECTOR_ANALYSIS_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_EXPORT_FILE_CSV_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_EXPORT_FILE_STIX_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_EXPORT_FILE_TXT_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_HISTORY_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_IMPORT_DOCUMENT_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_IMPORT_EXTERNAL_REFERENCE_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_IMPORT_FILE_STIX_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_IMPORT_FILE_YARA_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_MITRE_ID=$(cat /proc/sys/kernel/random/uuid)
# UUIDs for connectors (unique per installation)

ELASTIC_MEMORY_SIZE=4G
# Allocate memory for ElasticSearch

MINIO_ROOT_PASSWORD=$(cat /proc/sys/kernel/random/uuid)
MINIO_ROOT_USER=$(cat /proc/sys/kernel/random/uuid)
# Credentials for MinIO (S3-compatible storage)

OPENCTI_ADMIN_EMAIL=admin@opencti.io
OPENCTI_ADMIN_PASSWORD=ChangeMePlease
OPENCTI_ADMIN_TOKEN=$(cat /proc/sys/kernel/random/uuid)
OPENCTI_EXTERNAL_SCHEME=http
# Admin user and token for OpenCTI web interface

OPENCTI_BASE_URL=http://localhost:8080
OPENCTI_ENCRYPTION_KEY=$(openssl rand -base64 32)
# Main encryption key for OpenCTI (32 bytes, base64)

OPENCTI_HEALTHCHECK_ACCESS_KEY=$(cat /proc/sys/kernel/random/uuid)
OPENCTI_HOST=http://localhost
OPENCTI_PORT=8080
# OpenCTI service URLs and access keys

RABBITMQ_DEFAULT_PASS=$(cat /proc/sys/kernel/random/uuid)
RABBITMQ_DEFAULT_USER=$(cat /proc/sys/kernel/random/uuid)
# credentials for RabbitMQ

SMTP_HOSTNAME=localhost
# SMTP server for email notifications

XTM_COMPOSER_ID=$(cat /proc/sys/kernel/random/uuid)

EOD

# -------------------------------
# Export variables from .env
# -------------------------------

export $(grep -v '^#' .env | xargs)
# Load all key/value pairs from .env into the shell environment


# -------------------------------
# Start OpenCTI containers
# -------------------------------

echo "new version"
sudo docker-compose up -d
# Run docker-compose in detached
