// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import 'phoenix_html'

// Establish Phoenix Socket and LiveView configuration.
import { Socket } from 'phoenix'
import { LiveSocket } from 'phoenix_live_view'
import { hooks as colocatedHooks } from 'phoenix-colocated/whiteboard'
import topbar from '../vendor/topbar'

// Hooks
import { ExerciseReorder } from './exerciseReorder'
import { FlashAutoDismiss } from './flashAutoDismiss'
import { ThemeSwitcher } from './themeSwitcher'

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute('content')

const hooks = { ...colocatedHooks, ExerciseReorder, FlashAutoDismiss, ThemeSwitcher }

const liveSocket = new LiveSocket('/live', Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: '#29d' }, shadowColor: 'rgba(0, 0, 0, .3)' })
window.addEventListener('phx:page-loading-start', (_info) => topbar.show(300))
window.addEventListener('phx:page-loading-stop', (_info) => topbar.hide())

// iex logs in console
// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

if (process.env.NODE_ENV === 'development') {
  window.addEventListener('phx:live_reload:attached', ({ detail: reloader }) => {
    reloader.enableServerLogs()

    let keyDown
    window.addEventListener('keydown', (event) => (keyDown = event.key))
    window.addEventListener('keyup', () => (keyDown = null))
    window.addEventListener(
      'click',
      (event) => {
        if (keyDown === 'c') {
          event.preventDefault()
          event.stopImmediatePropagation()
          reloader.openEditorAtCaller(event.target)
        } else if (keyDown === 'd') {
          event.preventDefault()
          event.stopImmediatePropagation()
          reloader.openEditorAtDef(event.target)
        }
      },
      true
    )

    window.liveReloader = reloader
  })
}
