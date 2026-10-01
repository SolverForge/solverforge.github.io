import { createServer } from "node:http";
import {
  existsSync,
  readFileSync,
  readdirSync,
  statSync,
} from "node:fs";
import { extname, join, dirname, normalize, relative, resolve } from "node:path";
import { chromium } from "playwright";

// The benchmarks page renders one section per publishable problem and one table
// per tested budget. The expected set comes from the imported data file rather
// than a hand-written list, so a problem that joins the page is checked and a
// problem that silently drops out fails.
const benchmarksDataPath = resolve("src/_data/benchmarks.json");

// Rank by feasibility, earlier-gate coverage, then quality—not runtime.
// This is an independent reimplementation of that rule: if it agreed
// with the importer only by construction, a bug in the importer would move the
// rendered order and the check would move with it instead of failing.
function rankSolvers(problem, budget = Math.max(...problem.time_limits_seconds)) {
  const rows = problem.summaries.filter((row) => row.budget === budget);
  const compareOptional = (a, b) => {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return a - b;
  };
  const earlierCoverage = (a, b) => {
    for (const gate of [...problem.time_limits_seconds].sort((x, y) => x - y)) {
      if (gate >= budget) break;
      const count = (solver) => problem.summaries.find((row) => row.solver === solver && row.budget === gate).feasible;
      const difference = count(b) - count(a);
      if (difference) return difference;
    }
    return 0;
  };
  return [...rows].sort((a, b) => (
    (a.total - a.feasible) - (b.total - b.feasible) ||
    earlierCoverage(a.solver, b.solver) ||
    compareOptional(a.gap_percent, b.gap_percent) ||
    compareOptional(a.mean_cost, b.mean_cost) ||
    a.solver.localeCompare(b.solver)
  )).map((row) => row.solver);
}

