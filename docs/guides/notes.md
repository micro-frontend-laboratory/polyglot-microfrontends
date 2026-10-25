# Notes, from a Vue app to a web component

`apps/microfrontends/notes` is a regular Vue application, created with `npm create vite@latest` (Vue +
TypeScript template). It owns one thing, the notes of an order. Its component is then turned into
a custom element without changing a line inside it. The app shows both side by side:

| Route | What it shows |
| --- | --- |
| `http://localhost:4400/mf/notes/components` | Step 1: the component used by Vue, the normal way |
| `http://localhost:4400/mf/notes/web-components` | Step 2: the same component as `<shop-order-notes>` |

## Step 1: a correct Vue app

```text
contract/                         @shop/notes-contract: what other apps may use
src/
  notes/                          everything about notes, grouped by kind
    clients/
      notes-client.ts             NotesClient: implements listOrderNotes and addOrderNote
    services/
      notes-service.ts            NotesService: what the component uses; calls the client
    config/
      notes-config.ts             INotesConfig and the API address
      create-notes.ts             createNotes(config): a Vue plugin that provides the service
      use-notes-service.ts        inject() for components
    components/
      order-notes/                OrderNotes.vue + order-notes.css
  pages/                          one page per route
  shared/                         EventLog, OrderPicker, useEventLog
  web-components/                 the transformation (step 2)
  elements.ts                     defineElements()
  main.ts  App.vue  router.ts
```

The template adds two packages: `vue-router` for the two routes, and `@module-federation/vite`
for step 3.

**Configuration through a plugin.** Vue's way to provide app-wide services is a plugin, like
`app.use(router)`. `main.ts` installs it once:

```ts
createApp(App).use(router).use(createNotes(notesConfig)).mount('#app');
```

`createNotes` builds `NotesClient` and `NotesService` from the config and `provide`s the service.
The component gets it with `useNotesService()`, which is `inject` underneath. No component
receives a URL or a token.

**The component is plain Vue.** Props go in, emits come out:

```vue
<OrderNotes :order-id="orderId" @note-added="noteAdded" />
```

Its props and event details come from the element contract the team publishes:

```ts
const { orderId } = defineProps<Partial<IOrderNotesContract['properties']>>();
const emit = defineEmits<{ noteAdded: [detail: Events['noteAdded']] }>();
```

The event name is written out because Vue's compiler needs the literal key to generate the
runtime emits; `elements.ts` checks it against the contract (step 2).

`NotesClient` implements the two API operations the app calls, from the API team's contract:
`class NotesClient implements Pick<IOrdersApi, 'listOrderNotes' | 'addOrderNote'>`.

Its CSS lives in a file next to it (`<style src="./order-notes.css">`), with class names that
carry the component name, so the same file works on the page and inside a shadow root.

## Step 2: the transformation to a web component

Vue ships `defineCustomElement`, so most of the work is built in: props become attributes and
properties, the styles go into a shadow root, and `configureApp` installs plugins on the
element's own app. Only the events need help. Vue dispatches an emit as
`new CustomEvent(name, { detail: [...args] })`: the detail is an array, and the event neither
bubbles nor crosses the shadow root. The contract needs `detail: { orderId, text }` with `bubbles`
and `composed`.

`web-components/define-vue-element.ts` therefore wraps the component in about 50 lines:

| Part | What it does |
| --- | --- |
| `props: component.props` | the element gets exactly the component's props: `order-id` / `orderId` |
| `component.emits` | for each declared emit, a handler that dispatches the contract `CustomEvent` from the host element (`useHost()`) |
| `styles` | the component's CSS, imported with Vite's `?inline` suffix |
| `configureApp` | here `app.use(notes)`, the same plugin the app uses |
| `data-vue-version` | the host element carries the Vue it runs on, like Angular's `ng-version`; Notes needs Vue 3.5 or later for `useHost()` |

The emit names come from the compiled component, so nothing is listed twice.

`elements.ts` uses it through `defineNotesElement`, which finds the contract by the tag name and
checks the component against it:

```ts
function registerElements(): void {
  const notes = createNotes(notesConfig);

  defineNotesElement('shop-order-notes', OrderNotes, {
    styles: [orderNotesStyles],
    configureApp: (app) => app.use(notes),
  });
}
```

A component is accepted only if it has every property of the contract and an `on…` handler for
every event, with the contract's types. Rename the `noteAdded` emit and the build stops.

`main.ts` awaits `defineElements()` before mounting, and the web components page uses
the tag like any host would:

```vue
<shop-order-notes :order-id="orderId" @noteAdded="noteAdded" />
```

- **`isCustomElement`** in `vite.config.ts` tells the Vue compiler that `shop-` tags are custom
  elements, not Vue components.
- **Data in:** `:order-id` is set as an attribute.
- **Events out:** on a plain element, `@noteAdded` listens to `noteAdded` exactly as written.
  The handler receives the `CustomEvent`, with the value in `event.detail`.

## Step 3: share it with Module Federation

The same plugin as Insights, with Vue shared instead of React:

```ts
federation({
  name: 'notes',
  filename: 'remoteEntry.js',
  exposes: {
    './elements': './src/elements.ts',
  },
  shared: ['vue'],
  dts: false,
}),
```

`base` is `/mf/notes/`, the path every edge proxy forwards to Notes, so the files the remote entry points to
always load from Notes, whichever page imports it.

## The API

The notes are stored by `apps/services/mock-api` next to the orders:

| Request | Result |
| --- | --- |
| `GET /orders/A-1001/notes` | the notes of one order, or a 404 |
| `POST /orders/A-1001/notes` `{ "text": "Call first" }` | the new note, `201` |

## What changes for the host

| | Vue component (step 1) | Custom element (step 2) |
| --- | --- | --- |
| Tag | `<OrderNotes>` | `<shop-order-notes>` |
| Usable from | this Vue app only | any page: Angular, React, an older Angular, plain HTML |
| Data in | props, typed | attribute `order-id` |
| Events out | `emit('noteAdded', detail)` | `CustomEvent('noteAdded')`, value in `event.detail` |
| Configuration | `app.use(createNotes(config))` | none: `defineElements()` once, the element knows its API |

## Run it

```bash
docker compose -f compose.microfrontends.yaml up --build --watch notes
```

The remote is internal; the shells load it through their proxies. Start everything once with `tools\scripts\start-all.bat`, then this command rebuilds the remote and watches its files.

## What to try

- `/components`: picking an order loads its notes; adding a note logs `noteAdded(...)`.
- `/web-components` does the same with the custom element and logs the DOM event.
- A note typed as `<img src=x onerror=alert(1)>` shows as text.
