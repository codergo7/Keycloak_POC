<script setup lang="ts">
// OAuth2-Proxy turns three tokens into one session cookie (first 3 clicks of slide 7).
// Click 1: Keycloak hands over ID, access and refresh token on the back channel.
// Click 2: OAuth2-Proxy packs, compresses, encrypts and signs them (v7 cookie session store).
// Click 3: one Set-Cookie _oauth2_proxy goes to the browser.
// Measured on the cluster (oauth2-proxy v7.15.3, alice): token sizes 1,142 / 1,193 / 766 chars;
// cookie 3,516 chars = 3,460 encrypted | 10 timestamp | 44 signature; HttpOnly, SameSite=Lax, 8 h.
// From click 4 on the component fades out and the slide's cards take over.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 4))

const tokens = [
  { k: 'id', name: 'ID token', what: 'who logged in: alice, her email', meta: 'RS256 · ~1.1 KB' },
  { k: 'ac', name: 'Access token', what: 'for the APIs: roles, audience', meta: 'RS256 · 5 min · ~1.2 KB' },
  { k: 'rf', name: 'Refresh token', what: 'gets new tokens, only for Keycloak', meta: 'HS512 · 30 min · ~0.8 KB' },
]
const stations = [
  { v: 'pack', d: '3 tokens + user, email, expiry' },
  { v: 'compress', d: 'LZ4' },
  { v: 'encrypt', d: 'AES-GCM, key = cookie-secret' },
  { v: 'sign', d: 'HMAC-SHA256 + timestamp' },
]
const notes = [
  'At the end of a login, OAuth2-Proxy has three tokens from Keycloak. The browser must not hold them in readable form.',
  'On the back channel, Keycloak returns three tokens: the ID token, the access token and the refresh token.',
  'OAuth2-Proxy packs them into one session, compresses it, encrypts it with its cookie-secret and signs it.',
  'The browser gets one cookie. It can send it back, but it cannot read or change what is inside.',
]
</script>

<template>
  <div class="tc" :class="{ gone: s >= 4 }">
    <div class="stage">
      <svg class="wires" viewBox="0 0 860 232">
        <path d="M130 125 H370" class="w" :class="{ on: s === 1 }" />
        <path d="M670 125 H730" class="w ok" :class="{ on: s >= 3 }" />
      </svg>

      <div class="node kc" :class="{ on: s === 1 }">Keycloak<small>POST /token · back channel</small></div>

      <div v-for="(t, i) in tokens" :key="t.k" class="tok" :class="[t.k, 'p' + Math.min(s, 2)]"
        :style="{ '--i': i, top: s >= 1 && s < 2 ? 14 + i * 76 + 'px' : '' }">
        <div class="tn"><span class="dot" />{{ t.name }}</div>
        <div class="tw">{{ t.what }}</div>
        <div class="tm mono">{{ t.meta }}</div>
      </div>

      <div class="proxy" :class="{ on: s >= 2 }">
        <div class="ph">OAuth2-Proxy <small class="mono">v7 · cookie session</small></div>
        <div class="sess mono" :class="{ show: s >= 2 }">
          <i class="id" /><i class="ac" /><i class="rf" /><span>+ user · email · expiry</span>
        </div>
        <div v-for="(st, i) in stations" :key="st.v" class="st" :class="{ lit: s >= 2 }" :style="{ '--d': 0.5 + i * 0.45 + 's' }">
          <b class="n">{{ i + 1 }}</b><b>{{ st.v }}</b><span class="mono">{{ st.d }}</span><em>✓</em>
        </div>
      </div>

      <div class="node br" :class="{ on: s >= 3 }">Browser<small>alice</small></div>
      <div class="cookie mono" :class="{ show: s >= 3 }">_oauth2_proxy</div>
      <div class="setc mono" :class="{ show: s >= 3 }">Set-Cookie</div>
    </div>

    <div class="anat mono" :class="{ show: s >= 3 }">
      <span class="lbl">_oauth2_proxy =</span>
      <span class="seg enc">lSXX8KZHJZwH…<small>encrypted session · 3,460</small></span><span class="bar">|</span>
      <span class="seg ts">1794585771<small>created</small></span><span class="bar">|</span>
      <span class="seg sig">sg3NN7AWI12M…<small>signature · 44</small></span>
      <span class="flags">HttpOnly · SameSite=Lax · 8 h · 3.5 KB &lt; 4 KB</span>
    </div>

    <Transition name="n" mode="out-in">
      <p :key="s" class="note"><b v-if="s">{{ s }}.</b> {{ notes[Math.min(s, 3)] }}</p>
    </Transition>
  </div>
