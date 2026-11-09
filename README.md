# EarnApp Linker

One-shot installer for a fresh Ubuntu server (20.04 / 22.04 / 24.04).

Serves a simple web page that lets you paste EarnApp claim links / device IDs and open them one by one (or in auto mode) so each device gets linked to the EarnApp account signed in on that browser.

## Quick start

On a fresh Ubuntu server, run as root:

```bash
curl -fsSL https://raw.githubusercontent.com/rezanb111/earnapp-linker/main/setup-ubuntu.sh | bash
```

Or download and run:

```bash
wget -O setup-ubuntu.sh https://raw.githubusercontent.com/rezanb111/earnapp-linker/main/setup-ubuntu.sh
bash setup-ubuntu.sh
```

## Options (environment variables)

| Variable   | Default              | Description |
|-----------|----------------------|-------------|
| `DOMAIN`  | `earn.v2rei.surf`    | Domain to serve. Set `DOMAIN=""` to serve on the server IP only. |
| `EMAIL`   | (empty)              | Email for Let's Encrypt expiry notices (optional). |
| `FORCE_SSL` | `0`                | Set to `1` to request the certificate even if DNS does not point here yet. |

### Examples

Serve on a custom domain with email:

```bash
DOMAIN=linker.example.com EMAIL=you@example.com bash setup-ubuntu.sh
```

Serve only on the server IP (no HTTPS):

```bash
DOMAIN="" bash setup-ubuntu.sh
```

Force certificate request:

```bash
FORCE_SSL=1 bash setup-ubuntu.sh
```

## What the script does

1. Installs nginx + certbot
2. Writes the EarnApp Linker HTML page to `/var/www/earnapp-linker`
3. Configures nginx
4. Opens ports 80/443 in ufw if active
5. Requests a free Let's Encrypt certificate when the domain already points to this server (or when `FORCE_SSL=1`)

## Notes

- Sign in to earnapp.com in the **same browser** before opening claim links.
- If EarnApp says "device not found", wait a few minutes for the device container to start, then open the link again.
- Pop-up blockers can stop auto mode; allow pop-ups for the site or use the big button manually.
