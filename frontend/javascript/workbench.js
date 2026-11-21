// The constraint explorer on /docs/solverforge-workbench/constraints/: the
// Workbench's own fuzzy search over every stock model's constraints. A
// substring always matches; otherwise the letters appear in order, the first
// at a word start, each later one inside the word of the one before or at the
// start of a later word: "rst btwn" finds "Rest between shifts".

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

const FIELDS = [["name", 1], ["group", 0.6], ["level", 0.6], ["modelName", 0.5], ["description", 0.4]]

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
        const m = fuzzyMatch(term, rule[field])
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

export const initializeWorkbenchExplorer = () => {
  const root = document.querySelector("[data-workbench-explorer]")
  if (!root) return
  const input = root.querySelector("[data-workbench-query]")
  const model = root.querySelector("[data-workbench-model]")
  const level = root.querySelector("[data-workbench-level]")
  const list = root.querySelector("[data-workbench-list]")
  const status = root.querySelector("[data-workbench-status]")
  const empty = root.querySelector("[data-workbench-empty]")
  const rules = [...list.children].map(item => ({
    item,
    anchor: item.querySelector("[data-workbench-name]"),
    name: item.dataset.name,
    group: item.dataset.group,
    level: item.dataset.level,
    model: item.dataset.model,
    modelName: item.dataset.modelName,
    description: item.dataset.description,
  }))
  const total = rules.length

  const params = new URLSearchParams(window.location.search)
  input.value = params.get("q") || ""
  if (params.get("model")) model.value = params.get("model")
  if (params.get("level")) level.value = params.get("level")

  const render = () => {
    const pool = rules.filter(r => (!model.value || r.model === model.value) && (!level.value || r.level === level.value))
    const results = searchRules(pool, input.value)
    const shown = new Set(results.map(r => r.rule))
    rules.forEach(r => { r.item.hidden = !shown.has(r) })
    results.forEach(({ rule, hits }) => {
      highlight(rule.anchor, rule.name, hits)
      list.append(rule.item)
    })
    status.textContent = results.length === total ? `${total} constraints` : `${results.length} of ${total} constraints`
    empty.hidden = results.length > 0
    root.dataset.workbenchShown = String(results.length)
    const next = new URLSearchParams()
    if (input.value.trim()) next.set("q", input.value.trim())
    if (model.value) next.set("model", model.value)
    if (level.value) next.set("level", level.value)
    const query = next.toString()
    window.history.replaceState(null, "", query ? `?${query}` : window.location.pathname)
  }

  input.addEventListener("input", render)
  model.addEventListener("change", render)
  level.addEventListener("change", render)
  render()
  root.dataset.workbenchReady = "true"
}
