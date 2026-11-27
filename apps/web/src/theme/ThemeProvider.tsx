import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import { flushSync } from 'react-dom'
import { ThemeRippleOverlay, type RippleTriggerPayload } from './ThemeRippleOverlay'

export type ThemeMode = 'light' | 'dark'

export interface ToggleThemeOptions {
  origin?: { x: number; y: number }
  ripple?: boolean
}

interface ThemeContextValue {
  theme: ThemeMode
  setTheme: (next: ThemeMode) => void
  toggleTheme: (options?: ToggleThemeOptions) => void
}

const STORAGE_KEY = 'moonglade-theme'
const RIPPLE_DURATION_MS = 920
const ThemeContext = createContext<ThemeContextValue | null>(null)

function readInitialTheme(): ThemeMode {
  if (typeof document !== 'undefined') {
    const attr = document.documentElement.dataset.theme
    if (attr === 'dark' || attr === 'light') return attr
  }
  return 'light'
}

function applyThemeToDocument(theme: ThemeMode) {
  if (typeof document === 'undefined') return
  const root = document.documentElement
  root.dataset.theme = theme
  root.style.colorScheme = theme
  const meta = document.querySelector('meta[name="theme-color"]')
  if (meta) {
    meta.setAttribute('content', theme === 'dark' ? '#050129' : '#faf9fd')
  }
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<ThemeMode>(readInitialTheme)
  const rippleTriggerRef = useRef<((payload: RippleTriggerPayload) => void) | null>(null)

  const registerTrigger = useCallback((fn: (payload: RippleTriggerPayload) => void) => {
    rippleTriggerRef.current = fn
  }, [])

  useEffect(() => {
    applyThemeToDocument(theme)
    try {
      window.localStorage.setItem(STORAGE_KEY, theme)
    } catch {
      // Ignore storage failures in private browsing.
    }
  }, [theme])

  const setTheme = useCallback((next: ThemeMode) => {
    setThemeState(next)
  }, [])

  const toggleTheme = useCallback(
    (options?: ToggleThemeOptions) => {
      const next: ThemeMode = theme === 'dark' ? 'light' : 'dark'
      const reducedMotion =
        typeof window !== 'undefined' &&
        window.matchMedia('(prefers-reduced-motion: reduce)').matches

      const docWithTransition = document as Document & {
        startViewTransition?: (cb: () => void) => {
          ready: Promise<void>
          finished: Promise<void>
        }
      }

      if (!options?.ripple || reducedMotion || !docWithTransition.startViewTransition) {
        setThemeState(next)
        return
      }

      const x = options.origin?.x ?? window.innerWidth / 2
      const y = options.origin?.y ?? window.innerHeight / 2
      const maxRadius = Math.hypot(
        Math.max(x, window.innerWidth - x),
        Math.max(y, window.innerHeight - y),
      )

      const root = document.documentElement
      root.classList.add('theme-rippling')

      const transition = docWithTransition.startViewTransition(() => {
        flushSync(() => {
          setThemeState(next)
          applyThemeToDocument(next)
        })
      })

      transition.ready
        .then(() => {
          rippleTriggerRef.current?.({ x, y, maxRadius, durationMs: RIPPLE_DURATION_MS })
          root.animate(
            {
              clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${maxRadius}px at ${x}px ${y}px)`],
            },
            {
              duration: RIPPLE_DURATION_MS,
              easing: 'cubic-bezier(0.22, 0.61, 0.36, 1)',
              pseudoElement: '::view-transition-new(root)',
            },
          )
        })
        .catch(() => {
          root.classList.remove('theme-rippling')
        })

      transition.finished.finally(() => {
        root.classList.remove('theme-rippling')
      })
    },
    [theme],
  )

  return (
    <ThemeContext.Provider value={{ theme, setTheme, toggleTheme }}>
      {children}
      <ThemeRippleOverlay registerTrigger={registerTrigger} />
    </ThemeContext.Provider>
  )
}

export function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext)
  if (!ctx) {
    throw new Error('useTheme must be used inside ThemeProvider')
  }
  return ctx
}
