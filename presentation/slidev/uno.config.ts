// Slidev merges this with its own UnoCSS config. Its built-in icon preset fails
// to auto-load @iconify-json/carbon here, so the collection is declared explicitly
// (needed for the `i-carbon-*` classes, also inside v-for strings).
// UnoCSS de-duplicates presets by name, so this one needs its own name.
import { defineConfig, presetIcons } from 'unocss'

const carbonIcons = presetIcons({
  scale: 1.1,
  collections: {
    carbon: () => import('@iconify-json/carbon/icons.json').then(m => m.default as any),
  },
})

export default defineConfig({
  presets: [{ ...carbonIcons, name: 'carbon-icons' }],
})
