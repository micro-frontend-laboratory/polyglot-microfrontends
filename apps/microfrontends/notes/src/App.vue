<template>
  <header class="page-header">
    <h1>Notes</h1>
    <p>Vue. The same two components, used two ways.</p>
    <nav class="page-nav">
      <RouterLink to="/components">Vue components</RouterLink>
      <RouterLink to="/web-components">Web components</RouterLink>
    </nav>
  </header>

  <main>
    <RouterView />
  </main>
</template>