// Markers are small, but two can still land on the same interface element. An
// overlap means the reader cannot tell which number names which region. This is
// injected into the page, so it is written as a string rather than a closure.

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
    case ".mp4":
      return "video/mp4";
    case ".webm":
      return "video/webm";
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

    const body = readFileSync(normalized);
    const type = contentType(normalized);
    // Chromium fetches media with a Range request and will not settle a video
    // element without a 206, so serve ranges the way a real host does.
    const range = req.headers.range;
    const match = range && /bytes=(\d+)-(\d*)/.exec(range);
    if (match) {
      const start = Number(match[1]);
      const end = match[2] ? Number(match[2]) : body.length - 1;
      res.writeHead(206, {
        "content-type": type,
        "content-range": `bytes ${start}-${end}/${body.length}`,
        "accept-ranges": "bytes",
      });
      res.end(body.subarray(start, end + 1));
      return;
    }

    res.writeHead(200, { "content-type": type, "accept-ranges": "bytes" });
    res.end(body);
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
          annotated: slide.querySelectorAll(".use-case-showcase__marker").length,
          calloutsOffFrame: [...slide.querySelectorAll(".use-case-showcase__marker")].filter((marker) => {
            const frame = marker.closest(".use-case-showcase__trigger").getBoundingClientRect();
            const box = marker.getBoundingClientRect();
            return box.left < frame.left - 2 || box.right > frame.right + 2
              || box.top < frame.top - 2 || box.bottom > frame.bottom + 2;
          }).length,
          calloutLegend: slide.querySelectorAll(".use-case-showcase__legend-item").length,
          calloutOverlaps: (() => {
            let overlaps = 0;
            for (const item of slide.querySelectorAll(".use-case-showcase__item")) {
              const boxes = [...item.querySelectorAll(".use-case-showcase__marker")].map((m) => m.getBoundingClientRect());
              for (let a = 0; a < boxes.length; a += 1) {
                for (let b = a + 1; b < boxes.length; b += 1) {
                  const x = Math.min(boxes[a].right, boxes[b].right) - Math.max(boxes[a].left, boxes[b].left);
                  const y = Math.min(boxes[a].bottom, boxes[b].bottom) - Math.max(boxes[a].top, boxes[b].top);
                  if (x > 1 && y > 1) overlaps += 1;
                }
              }
            }
            return overlaps;
          })(),
          videos: [...slide.querySelectorAll("video")].map((video) => ({
            poster: Boolean(video.getAttribute("poster")),
            src: video.querySelector("source")?.getAttribute("src") || "",
          })),
          badges: slide.querySelectorAll(".use-case-showcase__badge").length,
          spaceRibbon: slide.querySelectorAll(".use-case-space-ribbon").length,
          docs: [...slide.querySelectorAll(".use-case-doc-link")].map((link) => link.getAttribute("href")).find((href) => href?.startsWith("/docs/")) || "",
          repo: [...slide.querySelectorAll(".use-case-doc-link")].map((link) => link.getAttribute("href")).find((href) => href?.includes("github.com/SolverForge")) || "",
          casePage: [...slide.querySelectorAll(".use-case-doc-link")].map((link) => link.getAttribute("href")).find((href) => /^\/use-cases\/[a-z-]+\/$/.test(href || "")) || "",
          space: slide.querySelector(".use-case-space-link")?.getAttribute("href") || "",
        })),
        selectors: selectors.map((selector) => selector.dataset.useCaseSelect),
        selected: selectors.filter((selector) => selector.getAttribute("aria-selected") === "true").map((selector) => selector.dataset.useCaseSelect),
      };
    });

    if (!showcase) {
      failures.push({ path, issue: "missing use-case carousel" });
    } else {
      if (showcase.slides.length !== 8) failures.push({ path, issue: "expected 8 slides", found: showcase.slides.length });
      if (showcase.selectors.length !== showcase.slides.length) {
        failures.push({ path, issue: "selector count does not match slide count", selectors: showcase.selectors.length, slides: showcase.slides.length });
      }

      const visible = showcase.slides.filter((slide) => !slide.hidden);
      if (visible.length !== 1) failures.push({ path, issue: "expected exactly one visible slide", visible: visible.length });

      for (const slide of showcase.slides) {
        if (slide.metrics !== 6) failures.push({ path, slide: slide.id, issue: "expected 6 metrics", found: slide.metrics });
        if (slide.constraints !== 6) failures.push({ path, slide: slide.id, issue: "expected 6 constraints", found: slide.constraints });
        // Every case carries at least six annotated captures; a case may ship more.
        if (slide.screenshots < 6) failures.push({ path, slide: slide.id, issue: "expected at least 6 screenshots", found: slide.screenshots });
        if (slide.annotated !== slide.screenshots * 2) {
          failures.push({ path, slide: slide.id, issue: "expected two annotations per capture", found: slide.annotated, screenshots: slide.screenshots });
        }
        if (slide.badges !== slide.screenshots) failures.push({ path, slide: slide.id, issue: "each capture needs its caption", found: slide.badges, screenshots: slide.screenshots });
        if (slide.calloutsOffFrame !== 0) failures.push({ path, slide: slide.id, issue: "annotations extend past their capture", found: slide.calloutsOffFrame });
        if (slide.calloutLegend !== slide.annotated) failures.push({ path, slide: slide.id, issue: "every marker needs a legend line", markers: slide.annotated, legend: slide.calloutLegend });
        if (slide.calloutOverlaps !== 0) failures.push({ path, slide: slide.id, issue: "markers overlap, so a number cannot be matched to its region", found: slide.calloutOverlaps });
        if (slide.videos.length !== 1) failures.push({ path, slide: slide.id, issue: "expected one runtime video", found: slide.videos.length });
        if (!slide.videos[0]?.poster) failures.push({ path, slide: slide.id, issue: "runtime video is missing its poster" });
        if (!slide.videos[0]?.src.includes(`/videos/use-cases/solverforge-${slide.id === "field-service" ? "fsr" : slide.id}-demo.mp4`)) {
          failures.push({ path, slide: slide.id, issue: "unexpected runtime video source", src: slide.videos[0]?.src });
        }
        // Each case links to its own page, generated from this same data file.
        if (slide.casePage !== `/use-cases/${slide.id}/`) {
          failures.push({ path, slide: slide.id, issue: "case page link does not match the case", casePage: slide.casePage });
        }
        const hasSpace = slide.space.startsWith("https://huggingface.co/spaces/SolverForge/");
        // The Space badge is the page's discriminant, so it must track the link.
        if (hasSpace && slide.spaceRibbon !== 1) failures.push({ path, slide: slide.id, issue: "Space case without its badge", spaceRibbon: slide.spaceRibbon });
        if (!hasSpace && slide.spaceRibbon !== 0) failures.push({ path, slide: slide.id, issue: "badge without a Space link", spaceRibbon: slide.spaceRibbon, space: slide.space });
        // A case with a written guide links it; a repository-only case must not.
        const hasGuide = slide.docs.startsWith("/docs/getting-started/");
        const hasRepo = slide.repo.startsWith("https://github.com/SolverForge/solverforge-usecases/");
        if (!hasGuide && !hasRepo) failures.push({ path, slide: slide.id, issue: "case links neither a guide nor its app source", docs: slide.docs });
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

      // Switching cases must stop the previous walkthrough: `hidden` alone
      // leaves a playing video audible in the background.
      await page.goto(`${origin}${path}`, { waitUntil: "load" });
      const playingSlide = await page.evaluate(async () => {
        const carousel = document.querySelector("[data-use-case-carousel]");
        const slides = [...carousel.querySelectorAll("[data-use-case-slide]")];
        const first = slides[0];
        const video = first.querySelector("video");
        if (!video) return { skipped: true, reason: "no video" };
        // Autoplay is muted so the check does not need user activation. `play()`
        // is wrapped in a bounded race so a media element that cannot settle can
        // never stall the gate. readiness is taken from readyState rather than a
        // `loadeddata` listener, which can fire before this code runs.
        video.muted = true;
        if (video.readyState < 2) {
          const ready = await Promise.race([
            new Promise((resolve) => video.addEventListener("loadeddata", () => resolve(true), { once: true })),
            new Promise((resolve) => setTimeout(() => resolve(false), 8000)),
          ]);
          if (!ready) return { skipped: true, reason: "media never became ready" };
        }
        try {
          await Promise.race([
            video.play(),
            new Promise((_, reject) => setTimeout(() => reject(new Error("play() did not settle")), 8000)),
          ]);
        } catch (error) {
          return { skipped: true, reason: String(error) };
        }
        return { skipped: false, playing: !video.paused, id: first.dataset.useCaseCase };
      });

      if (!playingSlide.skipped) {
        const otherCase = await page.evaluate(() => {
          const carousel = document.querySelector("[data-use-case-carousel]");
          return [...carousel.querySelectorAll("[data-use-case-slide]")][1].dataset.useCaseCase;
        });
        await page.click(`[data-use-case-select="${otherCase}"]`);
        const afterSwitch = await page.evaluate(() => {
          const all = [...document.querySelectorAll("[data-use-case-slide] video")];
          return all.map((video) => ({ paused: video.paused }));
        });
        if (afterSwitch.some((entry) => !entry.paused)) {
          failures.push({ path, issue: "a previous case's walkthrough kept playing after switching", videos: afterSwitch });
        }
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

// Each case also has its own page, generated from the same data file. It has to
// carry that case's proof and its own viewer, and the home page has to reach it.
async function checkUseCasePages(origin) {
  const browser = await chromium.launch({
    ...chromiumOptions(),
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1100 },
  });
  const page = await context.newPage();
  const failures = [];

  const cases = ["hospital", "lessons", "deliveries", "field-service", "furnace", "orders", "fleet", "flightcrew"];

  try {
    for (const caseId of cases) {
      const response = await page.goto(`${origin}/use-cases/${caseId}/`, { waitUntil: "load" });
      const status = response?.status() ?? 0;
      if (status >= 400) {
        failures.push({ path: `/use-cases/${caseId}/`, issue: "case page not served", status });
        continue;
      }

      const detail = await page.evaluate(() => {
        const root = document.querySelector(".use-case-detail");
        if (!root) return null;
        const callouts = [...root.querySelectorAll(".use-case-showcase__marker")];
        return {
          metrics: root.querySelectorAll(".use-case-proof__metric").length,
          constraints: root.querySelectorAll(".use-case-proof__constraint").length,
          screenshots: root.querySelectorAll(".use-case-showcase__item").length,
          annotated: callouts.length,
          offFrame: callouts.filter((marker) => {
            const frame = marker.closest(".use-case-showcase__trigger").getBoundingClientRect();
            const box = marker.getBoundingClientRect();
            return box.left < frame.left - 2 || box.right > frame.right + 2
              || box.top < frame.top - 2 || box.bottom > frame.bottom + 2;
          }).length,
          markerOverlaps: (() => {
            let overlaps = 0;
            for (const item of root.querySelectorAll(".use-case-showcase__item")) {
              const boxes = [...item.querySelectorAll(".use-case-showcase__marker")].map((m) => m.getBoundingClientRect());
              for (let a = 0; a < boxes.length; a += 1) {
                for (let b = a + 1; b < boxes.length; b += 1) {
                  const x = Math.min(boxes[a].right, boxes[b].right) - Math.max(boxes[a].left, boxes[b].left);
                  const y = Math.min(boxes[a].bottom, boxes[b].bottom) - Math.max(boxes[a].top, boxes[b].top);
                  if (x > 1 && y > 1) overlaps += 1;
                }
              }
            }
            return overlaps;
          })(),
          legendMismatch: [...root.querySelectorAll(".use-case-showcase__item")].filter((item) => {
            const markers = [...item.querySelectorAll(".use-case-showcase__marker")].map((m) => m.textContent.trim());
            const legend = [...item.querySelectorAll(".use-case-showcase__legend-number")].map((n) => n.textContent.trim());
            return JSON.stringify(markers) !== JSON.stringify(legend);
          }).length,
          videos: root.querySelectorAll("video").length,
          poster: Boolean(root.querySelector("video")?.getAttribute("poster")),
          viewer: Boolean(document.querySelector("[data-use-case-lightbox-root]")),
          otherCases: [...root.querySelectorAll(".use-case-detail__nav a")].length,
          stylesheets: [...document.querySelectorAll('link[rel="stylesheet"]')].length,
          heading: root.querySelector("h1")?.textContent?.trim() || "",
        };
      });

      if (!detail) {
        failures.push({ path: `/use-cases/${caseId}/`, issue: "case page has no detail shell" });
        continue;
      }

      // The zoomed viewer must explain itself the same way the page does. A
      // bare image here would strand the numbered markers with no legend.
      const lightboxState = await page.evaluate(() => {
        const trigger = document.querySelector(".use-case-showcase__trigger");
        if (!trigger) return null;
        trigger.click();
        const root = document.querySelector("[data-use-case-lightbox-root]");
        if (!root || root.hidden) return { opened: false };
        const frame = root.querySelector(".use-case-lightbox__frame")?.getBoundingClientRect();
        const markers = [...root.querySelectorAll("[data-use-case-lightbox-markers] .use-case-showcase__marker")].map((marker) => {
          const box = marker.getBoundingClientRect();
          return {
            number: marker.textContent.trim(),
            x: frame ? ((box.left + box.width / 2 - frame.left) / frame.width) * 100 : -1,
            y: frame ? ((box.top + box.height / 2 - frame.top) / frame.height) * 100 : -1,
          };
        });
        const legend = [...root.querySelectorAll("[data-use-case-lightbox-legend] li .use-case-showcase__legend-number")].map((n) => n.textContent.trim());
        // Markers must sit on the capture, not off its edges.
        const strayed = markers.filter((marker) => marker.x < 0 || marker.x > 100 || marker.y < 0 || marker.y > 100).length;
        return { opened: true, markers, legend, strayed };
      });

      if (lightboxState && lightboxState.opened) {
        const numbers = lightboxState.markers.map((marker) => marker.number);
        if (JSON.stringify(numbers) !== JSON.stringify(lightboxState.legend)) {
          failures.push({ path: `/use-cases/${caseId}/`, issue: "zoomed view markers do not match its legend", markers: numbers, legend: lightboxState.legend });
        }
        if (lightboxState.strayed !== 0) {
          failures.push({ path: `/use-cases/${caseId}/`, issue: "zoomed view markers sit outside the capture", found: lightboxState.strayed });
        }
        if (lightboxState.markers.length === 0) {
          failures.push({ path: `/use-cases/${caseId}/`, issue: "zoomed view lost the capture annotations" });
        }
      } else if (lightboxState && !lightboxState.opened) {
        failures.push({ path: `/use-cases/${caseId}/`, issue: "screenshot viewer did not open" });
      }
      // A page rendered without the site layout carries no stylesheet at all.
      if (detail.stylesheets === 0) failures.push({ path: `/use-cases/${caseId}/`, issue: "case page loaded without the site stylesheet" });
      if (detail.metrics !== 6) failures.push({ path: `/use-cases/${caseId}/`, issue: "expected 6 metrics", found: detail.metrics });
      if (detail.constraints !== 6) failures.push({ path: `/use-cases/${caseId}/`, issue: "expected 6 constraints", found: detail.constraints });
      if (detail.screenshots < 6) failures.push({ path: `/use-cases/${caseId}/`, issue: "expected at least 6 screenshots", found: detail.screenshots });
      if (detail.annotated !== detail.screenshots * 2) {
        failures.push({ path: `/use-cases/${caseId}/`, issue: "expected two annotations per capture", found: detail.annotated, screenshots: detail.screenshots });
      }
      if (detail.offFrame !== 0) failures.push({ path: `/use-cases/${caseId}/`, issue: "annotations extend past their capture", found: detail.offFrame });
      if (detail.markerOverlaps !== 0) failures.push({ path: `/use-cases/${caseId}/`, issue: "markers overlap, so a number cannot be matched to its region", found: detail.markerOverlaps });
      if (detail.legendMismatch !== 0) failures.push({ path: `/use-cases/${caseId}/`, issue: "marker numbers do not match their legend lines", found: detail.legendMismatch });
      if (detail.videos !== 1 || !detail.poster) failures.push({ path: `/use-cases/${caseId}/`, issue: "runtime walkthrough missing", videos: detail.videos, poster: detail.poster });
      if (!detail.viewer) failures.push({ path: `/use-cases/${caseId}/`, issue: "case page has no screenshot viewer" });
      if (detail.otherCases !== 7) failures.push({ path: `/use-cases/${caseId}/`, issue: "expected links to the other 7 cases", found: detail.otherCases });
      if (detail.heading.length === 0) failures.push({ path: `/use-cases/${caseId}/`, issue: "case page has no heading" });
    }

    // The viewer must work on a case page, not only in the carousel.
    await page.goto(`${origin}/use-cases/furnace/`, { waitUntil: "load" });
    const trigger = page.locator("[data-use-case-lightbox]").first();
    const expectedCaption = await trigger.getAttribute("data-use-case-lightbox-caption");
    await trigger.click();
    const opened = await page.evaluate(() => {
      const lightbox = document.querySelector("[data-use-case-lightbox-root]");
      return {
        hidden: lightbox.hidden,
        src: lightbox.querySelector(".use-case-lightbox__image")?.getAttribute("src") || "",
        caption: lightbox.querySelector(".use-case-lightbox__caption")?.textContent || "",
      };
    });
    if (opened.hidden || !opened.src.includes("/images/use-cases/") || opened.caption !== expectedCaption) {
      failures.push({ path: "/use-cases/furnace/", issue: "case page viewer did not open with the capture metadata", ...opened });
    }
    await page.keyboard.press("Escape");
    const closed = await page.evaluate(() => document.querySelector("[data-use-case-lightbox-root]").hidden);
    if (!closed) failures.push({ path: "/use-cases/furnace/", issue: "case page viewer did not close on Escape" });

    // The home page has to reach the case pages, not only the carousel.
    await page.goto(`${origin}/`, { waitUntil: "load" });
    const homeLinks = await page.evaluate(() =>
      [...document.querySelectorAll(".home-section a")].map((link) => link.getAttribute("href")).filter((href) => /^\/use-cases\/[a-z-]+\/$/.test(href || "")));
    if (homeLinks.length !== 8) failures.push({ path: "/", issue: "home page does not link all 8 case pages", found: homeLinks.length });
  } catch (error) {
    failures.push({ path: "/use-cases/<id>/", issue: "case page check threw", error: String(error) });
  }

  await context.close();
  await browser.close();
  return failures;
}

async function checkBenchmarksPage(origin) {
  const data = JSON.parse(readFileSync(benchmarksDataPath, "utf8"));
  const browser = await chromium.launch({
    ...chromiumOptions(),
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1100 },
  });
  const page = await context.newPage();
  const failures = [];

  try {
    await page.goto(`${origin}/benchmarks/`, { waitUntil: "load" });
    // Every budget readout must remain readable without ellipsis or clipping.
    for (const width of [1440, 1024, 390]) {
      await page.setViewportSize({ width, height: 1100 });
      const readouts = await page.evaluate(() => {
        const rows = [...document.querySelectorAll(".benchmark-chart__row")];
        return {
          rows: rows.length,
          invalid: rows.filter((row) => {
            const tracks = row.querySelectorAll(".benchmark-chart__track");
            const values = [...row.querySelectorAll(".benchmark-chart__value > span")];
            return values.length !== tracks.length || values.some((value) =>
              value.scrollWidth > value.clientWidth + 1 ||
              !/^\d+s\s/.test(value.textContent.trim())
            );
          }).length,
        };
      });
      if (!readouts.rows || readouts.invalid) {
        failures.push({ path: "/benchmarks/", width, issue: "chart budget values are clipped or unlabelled", ...readouts });
      }
    }
    await page.setViewportSize({ width: 1440, height: 1100 });
    // Measuring bar widths requires the browser to finish laying out the page.
    await page.waitForFunction(
      () => {
        const panels = document.querySelectorAll("figure.benchmark-chart");
        if (panels.length === 0) return false;
        return [...document.querySelectorAll(".benchmark-chart__bar:not(.benchmark-chart__bar--missing)")]
          .some((bar) => bar.getBoundingClientRect().width > 0.5);
      },
      null,
      { timeout: 10000 },
    );

    const rendered = await page.evaluate(() => ({
      stylesheets: [...document.querySelectorAll('link[rel="stylesheet"]')].length,
      bodyClasses: document.body.className,
      sections: [...document.querySelectorAll("section.benchmark-problem")].map((section) => ({
        id: section.id,
        heading: section.querySelector("h2")?.textContent.trim() || "",
        tables: [...section.querySelectorAll(".benchmark-table table")].map((table) => ({
          budget: Number(table.closest(".benchmark-table").getAttribute("data-budget")),
          headers: [...table.querySelectorAll("thead th")].map((th) => th.textContent.trim()),
          solvers: [...table.querySelectorAll("tbody th[scope='row']")]
            .map((th) => th.childNodes[0]?.textContent.trim() || ""),
        })),
        rows: section.querySelectorAll("tbody tr").length,
        provenance: section.querySelector("details") ? true : false,
        completed: section.querySelector("time")?.getAttribute("datetime") || "",
        referencesText: section.querySelector(".benchmark-references")?.textContent || "",
        // Two charts per problem, each with a row per solver and one bar per
        // tested budget. A bar whose fill is unset renders as zero-length at
        // every width, which is indistinguishable from a measured zero.
        charts: [...section.querySelectorAll("figure.benchmark-chart")].map((figure) => ({
          caption: figure.querySelector("h3")?.textContent.trim() || "",
          solvers: [...figure.querySelectorAll(".benchmark-chart__row")]
            .map((row) => row.querySelector(".benchmark-chart__label")?.textContent.trim() || ""),
          // An empty panel must carry its reason in prose, or the reader is
          // left to guess why a comparison is missing.
          captionReason: (figure.querySelector("figcaption p")?.textContent.trim() || "").length > 40,
          rows: figure.querySelectorAll(".benchmark-chart__row").length,
          bars: figure.querySelectorAll(".benchmark-chart__bar").length,
          missing: figure.querySelectorAll(".benchmark-chart__bar--missing").length,
          unfilled: [...figure.querySelectorAll(".benchmark-chart__bar:not(.benchmark-chart__bar--missing)")]
            .filter((bar) => {
              const declared = bar.style.getPropertyValue("--benchmark-bar-fill");
              return !declared || !Number.isFinite(parseFloat(declared));
            }).length,
          painted: [...figure.querySelectorAll(".benchmark-chart__bar:not(.benchmark-chart__bar--missing)")]
            .filter((bar) => bar.getBoundingClientRect().width > 0.5).length,
          // A measured zero must be marked so it is drawn at a visible width:
          // a solver that failed every instance and a solver that was never run
          // must not render identically.
          firstGates: [...figure.querySelectorAll("[data-benchmark-first-gate]")].map((bar) => ({
            solver: bar.closest(".benchmark-chart__row").querySelector(".benchmark-chart__label").textContent.trim(),
            budget: Number(bar.closest(".benchmark-chart__budget").dataset.budget),
            count: Number(bar.dataset.benchmarkFirstGate),
          })),
          measuredZero: [...figure.querySelectorAll(".benchmark-chart__bar")]
            .filter((bar) => parseFloat(bar.style.getPropertyValue("--benchmark-bar-fill")) === 0).length,
          markedZero: figure.querySelectorAll(".benchmark-chart__bar--zero").length,
          swatches: section.querySelectorAll(".benchmark-charts__legend-item").length,
        })),
      })),
      unavailableHeadings: [...document.querySelectorAll("section.benchmark-unavailable h2")]
        .map((heading) => heading.textContent.trim()),
    }));

    if (rendered.stylesheets === 0) {
      failures.push({ path: "/benchmarks/", issue: "page loaded without the site stylesheet" });
    }
    if (rendered.sections.length !== data.problems.length) {
      failures.push({
        path: "/benchmarks/",
        issue: `expected ${data.problems.length} problem sections`,
        found: rendered.sections.length,
      });
    }
    if (new Set(rendered.sections.map((section) => section.id)).size !== rendered.sections.length) {
      failures.push({ path: "/benchmarks/", issue: "a problem section id is duplicated" });
    }

    for (const problem of data.problems) {
      const section = rendered.sections.find((candidate) => candidate.id === problem.benchmark_name);
      if (!section) {
        failures.push({
          path: "/benchmarks/",
          issue: `publishable problem ${problem.benchmark_name} is not on the page`,
        });
        continue;
      }
      if (section.heading !== problem.title) {
        failures.push({
          path: "/benchmarks/",
          issue: `${problem.benchmark_name} shows the wrong heading`,
          found: section.heading,
          expected: problem.title,
        });
      }
      if (section.tables.length !== problem.time_limits_seconds.length) {
        failures.push({
          path: "/benchmarks/",
          issue: `${problem.benchmark_name} shows ${problem.time_limits_seconds.length} budgets`,
          found: section.tables.length,
        });
      }
      // Tables and charts share gate coverage and quality ranking.
      const expectedHeaders = [
        "Solver / tested version",
        "Feasible",
        "Mean gap",
        "Mean cost",
        "Runtime (feasible)",
        "Mean runtime",
        "Over budget",
      ];
      for (const table of section.tables) {
        if (table.headers.join("|") !== expectedHeaders.join("|")) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} table columns do not follow feasibility then quality`,
            found: table.headers,
            expected: expectedHeaders,
          });
          break;
        }
      }
      // Every tested budget must contribute its own rows, derived from the run's
      // own summaries so adding a budget cannot pass by rendering an empty table.
      const expectedRows = problem.summaries.length;
      if (section.rows !== expectedRows) {
        failures.push({
          path: "/benchmarks/",
          issue: `${problem.benchmark_name} expected ${expectedRows} solver rows`,
          found: section.rows,
        });
      }
      if (!section.provenance) {
        failures.push({
          path: "/benchmarks/",
          issue: `${problem.benchmark_name} publishes results without run provenance`,
        });
      }
      if (section.completed.slice(0, 10) !== problem.completed_at.slice(0, 10)) {
        failures.push({
          path: "/benchmarks/",
          issue: `${problem.benchmark_name} shows the wrong completion date`,
          found: section.completed,
          expected: problem.completed_at,
        });
      }

      // Reference provenance must be stated, and the page must agree with the
      // imported catalogs: a gap whose reference is unstated is unauditable, and
      // a page claiming full coverage for a partly covered problem is wrong.
      const coverageText = (section.referencesText || "").replace(/\s+/g, " ");
      if (!coverageText) {
        failures.push({
          path: "/benchmarks/",
          issue: `${problem.benchmark_name} states no reference provenance`,
        });
      } else {
        if (problem.reference_present && problem.reference_covers_run) {
          if (!coverageText.includes(`all ${problem.instances} instances`)) {
            failures.push({
              path: "/benchmarks/",
              issue: `${problem.benchmark_name} reference coverage disagrees with the catalog`,
              found: coverageText.slice(0, 140),
              expected: `all ${problem.instances} instances`,
            });
          }
        } else if (problem.reference_present) {
          // State what the run could grade against, not the catalog's size: a
          // catalog holding values for tuples this run never selects covers
          // none of them, and quoting its size beside the instance count reads
          // as coverage the run does not have.
          const expected =
            `${problem.reference_covered_run_instances} of ${problem.instances}`;
          if (!coverageText.includes(expected)) {
            failures.push({
              path: "/benchmarks/",
              issue: `${problem.benchmark_name} reference coverage disagrees with what the run graded`,
              found: coverageText.slice(0, 140),
              expected,
            });
          }
          if (!/not in this set|not these|outside the published|does not select/i.test(coverageText)) {
            failures.push({
              path: "/benchmarks/",
              issue: `${problem.benchmark_name} does not say the run's instances are outside the published reference set`,
              found: coverageText.slice(0, 140),
            });
          }
        }
        if (problem.reference_present) {
          for (const source of problem.reference_sources) {
            if (!coverageText.includes(source.name)) {
              failures.push({
                path: "/benchmarks/",
                issue: `${problem.benchmark_name} does not name its reference source`,
                missing: source.name,
              });
            }
          }
          // A best-known bound must not be presented as a proven optimum.
          const onlyBounds =
            problem.reference_kinds.length === 1 &&
            problem.reference_kinds[0] === "best_known_upper_bound";
          if (onlyBounds && !/not proven optima/i.test(coverageText)) {
            failures.push({
              path: "/benchmarks/",
              issue: `${problem.benchmark_name} presents best known bounds without saying they are not optima`,
              found: coverageText.slice(0, 140),
            });
          }
        } else if (!/no published reference/i.test(coverageText)) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} has no references but does not say so`,
            found: coverageText.slice(0, 140),
          });
        }
      }

      // Charts must cover the same solvers and budgets the tables do, in the
      // priority order: feasibility, earliest observed gate, then quality.
      // Both the count and the order are checked, so a
      // panel cannot be dropped or moved below a lower-priority one.
      const expectedBars = problem.solvers.length * problem.time_limits_seconds.length;
      const drawableGaps = problem.summaries.some((row) => Number(row.gap_percent) > 0);
      // Feasibility and first-gate counts always draw, including measured zero.
      // The quality panel is drawn only when the run holds a usable mean
      // gap, and states its absence in prose otherwise.
      const expectedCharts = 3;
      if (section.charts.length !== expectedCharts) {
        failures.push({
          path: "/benchmarks/",
          issue: `${problem.benchmark_name} should draw ${expectedCharts} chart panels`,
          found: section.charts.length,
        });
      }
      // The solvers themselves are ranked, not merely the columns: each chart
      // and table must read top to bottom in the page's stated priority order.
      // The expected order is recomputed here from the committed measurements,
      // not read from the file, so an importer bug cannot move both the page and
      // the expectation together. A rank that is present but wrong is worse than
      // no rank, because it reads as a considered ordering.
      const expectedRank = rankSolvers(problem);
      const pageRank = problem.solvers;
      if (pageRank.join("|") !== expectedRank.join("|")) {
        failures.push({
          path: "/benchmarks/",
          issue: `${problem.benchmark_name} ranked solvers ${JSON.stringify(pageRank)} but the measurements rank them ${JSON.stringify(expectedRank)}`,
        });
      }
      const chartRank = [...problem.time_limits_seconds].sort((a, b) => a - b)
        .flatMap((budget) => rankSolvers(problem, budget));
      for (const chart of section.charts) {
        if (chart.solvers.length > 0 && chart.solvers.join("|") !== chartRank.join("|")) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} chart "${chart.caption}" does not rank solvers by feasibility then quality`,
            found: chart.solvers,
            expected: chartRank,
          });
          break;
        }
      }
      for (const table of section.tables) {
        const tableRank = rankSolvers(problem, table.budget);
        if (table.solvers.length === 0 || table.solvers.join("|") !== tableRank.join("|")) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} ${table.budget}s table does not rank solvers by feasibility then quality`,
            found: table.solvers,
            expected: tableRank,
          });
          break;
        }
      }
      const gateChart = section.charts.find((chart) => chart.caption === "First feasible gate");
      const evidence = JSON.parse(readFileSync("src/benchmarks/results.json", "utf8"));
      const earliest = new Map();
      for (const row of evidence.results) {
        if (row.benchmark_name !== problem.benchmark_name || row.hard_feasible !== true) continue;
        const key = `${row.solver}|${row.instance}`;
        earliest.set(key, Math.min(earliest.get(key) ?? Infinity, row.time_limit_seconds));
      }
      if (!gateChart || gateChart.firstGates.length !== expectedBars) {
        failures.push({ path: "/benchmarks/", issue: `${problem.benchmark_name} missing first feasible gate counts` });
      } else {
        for (const value of gateChart.firstGates) {
          const count = [...earliest].filter(([key, gate]) => key.startsWith(`${value.solver}|`) && gate === value.budget).length;
          if (value.count !== count) failures.push({ path: "/benchmarks/", issue: `${problem.benchmark_name} wrong first feasible gate count`, value, expected: count });
        }
      }
      const expectedOrder = ["Feasible results", "First feasible gate", "Mean gap to reference"];
      const renderedOrder = section.charts.map((chart) => chart.caption);
      for (let i = 0; i < renderedOrder.length; i += 1) {
        if (renderedOrder[i] !== expectedOrder[i]) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} chart order does not follow feasibility then quality`,
            found: renderedOrder,
            expected: expectedOrder.slice(0, renderedOrder.length),
          });
          break;
        }
      }
      for (const chart of section.charts) {
        if (chart.rows === 0) {
          if (chart.bars !== 0 || chart.missing !== 0 || chart.painted !== 0) {
            failures.push({
              path: "/benchmarks/",
              issue: `${problem.benchmark_name} chart "${chart.caption}" is empty but still renders bars`,
              bars: chart.bars,
              missing: chart.missing,
              painted: chart.painted,
            });
          }
          continue;
        }
        if (chart.rows !== expectedBars) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} chart "${chart.caption}" expected ${expectedBars} budget-specific solver rows`,
            found: chart.rows,
          });
        }
        if (chart.bars !== expectedBars) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} chart "${chart.caption}" expected ${expectedBars} bars`,
            found: chart.bars,
          });
        }
        if (chart.unfilled !== 0) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} chart "${chart.caption}" has bars with no measurable fill`,
            found: chart.unfilled,
          });
        }
        if (chart.painted !== chart.bars - chart.missing) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} chart "${chart.caption}" has a measurement that renders at zero width`,
            painted: chart.painted,
            expected: chart.bars - chart.missing,
            missing: chart.missing,
          });
        }
        if (chart.markedZero !== chart.measuredZero) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} chart "${chart.caption}" has a measured zero that is drawn like a missing measurement`,
            measuredZero: chart.measuredZero,
            markedZero: chart.markedZero,
          });
        }
        if (chart.swatches !== problem.time_limits_seconds.length) {
          failures.push({
            path: "/benchmarks/",
            issue: `${problem.benchmark_name} legend does not name every tested budget`,
            found: chart.swatches,
          });
        }
      }
      // An empty quality panel is only honest if it says why it is empty.
      const emptyGapPanel = !drawableGaps && section.charts.some((chart) => chart.rows === 0);
      if (emptyGapPanel && !section.charts.some((chart) => chart.rows === 0 && chart.captionReason)) {
        failures.push({
          path: "/benchmarks/",
          issue: `${problem.benchmark_name} shows an empty quality panel without stating why`,
        });
      }
    }

    for (const problem of data.unavailable) {
      if (!rendered.unavailableHeadings.some((heading) => heading === problem.title)) {
        failures.push({
          path: "/benchmarks/",
          issue: `problem without a publishable run (${problem.id}) is not reported as unavailable`,
        });
      }
    }
    if (rendered.unavailableHeadings.length !== data.unavailable.length) {
      failures.push({
        path: "/benchmarks/",
        issue: "unavailable-problem headings do not match the imported data",
        found: rendered.unavailableHeadings,
      });
    }
  } catch (error) {
    failures.push({ path: "/benchmarks/", issue: "benchmarks page check threw", error: String(error) });
  }

  await context.close();
  await browser.close();
  return failures;
}

async function checkBenchmarksDocs(origin) {
  // The docs page is where a reader learns what a published gap was measured
  // against. It must carry the reference mechanism and the per-problem coverage,
  // and it must name the gate that keeps a hand-edited value from shipping.
  const browser = await chromium.launch({
    ...chromiumOptions(),
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1100 },
  });
  const page = await context.newPage();
  const failures = [];
  const path = "/docs/solverforge-bench/";

  try {
    const response = await page.goto(`${origin}${path}`, { waitUntil: "load" });
    if (!response || response.status() !== 200) {
      failures.push({ path, issue: "docs page not served", status: response?.status() });
    }
    const rendered = await page.evaluate(() => ({
      stylesheets: [...document.querySelectorAll('link[rel="stylesheet"]')].length,
      text: document.body.innerText.replace(/\s+/g, " "),
    }));

    if (rendered.stylesheets === 0) {
      failures.push({ path, issue: "docs page loaded without the site stylesheet" });
    }
    for (const required of [
      "Official References",
      "make verify-reference-catalogs",
      "make load-reference-catalogs",
      "benchmark_reference_resolved",
      "proven optimum",
      "best known upper bound",
    ]) {
      if (!rendered.text.includes(required)) {
        failures.push({ path, issue: `docs page does not state the reference mechanism`, missing: required });
      }
    }
    // Coverage per problem must appear, and must state what the run could
    // actually grade against. The catalog's size is not that number: a catalog
    // holding values for tuples the selection never runs covers none of them,
    // and quoting its size beside the run's instance count reads as coverage.
    const data = JSON.parse(readFileSync(benchmarksDataPath, "utf8"));
    for (const problem of data.problems) {
      const expected = `${problem.reference_covered_run_instances} of ${problem.instances}`;
      if (!rendered.text.includes(expected)) {
        failures.push({
          path,
          issue: `docs page does not state ${problem.benchmark_name} reference coverage`,
          expected,
        });
      }
    }
  } catch (error) {
    failures.push({ path, issue: "benchmarks docs check threw", error: String(error) });
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
let useCasePages = [];
let benchmarksPage = [];
let benchmarksDocs = [];

try {
  layoutFailures = await checkLayout(origin, paths);
  docsSidebarActive = await checkDocsSidebarActive(origin);
  useCaseShowcase = await checkUseCaseShowcase(origin);
  useCasePages = await checkUseCasePages(origin);
  benchmarksPage = await checkBenchmarksPage(origin);
  benchmarksDocs = await checkBenchmarksDocs(origin);
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
  useCasePages,
  benchmarksPage,
  benchmarksDocs,
  layoutFailures,
};

console.log(JSON.stringify(summary, null, 2));

if (
  staleCopy.length ||
  missingLinks.length ||
  docsIndexTargets.length ||
  docsSidebarActive.length ||
  useCaseShowcase.length ||
  useCasePages.length ||
  benchmarksPage.length ||
  benchmarksDocs.length ||
  layoutFailures.length
) {
  process.exit(1);
}
