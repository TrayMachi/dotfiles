---
name: expect
description: "Use when editing .tsx/.jsx/.css/.html, React components, pages, routes, forms, styles, or layouts. Also when asked to test, verify, validate, QA, find bugs, check for issues, or debug browser behavior."
---

# Expect

You test code changes in a real browser to find bugs, verify correctness, audit accessibility, and measure performance before claiming work is complete.

**If you haven't used the expect MCP tools in this conversation, you cannot claim the change works.** NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.

Always use the expect MCP tools instead of raw browser tools (Playwright MCP, chrome tools, browser MCP), unless the user explicitly overrides your decision.

You have two documented failure patterns. First, **happy-path seduction**: the page loads, the primary flow works, and you stop — the easy 80% passes and the bugs hide in the untested 20%. Second, **soft failures**: a check fails but the page "mostly works," so you report it as passing, hiding the bug from the developer.

## Delegate Verification to a Subagent

Browser verification is a separate concern from writing code. When you have a subagent or background task capability (e.g. `Task` tool, sub-task, background agent), delegate the entire verification workflow to it. The subagent acts as the **quality gate** — you made code changes, it verifies they actually work.

**How to delegate:** Launch a subagent with a prompt that includes:
- The URL to test against and how to start the dev server if needed
- What changed (files, components, routes) and what behavior to verify
- The primary flow to test first, then adjacent flows to cover
- Whether data needs to be seeded (if the page might be empty)
- Which UI quality checks apply (responsive, dark mode, cross-browser)

The subagent handles the full lifecycle (`open` → interact → audit → `close`) and returns a pass/fail summary with evidence. This frees you to continue working while verification runs in parallel.

**When to delegate:**
- After finishing a code change that touches UI, forms, routes, styles, or layouts
- When the user asks to test, QA, validate, or verify something
- During fix → re-verify loops (delegate each re-verification pass)

**When to run inline instead:** If subagent delegation isn't available in your environment, or for a single quick screenshot check, run the tools directly. But prefer delegation when possible — it's faster for the user and avoids blocking the conversation.

## Setup Check

The expect MCP server must be configured. If the `open` tool is not available, install it:

```bash
npx expect-cli@latest mcp
```

Or add it to your MCP config (`opencode.json`):

```json
{
  "mcp": {
    "expect": {
      "type": "local",
      "command": ["npx", "-y", "expect-cli@latest", "mcp"],
      "enabled": true
    }
  }
}
```

## MCP Tools

These are the ONLY tools you should use for browser interactions. Do NOT use any other browser automation tools.

1. **open** — Launch a browser and navigate to a URL. Pass `cookies=true` to reuse local browser cookies. Pass `browser='webkit'` or `browser='firefox'` for cross-browser testing. Pass `cdp='ws://...'` to connect to an existing Chrome instance.
2. **playwright** — Execute Playwright code in Node.js context. Globals: `page`, `context`, `browser`, `ref` (snapshot ref ID → Locator). Use `return` to collect data — response is JSON: `{ result: <value>, resultFile: '<path>' }`. The result file persists until `close` so you can read or grep it later. Batch multiple actions AND data collection into a single `playwright` call. Set `snapshotAfter=true` to auto-snapshot after DOM-changing actions (response adds `snapshot` alongside result).
3. **screenshot** — Capture page state. Modes: `snapshot` (ARIA accessibility tree with element refs — preferred), `screenshot` (PNG image), `annotated` (PNG with numbered labels on interactive elements). Pass `fullPage=true` for full scrollable content.
4. **console_logs** — Get browser console messages. Filter by type (`error`, `warning`, `log`). Pass `clear=true` to reset after reading.
5. **network_requests** — Get captured HTTP requests with automatic issue detection (4xx/5xx failures, duplicate requests, mixed content). Filter by method, URL, or resource type.
6. **performance_metrics** — Collect Core Web Vitals (FCP, LCP, CLS, INP), navigation timing (TTFB), Long Animation Frames (LoAF) with script attribution, and resource breakdown.
7. **accessibility_audit** — Run a WCAG accessibility audit using axe-core + IBM Equal Access. Returns violations sorted by severity with CSS selectors, HTML context, and fix guidance.
8. **close** — Close the browser and end the session. Always call this when done — it flushes the session video and screenshots to disk.

## What to Test

Scan the changed files and diff to identify what behavior changed and which user flows to test. Group related files into concrete flows — a flow is an end-to-end path with a clear entry point, user action, and observable outcome.

**Coverage rules — minimum bar:** Every changed route, page, form, mutation, API interaction, shared component, or shared utility that influences runtime behavior must be covered by at least one tested flow.

- When shared code changes, test multiple consumers, not just one happy path.
- If a diff changes validation, permissions, loading/empty/error states, include the matching negative or edge-case path.
- If a diff changes persistence or mutations, verify the before/after state and one durability check (refresh, revisit, or back-navigation).
- If multiple files implement one feature, test the full user journey end-to-end instead of isolated clicks.

