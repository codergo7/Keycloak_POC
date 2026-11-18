<script setup lang="ts">
// Per-slide layer:
// - the slide number at the bottom right of every slide except the title, so people can ask about "slide 14";
// - on backup slides (routeAlias "b-…"), a small link back to the backup index.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $frontmatter, $page } = useSlideContext()
const fm = computed(() => ($frontmatter as any)?.value ?? $frontmatter ?? {})
const isBackup = computed(() => String(fm.value.routeAlias ?? '').startsWith('b-'))
const isNavy = computed(() => String(fm.value.class ?? '').includes('navy'))
</script>

<template>
  <Link v-if="isBackup" to="backup-index" class="to-index">↩ index</Link>
  <div v-if="$page > 1" class="slide-no" :class="{ dark: isNavy }">{{ $page }}</div>
</template>

<style scoped>
.to-index {
  position: absolute; top: 1.1rem; right: 1.4rem; z-index: 20;
  font: 600 0.6rem 'JetBrains Mono', monospace; color: #7a8496 !important;
  background: rgba(255, 255, 255, 0.85); border: 1px solid #e0e3ea !important; border-radius: 6px;
  padding: 0.15rem 0.5rem; text-decoration: none !important; transition: all 0.2s;
}
.to-index:hover { color: #2459c9 !important; border-color: #2459c9 !important; }

.slide-no {
  position: absolute; right: 1.4rem; bottom: 0.9rem; z-index: 20; min-width: 1.6rem; text-align: center;
  font: 700 0.62rem 'JetBrains Mono', monospace; color: #7a8496;
  background: rgba(255, 255, 255, 0.85); border: 1px solid #e0e3ea; border-radius: 6px; padding: 0.12rem 0.4rem;
}
.slide-no.dark { color: #c9d3e6; background: rgba(255, 255, 255, 0.08); border-color: rgba(255, 255, 255, 0.2); }
</style>
