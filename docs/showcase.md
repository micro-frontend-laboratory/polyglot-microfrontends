# Demo script

Three micro-frontends, each with its own framework and its own server, run together in three
different shells.

Start everything first with `tools\scripts\start-all.bat`, and restore the seed data afterwards
with `tools\scripts\services\deploy-mock-api.bat`.

## 1. Any framework hosts any other

**Open** `http://localhost:4500/orders` (`backoffice-angular`).

- Click "Open" in the shell's own filter: the **Angular** list filters, the **React** feed logs it.
- Click a **React** stat tile: the shell's filter and the **Angular** list follow.
- Click an order in the **Angular** list: the URL changes, the detail and the **Vue** notes load.
- Add a note in **Vue**: it appears in the **React** feed.
- Mark the order as shipped in **Angular**: the **React** counts update.

**Message:** the plain custom element contract. Angular, React and Vue each ship a custom
element; the host listens to events and sets attributes. None of them imports another framework.

## 2. Versions don't matter

Every shell's header names its own framework version, and every element stamps the version it
runs on. In the browser console, on any of the three `/orders` pages:

```js
document.querySelector('shop-orders-list').getAttribute('ng-version');           // 22.x
document.querySelector('shop-order-stats').getAttribute('data-react-version');   // 18.x
document.querySelector('shop-order-notes').getAttribute('data-vue-version');     // 3.5.x
```

| Shell | Its own version | Hosts |
| --- | --- | --- |
| `http://localhost:4200` | React 19 (newer) | React 18 components from Insights |
| `http://localhost:4400` | Vue 3.5.42 (older) | Vue 3.5.44 components from Notes |
| `http://localhost:4500` | Angular 20 (older) | Angular 22 components from Orders; `app-root` says `ng-version="20.x"` |

A remote never relies on the shell's copy of its framework: Insights brings React 18 into the
React 19 shell, Notes brings Vue 3.5.44 into the Vue 3.5.42 shell.

**Message:** versions don't have to match, in either direction. Teams upgrade on their own
schedule.

## 3. Same components, different host

**Open** `http://localhost:4400/orders` (`backoffice-vue`) and `http://localhost:4200/orders`
(`backoffice-react`).

- The same Angular, React and Vue components, unchanged, with no rebuild.
- Each host paints everything in its own colour: Vue green, React blue, Angular red.
  In any back office, change the theme in Settings and watch every component recolour.

**Message:** the host decides the theme and the layout; the components don't care who hosts them.

## 4. Independent and resilient

In Docker Desktop, stop the `orders` container and reload `http://localhost:4500/orders`.

- Only the Orders card shows an error; the Vue and React parts keep working.
- Start `orders` again in Docker Desktop and click Retry.

**Message:** one team's outage never takes down the page.

## 5. One release, every shell

Open `apps/microfrontends/orders/src/app/orders/components/orders-list/orders-list.html` and
change the heading `Orders` to `Orders to ship`. Save, then deploy only the Orders team's
service with `tools\scripts\microfrontends\deploy-mf-orders.bat`. Reload `http://localhost:4200/orders`,
`http://localhost:4400/orders` and `http://localhost:4500/orders`.

- All three shells show the new heading. None of them was rebuilt or restarted.
- DevTools, Network tab: the Angular code comes from `/mf/orders/` on the site itself. The site's
  edge proxy fetched it from the Orders team's server, which the browser cannot reach.
- Change the heading back and deploy again with the same script.

**Message:** each team deploys on its own; a new release reaches every page at the next load.

## Closing slide

| Step | Takeaway |
| --- | --- |
| 1. Any framework hosts any other | Every framework can export and host custom elements |
| 2. Versions don't matter | Each remote brings its own framework version |
| 3. Same components, different host | The host owns URL, layout and theme |
| 4. Independent and resilient | One remote's outage stays on its own card |
| 5. One release, every shell | Each remote is a live service, deployed on its own |
