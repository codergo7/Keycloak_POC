<script setup lang="ts">
// Per-slide layer: on backup slides (routeAlias "b-…"), a small link back to the backup index.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $frontmatter } = useSlideContext()
const isBackup = computed(() => String($frontmatter.value?.routeAlias ?? $frontmatter?.routeAlias ?? '').startsWith('b-'))
</script>

<template>
  <Link v-if="isBackup" to="backup-index" class="to-index">↩ index</Link>
</template>

<style scoped>
.to-index {
  position: absolute; top: 1.1rem; right: 1.4rem; z-index: 20;
  font: 600 0.6rem 'JetBrains Mono', monospace; color: #7a8496 !important;
  background: rgba(255, 255, 255, 0.85); border: 1px solid #e0e3ea !important; border-radius: 6px;
  padding: 0.15rem 0.5rem; text-decoration: none !important; transition: all 0.2s;
}
.to-index:hover { color: #2459c9 !important; border-color: #2459c9 !important; }
</style>
