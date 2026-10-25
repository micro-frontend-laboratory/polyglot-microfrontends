# The Angular back office, an older host for new components

`apps/backoffices/backoffice-angular` is the third shell, and it is older on purpose: Angular 20,
written the classic way with NgModules, Zone.js, `*ngIf`, `@Input()` and constructor injection,
the way most Angular teams still work.
On its `/orders` page it hosts the latest Angular (Orders), React (Insights) and Vue (Notes).
Its colour is red (`#dc2626`).

| Route | What it shows |
| --- | --- |
| `http://localhost:4500/dashboard` | The Insights statistics and the Orders list of open orders; a click opens the order |
| `http://localhost:4500/orders` | The shell's filter and the five elements, wired together by the shell |
| `http://localhost:4500/orders/A-1003` | The same page opened with an order (a deep link) |
| `http://localhost:4500/settings` | The theme switch |

It has the same pages and layout as [backoffice-react](backoffice-react.md) and
[backoffice-vue](backoffice-vue.md).

It uses the classic `AppModule` and `AppRoutingModule`. Its components are declared in
NgModules, so each one says `standalone: false`.

## The project

```text
src/app/
  app.module.ts               AppModule: BrowserModule, routing, SharedModule
  app-routing.module.ts       /dashboard, and /orders as a lazy OrdersModule
  app.component.*             header and navigation
  remote-entries.ts           where each remote lives
  services/
    remote-elements.service.ts   loads the three remotes, once each
  shared/                     SharedModule: the RemoteGateComponent, for the dashboard and Orders
  dashboard/                  DashboardPageComponent: the Insights and Orders elements
  settings/                   SettingsPageComponent, uses ThemeService
  services/theme.service.ts   the three themes; apply() sets --shop-color-primary
  orders/
    orders.module.ts          declares the page and the filter, imports SharedModule
    orders-routing.module.ts  one route for /orders and /orders/:orderId
    orders-page/              the page that wires the five elements
    status-filter/            the shell's own All / Open / Shipped filter (@Input / @Output)
```

Two browser runtimes are added to the template:

| Package | Why |
| --- | --- |
| `@softarc/native-federation-orchestrator` | Reads Orders' `remoteEntry.json`, writes the import map for Angular 22, imports `./elements` |
| `@module-federation/runtime` | Loads Insights' and Notes' `remoteEntry.js`; the same runtime the React and Vue shells use |

The shell exposes nothing and cannot share Angular 20 with Angular 22, so it needs no federation
build: only the two runtimes, in the browser. It builds with the standard `@angular/build`
application builder.

The three element contracts are dev dependencies, installed from their teams' folders. The shell
never calls the API, so it has no HTTP client and no `HttpClientModule`; the
remote loader is typed with each remote's `defineElements`, and the Orders page's handlers take
their `detail` types from the element contracts.

## Loading three remotes

`RemoteElementsService` keeps one promise per remote and forgets it on failure, so Retry starts
again:

```ts
private readonly moduleFederation = createInstance({
  name: 'backoffice_angular',
  remotes: [
    { name: 'insights', entry: remoteEntries.insights, type: 'module' },
    { name: 'notes', entry: remoteEntries.notes, type: 'module' },
  ],
  shared: {},
  shareStrategy: 'loaded-first',
});

loadOrders(): Promise<void> {
  return this.loadOnce('orders', async () => {
    const nativeFederation = await initFederation({ orders: remoteEntries.orders });
    return nativeFederation.loadRemoteModule<IOrdersRemote>('orders', './elements');
  });
}
```

- **The same loaders as the React and Vue shells**: the orchestrator for Orders, the Module
  Federation runtime for Insights and Notes.
- **`shared: {}`.** The shell has no React and no Vue to offer, so each remote uses its own copy.

## The page wires everything

The router's single route uses a small `UrlMatcher`, so `/orders` and `/orders/A-1003` reuse
the same page and its activity feed. The order id comes from `route.paramMap` through the
`async` pipe.

```html
<app-remote-gate name="Orders" [load]="loadOrders">
  <ng-template>
    <shop-orders-list [attr.status]="status" page-size="10"
      (orderSelected)="orderSelected($event)"></shop-orders-list>
    <shop-order-detail [attr.order-id]="route.orderId"
      (orderUpdated)="orderUpdated($event)" (closed)="orderClosed($event)"></shop-order-detail>
  </ng-template>
</app-remote-gate>
```

- **`<ng-template>` inside the gate.** The elements are created only after their remote has
  defined them, through `*ngTemplateOutlet`.
- **`[attr.…]` for strings, `[entries]` for the array.** Exactly the contract: attributes for
  strings, a property for the feed.
- **`(orderSelected)`, `(statusPicked)`, …** Angular listens to the DOM events by their exact
  names; the handlers read `(event as CustomEvent<…>).detail`.
- **`CUSTOM_ELEMENTS_SCHEMA`** on `OrdersModule` lets the template use the `shop-` tags.

Zone.js triggers change detection for every event and every resolved load, as in any classic
Angular app; the Angular 22 elements run zoneless inside the same page.

## Theme

`ThemeService` is a root service, so the chosen theme survives navigation. Settings calls
`theme.apply(name)`, which writes `--shop-color-primary` on `:root` through the injected
`DOCUMENT`. Custom properties cross shadow roots, so every component recolours with the shell.

## Two Angular versions on one page

```js
document.querySelector('app-root').getAttribute('ng-version');         // 20.3.34
document.querySelector('shop-orders-list').getAttribute('ng-version'); // 22.2.3
```

## Reaching the remotes and the API

The shell has no published port. Its proxy in `shop-edge`, `tools/edge/backoffice-angular.conf`, is
published on `localhost:4500`. It serves the shell at `/` and reaches everything else by
Docker DNS name on the internal `shop-network`:

| Path on `localhost:4500` | Forwarded to |
| --- | --- |
| `/` | `http://backoffice-angular:4500`, the shell |
| `/mf/orders/` | `http://orders:4201` |
| `/mf/insights/` | `http://insights:4202` |
| `/mf/notes/` | `http://notes:4402` |
| `/api/` | `http://mock-api:3000`, without the `/api` prefix; only for the page's own `fetch` |

So `remote-entries.ts` holds paths on this site (`/mf/orders/remoteEntry.json`), and the
elements' `fetch('/api/orders')` goes through the same proxy.

## Run it

```bash
docker compose -f compose.backoffices.yaml up --build --watch backoffice-angular
```

The shell needs the other groups running: start everything once with `tools\scripts\start-all.bat`, then this command rebuilds the shell and watches its files. The site opens through its proxy in `shop-edge`.

## What to try

- Demo step 1: the shell's filter drives the Angular list; a React tile drives the filter; a row
  click changes the URL and the detail and the notes follow; a Vue note reaches the React feed;
  "Mark as shipped" changes the React counts.
- Demo step 2: two different `ng-version` values on one page.
- Demo step 4: `docker compose -f compose.microfrontends.yaml stop orders` leaves only the Orders card failing; Retry recovers it.
- Everything is red, inside every shadow root too; in Settings, Orange recolours every component.
