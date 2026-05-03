#!/bin/bash
# Jenkins Droplet setup script (cloud-init / user-data)
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ─── Update system ───────────────────────────────────────────────────────────
apt-get update -y
apt-get upgrade -y

# ─── Java 21 ─────────────────────────────────────────────────────────────────
apt-get install -y curl gnupg2 software-properties-common apt-transport-https

apt-get install -y temurin-21-jdk 2>/dev/null || {
    # Fallback: install from official Temurin repo
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | \
        gpg --dearmor -o /etc/apt/trusted.gpg.d/adoptium.gpg
    echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -sc) main" \
        > /etc/apt/sources.list.d/adoptium.list
    apt-get update -y
    apt-get install -y temurin-21-jdk
}

# ─── Jenkins LTS ─────────────────────────────────────────────────────────────
wget -qO /etc/apt/trusted.gpg.d/jenkins.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list
apt-get update -y
apt-get install -y jenkins

# Configure Jenkins to use Java 21
JAVA21=$(update-alternatives --list java | grep "21" | head -1)
if [ -n "$JAVA21" ]; then
    sed -i "s|^JAVA=.*|JAVA=$JAVA21|" /etc/default/jenkins 2>/dev/null || true
fi

# ─── Docker ──────────────────────────────────────────────────────────────────
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/trusted.gpg.d/docker.gpg
echo "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Add jenkins user to docker group
usermod -aG docker jenkins
usermod -aG docker ubuntu

# ─── kubectl ─────────────────────────────────────────────────────────────────
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | \
    gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb [signed-by=/etc/apt/trusted.gpg.d/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubectl

# ─── doctl ───────────────────────────────────────────────────────────────────
DOCTL_VERSION=$(curl -s https://api.github.com/repos/digitalocean/doctl/releases/latest | \
    grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
wget -qO /tmp/doctl.tar.gz \
    "https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz"
tar xf /tmp/doctl.tar.gz -C /usr/local/bin doctl
chmod +x /usr/local/bin/doctl

# ─── Gradle wrapper (for building without local Gradle) ──────────────────────
apt-get install -y git

# ─── Start services ──────────────────────────────────────────────────────────
systemctl enable jenkins docker
systemctl start docker
systemctl start jenkins

# ─── Open firewall ports ─────────────────────────────────────────────────────
ufw --force enable
ufw allow OpenSSH
ufw allow 8080/tcp   # Jenkins UI
ufw allow 50000/tcp  # Jenkins agent port

# ─── Print initial admin password ────────────────────────────────────────────
echo "=========================================="
echo "Jenkins initial setup:"
echo "URL: http://$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address):8080"
echo "Initial password:"
cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || \
    echo "(not yet generated, wait 1-2 min and run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
echo "=========================================="
