{
  const openMenus = () => document.querySelectorAll("details.menu[open]")

  document.addEventListener("pointerdown", (event) => {
    for (const menu of openMenus()) {
      if (!menu.contains(event.target)) menu.open = false
    }
  })

  document.addEventListener("keydown", (event) => {
    if (event.key !== "Escape") return
    for (const menu of openMenus()) {
      const hadFocus = menu.contains(document.activeElement)
      menu.open = false
      if (hadFocus) menu.querySelector("summary").focus()
    }
  })
}
