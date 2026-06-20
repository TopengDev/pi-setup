---
name: agent-browser
description: Automates browser interactions for web testing, form filling, screenshots, and data extraction via Playwright. Use when the user needs to navigate websites, interact with web pages, fill forms, take screenshots, test web applications, or extract information from web pages.
metadata:
  filePattern: "**/playwright*,**/browser*,**/*.spec.ts,**/*.spec.js"
  bashPattern: "agent-browser|playwright|npx playwright"
allowed-tools: Bash, Read, Write
---

# /agent-browser — Playwright-based browser automation

All browser interaction goes through **Playwright** (Chromium by default). Unlike the qutebrowser CDP approach in chilldawg-setup, pi-setup uses Playwright for cross-platform browser automation that works on Windows and Linux alike.

## Architecture

```
Claude (skill) → Playwright CLI / inline scripts → Chromium/Firefox/WebKit
```

## Prerequisites

Playwright must be installed in the project or globally:

```bash
# Install in project
npm install -D @playwright/test
npx playwright install chromium

# Or globally
npm install -g playwright
playwright install chromium
```

Verify: `npx playwright --version`

## Core operations

### Navigate

```bash
# Open a URL and take a screenshot
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('URL_HERE');
  await page.screenshot({ path: '/tmp/screenshot.png', fullPage: true });
  await browser.close();
})();
"
```

### Snapshot (page state / HTML)

```bash
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('URL_HERE');
  console.log(await page.content());
  await browser.close();
})();
"
```

### Click

```bash
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();
  await page.goto('URL_HERE');
  await page.click('SELECTOR_HERE');
  await page.screenshot({ path: '/tmp/after-click.png' });
  await browser.close();
})();
"
```

### Fill form

```bash
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();
  await page.goto('URL_HERE');
  await page.fill('input[name=email]', 'test@example.com');
  await page.fill('input[name=password]', 'password');
  await page.click('button[type=submit]');
  await page.screenshot({ path: '/tmp/after-fill.png' });
  await browser.close();
})();
"
```

### Console errors

```bash
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  const errors = [];
  page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', err => errors.push(err.message));
  await page.goto('URL_HERE');
  await page.waitForTimeout(2000);
  console.log(JSON.stringify(errors, null, 2));
  await browser.close();
})();
"
```

### Network requests

```bash
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  const requests = [];
  page.on('request', req => requests.push({ url: req.url(), method: req.method() }));
  page.on('response', res => {
    const r = requests.find(r => r.url === res.url());
    if (r) r.status = res.status();
  });
  await page.goto('URL_HERE', { waitUntil: 'networkidle' });
  console.log(JSON.stringify(requests.slice(0, 30), null, 2));
  await browser.close();
})();
"
```

## Multi-step session (recommended for complex flows)

For flows that need state (auth → navigate → interact), write a temp script file and run it:

```bash
cat > /tmp/pw-session.js << 'EOF'
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: false, slowMo: 100 });
  const context = await browser.newContext();
  const page = await context.newPage();

  // Step 1: Login
  await page.goto('http://localhost:3000/login');
  await page.fill('#email', 'test@example.com');
  await page.fill('#password', 'password');
  await page.click('button[type=submit]');
  await page.waitForURL('**/dashboard');
  await page.screenshot({ path: '/tmp/step1-login.png' });

  // Step 2: Navigate to feature
  await page.click('text=Feature');
  await page.screenshot({ path: '/tmp/step2-feature.png' });

  await browser.close();
})();
EOF
node /tmp/pw-session.js
```

## Headless vs headed

- **headless: true** — fast, no visible window, good for screenshots and data extraction
- **headless: false** — shows browser window, useful for debugging interactive flows
- Add **`slowMo: 100`** (ms) to slow down actions and observe what's happening

## Screenshots

Always save screenshots to `/tmp/` during testing. After the test, report their paths so evidence is clear. Name screenshots descriptively: `/tmp/step1-login.png`, `/tmp/after-submit.png`, `/tmp/error-state.png`.

## Waiting strategies

```js
await page.waitForURL('**/dashboard');           // wait for URL change
await page.waitForSelector('.toast-message');     // wait for element
await page.waitForTimeout(1000);                  // fixed delay (use sparingly)
await page.waitForLoadState('networkidle');       // wait for network quiet
```

## Error handling pattern

```js
try {
  await page.click('button.submit', { timeout: 5000 });
} catch (e) {
  await page.screenshot({ path: '/tmp/error.png' });
  console.error('Action failed:', e.message);
}
```

## Using existing Playwright tests

If the project has `playwright.config.ts` + `*.spec.ts` tests:

```bash
npx playwright test                          # run all tests
npx playwright test --project=chromium      # specific browser
npx playwright test auth.spec.ts            # specific file
npx playwright test --headed                # show browser
npx playwright show-report                  # view HTML report
```

## Cleanup

Playwright browsers are launched and closed per-session. No persistent browser process to kill. If a script hung and left a process, kill it with:

```bash
pkill -f chromium || true
pkill -f playwright || true
```

## Troubleshooting

| Issue | Fix |
|---|---|
| `Cannot find module 'playwright'` | Run `npm install -D @playwright/test` in project root |
| `Executable doesn't exist` | Run `npx playwright install chromium` |
| Timeout on element | Increase timeout: `{ timeout: 10000 }` or add a `waitForSelector` |
| Flaky on slow pages | Use `waitUntil: 'networkidle'` in `goto()` |
| Screenshots blank | Use `headless: false` + `slowMo` to debug |
