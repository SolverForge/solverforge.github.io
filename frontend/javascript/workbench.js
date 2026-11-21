// SolverForge Workbench docs: the Workbench's own fuzzy search over a model's
// constraints, and one search across all four models. A substring always
// matches; otherwise the letters appear in order, the first at a word start,
// each later one inside the word of the one before or at the start of a later
// word: "rst btwn" finds "Rest between shifts".

const WORD_START = /[\s\-_/·:(,]/

export const fuzzyMatch = (needle, hay) => {
  const q = Array.from(String(needle || "").toLowerCase())
  const t = Array.from(String(hay || "").toLowerCase())
  if (!q.length) return { score: 0, hits: [] }
  const starts = t.map((_, j) => j === 0 || WORD_START.test(t[j - 1]))
  const exact = t.join("").indexOf(q.join(""))
  if (exact >= 0) {
    return { score: 100 + q.length * 4 + (starts[exact] ? 40 : 0) - exact * 0.1, hits: q.map((_, i) => exact + i) }
  }
  const best = q.map(() => new Array(t.length).fill(-Infinity))
  const from = q.map(() => new Array(t.length).fill(-1))
  for (let j = 0; j < t.length; j++) if (t[j] === q[0] && starts[j]) best[0][j] = j === 0 ? 12 : 10
  const separator = t.map(ch => WORD_START.test(ch))
  for (let i = 1; i < q.length; i++) {
    let lead = -Infinity
    let leadAt = -1
    let word = -Infinity
    let wordAt = -1
    for (let j = 0; j < t.length; j++) {
      if (starts[j]) { word = -Infinity; wordAt = -1 }
      if (t[j] === q[i] && !separator[j]) {
        const options = [
          [j > 0 ? best[i - 1][j - 1] + 8 : -Infinity, j - 1],
          [starts[j] ? lead + 6 : -Infinity, leadAt],
          [word + 3, wordAt],
        ]
        for (const [score, at] of options) if (score > best[i][j]) { best[i][j] = score; from[i][j] = at }
      }
      if (best[i - 1][j] > lead) { lead = best[i - 1][j]; leadAt = j }
      if (best[i - 1][j] > word) { word = best[i - 1][j]; wordAt = j }
    }
  }
  const last = best[q.length - 1]
  let end = -1
  for (let j = 0; j < t.length; j++) if (last[j] > -Infinity && (end < 0 || last[j] > last[end])) end = j
  if (end < 0) return null
  const hits = []
  for (let i = q.length - 1, j = end; i >= 0; j = from[i][j], i--) hits.unshift(j)
  return { score: last[end], hits }
}

const FIELDS = [["name", 1], ["group", 0.6], ["level", 0.6], ["modelName", 0.5], ["description", 0.4], ["text", 0.3]]

/** Every term must match some field; best first. `hits` index into the name. */
export const searchRules = (rules, query) => {
  const terms = String(query || "").trim().split(/\s+/).filter(Boolean)
  if (!terms.length) return rules.map(rule => ({ rule, score: 0, hits: [] }))
  const found = []
  for (const rule of rules) {
    let total = 0
    let matched = true
    let previous = -1
    const hits = new Set()
    for (const term of terms) {
      let best = null
      for (const [field, weight] of FIELDS) {
        // An explanation is long enough for scattered letters to match
        // anything, so it counts only when it holds the term itself.
        const m = field === "text"
          ? (String(rule.text || "").toLowerCase().includes(term.toLowerCase()) ? { score: 100 + term.length * 4, hits: [] } : null)
          : fuzzyMatch(term, rule[field])
        if (m && (!best || m.score * weight > best.score)) best = { score: m.score * weight, field, hits: m.hits }
      }
      if (!best) { matched = false; break }
      total += best.score
      if (best.field === "name") {
        if (best.hits[0] > previous && previous >= 0) total += 8
        previous = best.hits[best.hits.length - 1]
        best.hits.forEach(h => hits.add(h))
      }
    }
    if (matched) found.push({ rule, score: total, hits: [...hits].sort((x, y) => x - y) })
  }
  return found.sort((x, y) => y.score - x.score)
}

const highlight = (anchor, text, hits) => {
  anchor.textContent = ""
  const marks = new Set(hits)
  const chars = Array.from(text)
  let run = ""
  let marked = false
  const flush = () => {
    if (!run) return
    if (marked) {
      const mark = document.createElement("mark")
      mark.textContent = run
      anchor.append(mark)
    } else {
      anchor.append(run)
    }
    run = ""
  }
  chars.forEach((ch, i) => {
    const on = marks.has(i)
    if (on !== marked) { flush(); marked = on }
    run += ch
  })
  flush()
}

const params = () => new URLSearchParams(window.location.search)

const keepQuery = (query, extra = {}) => {
  const next = new URLSearchParams()
  if (query.trim()) next.set("q", query.trim())
  for (const [key, value] of Object.entries(extra)) if (value) next.set(key, value)
  const search = next.toString()
  window.history.replaceState(null, "", `${window.location.pathname}${search ? `?${search}` : ""}${window.location.hash}`)
}

// A model's constraints page: every constraint heading and the explanation
// under it fold into one card that opens in place; a link to a constraint
// opens its card and scrolls to it.
export const initializeWorkbenchRules = () => {
  const toolbar = document.querySelector("[data-workbench-rules]")
  if (!toolbar) return
  const prose = toolbar.closest(".prose") || document
  const input = toolbar.querySelector("[data-workbench-query]")
  const level = toolbar.querySelector("[data-workbench-level]")
  const status = toolbar.querySelector("[data-workbench-status]")

  const cards = [...prose.querySelectorAll("h3.wb-rule")].map(heading => {
    const card = document.createElement("details")
    card.className = "wb-card"
    card.id = heading.id
    heading.removeAttribute("id")
    card.dataset.level = heading.dataset.level
    const summary = document.createElement("summary")
    summary.className = "wb-card__summary"
    const name = document.createElement("span")
    name.className = "wb-card__name"
    const title = heading.firstChild.textContent.trim()
    name.textContent = title
    summary.append(name, ...[...heading.querySelectorAll(".wb-level")])
    if (heading.dataset.off) {
      const flag = document.createElement("span")
      flag.className = "wb-flag"
      flag.textContent = "off unless weighted"
      summary.append(flag)
    }
    const link = document.createElement("a")
    link.className = "wb-card__link"
    link.href = `#${card.id}`
    link.textContent = "#"
    link.setAttribute("aria-label", `Link to ${title}`)
    summary.append(link)
    const body = document.createElement("div")
    body.className = "wb-card__body"
    let next = heading.nextElementSibling
    while (next && !/^H[1-3]$/.test(next.tagName)) {
      const after = next.nextElementSibling
      body.append(next)
      next = after
    }
    card.append(summary, body)
    heading.replaceWith(card)
    return { card, name, title, level: card.dataset.level, group: heading.dataset.group, text: body.textContent }
  })
  const groups = [...prose.querySelectorAll("h2")].filter(h => h.id.startsWith("group-"))

  const openHash = () => {
    const id = decodeURIComponent(window.location.hash.slice(1))
    const card = id && cards.find(c => c.card.id === id)
    if (card) {
      card.card.open = true
      card.card.hidden = false
      card.card.scrollIntoView({ block: "start" })
    }
  }

  const render = () => {
    const pool = cards.filter(c => !level.value || c.level === level.value)
    const results = searchRules(pool.map(c => ({ ...c, name: c.title })), input.value)
    const shown = new Map(results.map(r => [r.rule.card, r.hits]))
    for (const c of cards) {
      c.card.hidden = !shown.has(c.card)
      highlight(c.name, c.title, shown.get(c.card) || [])
    }
    for (const group of groups) {
      let visible = false
      for (let el = group.nextElementSibling; el && el.tagName !== "H2"; el = el.nextElementSibling) {
        if (el.classList.contains("wb-card") && !el.hidden) visible = true
      }
      group.hidden = !visible
    }
    const filtered = input.value.trim() || level.value
    status.hidden = !filtered
    status.textContent = results.length ? `${results.length} of ${cards.length} constraints` : "No constraint matches. Try fewer letters or another level."
    toolbar.dataset.workbenchShown = String(results.length)
    keepQuery(input.value, { level: level.value })
  }

  const p = params()
  input.value = p.get("q") || ""
  if (p.get("level")) level.value = p.get("level")
  input.addEventListener("input", render)
  level.addEventListener("change", render)
  window.addEventListener("hashchange", openHash)
  render()
  openHash()
  toolbar.dataset.workbenchReady = "true"
}

// The section's front page: one search across every model, grouped by model,
// empty until something is typed.
export const initializeWorkbenchSearch = () => {
  const root = document.querySelector("[data-workbench-search]")
  if (!root) return
  const input = root.querySelector("[data-workbench-query]")
  const status = root.querySelector("[data-workbench-status]")
  const results = root.querySelector("[data-workbench-results]")
  const rules = JSON.parse(root.querySelector("[data-workbench-index]").textContent)

  const render = () => {
    results.textContent = ""
    const query = input.value.trim()
    keepQuery(input.value)
    if (!query) {
      status.hidden = true
      root.dataset.workbenchShown = "0"
      return
    }
    const found = searchRules(rules, query)
    status.hidden = false
    status.textContent = found.length ? `${found.length} constraints` : "No constraint matches. Try fewer letters."
    root.dataset.workbenchShown = String(found.length)
    const byModel = new Map()
    for (const hit of found) {
      if (!byModel.has(hit.rule.model)) byModel.set(hit.rule.model, [])
      byModel.get(hit.rule.model).push(hit)
    }
    for (const hits of byModel.values()) {
      const section = document.createElement("section")
      section.className = "wb-search__model"
      const heading = document.createElement("h3")
      heading.textContent = hits[0].rule.modelName
      const list = document.createElement("ol")
      list.className = "wb-search__list"
      for (const { rule, hits: marks } of hits.slice(0, 8)) {
        const item = document.createElement("li")
        item.className = "wb-hit"
        item.dataset.name = rule.name
        item.dataset.model = rule.model
        const anchor = document.createElement("a")
        anchor.href = rule.url
        highlight(anchor, rule.name, marks)
        const level = document.createElement("span")
        level.className = `wb-level wb-level--${rule.level}`
        level.textContent = rule.level
        const where = document.createElement("span")
        where.className = "wb-hit__where"
        where.textContent = rule.group
        item.append(anchor, level, where)
        list.append(item)
      }
      section.append(heading, list)
      if (hits.length > 8) {
        const more = document.createElement("a")
        more.className = "wb-search__more"
        more.href = `${hits[0].rule.url.split("#")[0]}?q=${encodeURIComponent(query)}`
        more.textContent = `All ${hits.length} in ${hits[0].rule.modelName}`
        section.append(more)
      }
      results.append(section)
    }
  }

  input.value = params().get("q") || ""
  input.addEventListener("input", render)
  render()
  root.dataset.workbenchReady = "true"
}
