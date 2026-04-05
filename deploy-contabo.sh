#!/bin/bash
set -e

echo "Starting Budgy deployment on Contabo..."

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl start docker
    systemctl enable docker
fi

# Clone repository
echo "Preparing repository..."
cd /root
REPO_URL=${REPO_URL:-"https://github.com/Falulaan/budgy.git"}
if [ -d "budgy" ]; then
  cd budgy
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git pull; then
      echo "Git pull failed. Using existing files."
    fi
  fi
else
  git clone "$REPO_URL" budgy && cd budgy
fi

# Setup environment
echo "Configuring environment..."
DB_PASSWORD=$(openssl rand -hex 16)
SECRET_KEY=$(openssl rand -hex 32)

cat > backend/.env << EOF
DATABASE_URL=postgresql://budgy:${DB_PASSWORD}@db:5432/budgy
SECRET_KEY=${SECRET_KEY}
DEBUG=False
EOF

echo "Generated DB Password: ${DB_PASSWORD}"
echo "Generated Secret Key: ${SECRET_KEY}"

# Export for docker-compose
export DB_PASSWORD
export SECRET_KEY

# Start services
echo "Starting services..."
docker compose down 2>/dev/null || true
docker compose up -d --build

# Wait for backend
echo "Waiting for services to start..."
sleep 15

# Run migrations
docker compose exec -T backend alembic upgrade head

# Check status
echo ""
echo "Deployment complete!"
echo "Services status:"
docker compose ps
echo ""
echo "API accessible at: http://$(hostname -I | awk '{print $1}'):8000"
echo "Test with: curl http://localhost:8000/health"
