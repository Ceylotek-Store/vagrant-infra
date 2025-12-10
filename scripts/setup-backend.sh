#!/bin/bash

# --- CONFIGURATION ---
REPO_URL="https://github.com/Ceylotek-Store/ceylotek-store-backend.git" 
APP_DIR="/var/www/ceylotek-store-backend"
USER="vagrant"

echo "🚀 Starting Ceylotek Ecommerce Backend Deployment..."

# 1. Install System Dependencies & Node.js
echo "🔧 Installing System Dependencies..."
sudo apt-get update
sudo apt-get install -y git curl build-essential

# Install Node.js 20 (Check if installed first to save time)
if ! command -v node &> /dev/null; then
    echo "   Node.js not found. Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Install PM2 globally
if ! command -v pm2 &> /dev/null; then
    echo "   PM2 not found. Installing..."
    sudo npm install -g pm2
fi

# 2. Install Monitoring Agent (Node Exporter)
echo "📊 Checking Monitoring Agent..."
if ! systemctl is-active --quiet node_exporter; then
    echo "   Installing Node Exporter..."
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
    tar xvf node_exporter-1.6.1.linux-amd64.tar.gz > /dev/null
    sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
    rm -rf node_exporter*

    # Create Systemd Service
    cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=vagrant
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter
    echo "   Agent active on port 9100"
else
    echo "   Node Exporter is already running."
fi

# 3. Setup Application Directory
echo "📂 Checking directory structure..."
if [ ! -d "/var/www" ]; then
    echo "   Creating /var/www..."
    sudo mkdir -p /var/www
    sudo chown -R $USER:$USER /var/www
fi

# 4. Clone or Pull Code
if [ ! -d "$APP_DIR" ]; then
    echo "⬇️  Cloning repository..."
    cd /var/www
    git clone -b main $REPO_URL 
else
    echo "🔄 Repository exists. Pulling latest changes..."
    cd $APP_DIR
    git pull origin main
fi

# Move into App Directory
cd $APP_DIR

# 5. Install Dependencies
echo "📦 Installing Node dependencies..."
# Remove node_modules to ensure Linux binaries are built fresh (vs Windows ones)
rm -rf node_modules
npm install

# 6. Create .env File (Production Configuration)
echo "📝 Creating .env file..."
cat <<EOF > .env
PORT=5000
NODE_ENV=production

# Database (Postgres VM .10)
DATABASE_URL="postgresql://admin:password123@192.168.56.10:5432/ecommerce_store?schema=public"

# Redis (Redis VM .12)
REDIS_URL="redis://:password123@192.168.56.12:6379"

# RabbitMQ (RabbitMQ VM .11)
RABBITMQ_URL="amqp://admin:password123@192.168.56.11:5672"

# Security
JWT_SECRET="0bb9329078266d0e9b0e310f23119b5ec41744b792bc91b80b395983cbd8fcc4"

# Email Service (Mailpit on .50)
SMTP_HOST=192.168.56.50
SMTP_PORT=1025
SMTP_USER=null
SMTP_PASS=null
EMAIL_FROM=noreply@ceylotek.com
EOF

# 7. Generate Prisma Client
echo "⚙️  Generating Prisma Client..."
npx prisma generate

# 8. Start RabbitMQ Worker (PM2)
echo "🐇 Starting RabbitMQ Worker..."
pm2 delete ecommerce-worker 2>/dev/null || true
pm2 start worker.js --name ecommerce-worker --update-env

# 9. Seed the Database
echo "🌱 Seeding Database..."
npx prisma db seed

# 10. Start API Server (PM2)
echo "🚀 Starting API Server..."
pm2 delete ecommerce-api 2>/dev/null || true
pm2 start server.js --name ecommerce-api --update-env

# 11. Save PM2 List & Configure Persistence
echo "💾 Saving Process List..."
pm2 save

echo "🔌 Configuring PM2 Startup System..."
# This command tells Ubuntu's systemd to launch PM2 for user 'vagrant' automatically on boot
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u vagrant --hp /home/vagrant

echo "✅ Deployment Complete! Backend is running at http://192.168.56.20:5000"