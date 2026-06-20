---
name: ui-test
description: Automated UI testing via Playwright — exhaustively tests every interactive element on every page for every role, with screenshots and functional verification. Quick mode (page crawl + visibility) and full mode (exhaustive element testing + flows + responsive).
allowed-tools: Bash, Read, Glob, Grep, Write, Skill
---

# /ui-test Skill — Automated UI Testing via Playwright

Exhaustive UI test runner using Playwright. Covers every interactive element on every page for every role (unauthenticated, regular user, admin). Quick mode crawls pages and checks visibility; full mode tests every element + flows + responsive breakpoints.

All browser interaction uses **Playwright**. Use the `/agent-browser` skill for one-off automation snippets; `/ui-test` is for full structured coverage passes.

═══════════════════════════════════════════════════════════════════════════
## NON-NEGOTIABLE RULES

1. **All browser interaction goes through Playwright.** Use `npx playwright` or inline Node scripts. Never use curl to test visual behavior.
2. **Screenshot EVERY step.** Screenshots are evidence. Name them `<step>-<page>-<role>.png` and save to `/tmp/ui-test/`.
3. **Fresh browser context per role** — use `browser.newContext()` to reset state between roles.
4. **Always clean up.** Close browsers when done or on failure.
5. **Test ALL roles** — unauthenticated, regular user, admin (at minimum). Role-specific UI must be verified from that role's session.
═══════════════════════════════════════════════════════════════════════════

## Modes

```
/ui-test                     # full mode — exhaustive
/ui-test quick               # quick mode — page crawl + visibility only
/ui-test <url>               # target specific URL instead of localhost:3000
```

## Phase 0 — Environment check

```bash
# Verify playwright installed
npx playwright --version 2>/dev/null || echo "MISSING — npm install -D @playwright/test"
npx playwright install chromium 2>/dev/null || true

# Verify dev server is running
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302" \
  && echo "server UP" || echo "server DOWN — start dev server first"
```

## Phase 1 — Page discovery

```bash
node -e "
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto('http://localhost:3000');
  // Extract all internal links
  const links = await page.evaluate(() =>
    [...document.querySelectorAll('a[href]')]
      .map(a => a.href)
      .filter(h => h.startsWith(window.location.origin))
  );
  console.log(JSON.stringify([...new Set(links)], null, 2));
  await browser.close();
})();
"
```

## Phase 2 — Per-page, per-role testing

For each page × role combination:

```js
const { chromium } = require('playwright');
const fs = require('fs');

(async () => {
  const browser = await chromium.launch({ headless: true });
  fs.mkdirSync('/tmp/ui-test', { recursive: true });

  const roles = [
    { name: 'anon', setup: async (page) => {} },
    { name: 'user', setup: async (page) => {
      await page.goto('http://localhost:3000/login');
      await page.fill('#email', process.env.TEST_EMAIL || 'user@test.com');
      await page.fill('#password', process.env.TEST_PASS || 'password');
      await page.click('button[type=submit]');
      await page.waitForURL('**/dashboard', { timeout: 5000 }).catch(() => {});
    }},
  ];

  const pages = ['/', '/dashboard', '/settings']; // discover via Phase 1

  for (const role of roles) {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    await role.setup(page);

    for (const route of pages) {
      await page.goto('http://localhost:3000' + route);
      await page.waitForLoadState('networkidle').catch(() => {});

      // Screenshot
      await page.screenshot({
        path: '/tmp/ui-test/' + role.name + '-' + route.replace(/\//g, '_') + '.png',
        fullPage: true
      });

      // Check for JS errors
      const errors = [];
      page.on('pageerror', err => errors.push(err.message));

      // Check interactive elements are visible
      const buttons = await page.$$('button:visible');
      const inputs = await page.$$('input:visible, textarea:visible, select:visible');
      console.log(`${role.name} ${route}: ${buttons.length} buttons, ${inputs.length} inputs${errors.length ? ', ERRORS: ' + errors.join('; ') : ''}`);
    }

    await ctx.close();
  }

  await browser.close();
})();
```

## Full mode — element-level testing

In full mode, for each visible interactive element:

1. **Buttons** — click each, screenshot before/after, check for error state
2. **Forms** — fill with valid data, submit, verify success/error response
3. **Navigation** — click nav links, verify URL changes, screenshot each destination
4. **Modals/dialogs** — open + close, verify backdrop, verify close button
5. **Responsive** — re-test key pages at 375px (mobile), 768px (tablet), 1280px (desktop)

```js
// Responsive check
const viewports = [
  { name: 'mobile', width: 375, height: 812 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1280, height: 800 },
];
for (const vp of viewports) {
  await page.setViewportSize(vp);
  await page.screenshot({ path: `/tmp/ui-test/${vp.name}-home.png`, fullPage: true });
}
```

## Evidence collection

At the end of each run, list all screenshots taken:

```bash
ls -la /tmp/ui-test/*.png 2>/dev/null && echo "--- screenshots saved" || echo "no screenshots found"
```

Report format:
```
ROLE: anon
  / — PASS (screenshot: /tmp/ui-test/anon-_.png)
  /dashboard — REDIRECT to /login (expected for anon)
  /settings — REDIRECT to /login (expected for anon)

ROLE: user
  / — PASS (3 buttons, 0 errors, screenshot: /tmp/ui-test/user-_.png)
  /dashboard — PASS (7 buttons, 2 inputs, 0 errors)
  /settings — FAIL — JS error: Cannot read properties of undefined
```

## Cleanup

```bash
pkill -f chromium 2>/dev/null || true
rm -rf /tmp/ui-test/
```
