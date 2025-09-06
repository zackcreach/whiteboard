export const ThemeSwitcher = {
  mounted() {
    this.el.addEventListener('click', () => {
      const isDarkEnabled = document.documentElement.classList.contains('dark')

      if (isDarkEnabled) {
        document.documentElement.classList.remove('dark')
        localStorage.setItem('theme', 'light')
      } else {
        document.documentElement.classList.add('dark')
        localStorage.setItem('theme', 'dark')
      }
    })
  },
}
