# 🌐 Cloudflare Tunnel Integration

Du hast bereits einen Cloudflare Tunnel! Diese Anleitung zeigt, wie du die Datenschleuse damit verbindest.

## Tunnel-Info auslesen

Zuerst finde heraus, welcher Tunnel vorhanden ist:

```bash
# Wenn cloudflared installiert ist
cloudflared tunnel list

# Oder in Cloudflare Dashboard:
# Zero Trust → Networks → Tunnels
```

Notiere den Tunnel-Namen (z.B. `datenschleuse`, `main-tunnel`, etc.)

## Integration in bestehenden Tunnel

Es gibt zwei Möglichkeiten:

### Option 1: Separate Datenschleuse-Subdomain (empfohlen)

**Konfiguration**: `~/.cloudflared/config.yml`

```yaml
tunnel: datenschleuse  # oder dein bestehender Tunnel-Name
credentials-file: /root/.cloudflared/[tunnel-uuid].json

ingress:
  # Bestehende Einträge oben lassen (falls vorhanden)
  
  # Neu hinzufügen für Datenschleuse:
  - hostname: datenschleuse.yourdomain.com
    service: http://localhost:8080
    disableChunkedEncoding: true
    
  # Großer Upload/Download (optional)
  - hostname: datenschleuse.yourdomain.com
    path: /direct/*
    service: http://localhost:8000
    
  # Fallback für andere Seiten
  - service: http_status:404
```

**DNS eintragen** (im Cloudflare Dashboard):
```
Name: datenschleuse
Type: CNAME
Content: [tunnel-name].cfargotunnel.com
Proxy Status: Proxied
```

### Option 2: Unter bestehender Domain integrieren

Falls du z.B. `mycompany.com` hast und die Datenschleuse als Subpath einbauen möchtest:

```yaml
tunnel: main-tunnel
credentials-file: /root/.cloudflared/[uuid].json

ingress:
  # Bestehend
  - hostname: mycompany.com
    path: /blog/*
    service: http://localhost:3000
    
  # Neu: Datenschleuse
  - hostname: mycompany.com
    path: /datenschleuse*
    service: http://localhost:8080
    
  - hostname: mycompany.com
    path: /datenschleuse-direct/*
    service: http://localhost:8000
    
  - service: http_status:404
```

**Wichtig**: Die Reihenfolge in `ingress` ist entscheidend - spezifischere Pfade OBEN!

## Konfiguration mit MFA in Cloudflare

1. **Gehe zu** Zero Trust Dashboard → **Applications** → **Self-Hosted**
2. **Erstelle neue App**:
   - **Subdomain**: `datenschleuse` (oder Pfad)
   - **Domain**: `yourdomain.com`
   - **Application type**: Web
   - **URL**: `http://localhost:8080`

3. **Policies setzen** (Authentication):
   ```
   Allow
   ├─ Emails matching
   │  └─ *@yourdomain.com
   │
   └─ AND
   └─ Authentication methods
      └─ [Wähle deine Provider: Google, Azure, etc.]
   ```

4. **Optional: Zusätzliche Richtlinien**:
   ```
   - Require device enrollment
   - Require country: DE
   - Block if no device posture
   - Require mTLS certificate
   ```

## Tunnel neu starten

Nach Änderungen:

```bash
# Tunnel neu starten
cloudflared tunnel run datenschleuse

# Oder wenn als Service:
sudo systemctl restart cloudflared
```

## Health Check

```bash
# Prüfe ob Tunnel aktiv
cloudflared tunnel info datenschleuse

# Oder im Browser:
curl https://datenschleuse.yourdomain.com/health
# Sollte "OK" zurückgeben
```

## Logging

```bash
# Live tunnel logs
cloudflared tunnel logs datenschleuse

# System logs (wenn als Service)
sudo journalctl -u cloudflared -f
```

## Performance-Tipps für Cloudflare

### Cache für häufige Downloads
```
In Cloudflare Dashboard → Caching Rules:

If: hostname = datenschleuse.yourdomain.com AND path contains /direct/
Then: Cache Level = Standard / Ignore Query String = OFF
TTL = 1 hour
```

### Rate Limiting (gegen Brute Force)
```
In Cloudflare Dashboard → Security → Rate Limiting:

- Path: datenschleuse.yourdomain.com/api/*
- Requests: 100 per 10 seconds
- Action: Challenge
```

### WAF Rules
```
Security Rules → Create rule:

(cf.threat_score > 30) OR (cf.bot_management.verified_bot_category = "Bad Bot")
→ Block
```

## Troubleshooting

### Tunnel zeigt Error "no healthy origins"
```bash
# Prüfe ob Services laufen
docker-compose ps

# Prüfe Firewall
sudo iptables -L -n | grep 8080
sudo iptables -L -n | grep 8000

# Starte alles neu
docker-compose restart
sudo systemctl restart cloudflared
```

### Uploads funktionieren nicht über Cloudflare
```yaml
# In config.yml - wichtig für große Uploads:
ingress:
  - hostname: datenschleuse.yourdomain.com
    service: http://localhost:8080
    disableChunkedEncoding: true  # ← Verhindert Chunk-Probleme
```

### MFA wird umgangen
```bash
# Prüfe in Cloudflare Dashboard:
# Zero Trust → Applications → datenschleuse → [Settings]

# Überprüfe:
- [ ] Application is enabled
- [ ] Policy exists and is correct
- [ ] Identity provider is connected
```

### Cloudflare cached alte Seite
```bash
# Purge Cache in Dashboard:
# Caching → Purge Cache

# Oder per API:
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  --data '{"files":["https://datenschleuse.yourdomain.com/*"]}'
```

## Backup von Tunnel-Credentials

```bash
# Tunnel-Credentials sichern
cp ~/.cloudflared/[uuid].json backup/tunnel-credentials.json.backup

# Config sichern
cp ~/.cloudflared/config.yml backup/cloudflared-config.yml.backup
```

**WICHTIG**: Diese Dateien sind sensitiv - nicht in Git/öffentlich zugänglich machen!

## Monitore & Alerts in Cloudflare

1. **Gehe zu**: Zero Trust → Logs → Gateway
2. **Filter nach**:
   - `ClientRequestHost = datenschleuse.yourdomain.com`
   - `ClientCountry != DE` (optional)
   - `Status = 403` (Auth failures)

3. **Erstelle Alert**:
   - Notification → Add notification
   - Event: High Auth failure rate
   - Threshold: >10 failures in 5 min

---

Deine bestehende Tunnel-Konfiguration wird nicht unterbrochen! Die Datenschleuse wird einfach als neuer Eintrag in der `ingress` Liste hinzugefügt.
