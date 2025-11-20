JavaScript interoperability

To enable LiveView client/server interaction, we instantiate a LiveSocket. For example:

import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
liveSocket.connect()

All options are passed directly to the Phoenix.Socket constructor, except for the following LiveView specific options:

    bindingPrefix - the prefix to use for phoenix bindings. Defaults "phx-"
    params - the connect_params to pass to the view's mount callback. May be a literal object or closure returning an object. When a closure is provided, the function receives the view's element.
    hooks - a reference to a user-defined hooks namespace, containing client callbacks for server/client interop. See the Client hooks section below for details.
    uploaders - a reference to a user-defined uploaders namespace, containing client callbacks for client-side direct-to-cloud uploads. See the External uploads guide for details.
    metadata - additional user-defined metadata that is sent along events to the server. See the Key events section in the bindings guide for an example.

The liveSocket instance exposes the following methods:

    connect() - call this once after creation to connect to the server
    enableDebug() - turns on debug logging, see Debugging client events
    disableDebug() - turns off debug logging
    enableLatencySim(milliseconds) - turns on latency simulation, see Simulating latency
    disableLatencySim() - turns off latency simulation
    execJS(el, encodedJS) - executes encoded JavaScript in the context of the element
    js() - returns an object with methods to manipluate the DOM and execute JavaScript. The applied changes integrate with server DOM patching. See JS commands.

Debugging client events

To aid debugging on the client when troubleshooting issues, the enableDebug() and disableDebug() functions are exposed on the LiveSocket JavaScript instance. Calling enableDebug() turns on debug logging which includes LiveView life-cycle and payload events as they come and go from client to server. In practice, you can expose your instance on window for quick access in the browser's web console, for example:

// app.js
let liveSocket = new LiveSocket(...)
liveSocket.connect()
window.liveSocket = liveSocket

// in the browser's web console
>> liveSocket.enableDebug()

The debug state uses the browser's built-in sessionStorage, so it will remain in effect for as long as your browser session lasts.
Simulating Latency

Proper handling of latency is critical for good UX. LiveView's CSS loading states allow the client to provide user feedback while awaiting a server response. In development, near zero latency on localhost does not allow latency to be easily represented or tested, so LiveView includes a latency simulator with the JavaScript client to ensure your application provides a pleasant experience. Like the enableDebug() function above, the LiveSocket instance includes enableLatencySim(milliseconds) and disableLatencySim() functions which apply throughout the current browser session. The enableLatencySim function accepts an integer in milliseconds for the one-way latency to and from the server. For example:

// app.js
let liveSocket = new LiveSocket(...)
liveSocket.connect()
window.liveSocket = liveSocket

// in the browser's web console
>> liveSocket.enableLatencySim(1000)
[Log] latency simulator enabled for the duration of this browser session.
      Call disableLatencySim() to disable

Handling server-pushed events

When the server uses Phoenix.LiveView.push_event/3, the event name will be dispatched in the browser with the phx: prefix. For example, imagine the following template where you want to highlight an existing element from the server to draw the user's attention:

<div id={"item-#{item.id}"} class="item">
  {item.title}
</div>

Next, the server can issue a highlight using the standard push_event:

def handle_info({:item_updated, item}, socket) do
  {:noreply, push_event(socket, "highlight", %{id: "item-#{item.id}"})}
end

Finally, a window event listener can listen for the event and conditionally execute the highlight command if the element matches:

let liveSocket = new LiveSocket(...)
window.addEventListener("phx:highlight", (e) => {
  let el = document.getElementById(e.detail.id)
  if(el) {
    // logic for highlighting
  }
})

If you desire, you can also integrate this functionality with Phoenix' JS commands, executing JS commands for the given element whenever highlight is triggered. First, update the element to embed the JS command into a data attribute:

<div id={"item-#{item.id}"} class="item" data-highlight={JS.transition("highlight")}>
  {item.title}
</div>

