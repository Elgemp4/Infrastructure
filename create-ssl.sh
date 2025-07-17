#!/bin/bash

set -e

DOMAIN="startech.be"
WILDCARD="*.$DOMAIN"
SSL_DIR="./data/nginx/ssl"
CA_KEY=".ssl/myCA.key"
CA_CERT=".ssl/myCA.pem"
CA_CERT_DER=".ssl/rootCA.crt"
CERT_KEY="$SSL_DIR/privkey.pem"
CERT_CRT="$SSL_DIR/fullchain.pem"
EXT_FILE=".ssl/cert.ext"

echo "🔧 Creating SSL directory..."
mkdir -p "$SSL_DIR"

echo "🔐 Generating CA key and certificate..."
openssl genrsa -out "$CA_KEY" 4096
openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days 3650 -out "$CA_CERT" \
  -subj "/C=BE/ST=Brussels/L=Brussels/O=StartechLocal/CN=StartechLocalRootCA"

echo "🔐 Generating wildcard certificate key..."
openssl genrsa -out "$CERT_KEY" 2048

echo "📜 Creating certificate signing request (CSR)..."
openssl req -new -key "$CERT_KEY" -out cert.csr \
  -subj "/C=BE/ST=Brussels/L=Brussels/O=StartechLocal/CN=$WILDCARD"

echo "📄 Creating extension file..."
cat > "$EXT_FILE" <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = *.$DOMAIN
EOF

echo "🖋️ Signing certificate with local CA..."
openssl x509 -req -in cert.csr -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial \
  -out "$CERT_CRT" -days 825 -sha256 -extfile "$EXT_FILE"

echo "🧼 Cleaning up CSR and ext file..."
rm cert.csr "$EXT_FILE"

echo "📤 Exporting root CA as .crt..."
openssl x509 -in "$CA_CERT" -inform PEM -out "$CA_CERT_DER"

echo "📁 Installing CA for Docker..."
mkdir -p "/etc/docker/certs.d/registry.$DOMAIN/"
cp "$CA_CERT_DER" "/etc/docker/certs.d/registry.$DOMAIN/"

echo "📁 Installing CA into system trust store..."
mkdir -p /usr/share/ca-certificates/extra/
cp "$CA_CERT_DER" /usr/share/ca-certificates/extra/

echo "🛠️ Reconfiguring CA certificates..."
echo "extra/rootCA.crt" >> /etc/ca-certificates.conf
dpkg-reconfigure -f noninteractive ca-certificates

echo "🔄 Restarting Docker..."
systemctl restart docker

echo "✅ All done. Certificates are in $SSL_DIR"
