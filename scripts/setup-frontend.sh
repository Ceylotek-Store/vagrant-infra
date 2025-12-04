#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# --- CONFIGURATION ---
# [IMPORTANT] REPLACE THIS WITH YOUR REPO URL
GIT_REPO_URL="https://github.com/Ceylotek-Store/ceylotek-store-web.git"
APP_DIR="/var/www/frontend"
BACKEND_API_URL="http://192.168.56.40/api"
NEXT_PUBLIC_UPLOADS_BACKEND_URL="http://192.168.56.40"

echo "Started: Frontend Setup..."

# 1. Install System Dependencies
echo "Installing Git, Curl, and Unzip..."
sudo apt-get update
sudo apt-get install -y curl git unzip

# 2. Install Node.js 20 (LTS)
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# 3. Install PM2 (Process Manager) globally
echo "Installing PM2..."
sudo npm install -g pm2

# 4. Prepare Directory
# We create the folder and give ownership to the 'vagrant' user
if [ ! -d "$APP_DIR" ]; then
    echo "Creating application directory..."
    sudo mkdir -p "$APP_DIR"
    sudo chown -R vagrant:vagrant "$APP_DIR"
fi

# 5. Clone or Pull Code
if [ ! -d "$APP_DIR/.git" ]; then
    echo "Cloning repository..."
    git clone "$GIT_REPO_URL" "$APP_DIR"
else
    echo "Repository exists. Pulling latest changes..."
    cd "$APP_DIR"
    git pull origin main
fi

# 6. Install Dependencies & Configure Environment
cd "$APP_DIR"

echo "Installing NPM dependencies..."
npm install

echo "📝 Creating .env.local file..."
# We create this BEFORE building so Next.js can embed the values
cat <<EOF > .env.local
NEXT_PUBLIC_BACKEND_URL=$BACKEND_API_URL
NEXT_PUBLIC_UPLOADS_BACKEND_URL=$NEXT_PUBLIC_UPLOADS_BACKEND_URL
EOF

# 7. Build Application
echo "Building Next.js application..."
npm run build

# 8. Start Application with PM2
echo "Starting app with PM2..."
pm2 delete ecommerce-frontend || true
pm2 start npm --name "ecommerce-frontend" -- start

# Save PM2 list so it restarts on reboot
pm2 save

echo "Finished: Frontend Setup Complete!"
echo "You can access your site at http://localhost:3000"