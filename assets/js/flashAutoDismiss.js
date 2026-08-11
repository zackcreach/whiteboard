export const FlashAutoDismiss = {
  mounted() {
    this.message = this.el.textContent
    this.scheduleDismissal()
  },

  updated() {
    const message = this.el.textContent

    if (message !== this.message) {
      this.message = message
      this.scheduleDismissal()
    }
  },

  destroyed() {
    this.cancelDismissal()
  },

  scheduleDismissal() {
    this.cancelDismissal()
    const delay = Number.parseInt(this.el.dataset.dismissAfter, 10)
    this.dismissalTimeout = window.setTimeout(() => this.el.click(), delay)
  },

  cancelDismissal() {
    window.clearTimeout(this.dismissalTimeout)
  },
}
