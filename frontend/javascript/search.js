const SEARCH_MIN_QUERY_LENGTH = 2
const RESULT_LIMITS = {
  overlay: 8,
  page: 24,
}

let searchIndexPromise

const normalizeText = value =>
  (value || "")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9.+#_\-/:\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim()

const tokenize = value => {
  const tokens = normalizeText(value).match(/[a-z0-9][a-z0-9.+#-]*/g) || []
  const expanded = []

  tokens.forEach(token => {
    expanded.push(token)
    token
      .split(/[-_:\/]+/)
      .filter(Boolean)
      .forEach(part => expanded.push(part))
  })

  return [...new Set(expanded.filter(token => token.length > 1))]
}

const escapeHtml = value =>
  (value || "").replace(/[&<>"']/g, char => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[char])

const escapeRegExp = value => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")

const isSubsequence = (needle, haystack) => {
  let index = 0

  for (const char of haystack) {
    if (char === needle[index]) {
      index += 1
      if (index === needle.length) return true
    }
  }

  return false
}

const subsequenceSpan = (needle, haystack) => {
  let first = -1
  let last = -1
  let index = 0

  for (let position = 0; position < haystack.length; position += 1) {
    if (haystack[position] !== needle[index]) continue
    if (first === -1) first = position
    last = position
    index += 1
    if (index === needle.length) break
  }

  return first === -1 || last === -1 ? haystack.length : (last - first + 1)
}

const fuzzyTokenScore = (queryToken, candidateToken) => {
  if (queryToken.length < 2 || candidateToken.length < queryToken.length) return 0
  if (!isSubsequence(queryToken, candidateToken)) return 0

  const span = subsequenceSpan(queryToken, candidateToken)
  const compactness = queryToken.length / Math.max(span, 1)
  const coverage = queryToken.length / Math.max(candidateToken.length, 1)

  return 12 + compactness * 24 + coverage * 18
}

const scoreField = (query, fieldValue, weight) => {
  if (!fieldValue) return 0
  if (fieldValue === query) return 170 * weight
  if (fieldValue.startsWith(query)) return (132 + query.length * 2) * weight
  if (fieldValue.includes(query)) return (104 + Math.min(query.length, 12)) * weight

  let best = 0

  fieldValue.split(" ").forEach(word => {
    if (word === query) {
      best = Math.max(best, 120)
      return
    }
    if (word.startsWith(query)) {
      best = Math.max(best, 96)
      return
    }
    if (word.includes(query)) {
      best = Math.max(best, 72)
      return
    }
    best = Math.max(best, fuzzyTokenScore(query, word))
  })

  return best * weight
}

const scoreDocument = (query, queryTokens, document) => {
  let score = document.priority || 0
  let matchedTokens = 0

  score += scoreField(query, document.search_title, 2.4)
  score += scoreField(query, document.search_section, 1.8)
  score += scoreField(query, document.search_text, 0.85)

  queryTokens.forEach(token => {
    let best = 0

    document.terms.forEach(term => {
      if (term === token) {
        best = Math.max(best, 44)
        return
      }
      if (term.startsWith(token)) {
        best = Math.max(best, 32 + Math.min(token.length, 7))
        return
      }
      if (term.includes(token)) {
        best = Math.max(best, 24)
        return
      }
      best = Math.max(best, fuzzyTokenScore(token, term))
    })

    if (best > 0) matchedTokens += 1
    score += best
  })

  if (queryTokens.length > 0) {
    if (matchedTokens === queryTokens.length) {
      score += 52 + queryTokens.length * 8
    } else {
      score -= (queryTokens.length - matchedTokens) * 20
    }
  }

  if (document.entry_type === "section") score += 8
  if (document.section && document.search_section?.startsWith(query)) score += 12
  if (document.search_title?.includes(query) && document.search_section?.includes(query)) score += 14

  return score
}

const buildSnippet = (document, queryTokens) => {
  const source = document.excerpt || document.description || ""
  if (!source) return ""

  const lower = source.toLowerCase()
  let bestIndex = Infinity

  queryTokens.forEach(token => {
    const matchIndex = lower.indexOf(token.toLowerCase())
    if (matchIndex !== -1 && matchIndex < bestIndex) bestIndex = matchIndex
  })

  if (!Number.isFinite(bestIndex) || bestIndex < 80) return source

  const start = Math.max(bestIndex - 60, 0)
  const end = Math.min(start + 220, source.length)
  const prefix = start > 0 ? "…" : ""
  const suffix = end < source.length ? "…" : ""

  return `${prefix}${source.slice(start, end).trim()}${suffix}`
}

const highlight = (text, queryTokens) => {
  if (!text) return ""
  if (queryTokens.length === 0) return escapeHtml(text)

  const pattern = new RegExp(`(${queryTokens.map(escapeRegExp).join("|")})`, "ig")
  return escapeHtml(text).replace(pattern, "<mark>$1</mark>")
}

const formatMeta = document => {
  const parts = [document.kind_label]
  if (document.group_label) parts.push(document.group_label)
  if (document.date_display) parts.push(document.date_display)
  return parts
}

const rankDocuments = (documents, query, scope, mode) => {
  const normalizedQuery = normalizeText(query)
  const queryTokens = tokenize(query)
  const limit = RESULT_LIMITS[mode] || RESULT_LIMITS.page
  const perPageLimit = mode === "overlay" ? 1 : 2

  if (normalizedQuery.length < SEARCH_MIN_QUERY_LENGTH) return []

  const ranked = documents
    .filter(document => scope === "all" || document.kind === scope)
    .map(document => ({
      ...document,
      score: scoreDocument(normalizedQuery, queryTokens, document),
    }))
    .filter(document => document.score >= 42)
    .sort((left, right) => right.score - left.score)

  const countsByPage = new Map()
  const limited = []

  for (const document of ranked) {
    const count = countsByPage.get(document.page_url) || 0
    if (count >= perPageLimit) continue
    countsByPage.set(document.page_url, count + 1)
    limited.push(document)
    if (limited.length >= limit) break
  }

  return limited
}

const renderResults = (root, documents, query, scope, state) => {
  const status = root.querySelector("[data-search-status]")
  const resultsFrame = root.querySelector("[data-search-results-frame]")
  const results = root.querySelector("[data-search-results]")
  const emptyState = root.querySelector("[data-search-empty]")
  const queryTokens = tokenize(query)

  if (normalizeText(query).length < SEARCH_MIN_QUERY_LENGTH) {
    resultsFrame.hidden = true
    emptyState.hidden = false
    status.textContent = "Try a concept, version, component name, or problem type."
    state.activeIndex = -1
    return
  }

  emptyState.hidden = true
  resultsFrame.hidden = false

  if (documents.length === 0) {
    results.innerHTML = `
      <article class="search-result-card search-result-card--empty">
        <h3>No matches for “${escapeHtml(query)}”.</h3>
        <p>Try a shorter name, a partial version, or switch the scope.</p>
      </article>
    `
    status.textContent = `No results in ${scope === "all" ? "the full site" : scope}.`
    state.activeIndex = -1
    return
  }

  status.textContent = `${documents.length} result${documents.length === 1 ? "" : "s"} for “${query}” in ${scope === "all" ? "the full site" : scope}.`

  results.innerHTML = documents.map((document, index) => `
    <a class="search-result-card${index === state.activeIndex ? " is-active" : ""}" href="${document.url}" data-search-result data-search-index="${index}">
      <div class="search-result-card__meta">
        ${formatMeta(document).map(part => `<span>${escapeHtml(part)}</span>`).join("")}
      </div>
      <h3 class="search-result-card__title">${highlight(document.title, queryTokens)}</h3>
      ${document.section ? `<p class="search-result-card__section">${highlight(document.section, queryTokens)}</p>` : ""}
      <p class="search-result-card__snippet">${highlight(buildSnippet(document, queryTokens), queryTokens)}</p>
    </a>
  `).join("")
}

const updateScopeButtons = (root, scope) => {
  root.querySelectorAll("[data-search-scope]").forEach(button => {
    const active = button.dataset.searchScope === scope
    button.classList.toggle("is-active", active)
    button.setAttribute("aria-pressed", String(active))
  })
}

const syncSearchPageUrl = (state, mode) => {
  if (mode !== "page") return

  const url = new URL(window.location.href)
  if (state.query) {
    url.searchParams.set("q", state.query)
  } else {
    url.searchParams.delete("q")
  }

  if (state.scope && state.scope !== "all") {
    url.searchParams.set("scope", state.scope)
  } else {
    url.searchParams.delete("scope")
  }

  window.history.replaceState({}, "", url)
}

const fetchSearchIndex = async root => {
  if (!searchIndexPromise) {
    const indexUrl = root.dataset.searchIndexUrl
    searchIndexPromise = fetch(indexUrl).then(async response => {
      if (!response.ok) {
        throw new Error(`Search index request failed with ${response.status}`)
      }
      const payload = await response.json()
      return payload.documents || []
    })
  }

  return searchIndexPromise
}

const runSearch = async (root, state) => {
  const status = root.querySelector("[data-search-status]")

  try {
    const documents = await fetchSearchIndex(root)
    const ranked = rankDocuments(documents, state.query, state.scope, state.mode)

    if (state.activeIndex >= ranked.length) {
      state.activeIndex = ranked.length > 0 ? 0 : -1
    }

    renderResults(root, ranked, state.query, state.scope, state)
  } catch (error) {
    status.textContent = "Search index failed to load."
    root.querySelector("[data-search-results-frame]").hidden = false
    root.querySelector("[data-search-empty]").hidden = true
    root.querySelector("[data-search-results]").innerHTML = `
      <article class="search-result-card search-result-card--empty">
        <h3>Search is temporarily unavailable.</h3>
        <p>${escapeHtml(error.message)}</p>
      </article>
    `
  }

  syncSearchPageUrl(state, state.mode)
  updateScopeButtons(root, state.scope)
}

const focusActiveResult = root => {
  const active = root.querySelector('[data-search-result].is-active')
  if (active) active.focus()
}

const activateNextResult = (root, state, direction) => {
  const results = [...root.querySelectorAll("[data-search-result]")]
  if (results.length === 0) return

  state.activeIndex = state.activeIndex === -1 ? 0 : (state.activeIndex + direction + results.length) % results.length
  results.forEach((result, index) => {
    result.classList.toggle("is-active", index === state.activeIndex)
  })
  focusActiveResult(root)
}

const openOverlay = overlayRoot => {
  if (!overlayRoot) return
  overlayRoot.hidden = false
  document.body.classList.add("search-overlay-open")
  window.setTimeout(() => {
    overlayRoot.querySelector("[data-search-input]")?.focus()
    overlayRoot.querySelector("[data-search-input]")?.select()
  }, 0)
}

const closeOverlay = overlayRoot => {
  if (!overlayRoot) return
  overlayRoot.hidden = true
  document.body.classList.remove("search-overlay-open")
}

const initializeSearchRoot = root => {
  const queryInput = root.querySelector("[data-search-input]")
  const clearButton = root.querySelector("[data-search-clear]")
  const overlay = root.dataset.searchMode === "overlay"
  const state = {
    mode: root.dataset.searchMode,
    scope: "all",
    query: "",
    activeIndex: -1,
  }

  if (state.mode === "page") {
    const params = new URLSearchParams(window.location.search)
    state.query = params.get("q") || ""
    state.scope = ["all", "docs", "reference", "blog", "pages"].includes(params.get("scope"))
      ? params.get("scope")
      : "all"
    queryInput.value = state.query
  }

  queryInput.addEventListener("input", async event => {
    state.query = event.target.value.trim()
    state.activeIndex = 0
    await runSearch(root, state)
  })

  queryInput.addEventListener("keydown", event => {
    if (event.key === "ArrowDown") {
      event.preventDefault()
      activateNextResult(root, state, 1)
      return
    }
    if (event.key === "ArrowUp") {
      event.preventDefault()
      activateNextResult(root, state, -1)
      return
    }
    if (event.key === "Escape" && overlay) {
      event.preventDefault()
      closeOverlay(root)
      return
    }
    if (event.key === "Enter" && state.activeIndex >= 0) {
      const active = root.querySelector(`[data-search-result][data-search-index="${state.activeIndex}"]`)
      if (active) {
        event.preventDefault()
        window.location.href = active.getAttribute("href")
      }
    }
  })

  clearButton.addEventListener("click", async () => {
    state.query = ""
    state.activeIndex = -1
    queryInput.value = ""
    queryInput.focus()
    await runSearch(root, state)
  })

  root.querySelectorAll("[data-search-scope]").forEach(button => {
    button.addEventListener("click", async () => {
      state.scope = button.dataset.searchScope
      state.activeIndex = 0
      await runSearch(root, state)
    })
  })

  root.addEventListener("click", event => {
    const result = event.target.closest("[data-search-result]")
    if (!result) return
    state.activeIndex = Number(result.dataset.searchIndex)
  })

  if (overlay) {
    root.querySelectorAll("[data-search-close]").forEach(button => {
      button.addEventListener("click", () => closeOverlay(root))
    })
  }

  runSearch(root, state)

  return { root, state }
}

export const initializeSearch = () => {
  const roots = [...document.querySelectorAll("[data-search-root]")]
  if (roots.length === 0) return

  const searchRoots = roots.map(initializeSearchRoot)
  const overlayRoot = searchRoots.find(entry => entry?.state.mode === "overlay")?.root
  const pageRoot = searchRoots.find(entry => entry?.state.mode === "page")?.root

  document.querySelectorAll("[data-search-open]").forEach(link => {
    link.addEventListener("click", event => {
      if (pageRoot && window.location.pathname === new URL(link.href, window.location.origin).pathname) {
        event.preventDefault()
        pageRoot.querySelector("[data-search-input]")?.focus()
        pageRoot.querySelector("[data-search-input]")?.select()
        return
      }

      event.preventDefault()
      openOverlay(overlayRoot)
    })
  })

  document.addEventListener("keydown", event => {
    const target = event.target
    const inEditableField =
      target instanceof HTMLElement &&
      (target.matches("input, textarea, select") || target.isContentEditable)

    if ((event.key === "k" && (event.metaKey || event.ctrlKey)) || (event.key === "/" && !inEditableField)) {
      event.preventDefault()
      if (pageRoot && window.location.pathname === new URL(pageRoot.dataset.searchPageUrl, window.location.origin).pathname) {
        pageRoot.querySelector("[data-search-input]")?.focus()
        pageRoot.querySelector("[data-search-input]")?.select()
        return
      }
      openOverlay(overlayRoot)
      return
    }

    if (event.key === "Escape" && !overlayRoot?.hidden) {
      event.preventDefault()
      closeOverlay(overlayRoot)
    }
  })
}