Now, in the event listener, use LiveSocket.execJS to trigger all JS commands in the new attribute:

let liveSocket = new LiveSocket(...)
window.addEventListener("phx:highlight", (e) => {
  document.querySelectorAll(`[data-highlight]`).forEach(el => {
    if(el.id == e.detail.id){
      liveSocket.execJS(el, el.getAttribute("data-highlight"))
    }
  })
})

Client hooks via phx-hook

To handle custom client-side JavaScript when an element is added, updated, or removed by the server, a hook object may be provided via phx-hook. phx-hook must point to an object with the following life-cycle callbacks:

    mounted - the element has been added to the DOM and its server LiveView has finished mounting
    beforeUpdate - the element is about to be updated in the DOM. Note: any call here must be synchronous as the operation cannot be deferred or cancelled.
    updated - the element has been updated in the DOM by the server
    destroyed - the element has been removed from the page, either by a parent update, or by the parent being removed entirely
    disconnected - the element's parent LiveView has disconnected from the server
    reconnected - the element's parent LiveView has reconnected to the server

Note: When using hooks outside the context of a LiveView, mounted is the only callback invoked, and only those elements on the page at DOM ready will be tracked. For dynamic tracking of the DOM as elements are added, removed, and updated, a LiveView should be used.

The above life-cycle callbacks have in-scope access to the following attributes:

    el - attribute referencing the bound DOM node
    liveSocket - the reference to the underlying LiveSocket instance
    pushEvent(event, payload, (reply, ref) => ...) - method to push an event from the client to the LiveView server. If no callback function is passed, a promise that resolves to the reply is returned.
    pushEventTo(selectorOrTarget, event, payload, (reply, ref) => ...) - method to push targeted events from the client to LiveViews and LiveComponents. It sends the event to the LiveComponent or LiveView the selectorOrTarget is defined in, where its value can be either a query selector or an actual DOM element. If the query selector returns more than one element it will send the event to all of them, even if all the elements are in the same LiveComponent or LiveView. pushEventTo supports passing the node element e.g. this.el instead of selector e.g. "#" + this.el.id as the first parameter for target. As there can be multiple targets, if no callback is passed, a promise is returned that matches the return value of Promise.allSettled(). Individual fulfilled values are of the format { reply, ref }.
    handleEvent(event, (payload) => ...) - method to handle an event pushed from the server. Returns a value that can be passed to removeHandleEvent to remove the event handler.
    removeHandleEvent(ref) - method to remove an event handler added via handleEvent
    upload(name, files) - method to inject a list of file-like objects into an uploader.
    uploadTo(selectorOrTarget, name, files) - method to inject a list of file-like objects into an uploader. The hook will send the files to the uploader with name defined by allow_upload/3 on the server-side. Dispatching new uploads triggers an input change event which will be sent to the LiveComponent or LiveView the selectorOrTarget is defined in, where its value can be either a query selector or an actual DOM element. If the query selector returns more than one live file input, an error will be logged.
    js() - returns an object with methods to manipluate the DOM and execute JavaScript. The applied changes integrate with server DOM patching. See JS commands.

For example, the markup for a controlled input for phone-number formatting could be written like this:

<input type="text" name="user[phone_number]" id="user-phone-number" phx-hook="PhoneNumber" />

Then a hook callback object could be defined and passed to the socket:

/**
 * @type {import("phoenix_live_view").HooksOptions}
 */
let Hooks = {}
Hooks.PhoneNumber = {
  mounted() {
    this.el.addEventListener("input", e => {
      let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
      if(match) {
        this.el.value = `${match[1]}-${match[2]}-${match[3]}`
      }
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, ...})
...

Note: when using phx-hook, a unique DOM ID must always be set.

For integration with client-side libraries which require a broader access to full DOM management, the LiveSocket constructor accepts a dom option with an onBeforeElUpdated callback. The fromEl and toEl DOM nodes are passed to the function just before the DOM patch operations occurs in LiveView. This allows external libraries to (re)initialize DOM elements or copy attributes as necessary as LiveView performs its own patch operations. The update operation cannot be cancelled or deferred, and the return value is ignored.

For example, the following option could be used to guarantee that some attributes set on the client-side are kept intact:

...
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
  dom: {
    onBeforeElUpdated(from, to) {
      for (const attr of from.attributes) {
        if (attr.name.startsWith("data-js-")) {
          to.setAttribute(attr.name, attr.value);
        }
      }
    }
  }
})

