#!/bin/bash

set -e

CERT_FILE="$1"

if [ -z "$CERT_FILE" ]; then
  echo "Usage: $0 <path-to-cert.crt>"
  exit 1
fi

if [ ! -f "$CERT_FILE" ]; then
  echo "Error: Certificate file '$CERT_FILE' not found."
  exit 1
fi

# Detect distro
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
else
  echo "Cannot detect Linux distribution"
  exit 1
fi

echo "Detected distribution: $DISTRO"
CERT_BASENAME=$(basename "$CERT_FILE")

install_for_debian() {
  sudo cp "$CERT_FILE" "/usr/local/share/ca-certificates/$CERT_BASENAME"
  sudo update-ca-certificates
}

install_for_arch() {
  sudo cp "$CERT_FILE" "/etc/ca-certificates/trust-source/anchors/$CERT_BASENAME"
  sudo trust extract-compat
}

setup_docker_ca() {
  read -p "Enter Docker registry domain (e.g., registry.example.com): " REGISTRY_DOMAIN
  if [ -z "$REGISTRY_DOMAIN" ]; then
    echo "Skipped Docker CA setup."
    return
  fi
  sudo mkdir -p "/etc/docker/certs.d/$REGISTRY_DOMAIN/"
  sudo cp "$CERT_FILE" "/etc/docker/certs.d/$REGISTRY_DOMAIN/ca.crt"
  echo "Restarting Docker..."
  sudo systemctl restart docker
}

case "$DISTRO" in
  ubuntu|debian)
    install_for_debian
    ;;
  arch)
    install_for_arch
    ;;
  *)
    echo "Unsupported distribution: $DISTRO"
    exit 1
    ;;
esac

echo "✅ Root CA installed successfully."

read -p "Do you want to add it to Docker trusted CAs? (y/n): " RESP
if [[ "$RESP" =~ ^[Yy]$ ]]; then
  setup_docker_ca
fi
