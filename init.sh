#!/bin/bash

set -e

echo "=== Datenschleuse Initialization ==="

# Create directories
mkdir -p data scan-logs

# Set permissions
chmod 755 data
chmod 755 scan-logs

# Copy .env file if not exists
if [ ! -f .env ]; then
    cp .env.example .env
    echo "✓ Created .env file - please edit it with your credentials"
fi

# Create FileBrowser database
if [ ! -f filebrowser-db.db ]; then
    echo "✓ FileBrowser database will be created on first run"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Edit .env with your admin credentials"
echo "2. Run: docker-compose up -d"
echo "3. Access locally: http://localhost:8080"
echo "4. Install Cloudflare Tunnel: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/"
echo "5. Configure tunnel in your Cloudflare dashboard"
echo ""
echo "=== Cloudflare Tunnel Setup ==="
echo "cloudflared tunnel create datenschleuse"
echo "cloudflared tunnel route dns datenschleuse yourdomain.com"
echo "cloudflared tunnel run datenschleuse --url http://localhost:8080 --http2-origin"
echo ""
echo "Then add these to your Cloudflare dashboard for MFA protection:"
echo "- Enable 'Require authentication' with your identity provider"
echo "- Set up rules for IP restrictions or additional headers"
echo ""
