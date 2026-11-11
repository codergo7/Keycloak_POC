<script setup lang="ts">
// "Four components, four jobs": one card per click, with what each component hands to the next.
// Click 5 shows all four as equals, for the one-line summary. The slide needs `clicks: 5`.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 5))

const cards = [
  { icon: 'i-carbon-password', n: 'Keycloak', r: 'Identity provider', d: 'Knows the users, checks passwords, issues signed tokens.', cls: '' },
  { icon: 'i-carbon-earth', n: 'OAuth2-Proxy', r: 'Browser login', d: 'Runs the login flow for browsers and keeps the session cookie.', cls: '' },
  { icon: 'i-carbon-security', n: 'Istio', r: 'Policy enforcement', d: 'Validates tokens and applies access rules at the edge and at each pod.', cls: 'orange' },
  { icon: 'i-carbon-code', n: 'Spring Boot · FastAPI', r: 'Applications', d: 'Do their business job. No login code, no token parsing.', cls: 'navy' },
]
// what goes from card i to card i + 1
const hand = ['signed tokens', 'identity headers + token', 'checked request']

function cardState(i: number) {
  if (s.value === 5) return 'all'
  if (i >= s.value) return 'hidden'
  return i === s.value - 1 ? 'active' : 'past'
}
</script>

<template>
  <div class="cf">
    <template v-for="(c, i) in cards" :key="c.n">
      <div class="card cf-card" :class="cardState(i)">
        <span class="icon-dot mb-3" :class="c.cls"><span :class="c.icon" /></span>
        <h3>{{ c.n }}</h3>
        <div class="mono text-xs mb-2" :class="i === 2 ? 'text-[var(--orange)]' : 'text-[var(--blue)]'">{{ c.r }}</div>
        <p>{{ c.d }}</p>
      </div>
      <div v-if="i < cards.length - 1" class="hand" :class="{ on: s >= i + 2 }">
        <div class="lbl">{{ hand[i] }}</div>
        <div class="line"><span /></div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.cf { display: grid; grid-template-columns: 1fr 64px 1fr 64px 1fr 64px 1fr; align-items: stretch; margin-top: 1.25rem; }
.cf-card { padding: 1rem !important; transition: all 0.55s cubic-bezier(0.2, 0.7, 0.2, 1); }
.cf-card.hidden { opacity: 0; transform: translateY(40px) rotateX(35deg); }
.cf-card.past { opacity: 0.55; }
.cf-card.active { transform: translateY(-6px); box-shadow: 0 0 0 2px var(--blue), 0 14px 28px -12px rgba(20, 33, 61, 0.45); }
.cf-card.all { opacity: 1; }

.hand { position: relative; display: flex; align-items: center; padding: 0 4px; opacity: 0; transition: opacity 0.4s 0.25s; }
.hand.on { opacity: 1; }
.lbl { position: absolute; left: 0; right: 0; bottom: calc(50% + 6px); font: 600 0.5rem/1.25 'JetBrains Mono', monospace; color: var(--orange); text-align: center; }
.line { width: 100%; height: 2px; background: #d5d9e2; position: relative; overflow: visible; }
.line span { position: absolute; inset: 0; background: var(--orange); transform-origin: left; transform: scaleX(0); transition: transform 0.6s 0.3s ease-out; }
.hand.on .line span { transform: scaleX(1); }
.line::after { content: ''; position: absolute; right: -2px; top: -4px; border: 5px solid transparent; border-left: 7px solid var(--orange); border-right: 0; opacity: 0; transition: opacity 0.2s 0.85s; }
.hand.on .line::after { opacity: 1; }
</style>