In the example above, all attributes starting with data-js- won't be replaced when the DOM is patched by LiveView.

A hook can also be defined as a subclass of ViewHook:

import { ViewHook } from "phoenix_live_view"

class MyHook extends ViewHook {
  mounted() {
    ...
  }
}

let liveSocket = new LiveSocket(..., {
  hooks: {
    MyHook
  }
})

Colocated Hooks / Colocated JavaScript

When writing components that require some more control over the DOM, it often feels inconvenient to have to write a hook in a separate file. Instead, one wants to have the hook logic right next to the component code. For such cases, HEEx supports Phoenix.LiveView.ColocatedHook and Phoenix.LiveView.ColocatedJS.

Let's see an example:

def phone_number_input(assigns) do
  ~H"""
  <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
  <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
    export default {
      mounted() {
        this.el.addEventListener("input", e => {
          let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
          if(match) {
            this.el.value = `${match[1]}-${match[2]}-${match[3]}`
          }
        })
      }
    }
  </script>
  """
end

When LiveView finds a <script> element with :type={ColocatedHook}, it will extract the hook code at compile time and write it into a special folder inside the _build/ directory. To use the hooks, all that needs to be done is to import the manifest into your JS bundle, which is automatically done in the app.js file generated by mix phx.new for new Phoenix 1.8 apps:

...
  import {Socket} from "phoenix"
  import {LiveSocket} from "phoenix_live_view"
  import topbar from "../vendor/topbar"
+ import {hooks as colocatedHooks} from "phoenix-colocated/my_app"

  let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
  let liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: {_csrf_token: csrfToken},
+   hooks: {...colocatedHooks}
 })

The "phoenix-colocated" package is a folder inside the Mix.Project.build_path(), which is included by default in the esbuild configuration of new Phoenix projects (requires {:esbuild, "~> 0.10"} or later):

config :esbuild,
  ...
  my_app: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{
      "NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]
    }
  ]

When rendering a component that includes a colocated hook, the <script> tag is omitted from the rendered output. Furthermore, to prevent conflicts with other components, colocated hooks require you to use the special dot syntax when naming the hook, as well as in the phx-hook attribute. LiveView will prefix the hook name by the current module name at compile time. This also means that in cases where a hook is meant to be used in multiple components across a project, the hook should be defined as a regular, non-colocated hook instead.

You can read more about colocated hooks in the module documentation for ColocatedHook. LiveView also supports colocating other JavaScript code, for more information, see Phoenix.LiveView.ColocatedJS.
Client-server communication

A hook can push events to the LiveView by using the pushEvent function and receive a reply from the server via a {:reply, map, socket} return value. The reply payload will be passed to the optional pushEvent response callback.

Communication with the hook from the server can be done by reading data attributes on the hook element or by using Phoenix.LiveView.push_event/3 on the server and handleEvent on the client.

An example of responding with :reply might look like this.

<div phx-hook="ClickMeHook" id="click-me">
  Click me for a message!
</div>

Hooks.ClickMeHook = {
  mounted() {
    this.el.addEventListener("click", () => {
      // Push event to LiveView with callback for reply
      this.pushEvent("get_message", {}, (reply) => {
        console.debug(reply.message);
      });
    });
  }
}

Then in your callback you respond with {:reply, map, socket}

def handle_event("get_message", _params, socket) do
  # Use :reply to respond to the pushEvent
  {:reply, %{message: "Hello from LiveView!"}, socket}
