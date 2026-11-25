import { Moon, Sun } from 'lucide-react'
import { useTheme } from '../../theme/ThemeProvider'

export function ThemeToggle({ compact = false }: { compact?: boolean }) {
  const { theme, toggleTheme } = useTheme()
  const isDark = theme === 'dark'

  return (
    <button
      type="button"
      onClick={toggleTheme}
      aria-label={isDark ? 'Switch to light theme' : 'Switch to dark theme'}
      title={isDark ? 'Daylight Mist (Light)' : 'Midnight Desk (Dark)'}
      className={`inline-flex min-h-[40px] min-w-[40px] items-center justify-center rounded-[var(--radius-xs)] border border-hairline bg-transparent text-xs font-medium text-ink transition-colors hover:border-accent hover:bg-accent-soft ${
        compact ? 'p-2' : 'gap-2 px-3 py-2'
      }`}
    >
      {isDark ? (
        <Sun size={15} strokeWidth={1.6} aria-hidden="true" />
      ) : (
        <Moon size={15} strokeWidth={1.6} aria-hidden="true" />
      )}
      {!compact && <span>{isDark ? 'Light' : 'Dark'}</span>}
    </button>
  )
}
