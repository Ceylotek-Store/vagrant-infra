Vagrant.configure("2") do |config|
  # Default OS for all machines
  config.vm.box = "ubuntu/jammy64"

  # =========================================================================
  # 1. DATA LAYER (Persistence & Messaging)
  # =========================================================================

  # --- PostgreSQL Database (.10) ---
  config.vm.define "db" do |db|
    db.vm.hostname = "ecommerce-db"
    db.vm.network "private_network", ip: "192.168.56.10"
    
    db.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
      vb.name = "ceylotek-db"
    end
    
    db.vm.provision "shell", path: "scripts/setup-db.sh"
  end

  # --- RabbitMQ Message Broker (.11) ---
  config.vm.define "rabbitmq" do |mq|
    mq.vm.hostname = "ecommerce-rabbitmq"
    mq.vm.network "private_network", ip: "192.168.56.11"
    
    # Expose Management UI (15672) to host for convenience
    mq.vm.network "forwarded_port", guest: 15672, host: 15672

    mq.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
      vb.name = "ceylotek-rabbitmq"
    end
    
    mq.vm.provision "shell", path: "scripts/setup-rabbitmq.sh"
  end

  # --- Redis Cache (.12) ---
  config.vm.define "redis" do |redis|
    redis.vm.hostname = "ecommerce-redis"
    redis.vm.network "private_network", ip: "192.168.56.12"
    
    redis.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
      vb.name = "ceylotek-redis"
    end
    
    redis.vm.provision "shell", path: "scripts/setup-redis.sh"
  end

  # =========================================================================
  # 2. APPLICATION LAYER (API & Web)
  # =========================================================================

  # --- Backend API (.20) ---
  config.vm.define "backend" do |api|
    api.vm.hostname = "ecommerce-backend"
    api.vm.network "private_network", ip: "192.168.56.20"
    
    # [UPDATED] Removed synced_folder to fix Windows EPROTO/symlink errors.
    # Code must now be cloned via git in setup-backend.sh

    api.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
      vb.name = "ceylotek-backend"
    end
    
    # privileged: false ensures PM2 starts as 'vagrant' user, not root
    api.vm.provision "shell", path: "scripts/setup-backend.sh", privileged: false
  end

  # --- Frontend App (.30) ---
  config.vm.define "frontend" do |web|
    web.vm.hostname = "ecommerce-frontend"
    web.vm.network "private_network", ip: "192.168.56.30"
    
    # [UPDATED] Removed synced_folder to fix Windows EPROTO/symlink errors.
    # Code must now be cloned via git in setup-frontend.sh

    web.vm.provider "virtualbox" do |vb|
      vb.memory = "1536" # Next.js build needs more RAM
      vb.cpus = 2
      vb.name = "ceylotek-frontend"
    end
    
    web.vm.provision "shell", path: "scripts/setup-frontend.sh", privileged: false
  end

  # =========================================================================
  # 3. ROUTING LAYER (Gateway)
  # =========================================================================

  # --- Nginx Gateway (.40) ---
  config.vm.define "gateway" do |gw|
    gw.vm.hostname = "ecommerce-gateway"
    gw.vm.network "private_network", ip: "192.168.56.40"
    
    # Main Entry Point: Forward port 80 to localhost:8080
    # Access your app at http://localhost:8080
    gw.vm.network "forwarded_port", guest: 80, host: 8080

    gw.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.cpus = 1
      vb.name = "ceylotek-gateway"
    end
    
    gw.vm.provision "shell", path: "scripts/setup-gateway.sh"
  end

  # =========================================================================
  # 4. OPS LAYER (Monitoring & Tools)
  # =========================================================================

  # --- Ops Server (.50) ---
  config.vm.define "ops" do |ops|
    ops.vm.hostname = "ecommerce-ops"
    ops.vm.network "private_network", ip: "192.168.56.50"
    
    # Forward Ports for Windows Access
    ops.vm.network "forwarded_port", guest: 8025, host: 8025  # Mailpit UI
    ops.vm.network "forwarded_port", guest: 3000, host: 3030  # Grafana UI (Mapped to 3030)
    ops.vm.network "forwarded_port", guest: 9090, host: 9090  # Prometheus UI

    ops.vm.provider "virtualbox" do |vb|
      vb.memory = "1536" # Needs RAM for Grafana + Prometheus
      vb.cpus = 2
      vb.name = "ceylotek-ops"
    end
    
    ops.vm.provision "shell", path: "scripts/setup-ops.sh"
  end

end