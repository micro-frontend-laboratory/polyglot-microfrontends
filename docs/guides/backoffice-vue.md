# The Vue back office, hosting all three frameworks

`apps/backoffices/backoffice-vue` is the second shell: a Vue app (`npm create vite@latest`,
Vue + TypeScript template) that puts the Angular components from Orders, the React components
from Insights and the Vue components from Notes on one page. It imports none of them. All three
are loaded at runtime, the first time `/orders` opens. Its colour is green (`#16a34a`).

The shell runs **Vue 3.5.42** on purpose, older than the Notes components it hosts (Vue 3.5.44):
the header shows the shell's version, and each Notes element carries `data-vue-version="3.5.44"`.
`package.json` pins `vue` to exactly `3.5.42`, so npm cannot move it to the newer release.

| Route | What it shows |
| --- | --- |
| `http://localhost:4400/dashboard` | The Insights statistics and the Orders list of open orders; a click opens the order |
| `http://localhost:4400/orders` | The shell's filter and the five elements, wired together by the shell |
| `http://localhost:4400/orders/A-1003` | The same page opened with an order (a deep link) |
| `http://localhost:4400/settings` | The theme switch |

It has the same pages and layout as [backoffice-react](backoffice-react.md), so this guide shows
what is different.

## The project

```text
src/
  remote-entries.ts          where each remote lives
  remotes/
    orders-remote.ts         Native Federation
    insights-remote.ts       Module Federation
    notes-remote.ts          Module Federation
    module-federation.ts     the Module Federation runtime instance
    RemoteGate.vue           loading text, then the slot or an error card with Retry
  components/StatusFilter.vue the shell's own All / Open / Shipped filter (defineModel)
  pages/                     DashboardPage.vue, OrdersPage.vue, SettingsPage.vue
  theme/themes.ts            the three themes and the injection key
  shared/use-activity-log.ts
  App.vue  router.ts  main.ts  styles.css
```

The same packages as the React shell, in their Vue versions: `vue-router`,
`@softarc/native-federation-orchestrator` and `@module-federation/runtime`, plus the three element contracts
as dev dependencies. The event handlers on the Orders page take their `detail` types from the
contracts, for example `(event: CustomEvent<IOrderSelectedDetail>)` from `@shop/orders-contract`.

## Three remotes, two runtimes

```ts
export const moduleFederation = createInstance({
  name: 'backoffice_vue',
  remotes: [
    { name: 'insights', entry: remoteEntries.insights, type: 'module' },
    { name: 'notes', entry: remoteEntries.notes, type: 'module' },
  ],
  shared: {},
  shareStrategy: 'loaded-first',
});
```

- **The same loaders as the React shell**, with `@module-federation/runtime`; `vite.config.ts`
  has only the Vue plugin.
- **`shared: {}`.** The shell's Vue is never offered, so Notes loads its own Vue next to the
  shell's, and Insights brings its own React.
- **Orders** is loaded by the orchestrator, exactly as in the React shell.
- **`isCustomElement`** for `shop-` tags tells the Vue compiler that they are not Vue components.

## The page wires everything

```vue
<StatusFilter v-model="status" @update:model-value="filterChanged" />

<shop-orders-list :status="status" page-size="10" @orderSelected="orderSelected" />
<shop-order-detail :order-id="props.orderId" @orderUpdated="orderUpdated" @closed="orderClosed" />

<shop-order-stats :refresh-key="String(refreshCount)" @statusPicked="statusPicked" />
<shop-order-notes :order-id="props.orderId" @noteAdded="noteAdded" />
<shop-activity-feed :entries="entries" @cleared="clear" />
```

The router passes the order id as a prop (`props: true` on `/orders/:orderId?`), so the page reads
it like any other input and hands it to two elements from two frameworks.

| Who | Does what | How the others learn |
| --- | --- | --- |
| The shell's own filter (Vue) | picks a status | `status` on the Angular list |
| React stat tile (Insights) | `statusPicked` | the shell's filter and the Angular list follow |
| Angular list (Orders) | `orderSelected` | the URL changes; the Angular detail and the Vue notes follow it |
| Vue notes (Notes) | `noteAdded` | the React feed logs it |
| Angular detail (Orders) | `orderUpdated` | `refresh-key` changes; the React counts reload |
| Angular detail (Orders) | `closed` | back to `/orders` |

On a plain element, Vue keeps the event name exactly as written, so `@orderSelected` listens to
`orderSelected`. The handlers receive the `CustomEvent` and read `event.detail`.

## Failure stays local

Each element group sits in a `RemoteGate`. With `docker compose -f compose.microfrontends.yaml stop orders`, only the Orders card
shows "Orders is unavailable"; the filter, the notes and the React statistics keep working,
and Retry recovers after `docker compose -f compose.microfrontends.yaml start orders`. As in the React shell, a Module
Federation remote that was down recovers on a page reload.

## Theme

`App.vue` keeps the theme in a `ref`, writes `--shop-color-primary` on `:root` with
`watchEffect`, and `provide`s the ref. `SettingsPage.vue` `inject`s it and changes it. Custom
properties cross shadow roots, so every component recolours with the shell.

## Reaching the remotes and the API

The shell has no published port. Its proxy in `shop-edge`, `tools/edge/backoffice-vue.conf`, is
published on `localhost:4400`. It serves the shell at `/` and reaches everything else by
Docker DNS name on the internal `shop-network`:

| Path on `localhost:4400` | Forwarded to |
| --- | --- |
| `/` | `http://backoffice-vue:4400`, the shell |
| `/mf/orders/` | `http://orders:4201` |
| `/mf/insights/` | `http://insights:4202` |
| `/mf/notes/` | `http://notes:4402` |
| `/api/` | `http://mock-api:3000`, without the `/api` prefix; only for the page's own `fetch` |

So `remote-entries.ts` holds paths on this site (`/mf/orders/remoteEntry.json`), and the
elements' `fetch('/api/orders')` goes through the same proxy.

## Run it

```bash
docker compose -f compose.backoffices.yaml up --build --watch backoffice-vue
```

The shell needs the other groups running: start everything once with `tools\scripts\start-all.bat`, then this command rebuilds the shell and watches its files. The site opens through its proxy in `shop-edge`.

## What to try

- `/dashboard` shows the Insights tiles and the open orders from Orders. Every API call comes from
  those two elements; the shell itself makes none.
- An order link opens `/orders/<id>` with that order in the Angular detail and the Vue notes.
- The shell's filter changes the Angular list; a React tile changes the filter and the list.
- A row click changes the URL; the detail and the notes follow.
- A Vue note appears in the React feed; "Mark as shipped" changes the React counts.
- Everything is green, inside every shadow root too; in Settings, Orange recolours every component.
- `docker compose -f compose.microfrontends.yaml stop orders`: only the Orders card fails; Retry recovers it.
