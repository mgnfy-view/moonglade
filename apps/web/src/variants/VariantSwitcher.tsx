import { Moon, Sun } from 'lucide-react'
import { useTheme } from '../theme/ThemeProvider'
import { VARIANTS_META } from './types'
import { useLandingVariant } from './variantContext'

const SHOW_SWITCHER =
  import.meta.env.DEV || import.meta.env.VITE_ENABLE_VARIANT_SWITCHER === 'true'

export function VariantSwitcher() {
  const { variant, setVariant } = useLandingVariant()
  const { theme, toggleTheme } = useTheme()

  if (!SHOW_SWITCHER) return null

  return (
    <aside
      aria-label="Shell variant switcher"
      className="fixed bottom-3 left-3 z-50 inline-flex items-center gap-1 rounded-[var(--radius-sm)] border border-hairline-strong bg-glass p-1 backdrop-blur-md shadow-sm"
    >
      <span className="hidden sm:inline px-2 text-[10px] font-medium uppercase tracking-[0.08em] text-ink-muted">
        Shell
      </span>
      {VARIANTS_META.map((item) => {
        const active = item.id === variant
        return (
          <button
            key={item.id}
            type="button"
            onClick={() => setVariant(item.id)}
            title={item.name}
            aria-pressed={active}
            className={`min-h-[28px] min-w-[32px] rounded-[var(--radius-xs)] px-2.5 text-xs font-medium tabular-nums transition-colors ${
              active
                ? 'bg-ink text-canvas'
                : 'text-ink-secondary hover:bg-accent-soft hover:text-ink'
            }`}
          >
            {item.shortLabel}
          </button>
        )
      })}
      <span className="mx-0.5 h-4 w-px bg-hairline" aria-hidden="true" />
      <button
        type="button"
        onClick={toggleTheme}
        aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
        title={theme === 'dark' ? 'Daylight Mist' : 'Midnight Desk'}
        className="inline-flex h-7 w-7 items-center justify-center rounded-[var(--radius-xs)] text-ink hover:bg-accent-soft"
      >
        {theme === 'dark' ? (
          <Sun size={14} aria-hidden="true" />
        ) : (
          <Moon size={14} aria-hidden="true" />
        )}
      </button>
    </aside>
  )
}
