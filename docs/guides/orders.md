# Orders, from an Angular app to web components

`apps/microfrontends/orders` is a regular Angular application, written the way the Angular team recommends.
The same two components are then turned into custom elements without changing a line inside
them. The app shows both side by side:

| Route | What it shows |
| --- | --- |
| `http://localhost:4200/mf/orders/components` | Step 1: the components used by Angular, the normal way |
| `http://localhost:4200/mf/orders/web-components` | Step 2: the same components as `<shop-orders-list>` and `<shop-order-detail>` |

## Step 1: a correct Angular app

```text
contract/                      @shop/orders-contract: what other apps may use (step 2)
src/app/
  orders/                      everything about orders, grouped by kind
    clients/
      orders-client.ts         OrdersClient: the API operations this app calls
      observable-api.ts        ObservableApi: the API contract with Observables instead of Promises
    services/
      orders-service.ts        OrdersService: what the components use; calls the client
    config/
      orders-config.ts         the ORDERS_CONFIG injection token
      provide-orders.ts        provideOrders(config): registers the config, client and service
    components/
      orders-list/             OrdersList
      order-detail/            OrderDetail
      order-status-select/     OrderStatusSelect
  pages/                       one page per route
  shared/event-log.ts
  elements.ts                  the transformation to web components (step 2)
  app.config.ts                the providers of the whole app
```

**Configuration through dependency injection.** The components never receive a URL.
`orders/config/orders-config.ts` holds the API address, and `provideOrders()` provides it once,
like `provideHttpClient()` or `provideRouter()`:

```ts
export const ordersConfig: IOrdersConfig = { apiBase: '/api' };

export const appConfig: ApplicationConfig = {
  providers: [provideRouter(routes), provideHttpClient(), provideOrders()],
};
```

**Two layers, both injected.** `OrdersClient` only talks HTTP: URLs and `HttpClient`.
It implements the three operations of the API team's contract that this app calls, with
`Observable`s instead of `Promise`s:

```ts
export class OrdersClient
  implements ObservableApi<Pick<IOrdersApi, 'listOrders' | 'getOrder' | 'updateOrderStatus'>>
```

`IOrdersApi`, the models and the parameter types come from `@shop/api-contract`, installed from
`apps/services/mock-api/contract`. A wrong parameter or result type does not compile. `OrdersService` is
what the components use; today it mostly calls the client, and it is where the app's own logic
goes. Both are plain `@Injectable()` classes with no
`providedIn: 'root'`: they exist only where an app calls `provideOrders(...)`, and the components
ask for the service with `inject(OrdersService)`.

**Components own only their own inputs and outputs.** `OrdersList` has `status` and `pageSize`
and emits `orderSelected`; `OrderDetail` has `orderId` and emits `orderUpdated` and `closed`.
They load data with `rxResource`, which turns the service's `Observable`s into signals, so a
changed input reloads by itself.

**Sharing state through the service.** After `OrderDetail` saves a change, `OrdersService` bumps
a `changeCount` signal that `OrdersList` reads in its resource `params`, so the list reloads
without the two components knowing about each other.

The page wires them like any Angular template, checked by the compiler:

```html
<app-orders-list [status]="status()" (orderSelected)="selectOrder($event)" />
<app-order-detail [orderId]="selectedOrderId()" (closed)="closeOrder($event)" />
```

## Step 2: the transformation to web components

Two choices in the components make the transformation possible, and they are good Angular
anyway:

| In the component | Why it matters for a custom element |
| --- | --- |
| `encapsulation: ViewEncapsulation.ShadowDom` | The styles live inside the element's Shadow DOM, so they cannot leak into React or Vue pages, and theirs cannot leak in |
| Signal `input()` and `output()` | Angular Elements maps each `input()` to an attribute and a property (`orderId` → `order-id`) and each `output()` to a `CustomEvent` with the value in `detail` |
| `--shop-*` custom properties with fallbacks | The host's theme crosses the Shadow DOM boundary; nothing else does |
| Text only through `{{ }}` | Angular writes interpolations with `textContent`, so customer data never runs as HTML |

**The contract.** What other apps may rely on is published in `contract/` as
`@shop/orders-contract`: each tag with its attributes, properties and events, and the type of
`defineElements`. The components use its event detail types for their `output()`s.

Everything else lives in one file, `elements.ts`:

```ts
export const defineElements: IOrdersRemote['defineElements'] = () => {
  elementsDefined ??= registerElements();
  return elementsDefined;
};

async function registerElements(): Promise<void> {
  const application = await createApplication({
    providers: [provideZonelessChangeDetection(), provideHttpClient(), provideOrders()],
  });
  defineElement<IOrdersListContract>('shop-orders-list', OrdersList, application.injector);
  defineElement<IOrderDetailContract>('shop-order-detail', OrderDetail, application.injector);
}
```

