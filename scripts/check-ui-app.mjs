// Loads the solverforge-ui getting-started app in a browser and runs the
// scheduling-view and map snippets from the docs against the assets that app
// serves. Driven by scripts/verify-ui-getting-started.rb, which builds and
// boots the app from the page and passes the page's snippets in a JSON spec:
//
//   node scripts/check-ui-app.mjs <spec.json>
//
// spec = { origin, version, pages: [{ name, path, html?, expect }] }
//
// Every page must load with zero console errors and zero uncaught exceptions.
// A page given as `html` is served at `path` on the app's own origin, so its
// `/sf/*` references resolve against the embedded assets exactly as they would
// in the reader's app.

import { existsSync, readFileSync } from "node:fs";
import { chromium } from "playwright";

// Leaflet requests OpenStreetMap tiles. The snippet's behaviour is the subject,
// not the tile server's availability, so tiles are answered locally.
const TRANSPARENT_PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
  "base64",
);

function chromiumOptions() {
  if (process.env.PLAYWRIGHT_CHANNEL) return { channel: process.env.PLAYWRIGHT_CHANNEL };
  const executablePath = existsSync("/usr/bin/chromium") ? "/usr/bin/chromium" : undefined;
  return { executablePath, args: executablePath ? ["--no-sandbox"] : [] };
}

const EXPECTATIONS = {
  // The app shell: the header the page's script builds must exist, proving the
  // script ran against a real `SF` global rather than a text/plain document.
  async app(page) {
    await page.waitForSelector(".sf-header", { timeout: 10_000 });
    return page.evaluate(() => ({
      header: document.querySelectorAll(".sf-header").length,
      tabs: document.querySelectorAll(".sf-header-nav button, .sf-header-nav a").length,
      lifecycle: document.body.dataset.lifecycleState ?? null,
    }));
  },
  // Frappe Gantt draws one bar wrapper per task inside the split pane.
  async gantt(page) {
    await page.waitForSelector("#my-container .bar-wrapper", { timeout: 10_000 });
    return page.evaluate(() => ({
      bars: document.querySelectorAll("#my-container .bar-wrapper").length,
      gridRows: document.querySelectorAll("#my-container tbody tr").length,
    }));
  },
  // The map module wraps Leaflet; the container must be initialised.
  async map(page) {
    await page.waitForSelector("#map.leaflet-container", { timeout: 10_000 });
    return page.evaluate(() => ({
      hasMapModule: typeof window.SF?.map?.create === "function",
      panes: document.querySelectorAll("#map .leaflet-pane").length,
    }));
  },
};

const spec = JSON.parse(readFileSync(process.argv[2], "utf8"));
const failures = [];
const browser = await chromium.launch(chromiumOptions());

try {
  for (const entry of spec.pages) {
    const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
    const page = await context.newPage();
    const errors = [];
    page.on("console", (message) => {
      if (message.type() === "error") errors.push(`console: ${message.text()}`);
    });
    page.on("pageerror", (error) => errors.push(`exception: ${error.message}`));
    // Leaflet cancels in-flight tile loads when the view changes; a cancelled
    // request is not a failure the reader sees.
    page.on("requestfailed", (request) => {
      const reason = request.failure()?.errorText ?? "";
      if (reason !== "net::ERR_ABORTED") errors.push(`request failed: ${request.url()} ${reason}`);
    });
    await page.route(/^https:\/\/[a-z]\.tile\.openstreetmap\.org\//, (route) =>
      route.fulfill({ status: 200, contentType: "image/png", body: TRANSPARENT_PNG }));
    if (entry.html) {
      await page.route(`${spec.origin}${entry.path}`, (route) =>
        route.fulfill({ status: 200, contentType: "text/html; charset=utf-8", body: entry.html }));
    }

    const response = await page.goto(`${spec.origin}${entry.path}`, { waitUntil: "load" });
    const contentType = response?.headers()["content-type"] ?? "";
    if (!contentType.startsWith("text/html")) {
      failures.push({ page: entry.name, issue: "not served as text/html", contentType });
    }

    let observed = null;
    try {
      observed = await EXPECTATIONS[entry.expect](page);
    } catch (error) {
      failures.push({ page: entry.name, issue: "expected UI never rendered", error: String(error).split("\n")[0] });
    }
    // Late errors from timers and tile loads still count.
    await page.waitForTimeout(500);

    const version = await page.evaluate(() => (typeof window.SF === "object" ? window.SF.version : null));
    if (version !== spec.version) {
      failures.push({ page: entry.name, issue: "SF.version does not match the crate", expected: spec.version, actual: version });
    }
    if (errors.length > 0) {
      failures.push({ page: entry.name, issue: "browser reported errors", errors });
    }
    console.log(`[check-ui-app] ${entry.name}: content-type=${contentType} SF.version=${version} errors=${errors.length} ${JSON.stringify(observed)}`);
    if (observed && entry.expect === "gantt" && observed.bars < 1) {
      failures.push({ page: entry.name, issue: "Gantt drew no bars", observed });
    }
    if (observed && entry.expect === "map" && !observed.hasMapModule) {
      failures.push({ page: entry.name, issue: "SF.map is missing", observed });
    }
    await context.close();
  }
} finally {
  await browser.close();
}

if (failures.length > 0) {
  console.error(JSON.stringify(failures, null, 2));
  process.exit(1);
}
console.log(`[check-ui-app] ${spec.pages.length} pages loaded with zero browser errors`);
