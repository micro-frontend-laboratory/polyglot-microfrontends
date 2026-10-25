<script setup lang="ts">
import { provide, ref, version, watchEffect } from 'vue';
import { themeKey, themes, type ThemeName } from './theme/themes';

const theme = ref<ThemeName>('Green');

watchEffect(() => {
  document.documentElement.style.setProperty('--shop-color-primary', themes[theme.value]);
});

provide(themeKey, theme);
</script>

<template>
  <header class="page-header">
    <h1>Shop Back Office</h1>
    <p>The Vue {{ version }} host. Angular, React and Vue components, loaded at runtime.</p>
    <nav class="page-nav">
      <RouterLink to="/dashboard">Dashboard</RouterLink>
      <RouterLink to="/orders">Orders</RouterLink>
      <RouterLink to="/settings">Settings</RouterLink>
    </nav>
  </header>

  <main>
    <RouterView />
  </main>
</template>