`defineElement` accepts a component only if it has an `input()` for every property of the
contract and an `output()` for every event, with the contract's types. Rename `orderSelected` in
`OrdersList` and the build stops with
`Property 'orderSelected' is missing in type 'OrdersList'`.

What each line does:

- **`createApplication`** starts Angular without a root component: only an injector. It gets the
  same providers as `app.config.ts`, so the components find `OrdersService` exactly as before.
- **`provideOrders()`**: the elements get the same API address as the app's own pages. The host
  passes nothing: the elements are standalone and call the endpoint they know.
- **`provideZonelessChangeDetection()`** is explicit on purpose. A host such as the Angular 20 shell loads
  Zone.js; the elements must not depend on it.
- **One injector for both tags**, so the list and the detail share one `OrdersService`, as in
  step 1.
- **`createCustomElement` + `customElements.define`** registers the tags. The guard makes
  `defineElements` safe to call from every page and every host.

The host then uses tags, attributes and DOM events. In this app, `app.config.ts` calls
`defineElements()` through `provideAppInitializer`, so the tags exist before the first
route renders:

```html
<shop-orders-list [attr.status]="status()" (orderSelected)="selectOrder($event)"></shop-orders-list>
<shop-order-detail [attr.order-id]="selectedOrderId()" (closed)="closeOrder($event)"></shop-order-detail>
```

## What changes for the host

| | Angular component (step 1) | Custom element (step 2) |
| --- | --- | --- |
| Tag | `<app-orders-list>` | `<shop-orders-list>` |
| Usable from | this Angular app only | any page: React, Vue, an older Angular, plain HTML |
| Data in | `[status]="…"`, typed | attribute `status="open"` or property `list.status = 'open'` |
| Events out | `(orderSelected)`, typed value | `CustomEvent`, value in `event.detail` |
| Configuration | `provideOrders()` in `app.config.ts` | none: `defineElements()` once, the element knows its API |
| Checked by | the Angular compiler | the contract in [architecture.md](../architecture.md#contracts) |

## Step 3: share it with Native Federation

Steps 1 and 2 run inside this app. To let the React, Vue and Angular shells load the same
`defineElements` at runtime, the app also publishes it as a federation remote. One dependency is
added: `@angular-architects/native-federation`.

`federation.config.mjs` names what other apps may load:

```js
export default withNativeFederation({
  name: 'orders',
  exposes: {
    './elements': './src/app/elements.ts',
  },
  shared: fromPackageJson({ singleton: true, strictVersion: true, requiredVersion: 'auto', build: 'package' })
    .patch(['@angular/*'], { includeSecondaries: { keepAll: true } })
    .get(),
});
```

- **`exposes`** publishes `elements.ts` and nothing else: the shells get `defineElements`, never
  the app's pages or routes.
- **`shared`** lets another Angular remote reuse this app's Angular instead of downloading a
  second copy.

`main.ts` starts federation first, then the unchanged app, now in `bootstrap.ts`:

```ts
initFederation({}, { hostRemoteEntry: { url: './remoteEntry.json' }, shimMode: false })
  .then(() => import('./bootstrap'));
```

Why a separate file: shared packages such as `@angular/core` are not bundled; the browser finds
them through an import map that `initFederation()` creates. Static `import` lines load before any
code runs, so `main.ts` must not import Angular directly. The dynamic `import('./bootstrap')`
loads the app only after the import map exists. This is the usual Native Federation and Module
Federation convention.

The same dev server now serves both the app and the remote:

| URL | What it is |
| --- | --- |
| `http://localhost:4200/mf/orders/components`, `/web-components` | the app, exactly as before |
| `http://localhost:4200/mf/orders/remoteEntry.json` | the manifest: `name: orders`, exposes `./elements` |

A shell loads it like this:

```ts
await initFederation({ orders: '/mf/orders/remoteEntry.json' });
const { defineElements } = await loadRemoteModule({ remoteName: 'orders', exposedModule: './elements' });
await defineElements();
```

## Run it

```bash
docker compose -f compose.microfrontends.yaml up --build --watch orders
```

The remote is internal; the shells load it through their proxies. Start everything once with `tools\scripts\start-all.bat`, then this command rebuilds the remote and watches its files.

## What to try

- `/components` lists 5 orders; the status select filters them; a click fills the detail; "Mark
  as shipped" updates the list; the event log shows `(orderSelected)`, `(orderUpdated)`, `(closed)`.
- `/web-components` does the same with the custom elements, and its log shows the DOM events.
- `http://localhost:4200/mf/orders/remoteEntry.json` lists `./elements`.
- The Network tab shows no `zone.js`: the app is zoneless.
