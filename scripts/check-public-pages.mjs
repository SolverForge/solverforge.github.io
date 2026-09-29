import { createServer } from "node:http";
import {
  existsSync,
  readFileSync,
  readdirSync,
  statSync,
} from "node:fs";
import { extname, join, dirname, normalize, relative, resolve } from "node:path";
import { chromium } from "playwright";

const outputDir = resolve("output");
const stalePatterns = [
  /public surface/i,
  /technical surface/i,
  /commercial side/i,
  /commercial surface/i,
  /ecosystem/i,
  /sits on top of/i,
  /where companies engage/i,
  /demo footprint/i,
  /story behind/i,
  /service line/i,
  /foundation/i,
  /content architecture/i,
  /site is/i,
  /website as/i,
  /public project surface/i,
  /current surfaces/i,
  /Integration Surfaces/,
  /Ecosystem Maintainer/,
];

function walk(dir, predicate, out = []) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    const stat = statSync(path);
    if (stat.isDirectory()) {
      walk(path, predicate, out);
    } else if (predicate(path)) {
      out.push(path);
    }
  }
  return out;
}

function pagePaths() {
  return walk(outputDir, (path) => path.endsWith("index.html"))
    .sort()
    .map((file) => {
      const dir = dirname(relative(outputDir, file));
      return dir === "." ? "/" : `/${dir}/`;
    });
}

function contentType(path) {
  switch (extname(path)) {
    case ".css":
      return "text/css";
    case ".js":
      return "text/javascript";
    case ".svg":
      return "image/svg+xml";
    case ".png":
      return "image/png";
    case ".jpg":
    case ".jpeg":
      return "image/jpeg";
    case ".ico":
      return "image/x-icon";
    default:
      return "text/html";
  }
}

function startServer() {
  const server = createServer((req, res) => {
    const url = new URL(req.url || "/", "http://127.0.0.1");
    const decoded = decodeURIComponent(url.pathname);
    const requested = decoded.endsWith("/")
      ? join(outputDir, decoded, "index.html")
      : join(outputDir, decoded);
    const normalized = normalize(requested);

    if (!normalized.startsWith(outputDir) || !existsSync(normalized)) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }

    res.writeHead(200, { "content-type": contentType(normalized) });
    res.end(readFileSync(normalized));
  });

  return new Promise((resolveServer) => {
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      resolveServer({ server, origin: `http://127.0.0.1:${address.port}` });
    });
  });
}

function checkStaleCopy() {
  const failures = [];
  for (const file of walk(outputDir, (path) => path.endsWith(".html"))) {
    const html = readFileSync(file, "utf8");
    for (const pattern of stalePatterns) {
      if (pattern.test(html)) {
        failures.push({ file: relative(outputDir, file), pattern: pattern.toString() });
      }
    }
  }
  return failures;
}

function checkInternalLinks() {
  const misses = [];
  for (const file of walk(outputDir, (path) => path.endsWith(".html"))) {
    const html = readFileSync(file, "utf8");
    for (const match of html.matchAll(/\s(?:href|src)=["']([^"']+)["']/g)) {
      const raw = match[1];
      if (
        !raw ||
        raw.startsWith("#") ||
        raw.startsWith("http:") ||
        raw.startsWith("https:") ||
        raw.startsWith("mailto:") ||
        raw.startsWith("tel:") ||
        raw.startsWith("data:")
      ) {
        continue;
      }

      const clean = raw.split("#")[0].split("?")[0];
      if (!clean) continue;

      const target = clean.startsWith("/")
        ? join(outputDir, clean)
        : normalize(join(dirname(file), clean));
      if (![target, join(target, "index.html")].some(existsSync)) {
        misses.push({ file: relative(outputDir, file), link: raw });
      }
    }
  }
  return misses;
}

