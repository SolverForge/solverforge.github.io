const SELECTOR_QUERY = "[data-use-case-select]"
const SLIDE_QUERY = "[data-use-case-slide]"

// One slide per use case. The selector strip is a tablist, the slides are
// tabpanels, and the hash keeps deep links such as /use-cases/#lessons working.
export const initializeUseCaseCarousel = () => {
  document.querySelectorAll("[data-use-case-carousel]").forEach(carousel => {
    const slides = [...carousel.querySelectorAll(SLIDE_QUERY)]
    const selectors = [...carousel.querySelectorAll(SELECTOR_QUERY)]
    const previousButton = carousel.querySelector("[data-use-case-prev]")
    const nextButton = carousel.querySelector("[data-use-case-next]")
    const selectorStrip = carousel.querySelector(".use-case-carousel__selectors")

    if (slides.length === 0 || selectors.length === 0) return

    let activeIndex = 0

    const caseIdFor = index => slides[index].dataset.useCaseCase
    const indexForCase = caseId => slides.findIndex(slide => slide.dataset.useCaseCase === caseId)

    const activate = (index, { updateHash = false, focusTab = false, scroll = false } = {}) => {
      activeIndex = (index + slides.length) % slides.length

      slides.forEach((slide, slideIndex) => {
        const active = slideIndex === activeIndex
        slide.hidden = !active
      })

      selectors.forEach(selector => {
        const active = selector.dataset.useCaseSelect === caseIdFor(activeIndex)
        selector.setAttribute("aria-selected", active ? "true" : "false")
        if (active && focusTab) selector.focus({ preventScroll: true })
      })

      carousel.dataset.useCaseActive = caseIdFor(activeIndex)

      if (updateHash) {
        history.replaceState(null, "", `#${caseIdFor(activeIndex)}`)
      }

      if (scroll && selectorStrip) {
        selectorStrip.scrollIntoView({ block: "start", behavior: "smooth" })
      }
    }

    const activateFromHash = ({ scroll = false } = {}) => {
      const caseId = window.location.hash.replace("#", "")
      const index = indexForCase(caseId)
      if (index >= 0) activate(index, { focusTab: false, scroll })
    }

    selectors.forEach(selector => {
      selector.addEventListener("click", event => {
        event.preventDefault()
        const index = indexForCase(selector.dataset.useCaseSelect)
        if (index >= 0) activate(index, { updateHash: true })
      })
    })

    previousButton?.addEventListener("click", () => activate(activeIndex - 1, { updateHash: true, focusTab: true }))
    nextButton?.addEventListener("click", () => activate(activeIndex + 1, { updateHash: true, focusTab: true }))

    carousel.addEventListener("keydown", event => {
      if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return
      event.preventDefault()
      activate(activeIndex + (event.key === "ArrowLeft" ? -1 : 1), { updateHash: true, focusTab: true })
    })

    window.addEventListener("hashchange", () => activateFromHash())
    activateFromHash({ scroll: Boolean(window.location.hash) })
    activate(activeIndex)
  })
}

// Click a capture to read it at full size. Values arrive on the trigger so the
// viewer holds no content of its own.
export const initializeUseCaseLightbox = () => {
  const lightbox = document.querySelector("[data-use-case-lightbox-root]")
  const triggers = [...document.querySelectorAll("[data-use-case-lightbox]")]
  if (!lightbox || triggers.length === 0) return

  const image = lightbox.querySelector(".use-case-lightbox__image")
  const caption = lightbox.querySelector(".use-case-lightbox__caption")
  const closeButton = lightbox.querySelector("[data-use-case-lightbox-close]")
  let lastActiveElement = null

  const open = trigger => {
    lastActiveElement = document.activeElement
    image.src = trigger.dataset.useCaseLightboxSrc || ""
    image.alt = trigger.dataset.useCaseLightboxAlt || ""
    caption.textContent = trigger.dataset.useCaseLightboxCaption || ""
    lightbox.hidden = false
    document.body.classList.add("use-case-lightbox-open")
    closeButton.focus()
  }

  const close = () => {
    lightbox.hidden = true
    document.body.classList.remove("use-case-lightbox-open")
    image.removeAttribute("src")
    caption.textContent = ""

    if (lastActiveElement && typeof lastActiveElement.focus === "function") {
      lastActiveElement.focus()
    }
  }

  triggers.forEach(trigger => {
    trigger.addEventListener("click", () => open(trigger))
  })

  lightbox.addEventListener("click", event => {
    if (event.target === lightbox || event.target.closest("[data-use-case-lightbox-close]")) close()
  })

  document.addEventListener("keydown", event => {
    if (lightbox.hidden) return

    if (event.key === "Escape") {
      close()
      return
    }

    // The viewer is a modal dialog with a single control, so keep focus there.
    if (event.key === "Tab") {
      event.preventDefault()
      closeButton.focus()
    }
  })
}