**Scope strategy:**
- For small/focused changes: test the primary flow first, then 2-3 adjacent flows that exercise the same code paths.
- For broad changes touching shared code: test 3-5 flows, prioritizing paths that share components or data with the changed files. If shared layouts or utilities changed, verify multiple pages.
- For branch-level reviews: aim for 5-8 total flows. Each changed route, component, or data path should get its own verification. Prioritize security and authorization edge cases. Do not stop after the happy path passes.

## Execution Strategy

`open` → interact with `playwright` and `screenshot` → observe with `console_logs` and `network_requests` → audit with `accessibility_audit` and `performance_metrics` → `close`. One browser session at a time.

- First master the primary flow the developer asked for. Verify it thoroughly before moving on.
- For each flow, test both the happy path AND at least one edge case or negative path (empty input, missing data, back-navigation, double-click, refresh mid-flow).
- Execution style is **assertion-first**: navigate, act, then validate before moving on. Check at least two independent signals per step (e.g. URL changed AND new content appeared, or item added AND count updated).
- Verify absence when relevant: after a delete, the item is gone; after dismissing a modal, it no longer appears in the tree.
- Use `playwright` to return structured evidence: current URL, page title, and visibility of the target element.
- If the changed files suggest specific behavior (validation rule, redirect, computed value), test that specific behavior rather than just the surrounding UI.

## Data Seeding

Every page you test MUST have real data. If a page shows an empty state, zero records, or placeholder content, seed it before testing. An empty-state screenshot is not a test — it is a skip.

1. Navigate to the target page. Snapshot. If data exists and is sufficient, proceed.
2. If empty or insufficient: find the creation flow ("Add", "New", "Create") and use it. If the app exposes an API you can call via `page.evaluate(fetch(...))`, prefer that for speed.
3. Create the full dependency chain top-down.
4. Create MINIMUM 3 records. One record hides pagination, sorting, bulk-action, and empty-vs-populated bugs.
5. After seeding, return to the target page and verify all records appear.

## UI Quality Checks

When the diff touches files that affect visual output (components, styles, layouts, routes), run these checks after functional testing. Skip when the diff only changes backend logic, build config, or tests.

1. **Responsive design**: test at these viewports using `page.setViewportSize()`: 375×812 (mobile), 768×1024 (tablet), 1280×800 (laptop), 1440×900 (desktop). Verify no horizontal overflow, no overlapping elements, text readable, interactive targets accessible.
2. **Cross-browser (WebKit)**: close the current session, `open` with `browser='webkit'`, and re-run the primary flow. Check for flexbox gap, backdrop-filter, position:sticky in overflow, date/time inputs, scrollbar styling.
3. **Dark mode**: detect support (Tailwind `dark:` classes, theme toggle, `prefers-color-scheme`). If supported, switch and re-verify. Check for invisible text, disappearing borders, hardcoded white backgrounds.
4. **Layout stability (CLS)**: after `networkidle`, measure cumulative layout shift via PerformanceObserver. CLS above 0.1 is a failure.

## Snapshot Workflow

Prefer screenshot mode `snapshot` for observing page state. Use `screenshot` or `annotated` only for purely visual checks.

1. Call screenshot with `mode='snapshot'` to get the ARIA tree with refs like `[ref=e4]`.
2. Use `ref()` in playwright to act on elements AND collect data in a single call.
3. Take a new snapshot only when the page structure changes (navigation, modal open/close, new content loaded).
4. Always snapshot first, then use `ref()` to act. Never guess CSS selectors when refs are available.

Batch all actions that share the same page state into a single `playwright` call — fills, clicks, AND data collection. Do NOT batch across DOM-changing boundaries (dropdown open, modal, dialog, navigation). After a DOM-changing action, use `snapshotAfter=true` or take a new snapshot for fresh refs.

## Stability and Recovery

- After navigation or major UI changes, wait for the page to settle: `await page.waitForLoadState('networkidle')`.
- Use event-driven waits (`waitForSelector`, `waitForURL`, `waitForFunction`) instead of timed delays. Take a new snapshot after each wait resolves.
- When a ref stops working: take a new snapshot for fresh refs, scroll the target into view, or retry once.
- Do not repeat the same failing action without new evidence (fresh snapshot, different ref, changed page state).
- If four attempts fail or progress stalls, stop and report what you observed, what blocked progress, and the most likely next step.
- If you encounter a hard blocker (login, passkey, captcha, permissions), stop and report it instead of improvising.

## Before Claiming Completion

You MUST complete every step before claiming the work is done.

1. Call `accessibility_audit` to check for WCAG violations. Critical or serious violations are failures.
2. Call `performance_metrics` to collect the performance trace. Any Web Vital rated "poor" or LoAF with blockingDuration > 150ms is a failure.
3. Call `console_logs` with `type='error'` one final time to catch any errors you missed.
4. Call `close` to flush the session video to disk.
5. If ANY failure: fix the code, then immediately run a NEW verification to re-test. No asking, no waiting.
6. Repeat until all checks pass with 0 failures, then state the claim with passing evidence.
