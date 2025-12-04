#!/bin/bash

echo "🚀 Starting Database VM Setup..."

# 1. Update & Install PostgreSQL
echo "📦 Updating packages and installing PostgreSQL..."
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib

# FIX: Change directory to root so the 'postgres' user doesn't get "Permission denied" 
# when trying to access the current folder (/home/vagrant).
cd /

# 2. Database Configuration
echo "⚙️  Configuring User and Database..."

# Create User 'admin' (Using || true to ignore if already exists)
sudo -u postgres psql -c "CREATE USER admin WITH PASSWORD 'password123';" || true

# Grant 'CREATEDB' permission (Required for Prisma Shadow Database)
sudo -u postgres psql -c "ALTER USER admin CREATEDB;"

# Create the Database
sudo -u postgres psql -c "CREATE DATABASE ecommerce_store OWNER admin;" || true

# 3. Enable Remote Access (postgresql.conf)
PG_CONF="/etc/postgresql/*/main/postgresql.conf"
PG_HBA="/etc/postgresql/*/main/pg_hba.conf"

echo "🔓 Enabling Remote Access in $PG_CONF..."
# Change listen_addresses from 'localhost' to '*'
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF

# 4. Configure Authentication (pg_hba.conf)
echo "🛡️  Configuring Authentication in $PG_HBA..."
# Allow connection from 192.168.56.X (Your Host & Other VMs)
if ! sudo grep -q "192.168.56.0/24" $PG_HBA; then
    echo "host    all             all             192.168.56.0/24         scram-sha-256" | sudo tee -a $PG_HBA
fi

# 5. Install Monitoring Agent (Node Exporter)
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

# 6. Restart Service
echo "🔄 Restarting PostgreSQL..."
sudo systemctl restart postgresql

echo "✅ Database Setup Complete!"