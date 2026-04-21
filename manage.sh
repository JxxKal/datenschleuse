#!/bin/bash

# Datenschleuse Management Script

case "$1" in
  "start")
    echo "Starting Datenschleuse..."
    docker-compose up -d
    echo "✓ Stack started"
    echo "Local access: http://localhost:8080"
    ;;

  "stop")
    echo "Stopping Datenschleuse..."
    docker-compose down
    echo "✓ Stack stopped"
    ;;

  "restart")
    echo "Restarting Datenschleuse..."
    docker-compose restart
    echo "✓ Stack restarted"
    ;;

  "logs")
    docker-compose logs -f "${2:-}"
    ;;

  "status")
    echo "=== Datenschleuse Status ==="
    docker-compose ps
    echo ""
    echo "=== Health Checks ==="
    curl -s http://localhost:8000/health && echo "✓ Nginx healthy"
    docker exec datenschleuse-clamav clamscan --version > /dev/null && echo "✓ ClamAV healthy"
    ;;

  "update-virus-defs")
    echo "Updating ClamAV virus definitions..."
    docker exec datenschleuse-clamav freshclam
    echo "✓ Virus definitions updated"
    ;;

  "scan-logs")
    tail -f scan-logs/scans.log
    ;;

  "backup")
    BACKUP_DIR="${2:-.}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/datenschleuse_backup_$TIMESTAMP.tar.gz"
    echo "Creating backup to $BACKUP_FILE..."
    tar -czf "$BACKUP_FILE" \
      data/ \
      filebrowser-db.db \
      filebrowser-config.json \
      .env \
      scan-logs/
    echo "✓ Backup created: $BACKUP_FILE"
    ls -lh "$BACKUP_FILE"
    ;;

  "restore")
    BACKUP_FILE="$2"
    if [ -z "$BACKUP_FILE" ]; then
      echo "Usage: $0 restore <backup-file>"
      exit 1
    fi
    echo "Restoring from $BACKUP_FILE..."
    docker-compose stop
    tar -xzf "$BACKUP_FILE"
    docker-compose up -d
    echo "✓ Restore complete"
    ;;

  "reset-admin")
    echo "Resetting FileBrowser admin password..."
    NEW_PASS="${2:-changeme}"
    docker exec datenschleuse-filebrowser filebrowser -d /database.db users update admin --password "$NEW_PASS"
    echo "✓ Admin password reset to: $NEW_PASS"
    echo "⚠️ Change this immediately after login!"
    ;;

  "test-scan")
    echo "Testing ClamAV with EICAR test file..."
    # EICAR test string (harmless, recognized by all AV engines)
    EICAR='X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'
    echo "$EICAR" > data/eicar.txt
    docker exec datenschleuse-clamav clamscan -v data/eicar.txt
    rm -f data/eicar.txt
    ;;

  "cloudflared-setup")
    echo "=== Cloudflare Tunnel Setup Guide ==="
    echo ""
    echo "1. Install cloudflared:"
    echo "   wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb"
    echo "   sudo dpkg -i cloudflared-linux-amd64.deb"
    echo ""
    echo "2. Authenticate:"
    echo "   cloudflared tunnel login"
    echo ""
    echo "3. Create tunnel:"
    echo "   cloudflared tunnel create datenschleuse"
    echo ""
    echo "4. Run tunnel:"
    echo "   cloudflared tunnel run datenschleuse"
    echo ""
    echo "5. Configure in Cloudflare Zero Trust dashboard:"
    echo "   - Add application with this URL: http://localhost:8080"
    echo "   - Enable MFA/authentication"
    echo ""
    ;;

  "help")
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start              Start all services"
    echo "  stop               Stop all services"
    echo "  restart            Restart all services"
    echo "  status             Show services status and health checks"
    echo "  logs [service]     Show logs (optional: specify service)"
    echo "  update-virus-defs  Update ClamAV virus definitions"
    echo "  scan-logs          Follow scan log in real-time"
    echo "  backup [dir]       Create backup tarball"
    echo "  restore <file>     Restore from backup"
    echo "  reset-admin [pwd]  Reset FileBrowser admin password"
    echo "  test-scan          Test ClamAV with EICAR test file"
    echo "  cloudflared-setup  Show Cloudflare Tunnel setup instructions"
    echo "  help               Show this help message"
    echo ""
    ;;

  *)
    echo "Unknown command: $1"
    echo "Run '$0 help' for usage information"
    exit 1
    ;;
esac
