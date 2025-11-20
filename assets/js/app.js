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
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { getHooks } from "live_svelte"
import * as Components from "../svelte/**/*.svelte"

let Hooks = getHooks(Components)

Hooks.TrackClientCursor = {
  mounted() {
    console.log('TrackClientCursor hook mounted');
    
    let lastUpdate = 0;
    const THROTTLE_MS = 50;
    
    this.handleMouseMove = (e) => {
      const now = Date.now();
      
      if (now - lastUpdate < THROTTLE_MS) return;
      lastUpdate = now;
      
      const rect = this.el.getBoundingClientRect();
      
      const mouseX = e.clientX - rect.left;
      const mouseY = e.clientY - rect.top;
      
      const clampedX = Math.max(0, Math.min(mouseX, rect.width));
      const clampedY = Math.max(0, Math.min(mouseY, rect.height));
      
      const mouse_x = (clampedX / rect.width) * 100;
      const mouse_y = (clampedY / rect.height) * 100;
      
      console.log('Cursor position:', { mouse_x, mouse_y });
      
      this.pushEvent('cursor-move', { 
        mouse_x: mouse_x.toFixed(2), 
        mouse_y: mouse_y.toFixed(2) 
      });
    };
    
    this.el.addEventListener('mousemove', this.handleMouseMove);
  },
  
  destroyed() {
    console.log('TrackClientCursor hook destroyed');
    if (this.handleMouseMove) {
      this.el.removeEventListener('mousemove', this.handleMouseMove);
    }
  }
};

Hooks.ThemeManager = {
  mounted() {
    this.updateTheme();
  },
  updated() {
    this.updateTheme();
  },
  updateTheme() {
    const theme = localStorage.getItem('theme');
    if (theme) this.el.querySelector(`input[value="${theme}"]`).checked = true;
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

document.addEventListener('DOMContentLoaded', function() {
  const savedTheme = localStorage.getItem('theme');
  if (savedTheme) {
    document.documentElement.setAttribute('data-theme', savedTheme);
  }
});

document.querySelectorAll('.theme-controller').forEach(input => {
  input.addEventListener('change', (e) => {
    const theme = e.target.value;
    localStorage.setItem('theme', theme);
    document.documentElement.setAttribute('data-theme', theme);
  });
});