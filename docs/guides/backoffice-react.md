# The React back office, hosting all three frameworks

`apps/backoffices/backoffice-react` is a React shell (`npm create vite@latest`, React + TypeScript
template) that puts the Angular components from Orders, the React components from Insights and
the Vue components from Notes on one page. It imports none of them. All three are loaded at
runtime, the first time `/orders` opens. Its colour is blue (`#2563eb`).

The shell runs **React 19**, the newest React, while the Insights components it hosts run on
React 18: the header shows the shell's version, and each Insights element carries
`data-react-version="18.3.1"`.

| Route | What it shows |
| --- | --- |
| `http://localhost:4200/dashboard` | The Insights statistics and the Orders list of open orders; a click opens the order |
| `http://localhost:4200/orders` | The shell's filter and the five elements, wired together by the shell |
| `http://localhost:4200/orders/A-1003` | The same page opened with an order (a deep link) |
| `http://localhost:4200/settings` | The theme switch |

The Vue and Angular shells have the same pages and the same layout; only the framework of the
shell changes.

## The project

```text
src/
  remote-entries.ts          where each remote lives
  remotes/
    orders-remote.ts         Native Federation
    insights-remote.ts       Module Federation
    notes-remote.ts          Module Federation
    module-federation.ts     the Module Federation runtime instance
    RemoteGate.tsx           loading text, then the elements or an error card with Retry
  web-components/
    custom-elements.d.ts     JSX typings for the five shop- tags, built from the three contracts
  components/StatusFilter.tsx the shell's own All / Open / Shipped filter
  pages/                     DashboardPage, OrdersPage, SettingsPage
  theme/themes.ts
  shared/useActivityLog.ts
  App.tsx  router.tsx  main.tsx  styles.css
```

Three packages are added to the template:

| Package | Why |
| --- | --- |
| `react-router` | The shell owns the URL. The order id in `/orders/:orderId` becomes `order-id` |
| `@softarc/native-federation-orchestrator` | The Native Federation runtime for any page; loads Orders' `remoteEntry.json` |
| `@module-federation/runtime` | Loads Insights' and Notes' `remoteEntry.js`; the same runtime the Angular shell uses |

And the three element contracts, as dev dependencies installed from their teams' folders:
`@shop/orders-contract`, `@shop/insights-contract` and `@shop/notes-contract`. The shell never
calls the API, so it does not need `@shop/api-contract`. The shell has no copy of any shared type: the models, the event details,
and the type of each remote's `defineElements` all come from them.

```ts
declare module 'react' {
  namespace JSX {
    interface IntrinsicElements
      extends ContractElements<OrdersContracts | InsightsContracts | NotesContracts> {}
  }
}
```

`ContractElements` turns every contract into the JSX props of its tag: attributes, properties,
and an `on<event>` prop typed with the event's `detail`. A tag, attribute or event that a team
renames stops compiling here.

## Three remotes, two runtimes, one contract

Orders is built with Native Federation, Insights and Notes with Module Federation, so there are
two loaders. Behind each is the same call, with no configuration: `defineElements()`.

```ts
export function loadOrdersElements(): Promise<void> {
  ordersReady ??= initFederation({ orders: remoteEntries.orders })
    .then(({ loadRemoteModule }) => loadRemoteModule<IOrdersRemote>('orders', './elements'))
    .then(({ defineElements }) => defineElements())
    .catch((error: unknown) => {
      ordersReady = undefined;
      throw error;
    });
  return ordersReady;
}
```

```ts
export const moduleFederation = createInstance({
  name: 'backoffice',
  remotes: [
    { name: 'insights', entry: remoteEntries.insights, type: 'module' },
    { name: 'notes', entry: remoteEntries.notes, type: 'module' },
  ],
  shared: {},
  shareStrategy: 'loaded-first',
});

export function loadNotesElements(): Promise<void> {
  notesReady ??= moduleFederation
    .loadRemote<INotesRemote>('notes/elements')
    .then((elements) => {
      if (!elements) {
        throw new Error('notes exposes no elements');
      }
      return elements.defineElements();
    })
    .catch(/* the same reset */);
  return notesReady;
}
```

- **Native Federation.** The orchestrator reads `remoteEntry.json`, writes a native import map
  for Angular's shared packages, and imports `./elements`.
