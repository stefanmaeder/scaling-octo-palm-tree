sudo apt update -y
sudo apt install podman-docker podman-compose git jq -y
sudo tee /etc/containers/registries.conf <<EOF
[registries.search]
registries = ["docker.io"]
EOF
sudo useradd \
  --system \
  --create-home \
  podman-svc
sudo bash -c 'echo "podman-svc:100000:65536" >> /etc/subuid'
sudo bash -c 'echo "podman-svc:100000:65536" >> /etc/subgid'
sudo loginctl enable-linger podman-svc
sudo sysctl -w vm.max_map_count=1048575
echo "vm.max_map_count=1048575" | sudo tee /etc/sysctl.d/99-max_map_count.conf
sudo sysctl --system
sudo -u podman-svc -i bash <<'EOF'
set -e

cd /home/podman-svc
mkdir -p opencti && cd opencti

# Clone the repo
git clone https://github.com/OpenCTI-Platform/docker.git
cd docker

# Generate .env file
cat > .env <<EOD
OPENCTI_ADMIN_EMAIL=admin@opencti.io
OPENCTI_ADMIN_PASSWORD=ChangeMePlease
OPENCTI_ADMIN_TOKEN=$(cat /proc/sys/kernel/random/uuid)
OPENCTI_BASE_URL=http://localhost:8080
OPENCTI_HEALTHCHECK_ACCESS_KEY=$(cat /proc/sys/kernel/random/uuid)
MINIO_ROOT_USER=$(cat /proc/sys/kernel/random/uuid)
MINIO_ROOT_PASSWORD=$(cat /proc/sys/kernel/random/uuid)
RABBITMQ_DEFAULT_USER=guest
RABBITMQ_DEFAULT_PASS=guest
ELASTIC_MEMORY_SIZE=4G
CONNECTOR_HISTORY_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_EXPORT_FILE_STIX_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_EXPORT_FILE_CSV_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_IMPORT_FILE_STIX_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_EXPORT_FILE_TXT_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_IMPORT_DOCUMENT_ID=$(cat /proc/sys/kernel/random/uuid)
CONNECTOR_ANALYSIS_ID=$(cat /proc/sys/kernel/random/uuid)
SMTP_HOSTNAME=localhost
EOD

# Export variables from .env
export $(grep -v '^#' .env | xargs)

# Podman systemd setup
export XDG_RUNTIME_DIR=/run/user/$(id -u)
systemctl --user daemon-reexec
systemctl --user enable --now podman.socket
systemctl --user start --now podman.socket
systemctl --user start --now podman

# Start containers
podman-compose up
EOF
sudo usermod -s /usr/sbin/nologin podman-svc
sudo passwd -l podman-svc
