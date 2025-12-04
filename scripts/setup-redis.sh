#!/bin/bash

# 1. Update & Install Redis
echo "--- Updating packages and installing Redis ---"
sudo apt-get update
sudo apt-get install -y redis-server

# 2. Configure Redis
# On Ubuntu, the config is at /etc/redis/redis.conf
CONFIG_FILE="/etc/redis/redis.conf"

echo "--- Configuring Redis Settings ---"

# A. Bind to 0.0.0.0 (Allow remote connections)
# The default line in Ubuntu 22.04 is usually "bind 127.0.0.1 ::1"
# We replace it to listen on all interfaces.
sudo sed -i "s/^bind 127.0.0.1 ::1/bind 0.0.0.0/" $CONFIG_FILE

# Fallback: In case the default config format varies slightly
sudo sed -i "s/^bind 127.0.0.1/bind 0.0.0.0/" $CONFIG_FILE

# B. Disable Protected Mode
# Required when listening on external IPs if you haven't set up complex ACLs
sudo sed -i "s/protected-mode yes/protected-mode no/" $CONFIG_FILE

# C. Set Password (Security Best Practice)
# Replaces the default commented out line "# requirepass foobared"
# Matches the password used in your .env file
sudo sed -i "s/# requirepass foobared/requirepass password123/" $CONFIG_FILE

# 3. Enable and Restart Service (Systemd)
echo "--- Enabling and Restarting Redis Service ---"

# This command ensures Redis starts automatically on VM reboot
sudo systemctl enable redis-server

# Restart immediately to apply the configuration changes we just made
sudo systemctl restart redis-server

# ---------------------------------------------------------
# 4. Install Monitoring Agent (Node Exporter)
# ---------------------------------------------------------
if ! systemctl is-active --quiet node_exporter; then
    echo "📊 Installing Node Exporter Agent..."
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
    echo "📊 Node Exporter is already running."
fi
# ---------------------------------------------------------

echo "--- Redis Setup Complete! ---"