function checkDocsIndexTargets() {
  const docsIndex = join(outputDir, "docs", "index.html");
  const failures = [];
  if (!existsSync(docsIndex)) return failures;

  const docsHtml = readFileSync(docsIndex, "utf8");
  const expectedFooterLinks = new Map([
    ["solverforge-cli", "/docs/solverforge-cli/"],
    ["solverforge-ui", "/docs/solverforge-ui/"],
    ["solverforge-maps", "/docs/solverforge-maps/"],
  ]);
  for (const match of docsHtml.matchAll(/<a\s+href=["']([^"']+)["'][^>]*>\s*(solverforge-cli|solverforge-ui|solverforge-maps)\s*<\/a>/g)) {
    const href = match[1];
    const title = match[2];
    const expected = expectedFooterLinks.get(title);
    if (expected && href !== expected) {
      failures.push({ surface: "footer", title, expected, link: href });
    }
  }

  const hospitalPage = join(outputDir, "docs", "getting-started", "solverforge-hospital-use-case", "index.html");
  if (existsSync(hospitalPage)) {
    const hospitalHtml = readFileSync(hospitalPage, "utf8");
    const expectedSidebarLinks = [
      ["Getting Started", "/docs/getting-started/"],
      ["Start with solverforge-cli", "/docs/solverforge-cli/getting-started/"],
      ["SolverForge Hospital Use Case", "/docs/getting-started/solverforge-hospital-use-case/"],
      ["Setup", "/docs/getting-started/solverforge-hospital-use-case/#getting-started"],
      ["Data Model", "/docs/getting-started/solverforge-hospital-use-case/#understanding-the-data-model"],
      ["Constraints", "/docs/getting-started/solverforge-hospital-use-case/#writing-constraints"],
      ["Solver Policy", "/docs/getting-started/solverforge-hospital-use-case/#solver-policy"],
      ["Runtime", "/docs/getting-started/solverforge-hospital-use-case/#runtime-and-browser-behavior"],
    ];

    for (const [title, href] of expectedSidebarLinks) {
      const linkPattern = new RegExp(
        `<a\\s+class="docs-sidebar__link"\\s+href="${escapeRegExp(href)}"[\\s\\S]*?>\\s*${escapeRegExp(title)}\\s*<\\/a>`,
      );
      if (!linkPattern.test(hospitalHtml)) {
        failures.push({ surface: "hospital-sidebar", title, expected: href });
      }
    }
  }

  const cliGettingStartedPage = join(outputDir, "docs", "solverforge-cli", "getting-started", "index.html");
  if (existsSync(cliGettingStartedPage)) {
    const cliHtml = readFileSync(cliGettingStartedPage, "utf8");
    const activeSidebarLinks = [...cliHtml.matchAll(/<li class="docs-sidebar__item is-active">[\s\S]*?<a\s+class="docs-sidebar__link"\s+href="([^"]+)"[\s\S]*?>([^<]+)<\/a>/g)]
      .map((match) => ({ href: match[1], title: match[2].trim() }));
    const crossLinkActive = activeSidebarLinks.some(
      (link) => link.href === "/docs/solverforge-cli/getting-started/" && link.title === "Start with solverforge-cli",
    );
    if (crossLinkActive) {
      failures.push({
        surface: "cli-sidebar-active",
        title: "Start with solverforge-cli",
        link: "/docs/solverforge-cli/getting-started/",
      });
    }
  }

  return failures;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function chromiumOptions() {
  const executablePath = existsSync("/usr/bin/chromium") ? "/usr/bin/chromium" : undefined;
  return {
    executablePath,
    args: executablePath ? ["--no-sandbox"] : [],
  };
}

async function checkLayout(origin, paths) {
  const browser = await chromium.launch({
    ...chromiumOptions(),
  });
  const viewports = [
    { label: "desktop", width: 1440, height: 1100, isMobile: false },
    { label: "mobile", width: 390, height: 1000, isMobile: true },
  ];
  const failures = [];

  for (const viewport of viewports) {
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      isMobile: viewport.isMobile,
    });
    const page = await context.newPage();

    for (const path of paths) {
      const response = await page.goto(`${origin}${path}`, { waitUntil: "load" });
      const status = response?.status() ?? 0;
      const layout = await page.evaluate(() => {
        const ignored =
          "pre, code, table, svg, img, video, canvas, .terminal-card, .code-tabs, .showcase, .planner-page";
        const viewportWidth = window.innerWidth;
        const offenders = [];

        for (const element of document.querySelectorAll("body *")) {
          if (element.closest(ignored)) continue;
          const rect = element.getBoundingClientRect();
          const style = getComputedStyle(element);
          if (rect.width <= 0 || rect.height <= 0) continue;
          if (style.position === "fixed") continue;
          if (rect.left < -2 || rect.right > viewportWidth + 2) {
            offenders.push({
              tag: element.tagName.toLowerCase(),
              className: String(element.className).slice(0, 80),
              text: (element.textContent || "").trim().replace(/\s+/g, " ").slice(0, 120),
              left: Math.round(rect.left),
              right: Math.round(rect.right),
              width: Math.round(rect.width),
            });
          }
        }

        return {
          title: document.title,
          innerWidth: viewportWidth,
          scrollWidth: document.documentElement.scrollWidth,
          offenderCount: offenders.length,
          offenders: offenders.slice(0, 5),
        };
      });

      if (status >= 400 || layout.scrollWidth > layout.innerWidth + 2 || layout.offenderCount > 0) {
        failures.push({ viewport: viewport.label, path, status, ...layout });
      }
    }

    await context.close();
  }

  await browser.close();
  return failures;
}

