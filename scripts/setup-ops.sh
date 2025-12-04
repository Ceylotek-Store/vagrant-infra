#!/bin/bash

echo "🛠️  Setting up Combined Ops Server (Mailpit + Monitoring)..."

# 1. System Updates & Dependencies
sudo apt-get update
sudo apt-get install -y curl wget apt-transport-https software-properties-common gnupg2

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

# ==========================================
# PART 1: MAILPIT (Email Capture)
# ==========================================
echo "📧 Installing Mailpit..."
sudo bash -c 'curl -sL https://raw.githubusercontent.com/axllent/mailpit/develop/install.sh | bash'

# Configure Mailpit Service
cat <<EOF | sudo tee /etc/systemd/system/mailpit.service
[Unit]
Description=Mailpit
After=network.target

[Service]
# Listen on 0.0.0.0 so other VMs can reach it
ExecStart=/usr/local/bin/mailpit --smtp 0.0.0.0:1025 --listen 0.0.0.0:8025
Restart=always
User=vagrant

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable mailpit
sudo systemctl start mailpit

# ==========================================
# PART 2: PROMETHEUS (Metrics Database)
# ==========================================
echo "📈 Installing Prometheus..."
PROMETHEUS_VERSION="2.45.0"
wget -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz > /dev/null
sudo mv prometheus-${PROMETHEUS_VERSION}.linux-amd64 /etc/prometheus
rm prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

# Configure Prometheus Scrape Targets
cat <<EOF | sudo tee /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'microservices_cluster'
    static_configs:
      - targets: [
          '192.168.56.10:9100', # DB
          '192.168.56.11:9100', # RabbitMQ
          '192.168.56.12:9100', # Redis
          '192.168.56.20:9100', # Backend
          '192.168.56.30:9100', # Frontend
          '192.168.56.40:9100', # Gateway
          '192.168.56.50:9100'  # Self (Ops VM)
        ]
EOF

# Configure Prometheus Service
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
After=network.target

[Service]
User=root
ExecStart=/etc/prometheus/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/etc/prometheus/data
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable prometheus
sudo systemctl start prometheus

# ==========================================
# PART 3: GRAFANA (Dashboard)
# ==========================================
echo "📊 Installing Grafana..."
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

sudo apt-get update
sudo apt-get install -y grafana

# Configure Grafana to listen on all interfaces
sudo sed -i "s/;http_addr =/http_addr = 0.0.0.0/" /etc/grafana/grafana.ini

sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "✅ Ops VM Setup Complete!"
echo "   📧 Mailpit:    http://192.168.56.50:8025"
echo "   📊 Grafana:    http://192.168.56.50:3000 (admin/admin)"
echo "   📈 Prometheus: http://192.168.56.50:9090"