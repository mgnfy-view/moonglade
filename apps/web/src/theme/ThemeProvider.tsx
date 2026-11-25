import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'

export type ThemeMode = 'light' | 'dark'

interface ThemeContextValue {
  theme: ThemeMode
  setTheme: (next: ThemeMode) => void
  toggleTheme: () => void
}

const STORAGE_KEY = 'moonglade-theme'
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

  const toggleTheme = useCallback(() => {
    setThemeState((prev) => (prev === 'dark' ? 'light' : 'dark'))
  }, [])

  return (
    <ThemeContext.Provider value={{ theme, setTheme, toggleTheme }}>
      {children}
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