end

Another example, to implement infinite scrolling, one can pass the current page using data attributes:

<div id="infinite-scroll" phx-hook="InfiniteScroll" data-page={@page}>

And then in the client:

/**
 * @type {import("phoenix_live_view").Hook}
 */
Hooks.InfiniteScroll = {
  page() { return this.el.dataset.page },
  mounted(){
    this.pending = this.page()
    window.addEventListener("scroll", e => {
      if(this.pending == this.page() && scrollAt() > 90){
        this.pending = this.page() + 1
        this.pushEvent("load-more", {})
      }
    })
  },
  updated(){ this.pending = this.page() }
}

However, the data attribute approach is not a good approach if you need to frequently push data to the client. To push out-of-band events to the client, for example to render charting points, one could do:

<div id="chart" phx-hook="Chart">

And then on the client:

/**
 * @type {import("phoenix_live_view").Hook}
 */
Hooks.Chart = {
  mounted(){
    this.handleEvent("points", ({points}) => MyChartLib.addPoints(points))
  }
}

And then you can push events as:

{:noreply, push_event(socket, "points", %{points: new_points})}

Events pushed from the server via push_event are global and will be dispatched to all active hooks on the client who are handling that event. If you need to scope events (for example when pushing from a live component that has siblings on the current live view), then this must be done by namespacing them:

def update(%{id: id, points: points} = assigns, socket) do
  socket =
    socket
    |> assign(assigns)
    |> push_event("points-#{id}", points)

  {:ok, socket}
end

And then on the client:

Hooks.Chart = {
  mounted(){
    this.handleEvent(`points-${this.el.id}`, (points) => MyChartLib.addPoints(points));
  }
}

Note: In case a LiveView pushes events and renders content, handleEvent callbacks are invoked after the page is updated. Therefore, if the LiveView redirects at the same time it pushes events, callbacks won't be invoked on the old page's elements. Callbacks would be invoked on the redirected page's newly mounted hook elements.
JS commands

Note: If possible, construct commands via Elixir using Phoenix.LiveView.JS and trigger them via Phoenix DOM Bindings.

While Phoenix.LiveView.JS allows you to construct a declarative representation of a command, it may not cover all use cases. In addition, you can execute commands that integrate with server DOM patching via JavaScript using:

    Client hooks: this.js() or the
    LiveSocket instance: liveSocket.js().

The command interface returned by js() above offers the following functions:

    show(el, opts = {}) - shows an element. Options: display, transition, time, blocking. For more details, see Phoenix.LiveView.JS.show/1.
    hide(el, opts = {}) - hides an element. Options: transition, time, blocking. For more details, see Phoenix.LiveView.JS.hide/1.
    toggle(el, opts = {}) - toggles the visibility of an element. Options: display, in, out, time, blocking. For more details, see Phoenix.LiveView.JS.toggle/1.
    addClass(el, names, opts = {}) - adds CSS class(es) to an element. Options: transition, time, blocking. For more details, see Phoenix.LiveView.JS.add_class/1.
    removeClass(el, names, opts = {}) - removes CSS class(es) to an element. Options: transition, time, blocking. For more details, see Phoenix.LiveView.JS.remove_class/1.
    toggleClass(el, names, opts = {}) - toggles CSS class(es) to an element. Options: transition, time, blocking. For more details, see Phoenix.LiveView.JS.toggle_class/1.
    transition(el, transition, opts = {}) - applies a CSS transition to an element. Options: time, blocking. For more details, see Phoenix.LiveView.JS.transition/1.
    setAttribute(el, attr, val) - sets an attribute on an element
    removeAttribute(el, attr) - removes an attribute from an element
    toggleAttribute(el, attr, val1, val2) - toggles an attribute on an element between two values
    push(el, type, opts = {}) - pushes an event to the server. To target a LiveComponent by its ID, pass a separate target in the options. Options: target, loading, page_loading, value. For more details, see Phoenix.LiveView.JS.push/1.
    navigate(href, opts = {}) - sends a navigation event to the server and updates the browser's pushState history. Options: replace. For more details, see Phoenix.LiveView.JS.navigate/1.
    patch(href, opts = {}) - sends a patch event to the server and updates the browser's pushState history. Options: replace. For more details, see Phoenix.LiveView.JS.patch/1.
    exec(encodedJS) - only via Client hook this.js(): executes encoded JavaScript in the context of the hook's root node. The encoded JS command should be constructed via Phoenix.LiveView.JS and is usually stored as an HTML attribute. Example: this.js().exec(this.el.getAttribute('phx-remove')).
    exec(el, encodedJS) - only via liveSocket.js(): executes encoded JavaScript in the context of any element.

