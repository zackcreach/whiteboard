function applyTheme(theme) {
  if (theme === 'dark') {
    document.documentElement.classList.add('dark')
  } else if (theme === 'light') {
    document.documentElement.classList.remove('dark')
  } else {
    const systemPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    document.documentElement.classList.toggle('dark', systemPrefersDark)
  }
}

export const ThemeSwitcher = {
  mounted() {
    const saved = localStorage.getItem('theme')
    this.pushEvent('set_theme', { theme: saved || 'system' })

    this.el.querySelectorAll('[data-value]').forEach((button) => {
      button.addEventListener('click', () => {
        const theme = button.dataset.value

        if (theme === 'system') {
          localStorage.removeItem('theme')
        } else {
          localStorage.setItem('theme', theme)
        }

        applyTheme(theme)
        this.pushEvent('set_theme', { theme })
      })
    })
  },
}
