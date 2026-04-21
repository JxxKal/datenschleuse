# 🔐 Datenschleuse - Secure File Transfer Gateway

Eine sichere Datenschleuse mit FileBrowser, automatischer Virenprüfung via ClamAV und Cloudflare Tunnel für sichere externe Zugriffe.

## Features

✅ **FileBrowser** - Web-basierte Dateimanagement  
✅ **ClamAV** - Automatische Virenprüfung aller Dateien  
✅ **Cloudflare Tunnel** - Sichere externe Zugriffe via HTTPS  
✅ **MFA Protection** - Multi-Factor Authentication über Cloudflare  
✅ **Large File Support** - Optimiert für große Dateien (bis 10GB)  
✅ **Internal HTTP** - Schnelle Zugriffe im internen Netz  

## Architektur

```
┌─────────────────────────────────────────────────┐
│              Cloudflare (Extern)                 │
│         HTTPS + MFA + Rate Limiting              │
└────────────────────┬────────────────────────────┘
                     │
                     ↓
        ┌────────────────────────┐
        │  Cloudflare Tunnel     │
        │  (cloudflared agent)   │
        └────────┬───────────────┘
                 │
        ┌────────↓──────────────────────────────┐
        │     Datenschleuse Host                 │
        │  ┌──────────────────────────────────┐  │
        │  │  Nginx (Reverse Proxy)           │  │
        │  │  - Port 8000 (Direct Download)   │  │
        │  │  - Large File Optimization       │  │
        │  └────────────┬─────────────────────┘  │
        │               │                         │
        │  ┌────────────↓──────────────────────┐  │
        │  │  FileBrowser (Port 8080)         │  │
        │  │  - Web UI                         │  │
        │  │  - Upload/Download                │  │
        │  │  - File Management                │  │
        │  └────────────┬─────────────────────┘  │
        │               │                         │
        │  ┌────────────↓─────────────────────┐   │
        │  │  ClamAV Container                │   │
        │  │  - Daemon                        │   │
        │  │  - Auto-Scanning                 │   │
        │  │  - Virus Definitions             │   │
        │  └──────────────────────────────────┘   │
        │                                         │
        │  ┌──────────────────────────────────┐  │
        │  │  Shared Volume (/data)           │  │
        │  │  - Uploaded Files                │  │
        │  │  - Scan Logs                     │  │
        │  └──────────────────────────────────┘  │
        └─────────────────────────────────────┘
```

## Installation

### 1. Grundsetup

```bash
chmod +x init.sh
./init.sh
```

### 2. Konfiguration

```bash
cp .env.example .env
# Bearbeite .env mit deinen Einstellungen
nano .env
```

### 3. Docker Compose starten

```bash
docker-compose up -d
```

### 4. FileBrowser initialisieren

Besuche http://localhost:8080 und erstelle einen Admin-Account beim ersten Login.

## Lokale Nutzung (Intern)

### FileBrowser UI
```
http://localhost:8080
```

Features:
- Upload/Download von Dateien
- Ordner-Management
- Datei-Sharing
- Automatische Virenprüfung vor Download

### Direct Download (große Dateien optimiert)
```
http://localhost:8000/direct/myfile.iso
```

Direkter Download ohne FileBrowser UI, optimiert für große Dateien.

### Scan-Status
```
http://localhost:8000/scan-status
```

Live-Log der ClamAV-Scans.

## Cloudflare Tunnel Setup (Extern)

### Voraussetzungen

- Cloudflare Account mit aktiviertem "Zero Trust"
- Domain bei Cloudflare registriert
- `cloudflared` CLI installiert

### Installation

```bash
# 1. cloudflared installieren (Linux)
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# 2. Tunnel authentifizieren
cloudflared tunnel login

# 3. Tunnel erstellen
cloudflared tunnel create datenschleuse

# 4. Tunnel-Config erstellen
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml << 'EOF'
tunnel: datenschleuse
credentials-file: /root/.cloudflared/datenschleuse.json

ingress:
  - hostname: datenschleuse.yourdomain.com
    service: http://localhost:8080
    disableChunkedEncoding: true
  - service: http_status:404
EOF

# 5. DNS-Route erstellen
cloudflared tunnel route dns datenschleuse datenschleuse.yourdomain.com

# 6. Tunnel starten
cloudflared tunnel run datenschleuse
```

### MFA in Cloudflare aktivieren

1. Gehe zu **Zero Trust Dashboard** → **Applications**
2. Erstelle eine neue Self-Hosted App mit:
   - **Subdomain**: datenschleuse
   - **Domain**: yourdomain.com
   - **URL**: http://localhost:8080
   
3. Unter **Application policies** (Rules):
   - Aktiviere "Allow"
   - Wähle deine Identity Provider (Google, Microsoft, etc.)
   - Optional: Spezifische E-Mails/Gruppen beschränken