# cursor traking in liveview

Tracking cursor movement

We are going to use Javascript to track the mouse movement on the client and send it over to the Phoenix server we are building.

We understand that the idea of LiveView is to do as much work on the server as possible, but in this specific scenario, that is not possible.

Phoenix offers options for client/server interoperability, including client hooks. We are using the phx-hook binding for this. We are going to send events from Javascript to the server through this binding.

In this case, we are using the mousemove event to send the updated coordinates to the server. For this, add the following code in the assets/js/app.js.

let Hooks = {};

Hooks.TrackClientCursor = {
  mounted() {
    document.addEventListener('mousemove', (e) => {
      const mouse_x = (e.pageX / window.innerWidth) * 100; // in %
      const mouse_y = (e.pageY / window.innerHeight) * 100; // in %
      this.pushEvent('cursor-move', { mouse_x, mouse_y });
    });
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})

In the previous code block, we track the mouse position within the page in percentage. This way, the mouse position is displayed correctly in any device.

The mousemove event handler is added to the Hook object which, in turn, is passed through the liveSocket.

After this, we need to handle the event in the cursors.ex file. Let's add the event handler with the following code:

  def handle_event("cursor-move", %{"mouse_x" => x, "mouse_y" => y}, socket) do
    {:noreply,
      socket
        |> assign(:x, x)
        |> assign(:y, y)
    }
  end

In the cursors.html.heex file, let's change the first two lines with the following piece of code:

<ul class="list-none mt-9 max-h-full max-w-full" id="cursor" phx-hook="TrackClientCursor">
    <li style={"left: #{@x}%; top: #{@y}%"} class="flex flex-col absolute pointer-events-none whitespace-nowrap overflow-hidden">

Here, we are using the phx-hook binding with the hook created in the app.js file. Make sure to ann an id to the element so that LiveView can properly identify it.

If you restart the server and open the browser again, the cursor should follow your mouse movements.


 Tracking who is online

This is the most exciting part of the tutorial. We are going to have different users have their cursors and see them in real-time! For this, we need to be able to track who is online in the channel. For this, we are going to be using Phoenix Presence. We will use Presence to store information about the coordinates and username in the Presence channel.

    Phoenix Presence is a package within the Phoenix ecosystem that allows us to track processes and users that are within a channel. It provides many features. We recommend reading their documentation if you are interested in learning more.

Let's start by adding PResence to our application. Run the following command.

mix phx.gen.presence

After installing, the terminal should ask you to follow some instructions.

Add your new module to your supervision tree,
in lib/live_cursors/application.ex:

    children = [
      ...
      LiveCursorsWeb.Presence
    ]

Let's follow the instructions and do exactly that. Open lib/live_cursors/application.ex and add LiveCursorWeb.Presence to the children array.

With Presence installed, let's now work on the cursors.ex file. First, let's add alias LiveCursorsWeb.Presence after declaring the module so it's easier to write our code.

In the mount/3 function, we will initialize Presence for the channel through the Presence.track/4 function. We will define a constant @channel_topic and use it in the function as well. Change the code in cursors.ex file so the mounting function looks like such:

