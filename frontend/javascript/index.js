import "$styles/index.scss"
import "$styles/syntax-highlighting.css"
import components from "$components/**/*.{js,jsx,js.rb,css}"
import { initializeSearch } from "./search"

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

  initializeSearch()
})
