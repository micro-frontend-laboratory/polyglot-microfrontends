# CLAUDE.md

This repository, `polyglot-microfrontends`
(https://github.com/micro-frontend-laboratory/polyglot-microfrontends), belongs to the GitHub
organization `micro-frontend-laboratory` (https://github.com/micro-frontend-laboratory), where it
is part 2 of 5. It is a conference demo: one online shop back office, told in two acts.
The audience reads the code on screen, so the code must be clean and obvious.

1. **Pure Web Components:** `apps/basics/web-components-basics`, the native API with no framework.
2. **Micro-frontends calling each other:** the latest Angular (`apps/microfrontends/orders`),
   React (`apps/microfrontends/insights`) and Vue (`apps/microfrontends/notes`) export custom
   elements, each from its own live server; the React, Vue and Angular shells load them at
   runtime through federation and use them all on one page. The Angular shell, on an older
   Angular, hosts web components built with the latest Angular.

There is no package or "installed instead of loaded" variant: remotes are always live services.
Every README, guide and demo step should make clear which act it belongs to.

README and `docs/` are for someone who downloads the repo: what each app is, how to run it, how
it works. Build warnings, workarounds and package debates go in the pitfalls below, not there.

- [docs/architecture.md](docs/architecture.md): the apps, the rules, the contracts.
- [docs/showcase.md](docs/showcase.md): the live demo script.
- `docs/guides/<app>.md`: how each app is built, added in the stage that builds it.

## Rules

1. **Never change a contract.** Tag, attribute, property and event names, `detail` shapes,
   theme tokens and ports are listed in [docs/architecture.md](docs/architecture.md#contracts).
2. **Never commit to `main`.** Each stage is built on its own branch `feature/<what we built>`.
   When a stage is done, stop and let the user review it. Commit and push only when the user
   says so. Pull requests are opened from the feature branch into `main`.
3. **No comments in code.** Names carry the meaning. Explanations belong in `docs/`.
4. **No test suites.** Verify each stage yourself (lint, typecheck, build, open it in a browser),
   but do not commit test files.
5. **Show data with `textContent`**, never `innerHTML`, `dangerouslySetInnerHTML`, `v-html`
   or `[innerHTML]`.
6. **Every folder is an independent npm project** with its own `package.json`, `node_modules`
   and `package-lock.json`. No workspaces, no root `package.json`.
   Keep dependencies few and well known; prefer a few lines of our own code to an unfamiliar package.
   **Order of work for every project:** write `package.json` first, stop and let the user review
   every dependency, let the user install, then write the code.
   **The user runs every `npm` and `npx` command** (install, ci, run, scaffolders such as
   `ng new`), on the host and in containers. Give the exact command and folder, then wait.
   Docker image builds that run `npm ci` from a reviewed `package-lock.json` are fine.
   **Contracts are local packages.** Each team publishes a types-only contract in its own folder
   (`apps/services/mock-api/contract` → `@shop/api-contract`, `apps/microfrontends/<name>/contract` →
   `@shop/<name>-contract`). Consumers install it as a `devDependency` with `npm install <folder>`
   (a `file:` link), listed last in its section so local packages stand out; nothing is published
   to a registry (`"private": true`). No app keeps a copy
   of a shared type: models, parameters, event details and `defineElements` come from the
   contracts. Only micro-frontends call the API, each with its own endpoint; `defineElements()`
   takes no configuration, and shells pass none. Each micro-frontend writes its own HTTP client for the operations it calls and declares them
   (`implements Pick<IOrdersApi, '…'>`); each remote's elements are checked against their contract.
7. **Strict TypeScript** (`"strict": true`) in every TypeScript project. Plain JavaScript only
   where the point is "no build": `apps/basics/`.
8. **Each framework's default linter** behind `npm run lint`: ESLint with angular-eslint for
   Angular and the plain projects, oxlint (what `npm create vite` generates) for React and Vue.
   **No Prettier.** Formatting is VS Code's built-in formatters, set in the committed
   `.vscode/settings.json` (format on save, single quotes, semicolons), plus `.editorconfig`.
   Write code in that style: 2-space indent, single quotes, semicolons, lines under ~100 chars.
   **Interfaces start with `I`** (`IOrder`, `IOrdersConfig`, `IOrderSelectedDetail`) so a reader
   can tell an interface from a class (`OrdersService`, `OrdersClient`) at a glance. Type aliases
   (`OrderStatus`) and classes keep plain names.
9. **Latest stable versions**, except `apps/backoffices/backoffice-angular`, the shell, which stays on
   Angular 20 (`~20.3`) with Zone.js, `*ngIf`, `@Input()`, constructor injection and NgModules
   (`AppModule`, `AppRoutingModule`, components with `standalone: false`) on purpose, the way most
   Angular developers know it. The Angular
   web components it hosts come from `apps/microfrontends/orders`, on the latest Angular.
   **Every shell runs a different version of its framework than the remote it hosts**, on purpose:
   React shell 19 / Insights 18, Vue shell 3.5.42 / Notes 3.5.44, Angular shell 20 / Orders 22. Do
   not "upgrade" Insights or the shells. Insights keeps `react-router` 7 (8 needs React 19). The
   Vue shell is pinned to exactly `3.5.42` (no `^` or `~`, which would install 3.5.44), the Angular
   shell to `~20.3`. Each remote loads its own framework copy. Elements stamp the
   version they run on (`ng-version`, `data-react-version`, `data-vue-version`), and each shell's
   header shows its own.
10. When a guide's code does not work with the installed version, fix it minimally and update
    the guide in the same change.
11. **Everything runs through Docker**, following Docker's official guides
    (https://docs.docker.com/guides/angular/ and the equivalents for React and Vue). Each app has
    a `Dockerfile.dev` (dev server, Compose Watch) and a service in its group's `compose.<group>.yaml`.
    No production images or `-prod` services. Run and verify apps only
    with `docker compose`, never with a server started on the host. `npm install` on the host is
    fine: it keeps `package-lock.json` current and gives the editor its types.

## Layout and ports

Apps that export custom elements live in `apps/microfrontends/`; the shells that host them live
in `apps/backoffices/`; the back-end services they call live in `apps/services/`; the act 1 page
lives in `apps/basics/`. A reader should see from the path which side an app is on, and each
folder matches a Compose group. `tools/` holds only what runs around the apps: the edge proxies
and the scripts.

The apps form five Docker Compose projects, one per group, each with its own file in the repo
root. Docker Desktop shows each group on its own; `depends_on` never crosses groups.

| Group | File | Services | Networks | Published |
| --- | --- | --- | --- | --- |
| `shop-services` | `compose.services.yaml` | `mock-api` | creates `shop-network` (`internal: true`) | nothing |
| `shop-microfrontends` | `compose.microfrontends.yaml` | `orders`, `insights`, `notes` | `shop-network` (`external: true`) | nothing |
| `shop-backoffices` | `compose.backoffices.yaml` | `backoffice-react`, `backoffice-vue`, `backoffice-angular` | `shop-network` (`external: true`) | nothing |
| `shop-edge` | `compose.edge.yaml` | `backoffice-react-proxy`, `backoffice-vue-proxy`, `backoffice-angular-proxy` | `shop-network` and `shop-public` | 4200, 4400, 4500 |
| `shop-basics` | `compose.basics.yaml` | `web-components-basics` | its own default network | 4100 |

`shop-services` starts first because it creates `shop-network`; a group that joins it before it
exists fails with "network shop-network not found". `shop-network` is internal: no access from
the host, no internet at runtime. The edge proxies are the only containers on both networks.

| Act | Folder | What | Internal address | Public address |
| --- | --- | --- | --- | --- |
| 1 | `apps/basics/web-components-basics` | Three native Web Components | | `localhost:4100` |
| 2 | `apps/microfrontends/orders` | Latest Angular, exports `shop-orders-list`, `shop-order-detail` | `orders:4201/mf/orders/` | none |
| 2 | `apps/microfrontends/insights` | React 18, exports `shop-order-stats`, `shop-activity-feed` | `insights:4202/mf/insights/` | none |
| 2 | `apps/microfrontends/notes` | Vue 3.5, exports `shop-order-notes` | `notes:4402/mf/notes/` | none |
| 2 | `apps/backoffices/backoffice-react` | React 19 shell | `backoffice-react:4200/` | `localhost:4200` through its proxy |
| 2 | `apps/backoffices/backoffice-vue` | Vue 3.5.42 shell | `backoffice-vue:4400/` | `localhost:4400` through its proxy |
| 2 | `apps/backoffices/backoffice-angular` | Angular 20 shell (NgModules, Zone.js) | `backoffice-angular:4500/` | `localhost:4500` through its proxy |
| all | `apps/services/mock-api` | Orders REST API (Express, TypeScript run directly by Node) | `mock-api:3000` | none |
| all | `tools/edge` | One nginx proxy per shell: `<shell>.conf` and one `Dockerfile.dev` with `ARG SITE` | | 4200, 4400, 4500 |

Each proxy serves its shell at `/` and forwards `/mf/orders/`, `/mf/insights/`, `/mf/notes/` and
`/api/` (prefix stripped) by Docker DNS name. The remotes serve under the same `/mf/<name>/`
(Vite `base`, Angular `baseHref` and `servePath`), so their absolute file paths resolve inside
every site; the `/mf/` prefix keeps them clear of the shells' own routes like `/orders/A-1003`.
Shells and remote entries use these relative paths only. A proxy answers `/api/` only for
`Sec-Fetch-Site: same-origin` with `Sec-Fetch-Mode` `cors` or `same-origin`, and only `GET`,
`POST`, `PATCH`; everything else gets `403`. The mock API sends no CORS headers.

A new remote needs a `location` in every `tools/edge/*.conf`, never a `ports:` line. A new site
needs its own `.conf` and a proxy service in `compose.edge.yaml`.

```bash
docker compose -f compose.services.yaml up --build --detach --wait          # first: creates shop-network
docker compose -f compose.microfrontends.yaml up --build --detach --wait
docker compose -f compose.backoffices.yaml up --build --detach --wait
docker compose -f compose.edge.yaml up --build --detach --wait
docker compose -f compose.basics.yaml up --build --detach --wait
docker compose -f compose.microfrontends.yaml watch                         # live edits, one group per terminal
docker compose -f compose.services.yaml up -d --force-recreate mock-api     # back to the seed data
```

`tools/scripts/start-all.bat` and `live-all.bat` run the groups in this order; the `deploy-*.bat`
scripts sit in one folder per group.

Plain JavaScript projects (`apps/basics/`) are served by `nginx:stable-alpine` with no
npm at runtime; Node projects start with `npm start` (or `npm run start:docker`) inside their
image. Dev servers must listen on `0.0.0.0` in Docker only.
Use Compose Watch (`develop.watch`), not bind mounts, so edits on Windows reach the container.

## Stages

Each stage is one branch and one pull request, and ends with something that runs in Docker:
every app arrives with its `Dockerfile.dev` and its Compose service.

| # | Branch | Adds | Done when |
| --- | --- | --- | --- |
| 1 | `feature/foundation` | README, CLAUDE.md, architecture and demo docs, VS Code settings, `tools/mock-api`, `compose.yaml` | container is healthy; `/orders` returns 5, `?status=open` returns 3, PATCH works, recreating the container restores the seed |
| 2 | `feature/web-components-basics` | act 1: `examples/web-components-basics` | the page works; typed HTML shows as text |
| 3 | `feature/orders` | `apps/microfrontends/orders` (latest Angular) | dev page lists orders, row click fills the detail, "Mark as shipped" updates the list; `remoteEntry.json` exposes `./elements`; no `zone.js` |
| 4 | `feature/insights` | `apps/microfrontends/insights` | `/components` and `/web-components` work; `remoteEntry.js` exposes `./elements` and works from another origin |
| 5 | `feature/backoffice-react` | `apps/backoffices/backoffice-react` | dashboard, `/orders` master-detail, deep link, theme switch, error card |
| 6 | `feature/notes-and-backoffice-vue` | `apps/microfrontends/notes`, the notes API, the `microfrontends` / `backoffices` folders | Notes' `remoteEntry.js` exposes `./elements` and works from another origin |
| 6b | `feature/backoffice-vue` | `apps/backoffices/backoffice-vue` | Vue shell shows Angular + React + Vue on `/orders`; only the failed remote shows an error card |
| 7 | `feature/backoffice-angular` | `apps/backoffices/backoffice-angular` | demo acts 2.1, 2.2 and 2.4 pass; two `ng-version` values on one page |
| 8 | `feature/run-scripts` | Windows `.bat` shortcuts in `tools/scripts/` around `docker compose` `start-all`, `live-all` and one `deploy-*` per service; stopping is done from Docker Desktop |
| 9 | `feature/rename-polyglot-microfrontends` | the name `polyglot-microfrontends` and its place in the `micro-frontend-laboratory` organization: README navigation, clone snippet, "Go deeper" | README and CLAUDE.md name the repo and its URL |

## Known pitfalls

| Symptom | Fix |
| --- | --- |
| 404 or `index.html` instead of a remote's file | The remote is not serving under `/mf/<name>/`, or a proxy lacks its `location`; check the remote's Vite `base` or Angular `baseHref`/`servePath` against `tools/edge/*.conf` |
| `403` from `localhost:4200/api/...` in curl or the address bar | Expected: only the pages' `fetch` passes the proxy's `Sec-Fetch-*` check. To look at the API, use DevTools on a shell page, send `-H "Sec-Fetch-Site: same-origin" -H "Sec-Fetch-Mode: cors"`, or run `docker compose -f compose.services.yaml exec mock-api node -e "fetch('http://localhost:3000/orders').then(r=>r.text()).then(console.log)"` |
| A service needs the internet at runtime (a CDN, an npm download in `npm start`) | `shop-network` is `internal`; install everything in the image at build time, where the network is open |
| A proxy returns 502 for one path | That service is down or still starting; nginx resolves names at request time (`resolver 127.0.0.11` with a variable in `proxy_pass`), so the other paths keep working |
| Vite live reload does not connect through a proxy | The proxy must forward `Upgrade`/`Connection` and keep `Host $http_host` |
| `Failed to resolve component: shop-...` in Vue | Set `isCustomElement` for `shop-` tags in the Vite Vue plugin |
| Vue custom element events have an array `detail` and do not bubble | Vue's `defineCustomElement` dispatches `detail: [...args]` without `bubbles`/`composed`. `defineVueElement` in `apps/microfrontends/notes` wraps the component and dispatches the contract `CustomEvent` from `useHost()` instead |
| Vue build: `Failed to resolve index type into finite keys` | `defineEmits` cannot take a mapped type over a contract's event keys. Write the event names literally (`{ noteAdded: [detail: Events['noteAdded']] }`); `defineProps<Partial<IContract['properties']>>()` works. `elements.ts` checks the names against the contract |
| `npm ci` in a Docker build fails on a `file:` contract | The contract folder is not in the image. App images build from the repo root (`context: .`) and `COPY` each contract folder to the same relative path under `/repo` before `npm ci` |
| Native Federation warns `No meta data found for shared lib @shop/...` | A contract is in `dependencies`; it holds only types. Keep contracts in `devDependencies` |
| `tsc` passes but `ng build` fails in an Angular app | `tsc` does not check templates. Run `ng build` after changing an `input()` type a template binds to |
| oxlint reports React hook rules in a Vue project | Use the Vue plugins in `.oxlintrc.json` (`vue`, `typescript`, `oxc`), not the React config |
| React remote in another page: `@vitejs/plugin-react can't detect preamble` | Exclude the exposed folder from Fast Refresh: `react({ exclude: [/\/node_modules\//, /\/src\/insights\//] })` |
| Remote files load from the shell's own files instead of the remote's | Set `base` to the remote's proxied path (`/mf/insights/`, `/mf/notes/`) in `vite.config.ts` |
| A shell downloads every `remoteEntry.js` on its first page | Module Federation's default `shareStrategy: 'version-first'` fetches all remotes up front; set `shareStrategy: 'loaded-first'` in the shell's `createInstance` |
| Retry never recovers a Module Federation remote after an outage | The browser caches a failed `import()` of `remoteEntry.js` until the page reloads; reload the page. Native Federation fetches `remoteEntry.json` first, so its Retry works |
| Two federation formats | Angular remotes: Native Federation (`remoteEntry.json`). React and Vue remotes: `@module-federation/vite` (`remoteEntry.js`). Every shell loads them with the same two runtimes: `@softarc/native-federation-orchestrator` and `@module-federation/runtime` |
| Shells: should they use `@module-federation/vite`? | No. A host only consumes remotes and shares nothing (every remote's framework version differs from its shell's on purpose), so it needs the two runtimes and no federation build. Only the React and Vue remotes use the plugin, to build their `remoteEntry.js` |
| Do not set `ENV NODE_ENV=development` in a Vite `Dockerfile.dev` | The React guide does not; Vite sets the mode itself |
| Angular shell: should it use `@angular-architects/native-federation`? | No. The shell exposes nothing and shares nothing with Angular 22. The orchestrator plus `@module-federation/runtime` load all three remotes |
| Angular shell: `Component ... is standalone, and cannot be declared in an NgModule` | Since Angular 19 components are standalone by default. Components declared in an NgModule need `standalone: false` |
| Angular shell: lint asks for `inject()` and standalone components | The shell keeps the classic style on purpose; `prefer-inject` and `prefer-standalone` are off in its `eslint.config.mjs` |
| A proxy returns 502 although the service is healthy | The dev server listens on `127.0.0.1` inside the container. Bind `0.0.0.0` in Docker only (a `docker` configuration or a `start:docker` script), never in the local `npm start` |
| Edits do not reach the container | Start with `--watch`, and check the service's `develop.watch` paths |
| `docker compose watch` says "cannot take exclusive lock" | Another `watch` for this group is still running; stop it first. Each group has its own lock |
| nginx container is "unhealthy" but the page loads | Alpine resolves `localhost` to `::1`: nginx needs `listen [::]:80;` as well as `listen 80;` |
| `esbuild` or `rollup` binary errors in a container | Host `node_modules` leaked in: keep `node_modules` in every `.dockerignore` |
| An event never arrives | Event names are case-sensitive, and the listener must be on the element itself |
| React 18 (Insights' own pages): the feed stays empty, events never arrive | React 18 passes everything on a custom element as an attribute (`entries="[object Object]"`) and attaches no `on…` listener. Set properties and add listeners through refs; keep Insights' JSX typings to attributes only |
| React 19: a custom element event never arrives | React keeps the name after `on` exactly as written: `onstatusPicked` listens to `statusPicked`; `onStatusPicked` would listen to `StatusPicked` |
| The activity feed does not update | Assign a new array to `entries`; never mutate it |
| `Unknown argument: host` from `ng serve` | The federation builder has no `host` option. Put `"host": "0.0.0.0"` in a `docker` configuration of the `serve-original` dev server, point the federation `serve` target's `docker` configuration at it, and run `npm run start:docker` in the image. Local `npm start` keeps `localhost` |
| Federation: `Could not resolve "@angular/animations/browser"` | `keepAll` shares every Angular entry point; add `@angular/platform-browser/animations` and `.../animations/async` to `skip` |
| `ng add` for federation adds `es-module-shims` and the orchestrator to `package.json` | Both are already dependencies of `@angular-architects/native-federation`; keep only that one. Use native import maps: `shimMode: false` in `initFederation` and `esmsInitOptions` |
| Native Federation `ng add` fails | On Angular 20 or 21 the package is `@angular-architects/native-federation-v4`; on 22+ it is `@angular-architects/native-federation` |