async function checkUseCaseShowcase(origin) {
  const browser = await chromium.launch({
    ...chromiumOptions(),
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1100 },
  });
  const page = await context.newPage();
  const failures = [];
  const path = "/use-cases/";

  try {
    await page.goto(`${origin}${path}`, { waitUntil: "load" });

    const showcase = await page.evaluate(() => {
      const carousel = document.querySelector("[data-use-case-carousel]");
      if (!carousel) return null;

      const slides = [...carousel.querySelectorAll("[data-use-case-slide]")];
      const selectors = [...carousel.querySelectorAll("[data-use-case-select]")];

      return {
        slides: slides.map((slide) => ({
          id: slide.dataset.useCaseCase,
          hidden: slide.hidden,
          metrics: slide.querySelectorAll(".use-case-proof__metric").length,
          constraints: slide.querySelectorAll(".use-case-proof__constraint").length,
          screenshots: slide.querySelectorAll(".use-case-showcase__item").length,
          annotated: slide.querySelectorAll(".use-case-showcase__callout").length,
          calloutsOffFrame: [...slide.querySelectorAll(".use-case-showcase__callout")].filter((callout) => {
            const frame = callout.closest(".use-case-showcase__trigger").getBoundingClientRect();
            const box = callout.getBoundingClientRect();
            return box.right > frame.right + 2 || box.bottom > frame.bottom + 2;
          }).length,
          videos: [...slide.querySelectorAll("video")].map((video) => ({
            poster: Boolean(video.getAttribute("poster")),
            src: video.querySelector("source")?.getAttribute("src") || "",
          })),
          badges: slide.querySelectorAll(".use-case-showcase__badge").length,
          spaceRibbon: slide.querySelectorAll(".use-case-space-ribbon").length,
          docs: slide.querySelector(".use-case-doc-link")?.getAttribute("href") || "",
          space: slide.querySelector(".use-case-space-link")?.getAttribute("href") || "",
        })),
        selectors: selectors.map((selector) => selector.dataset.useCaseSelect),
        selected: selectors.filter((selector) => selector.getAttribute("aria-selected") === "true").map((selector) => selector.dataset.useCaseSelect),
      };
    });

    if (!showcase) {
      failures.push({ path, issue: "missing use-case carousel" });
    } else {
      if (showcase.slides.length !== 4) failures.push({ path, issue: "expected 4 slides", found: showcase.slides.length });
      if (showcase.selectors.length !== showcase.slides.length) {
        failures.push({ path, issue: "selector count does not match slide count", selectors: showcase.selectors.length, slides: showcase.slides.length });
      }

      const visible = showcase.slides.filter((slide) => !slide.hidden);
      if (visible.length !== 1) failures.push({ path, issue: "expected exactly one visible slide", visible: visible.length });

      for (const slide of showcase.slides) {
        if (slide.metrics !== 6) failures.push({ path, slide: slide.id, issue: "expected 6 metrics", found: slide.metrics });
        if (slide.constraints !== 6) failures.push({ path, slide: slide.id, issue: "expected 6 constraints", found: slide.constraints });
        if (slide.screenshots !== 6) failures.push({ path, slide: slide.id, issue: "expected 6 screenshots", found: slide.screenshots });
        if (slide.annotated !== 12) failures.push({ path, slide: slide.id, issue: "expected 12 annotations", found: slide.annotated });
        if (slide.badges !== 6) failures.push({ path, slide: slide.id, issue: "expected 6 screenshot captions", found: slide.badges });
        if (slide.calloutsOffFrame !== 0) failures.push({ path, slide: slide.id, issue: "annotations extend past their capture", found: slide.calloutsOffFrame });
        if (slide.videos.length !== 1) failures.push({ path, slide: slide.id, issue: "expected one runtime video", found: slide.videos.length });
        if (!slide.videos[0]?.poster) failures.push({ path, slide: slide.id, issue: "runtime video is missing its poster" });
        if (!slide.videos[0]?.src.includes(`/videos/use-cases/solverforge-${slide.id === "field-service" ? "fsr" : slide.id}-demo.mp4`)) {
          failures.push({ path, slide: slide.id, issue: "unexpected runtime video source", src: slide.videos[0]?.src });
        }
        if (!slide.docs.startsWith("/docs/getting-started/")) failures.push({ path, slide: slide.id, issue: "missing docs link", docs: slide.docs });
        const hasSpace = slide.space.startsWith("https://huggingface.co/spaces/SolverForge/");
        // The Space badge is the page's discriminant, so it must track the link.
        if (hasSpace && slide.spaceRibbon !== 1) failures.push({ path, slide: slide.id, issue: "Space case without its badge", spaceRibbon: slide.spaceRibbon });
        if (!hasSpace && slide.spaceRibbon !== 0) failures.push({ path, slide: slide.id, issue: "badge without a Space link", spaceRibbon: slide.spaceRibbon, space: slide.space });
      }

      // Switching cases must move the selection, the visible slide, and the URL hash.
      const second = showcase.selectors[1];
      await page.click(`[data-use-case-select="${second}"]`);
      const afterSelect = await page.evaluate(() => {
        const carousel = document.querySelector("[data-use-case-carousel]");
        const slides = [...carousel.querySelectorAll("[data-use-case-slide]")];
        const selectors = [...carousel.querySelectorAll("[data-use-case-select]")];
        return {
          hash: window.location.hash,
          visible: slides.filter((slide) => !slide.hidden).map((slide) => slide.dataset.useCaseCase),
          selected: selectors.filter((selector) => selector.getAttribute("aria-selected") === "true").map((selector) => selector.dataset.useCaseSelect),
          active: carousel.dataset.useCaseActive,
        };
      });

      if (afterSelect.visible.length !== 1 || afterSelect.visible[0] !== second) {
        failures.push({ path, issue: "selector click did not reveal its slide", ...afterSelect });
      }
      if (afterSelect.selected.length !== 1 || afterSelect.selected[0] !== second) {
        failures.push({ path, issue: "selector click did not move aria-selected", ...afterSelect });
      }
      if (afterSelect.active !== second || !afterSelect.hash.endsWith(`#${second}`)) {
        failures.push({ path, issue: "selector click did not update the deep link", ...afterSelect });
      }

      // Deep links activate the matching case on load.
      await page.goto(`${origin}${path}#${second}`, { waitUntil: "load" });
      const deepLinked = await page.evaluate(() => {
        const carousel = document.querySelector("[data-use-case-carousel]");
        return [...carousel.querySelectorAll("[data-use-case-slide]")]
          .filter((slide) => !slide.hidden)
          .map((slide) => slide.dataset.useCaseCase);
      });
      if (deepLinked.length !== 1 || deepLinked[0] !== second) {
        failures.push({ path, issue: "deep link did not activate its case", hash: second, visible: deepLinked });
      }

      // Arrow keys move between cases.
      await page.evaluate(() => document.querySelector("[data-use-case-carousel]").focus());
      await page.keyboard.press("ArrowRight");
      const afterArrow = await page.evaluate(() => {
        const carousel = document.querySelector("[data-use-case-carousel]");
        return {
          active: carousel.dataset.useCaseActive,
          visible: [...carousel.querySelectorAll("[data-use-case-slide]")].filter((slide) => !slide.hidden).map((slide) => slide.dataset.useCaseCase),
        };
      });
      if (afterArrow.visible.length !== 1 || afterArrow.visible[0] === second) {
        failures.push({ path, issue: "ArrowRight did not advance the carousel", ...afterArrow });
      }

      // The viewer opens the clicked capture and closes on Escape.
      const trigger = page.locator("[data-use-case-slide]:not([hidden]) [data-use-case-lightbox]").first();
      const expectedCaption = await trigger.getAttribute("data-use-case-lightbox-caption");
      await trigger.click();
      const opened = await page.evaluate(() => {
        const lightbox = document.querySelector("[data-use-case-lightbox-root]");
        return {
          hidden: lightbox.hidden,
          src: lightbox.querySelector(".use-case-lightbox__image")?.getAttribute("src") || "",
          caption: lightbox.querySelector(".use-case-lightbox__caption")?.textContent || "",
          bodyLocked: document.body.classList.contains("use-case-lightbox-open"),
        };
      });

      if (opened.hidden || !opened.src.includes("/images/use-cases/") || opened.caption !== expectedCaption || !opened.bodyLocked) {
        failures.push({ path, issue: "lightbox did not open with the capture metadata", ...opened });
      }

      await page.keyboard.press("Escape");
      const closed = await page.evaluate(() => document.querySelector("[data-use-case-lightbox-root]").hidden);
      if (!closed) failures.push({ path, issue: "lightbox did not close on Escape" });
    }
  } catch (error) {
    failures.push({ path, issue: "showcase check threw", error: String(error) });
  }

  await context.close();
  await browser.close();
  return failures;
}

