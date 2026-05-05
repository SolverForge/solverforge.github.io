import "$styles/index.scss"
import "$styles/syntax-highlighting.css"
import components from "$components/**/*.{js,jsx,js.rb,css}"
import { initializeSearch } from "./search"

const initializeDocsSidebar = () => {
  const sidebar = document.querySelector(".docs-sidebar")
  if (!sidebar) return

  const links = [...sidebar.querySelectorAll(".docs-sidebar__link")]
  const selectableLinks = links.filter(link => !link.hasAttribute("data-docs-sidebar-skip-active"))

  const linkUrl = link => new URL(link.getAttribute("href"), window.location.origin)

  const activate = () => {
    const currentPath = window.location.pathname
    const currentHash = window.location.hash

    const hashLink = currentHash
      ? selectableLinks.find(link => {
          const url = linkUrl(link)
          return url.pathname === currentPath && url.hash === currentHash
        })
      : undefined

    const pageLink = selectableLinks.find(link => {
      const url = linkUrl(link)
      return url.pathname === currentPath && !url.hash
    })

    const activeLink = hashLink || pageLink
    if (!activeLink) return

    sidebar.querySelectorAll(".docs-sidebar__item.is-active").forEach(item => {
      item.classList.remove("is-active")
    })

    for (
      let item = activeLink.closest(".docs-sidebar__item");
      item && sidebar.contains(item);
      item = item.parentElement.closest(".docs-sidebar__item")
    ) {
      item.classList.add("is-active")
    }
  }

  activate()
  window.addEventListener("hashchange", activate)
}

document.addEventListener("DOMContentLoaded", () => {
  const toggle = document.querySelector("[data-nav-toggle]")
  const menu = document.querySelector("[data-nav-menu]")

  if (toggle && menu) {
    toggle.addEventListener("click", () => {
      const open = menu.classList.toggle("is-open")
      toggle.setAttribute("aria-expanded", String(open))
    })
  }

  document.querySelectorAll("[data-code-tabs]").forEach(container => {
    const buttons = [...container.querySelectorAll("[data-tab-button]")]
    const panels = [...container.querySelectorAll("[data-tab-panel]")]

    const activate = id => {
      buttons.forEach(button => {
        button.classList.toggle("is-active", button.dataset.tabButton === id)
      })
      panels.forEach(panel => {
        panel.hidden = panel.dataset.tabPanel !== id
      })
    }

    buttons.forEach(button => {
      button.addEventListener("click", () => activate(button.dataset.tabButton))
    })

    if (buttons[0]) activate(buttons[0].dataset.tabButton)
  })

  initializeDocsSidebar()
  initializeSearch()
})