- **Module Federation.** `remotes/module-federation.ts` creates one runtime instance with
  `@module-federation/runtime`, exactly as the Angular shell does, and `loadRemote` reads
  `remoteEntry.js`.
- **No federation build.** The shell only consumes remotes, so it needs the two runtimes and no
  build plugin: `vite.config.ts` has only the React plugin. `shared: {}` offers the shell's
  React 19 to nobody; Insights asks for React 18 and Notes brings Vue, so each remote loads its
  own copy anyway. `shareStrategy: 'loaded-first'` keeps the remotes lazy: nothing is fetched
  before `/orders` opens.
- **Retrying.** A failed load resets the cached promise, so Retry starts again.

## The page wires everything

React 19 binds custom elements like an Angular template: properties and attributes go in, and
`on` plus the exact event name adds a listener. (Insights' own page, on React 18, needs refs for
the same elements; see [insights.md](insights.md).)

```tsx
<StatusFilter value={status} onChange={setStatus} />

<shop-orders-list
  status={status}
  page-size="10"
  onorderSelected={(event) => navigate(`/orders/${event.detail.id}`)}
/>
<shop-order-detail
  order-id={orderId}
  onorderUpdated={() => setRefreshCount((count) => count + 1)}
  onclosed={() => navigate('/orders')}
/>

<shop-order-stats
  refresh-key={String(refreshCount)}
  onstatusPicked={(event) => setStatus(event.detail.status)}
/>
<shop-order-notes order-id={orderId} onnoteAdded={(event) => log(event.detail.text)} />
<shop-activity-feed entries={entries} oncleared={clear} />
```

| Who | Does what | How the others learn |
| --- | --- | --- |
| The shell's own filter (React) | picks a status | `status` on the Angular list |
| React stat tile (Insights) | `statusPicked` | the shell's filter and the Angular list follow |
| Angular list (Orders) | `orderSelected` | the URL changes; the Angular detail and the Vue notes follow it |
| Vue notes (Notes) | `noteAdded` | the React feed logs it |
| Angular detail (Orders) | `orderUpdated` | `refresh-key` changes; the React counts reload |
| Angular detail (Orders) | `closed` | back to `/orders` |

Every event also goes into the activity feed. Browser back and forward move between orders,
because the selected order lives only in the URL.

## Failure stays local

Each element group sits in its own `RemoteGate`. If a remote's server is down, only its card
turns into "Orders is unavailable" with a Retry button. The other remotes, the dashboard and the
navigation keep working. Orders comes back with Retry; after an Insights or Notes outage, reload
the page.

## Theme

`App` keeps the theme in state and writes `--shop-color-primary` on `:root`. Settings changes it
through the router's outlet context. Custom properties cross shadow roots, so the Angular, React
and Vue components recolour with the shell.

## Reaching the remotes and the API

The shell has no published port. Its proxy in `shop-edge`, `tools/edge/backoffice-react.conf`, is
published on `localhost:4200`. It serves the shell at `/` and reaches everything else by
Docker DNS name on the internal `shop-network`:

| Path on `localhost:4200` | Forwarded to |
| --- | --- |
| `/` | `http://backoffice-react:4200`, the shell |
| `/mf/orders/` | `http://orders:4201` |
| `/mf/insights/` | `http://insights:4202` |
| `/mf/notes/` | `http://notes:4402` |
| `/api/` | `http://mock-api:3000`, without the `/api` prefix; only for the page's own `fetch` |

So `remote-entries.ts` holds paths on this site (`/mf/orders/remoteEntry.json`), and the
elements' `fetch('/api/orders')` goes through the same proxy.

## Run it

```bash
docker compose -f compose.backoffices.yaml up --build --watch backoffice-react
```

The shell needs the other groups running: start everything once with `tools\scripts\start-all.bat`, then this command rebuilds the shell and watches its files. The site opens through its proxy in `shop-edge`.

## What to try

- `/dashboard` shows the Insights tiles and the open orders from Orders. Every API call comes from
  those two elements; the shell itself makes none.
- An order link opens `/orders/<id>` with that order in the Angular detail and the Vue notes.
- The shell's filter changes the Angular list; a React tile changes the filter and the list.
- A row click changes the URL; the detail and the notes follow. Back and forward restore it.
- A Vue note appears in the React feed; "Mark as shipped" changes the React counts.
- In Settings, Orange recolours every component.
- Stop the `orders` container in Docker Desktop: only the Orders card shows the error; start it
  and press Retry.
