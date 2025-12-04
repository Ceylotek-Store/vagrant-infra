#!/bin/bash

echo "🚀 Starting Gateway VM Setup..."

# 1. Install Nginx
echo "📦 Updating packages and installing Nginx..."
sudo apt-get update
sudo apt-get install -y nginx

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

# 3. Configure Nginx
echo "⚙️  Configuring Nginx Routes..."
# We overwrite the default config directly
cat <<EOF | sudo tee /etc/nginx/sites-available/default
server {
    listen 80;
    server_name _;

    # --- ROUTE 1: API TRAFFIC ---
    # Any URL starting with /api goes to the Backend VM (.20)
    location /api {
        proxy_pass http://192.168.56.20:5000;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # --- ROUTE 2: STATIC UPLOADS ---
    # Any URL starting with /uploads (images) goes to the Backend VM (.20)
    location /uploads {
        proxy_pass http://192.168.56.20:5000;
        
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    # --- ROUTE 3: FRONTEND TRAFFIC ---
    # Everything else goes to the Frontend VM (.30)
    location / {
        proxy_pass http://192.168.56.30:3000;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# 4. Restart Nginx
echo "🔄 Restarting Nginx..."
sudo systemctl restart nginx

echo "✅ Gateway Setup Complete! Access at http://192.168.56.40"