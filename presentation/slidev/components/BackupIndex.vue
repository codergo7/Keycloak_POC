<script setup lang="ts">
// Backup index: every backup slide, grouped by topic. Each entry links to its slide by
// routeAlias (set in that slide's frontmatter), and shows the slide's current number.
import { useNav } from '@slidev/client'

const { slides } = useNav()

const groups = [
  { t: 'Requests through Envoy', cls: 'blue', items: [
    { a: 'b-claims', l: 'Every endpoint and the claim it needs' },
    { a: 'b-six', l: 'Six requests, where each one stops' },
    { a: 'b-filters', l: 'From Istio YAML to envoy.filters.http.*' },
    { a: 'b-debug', l: 'How to debug a 401 or 403' },
  ] },
  { t: 'Browser access and security', cls: 'orange', items: [
    { a: 'b-spoof', l: 'Can someone fake who they are?' },
    { a: 'b-policy', l: 'The CUSTOM policy: when OAuth2-Proxy is asked' },
    { a: 'b-headers', l: 'Every sensitive header, hop by hop' },
  ] },
  { t: 'Tokens and sessions', cls: 'green', items: [
    { a: 'b-lifetimes', l: 'Token, session and cookie lifetimes' },
    { a: 'b-limits', l: 'Keycloak session limits: idle and max' },
    { a: 'b-logout', l: 'What does signing out really end?' },
    { a: 'b-kcdown', l: 'What if Keycloak goes down?' },
  ] },
  { t: 'Design questions', cls: 'navy', items: [
    { a: 'b-audience', l: 'Audience and scopes: likely questions' },
    { a: 'b-s2s', l: 'One service calling another' },
    { a: 'b-lessons', l: 'Six issues we found' },
  ] },
]
function no(alias: string) {
  return slides.value.find(s => s.meta.slide?.frontmatter.routeAlias === alias)?.no ?? '?'
}
</script>

<template>
  <div class="bi">
    <div v-for="g in groups" :key="g.t" class="grp" :class="g.cls">
      <div class="gt">{{ g.t }}</div>
      <Link v-for="i in g.items" :key="i.a" :to="i.a" class="it">
        <span class="no">{{ no(i.a) }}</span><span class="lb">{{ i.l }}</span><span class="go">→</span>
      </Link>
    </div>
  </div>
</template>

<style scoped>
.bi { display: grid; grid-template-columns: 1fr 1fr; gap: 0.7rem; margin-top: 0.8rem; }
.grp { background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.6rem 0.75rem 0.5rem; border-top: 3px solid var(--c); }
.grp.blue { --c: #2459c9; } .grp.orange { --c: #c2570c; } .grp.green { --c: #1f8a5b; } .grp.navy { --c: #14213d; }
.gt { font: 700 0.6rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.08em; color: var(--c); margin-bottom: 0.3rem; }
.it { display: flex; align-items: center; gap: 0.55rem; padding: 0.2rem 0.35rem; border-radius: 6px; color: #1b2433 !important; text-decoration: none !important; border: none !important; font-size: 0.78rem; transition: background 0.2s; }
.it:hover { background: #eef2fa; }
.no { flex: none; min-width: 1.5rem; text-align: center; font: 700 0.62rem 'JetBrains Mono', monospace; color: #fff; background: var(--c); border-radius: 5px; padding: 0.1rem 0.25rem; }
.lb { flex: 1; }
.go { color: #b8c3d8; }
.it:hover .go { color: var(--c); }
</style>