defmodule LiveCursorsWeb.Cursors do
  alias LiveCursorsWeb.Presence
  use LiveCursorsWeb, :live_view

  @channel_topic "cursor_page"

  def mount(_params, _session, socket) do

    username = MnemonicSlugs.generate_slug

    Presence.track(self(), @channel_topic, socket.id, %{
      socket_id: socket.id,
      x: 50,
      y: 50,
      username: username,
    })

    LiveCursorsWeb.Endpoint.subscribe(@channel_topic)

    initial_users =
      Presence.list(@channel_topic)
      |> Enum.map(fn {_, data} -> data[:metas] |> List.first() end)

    updated =
      socket
      |> assign(:username, username)
      |> assign(:users, initial_users)
      |> assign(:socket_id, socket.id)

    {:ok, updated}
  end

To further explain what we just wrote, we are telling Presence to track ourselves, within the channel, the id of the socket and adding metadata we want to track, namely the username and the mouse coordinates (x and y). Additionally, whenever the user acecss the page, it subscribes to the channel events in the LiveCursorsWeb.Endpoint.subscribe(@channel_topic). After this, we create an initial_users variable, where we use the data from Presence and obtain the list of connected users and their respective metadata. At last, we assign the user data and the initial_users and socket.id data to the socket assigns, so we can access this information in the cursors.html.heex file.

Speaking of which, let's change the cursors.html.heex file to reflect these changes. We are going to iterate over the list of users that are online and render a cursor and name for each one. Your file should now look like the following:

<ul class="list-none mt-9 max-h-full max-w-full" id="cursor" phx-hook="TrackClientCursor">
  <%= for user <- @users do %>
    <li style={"left: #{user.x}%; top: #{user.y}%"} class="flex flex-col absolute pointer-events-none whitespace-nowrap overflow-hidden">
      <svg xmlns="http://www.w3.org/2000/svg" width="31" height="32" fill="none" viewBox="0 0 31 32">
        <path fill="url(#a)" d="m.609 10.86 5.234 15.488c1.793 5.306 8.344 7.175 12.666 3.612l9.497-7.826c4.424-3.646 3.69-10.625-1.396-13.27L11.88 1.2C5.488-2.124-1.697 4.033.609 10.859Z"/>
        <defs>
          <linearGradient id="a" x1="-4.982" x2="23.447" y1="-8.607" y2="25.891" gradientUnits="userSpaceOnUse">
            <stop style={"stop-color: #5B8FA3"}/>
            <stop offset="1" stop-color="#BDACFF"/>
          </linearGradient>
        </defs>
      </svg>
      <span class="mt-1 ml-4 px-1 text-sm text-white rounded-xl bg-slate-600">
        <%= user.username %>
      </span>
    </li>
  <% end %>
</ul>

After this, we ought to handle the cursor-move event coming from the client and update the coordinates in the list of active users in the channel with the socket.id as an identifier. Change the handle_event/1 function to this.

  def handle_event("cursor-move", %{"mouse_x" => x, "mouse_y" => y}, socket) do
    key = socket.id
    payload = %{x: x, y: y}

    metas =
      Presence.get_by_key(@channel_topic, key)[:metas]
      |> List.first()
      |> Map.merge(payload)

    Presence.update(self(), @channel_topic, key, metas)

    {:noreply, socket}
  end

The last thing that is left is to make our LiveView react to whenever a user joins or leaves the channel. Therefore, we sync the socket with the info available in the Presence channel. The following function updates the list of active users whenever someone joins or leaves the channel.

  def handle_info(%{event: "presence_diff", payload: _payload}, socket) do
    users =
      Presence.list(@channel_topic)
      |> Enum.map(fn {_, data} -> data[:metas] |> List.first() end)

    updated =
      socket
      |> assign(users: users)
      |> assign(socket_id: socket.id)

    {:noreply, updated}
  end

That was a lot! Now let's restart the server and open two different tabs. You will see the cursor moving in both tabs in real-time. Awesome stuff!