async function checkDocsSidebarActive(origin) {
  const browser = await chromium.launch({
    ...chromiumOptions(),
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1100 },
  });
  const page = await context.newPage();
  const failures = [];
  const checks = [
    {
      path: "/docs/getting-started/solverforge-deliveries-use-case/#solver-policy",
      expected: [
        ["Getting Started", "/docs/getting-started/"],
        ["SolverForge Deliveries Use Case", "/docs/getting-started/solverforge-deliveries-use-case/"],
        ["Solver Policy", "/docs/getting-started/solverforge-deliveries-use-case/#solver-policy"],
      ],
    },
    {
      path: "/docs/getting-started/solverforge-deliveries-use-case/#runtime-and-browser-behavior",
      expected: [
        ["Getting Started", "/docs/getting-started/"],
        ["SolverForge Deliveries Use Case", "/docs/getting-started/solverforge-deliveries-use-case/"],
        ["Runtime", "/docs/getting-started/solverforge-deliveries-use-case/#runtime-and-browser-behavior"],
      ],
    },
  ];

  for (const check of checks) {
    await page.goto(`${origin}${check.path}`, { waitUntil: "load" });
    const active = await page.evaluate(() => [...document.querySelectorAll("nav.docs-sidebar li.docs-sidebar__item.is-active > a.docs-sidebar__link")]
      .map((link) => [link.textContent.trim(), link.getAttribute("href")]));

    for (const expected of check.expected) {
      if (!active.some(([title, href]) => title === expected[0] && href === expected[1])) {
        failures.push({ path: check.path, expected, active });
      }
    }
  }

  await context.close();
  await browser.close();
  return failures;
}

if (!existsSync(outputDir)) {
  throw new Error("Missing output/. Run `make build` first.");
}

const paths = pagePaths();
const staleCopy = checkStaleCopy();
const missingLinks = checkInternalLinks();
const docsIndexTargets = checkDocsIndexTargets();
const { server, origin } = await startServer();
let layoutFailures = [];
let docsSidebarActive = [];
let useCaseShowcase = [];

try {
  layoutFailures = await checkLayout(origin, paths);
  docsSidebarActive = await checkDocsSidebarActive(origin);
  useCaseShowcase = await checkUseCaseShowcase(origin);
} finally {
  server.close();
}

const summary = {
  pages: paths.length,
  renderedChecks: paths.length * 2,
  staleCopy,
  missingLinks,
  docsIndexTargets,
  docsSidebarActive,
  useCaseShowcase,
  layoutFailures,
};

console.log(JSON.stringify(summary, null, 2));

if (
  staleCopy.length ||
  missingLinks.length ||
  docsIndexTargets.length ||
  docsSidebarActive.length ||
  useCaseShowcase.length ||
  layoutFailures.length
) {
  process.exit(1);
}