</template>

<style scoped>
.tc { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --violet: #7b3fbf; --muted: #7a8496; transition: opacity 0.4s; }
.tc.gone { opacity: 0; pointer-events: none; }
.mono { font-family: 'JetBrains Mono', monospace; }
.stage { position: relative; width: 860px; height: 232px; margin: 0 auto; }
.wires { position: absolute; inset: 0; width: 100%; height: 100%; }
.w { fill: none; stroke: #d6d8dc; stroke-width: 2; stroke-dasharray: 5 6; transition: stroke 0.4s; }
.w.on { stroke: var(--blue); animation: flow 0.8s linear infinite; }
.w.ok.on { stroke: var(--green); }
@keyframes flow { to { stroke-dashoffset: -11; } }

.node {
  position: absolute; top: 90px; width: 130px; height: 70px; display: flex; flex-direction: column; align-items: center; justify-content: center;
  background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; font-weight: 700; color: var(--navy); font-size: 0.9rem;
  box-shadow: 0 8px 24px -18px rgba(20, 33, 61, 0.5); transition: all 0.4s;
}
.node small { font: 500 0.5rem 'JetBrains Mono', monospace; color: var(--muted); margin-top: 0.15rem; }
.node.on { background: var(--navy); color: #fff; border-color: var(--navy); }
.node.on small { color: #8db4ff; }
.kc { left: 0; }
.br { left: 730px; }

/* the three tokens: hidden in Keycloak → lined up on the wire → swallowed by the proxy */
.tok {
  position: absolute; left: 6px; top: 96px; width: 196px; padding: 0.3rem 0.55rem; background: #fff; border: 1px solid #e6eaf2;
  border-left: 4px solid var(--c); border-radius: 10px; box-shadow: 0 10px 24px -20px rgba(20, 33, 61, 0.6);
  opacity: 0; transform: scale(0.5); transition: all 0.7s cubic-bezier(0.3, 0.8, 0.2, 1); transition-delay: calc(var(--i) * 0.12s);
}
.tok.p1 { left: 156px; opacity: 1; transform: none; }
.tok.p2 { left: 420px; top: 44px; opacity: 0; transform: scale(0.25); }
.tok.id { --c: var(--violet); } .tok.ac { --c: var(--blue); } .tok.rf { --c: var(--orange); }
.tn { display: flex; align-items: center; gap: 0.35rem; font-weight: 700; font-size: 0.68rem; color: var(--navy); }
.dot { width: 0.45rem; height: 0.45rem; border-radius: 50%; background: var(--c); }
.tw { font-size: 0.56rem; color: #1b2433; }
.tm { font-size: 0.5rem; color: var(--muted); }

.proxy {
  position: absolute; left: 370px; top: 0; width: 300px; height: 216px; border: 1.5px dashed #c9d2e3; border-radius: 14px;
  background: rgba(255, 255, 255, 0.55); padding: 0.45rem 0.6rem; transition: all 0.4s;
}
.proxy.on { border-style: solid; border-color: var(--navy); box-shadow: 0 18px 40px -28px rgba(20, 33, 61, 0.6); }
.ph { font-weight: 800; font-size: 0.82rem; color: var(--navy); display: flex; align-items: baseline; gap: 0.4rem; }
.ph small { font-size: 0.48rem; color: var(--muted); font-weight: 500; }
.sess {
  display: flex; align-items: center; gap: 0.2rem; margin: 0.35rem 0 0.3rem; height: 1.3rem; padding: 0 0.4rem; border-radius: 8px;
  background: #eef2fa; font-size: 0.5rem; color: var(--navy); opacity: 0; transform: scaleX(0.3); transform-origin: left;
  transition: all 0.6s cubic-bezier(0.3, 0.8, 0.2, 1) 0.35s;
}
.sess.show { opacity: 1; transform: none; }
.sess i { width: 1.6rem; height: 0.55rem; border-radius: 3px; }
.sess i.id { background: var(--violet); } .sess i.ac { background: var(--blue); } .sess i.rf { background: var(--orange); }
.sess span { margin-left: 0.3rem; }
.st {
  display: grid; grid-template-columns: 1.1rem 4.1rem 1fr auto; align-items: center; height: 2.05rem; margin-top: 0.28rem;
  padding: 0 0.45rem; border-radius: 8px; border: 1px solid #e6eaf2; background: #fff; font-size: 0.62rem; color: #9aa3b2;
  transition: all 0.45s; transition-delay: 0s;
}
.st b { font-weight: 700; }
.st .n { font-size: 0.55rem; }
.st span { font-size: 0.5rem; }
.st em { font-style: normal; font-weight: 800; color: var(--green); opacity: 0; transform: scale(0.5); transition: all 0.3s; transition-delay: 0s; }
.st.lit { color: var(--navy); border-color: #b9c8e6; background: #f5f8ff; transition-delay: var(--d); }
.st.lit span { color: #1b2433; }
.st.lit em { opacity: 1; transform: none; transition-delay: calc(var(--d) + 0.25s); }

.cookie {
  position: absolute; left: 560px; top: 190px; padding: 0.22rem 0.55rem; border-radius: 99px; background: var(--green); color: #fff;
  font-size: 0.56rem; font-weight: 700; opacity: 0; transform: scale(0.6); transition: all 0.8s cubic-bezier(0.3, 0.8, 0.2, 1);
}
.cookie.show { left: 724px; top: 172px; opacity: 1; transform: none; transition-delay: 0.15s; }
.setc { position: absolute; left: 676px; top: 104px; font-size: 0.48rem; font-weight: 700; color: var(--green); opacity: 0; transition: opacity 0.4s 0.5s; }
.setc.show { opacity: 1; }

.anat {
  display: flex; align-items: flex-start; gap: 0.25rem; flex-wrap: wrap; width: 860px; margin: 0.65rem auto 0; font-size: 0.6rem; color: var(--navy);
  opacity: 0; transform: translateY(8px); transition: all 0.5s 0.6s;
}
.anat.show { opacity: 1; transform: none; }
.lbl { font-weight: 700; padding-top: 0.15rem; }
.seg { display: flex; flex-direction: column; padding: 0.15rem 0.45rem; border-radius: 6px; font-weight: 600; }
.seg small { font-size: 0.45rem; font-weight: 500; color: var(--muted); }
.seg.enc { background: #def3e8; } .seg.ts { background: #eef2fa; } .seg.sig { background: #fcebdd; }
.bar { color: var(--muted); padding-top: 0.15rem; }
.flags { margin-left: auto; padding-top: 0.15rem; font-size: 0.52rem; color: var(--green); font-weight: 700; }

.note { font-size: 0.86rem; color: #1b2433; min-height: 2.4rem; margin: 0.55rem 0 0; text-align: left; }
.n-enter-active, .n-leave-active { transition: all 0.25s; }
.n-enter-from { opacity: 0; transform: translateY(6px); }
.n-leave-to { opacity: 0; }
</style>
