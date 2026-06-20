---
name: cloudflare-dns
description: Manage DNS records on Cloudflare for {{ORG_DOMAIN}}. Supports creating *-landing-page.{{ORG_DOMAIN}} A records, deleting records by subdomain, and listing all landing page records. Use when the user says /cloudflare-dns.
argument-hint: <create|delete|list> [subdomain-name]
allowed-tools: Bash, Read
---

## Cloudflare DNS Management for {{ORG_DOMAIN}}

Manage `*-landing-page.{{ORG_DOMAIN}}` DNS records via the Cloudflare API.

### Configuration

- **Zone ID:** `${CLOUDFLARE_ZONE_ID}`
- **API Token:** `${CLOUDFLARE_API_TOKEN}`
- **Domain:** `{{ORG_DOMAIN}}`
- **Default IP:** `$VPS_HOST` (sourced from `{{SECRETS_FILE}}`)
- **Proxied:** `true`

### Parse Arguments

Parse `$ARGUMENTS` to determine the command and optional name:
- First word = command (`create`, `delete`, or `list`)
- Second word (if present) = subdomain name (without `-landing-page.{{ORG_DOMAIN}}` suffix)
- If no arguments or unrecognized command, show usage help

### Commands

#### LIST (`/cloudflare-dns list`)

List all `*-landing-page.{{ORG_DOMAIN}}` records.

Run:
```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&per_page=100&name=contains:landing-page" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json"
```

Parse the JSON response. For each record, display a table with:
- Subdomain name
- IP address (content)
- Proxied status
- Record ID

If no records found, say so.

#### CREATE (`/cloudflare-dns create [name]`)

Create an A record for `{name}-landing-page.{{ORG_DOMAIN}}` pointing to `$VPS_HOST` with proxy enabled.

1. If no name is provided, generate a random two-word name in `adjective-noun` format. Use this bash one-liner to generate it:
```bash
python3 -c "
import random
adjectives = ['sunny','blue','swift','calm','bold','bright','cool','dark','deep','fair','fast','gold','grand','green','keen','kind','lost','new','old','pale','pure','rare','red','rich','safe','soft','tall','thin','vast','warm','wild','wise']
nouns = ['ocean','river','mountain','forest','meadow','valley','stone','cloud','flame','frost','storm','dawn','dusk','hawk','moon','peak','pine','reef','sage','star','tide','vine','wave','wolf','bear','crow','deer','dove','eagle','elk','fox','lake']
print(f'{random.choice(adjectives)}-{random.choice(nouns)}')
"
```

2. Create the DNS record:
```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"NAME-landing-page.{{ORG_DOMAIN}}\",\"content\":\"${VPS_HOST}\",\"ttl\":1,\"proxied\":true}"
```
Replace `NAME` with the actual subdomain name.

3. Parse the response and display:
   - **Subdomain:** `{name}-landing-page.{{ORG_DOMAIN}}`
   - **IP:** `$VPS_HOST`
   - **Proxied:** Yes
   - **Record ID:** from response
   - **Status:** Created successfully

If the API returns an error (e.g., duplicate record), display the error message.

#### DELETE (`/cloudflare-dns delete <name>`)

Delete a DNS record by subdomain name.

1. A name **must** be provided. If missing, tell the user to provide one.

2. First, find the record ID by searching for the full subdomain:
```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&name=NAME-landing-page.{{ORG_DOMAIN}}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json"
```
Replace `NAME` with the provided subdomain name.

3. If no record is found, tell the user.

4. If found, delete it using the record ID:
```bash
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/RECORD_ID" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json"
```

5. Confirm deletion with the subdomain name and record ID.

### Usage Help

If no valid command is recognized, display:
```
Cloudflare DNS Manager for {{ORG_DOMAIN}}
--------------------------------------
Usage: /cloudflare-dns <command> [name]

Commands:
  create [name]  - Create {name}-landing-page.{{ORG_DOMAIN}} A record (random name if omitted)
  delete <name>  - Delete {name}-landing-page.{{ORG_DOMAIN}} A record
  list           - List all *-landing-page.{{ORG_DOMAIN}} records
```

### Rules

- Always use the full subdomain format: `{name}-landing-page.{{ORG_DOMAIN}}`
- The user only provides the prefix (e.g., `sunny-ocean`), not the full domain
- All A records point to `$VPS_HOST` with proxy enabled
- Parse Cloudflare API JSON responses properly and handle errors gracefully
- Display results in a clean, readable format
