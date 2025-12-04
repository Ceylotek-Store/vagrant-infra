#!/bin/bash

echo "🚀 Starting RabbitMQ VM Setup..."

# 1. Update & Install RabbitMQ
echo "📦 Updating packages and installing RabbitMQ..."
sudo apt-get update
sudo apt-get install -y rabbitmq-server

# 2. Enable Management Plugin (The UI)
echo "🔌 Enabling Management Console..."
sudo rabbitmq-plugins enable rabbitmq_management

# 3. User Configuration
echo "⚙️  Configuring Admin User..."

# Start service just in case
sudo systemctl start rabbitmq-server

# Create user 'admin' with password 'password123'
# We use '|| true' to suppress errors if the user already exists (idempotency)
sudo rabbitmqctl add_user admin password123 || sudo rabbitmqctl change_password admin password123

# Make admin an administrator
sudo rabbitmqctl set_user_tags admin administrator

# Set permissions (Allow access to everything)
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"

# Optional: Delete default guest user for security
sudo rabbitmqctl delete_user guest || true

# 4. Install Monitoring Agent (Node Exporter)
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

echo "✅ RabbitMQ Setup Complete! Access at http://192.168.56.11:15672"