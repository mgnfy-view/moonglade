import { useState } from 'react'
import { Moon, Sun } from 'lucide-react'
import { motion, useReducedMotion } from 'motion/react'
import { useLocation } from 'react-router-dom'
import { useTheme } from '../../theme/ThemeProvider'

export function ThemeToggle({ compact = false }: { compact?: boolean }) {
  const { theme, toggleTheme } = useTheme()
  const { pathname } = useLocation()
  const reducedMotion = useReducedMotion()
  const [dipTick, setDipTick] = useState(0)
  const isDark = theme === 'dark'
  const isLanding = pathname === '/'

  return (
    <motion.button
      type="button"
      onClick={(event) => {
        const rect = event.currentTarget.getBoundingClientRect()
        if (isLanding && !reducedMotion) {
          setDipTick((prev) => prev + 1)
        }
        toggleTheme({
          ripple: isLanding,
          origin: {
            x: rect.left + rect.width / 2,
            y: rect.top + rect.height / 2,
          },
        })
      }}
      animate={
        dipTick > 0 && isLanding && !reducedMotion
          ? {
              scale: [1, 0.84, 1.03, 1],
              y: [0, 2, -0.5, 0],
            }
          : undefined
      }
      transition={{ duration: 0.42, ease: [0.22, 1, 0.36, 1] }}
      aria-label={isDark ? 'Switch to light theme' : 'Switch to dark theme'}
      title={isDark ? 'Daylight Mist (Light)' : 'Midnight Desk (Dark)'}
      className={`relative inline-flex min-h-[40px] min-w-[40px] items-center justify-center rounded-[var(--radius-xs)] border border-hairline bg-transparent text-xs font-medium text-ink transition-colors hover:border-accent hover:bg-accent-soft ${
        compact ? 'p-2' : 'gap-2 px-3 py-2'
      }`}
    >
      {isDark ? (
        <Sun size={15} strokeWidth={1.6} aria-hidden="true" />
      ) : (
        <Moon size={15} strokeWidth={1.6} aria-hidden="true" />
      )}
      {!compact && <span>{isDark ? 'Light' : 'Dark'}</span>}
    </motion.button>
  )
}