4. Unter **Additional settings**:
   - HTTP Only: OFF (wird über Tunnel zu HTTPS)
   - Require OIDC: ON

### Tunnel als Service (systemd)

```bash
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

Config speichern unter: `/root/.cloudflared/config.yml`
Credentials unter: `/root/.cloudflared/datenschleuse.json`

## ClamAV Virenscanning

### Wie es funktioniert

1. **Automatisches Scanning**: ClamAV läuft kontinuierlich und scannt neue/geänderte Dateien
2. **Pre-Download Check**: FileBrowser prüft Dateien vor dem Download
3. **Scan Logs**: Alle Scans werden protokolliert in `scan-logs/scans.log`

### Scan-Logs prüfen

```bash
tail -f scan-logs/scans.log
```

### ClamAV manuell testen

```bash
docker exec datenschleuse-clamav clamscan -v /srv/testfile.txt
```

### Virus Definitions aktualisieren

```bash
docker exec datenschleuse-clamav freshclam
```

Oder aktuell halten via `docker pull clamav/clamav:latest`.

## Security Best Practices

### 1. Datei-Upload Beschränkungen
```bash
# Im FileBrowser-UI oder Nginx konfiguriert
- Max Upload: 10GB
- Unterstützte Dateitypen: alle
- ClamAV scannt automatisch
```

### 2. Cloudflare Regeln
```
Empfohlene Policy-Rules:
- Only allow specific IP ranges
- Restrict to working hours
- Require device enrollment (for corporate)
- Allow only from company VPN
```

### 3. Dateien schützen
```bash
# Sensible Dateien in separaten Ordnern lagern
mkdir -p data/confidential data/public

# Im Nginx: Separate Rate Limits
location /confidential {
    limit_req zone=strict;
}

location /public {
    limit_req zone=normal;
}
```

### 4. Regelmäßige Backups
```bash
# Tägliches Backup (cron job)
0 2 * * * tar -czf /backups/datenschleuse-$(date +%Y%m%d).tar.gz /path/to/datenschleuse/data
```

## Monitoring & Logs

### Container-Logs

```bash
# Alle Logs
docker-compose logs -f

# Einzelner Service
docker-compose logs -f filebrowser
docker-compose logs -f clamav
docker-compose logs -f nginx
```

### Health Check

```bash
curl http://localhost:8000/health
```

## Troubleshooting

### ClamAV startet nicht
```bash
# ClamAV braucht Zeit zum Startup
docker-compose logs clamav

# Freshclam updatet die Definitionen
docker exec datenschleuse-clamav freshclam
```

### Große Dateien laden nicht
```bash
# Prüfe Nginx Buffer-Settings (sind optimiert)
# Oder erhöhe Docker memory/disk limits:
docker stats
```

### Cloudflare Tunnel nicht erreichbar
```bash
# Prüfe cloudflared Service
systemctl status cloudflared
journalctl -u cloudflared -f

# Oder starte manuell zum Debuggen
cloudflared tunnel run datenschleuse --loglevel debug
```

### FileBrowser Login funktioniert nicht
```bash
# Setze Admin-Account zurück
docker exec datenschleuse-filebrowser filebrowser -d /database.db users update admin --password newpassword
```

## Performance-Tipps

1. **Große Dateien**: Nutze `/direct/` Endpoint, nicht über FileBrowser UI
2. **Viele Dateien**: Aktiviere Index-Caching in Nginx (ist aktiv)
3. **Hoher Traffic**: Cloudflare Cache auf aggressive setzen
4. **Scanning Overhead**: Passe `SCAN_INTERVAL` an (default: 1h)

## Docker-Befehle

```bash
# Stack starten
docker-compose up -d

# Stack stoppen
docker-compose down

# Logs folgen
docker-compose logs -f

# Container neu bauen
docker-compose up -d --build

# Nur einen Service neu starten
docker-compose restart filebrowser

# Volume löschen (ACHTUNG: Dateienverlust!)
docker-compose down -v
```

## Umgebungsvariablen

Siehe `.env` Datei:
- `FB_ADMIN_USER` - FileBrowser Admin Username
- `FB_ADMIN_PASSWORD` - FileBrowser Admin Password
- `CF_TUNNEL_NAME` - Name für Cloudflare Tunnel
- `CF_TUNNEL_URL` - Externe Tunnel-URL
- `CLAMAV_MAX_FILESIZE` - Max Dateigröße für Scanning
- `SCAN_INTERVAL` - Scan-Intervall in Sekunden

## License

Private Use - Nicht für kommerziellen Einsatz ohne Anpassung.

## Support

Bei Problemen:
1. Logs prüfen: `docker-compose logs`
2. Services neu starten: `docker-compose restart`
3. Container vollständig neu bauen: `docker-compose down && docker-compose up -d`

---

Made with 🔐 for secure file transfers
