import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import type { VariantId } from './types'

const STORAGE_KEY = 'moonglade-landing-variant'

interface VariantContextValue {
  variant: VariantId
  setVariant: (next: VariantId) => void
}

const VariantContext = createContext<VariantContextValue | null>(null)

export function isVariantId(value: string | null | undefined): value is VariantId {
  return value === 'v1' || value === 'v3'
}

function resolveEnvDefault(): VariantId {
  const envVal = import.meta.env.VITE_LANDING_VARIANT
  return isVariantId(envVal) ? envVal : 'v1'
}

function resolveInitialVariant(search: string): VariantId {
  const param = new URLSearchParams(search).get('variant')
  if (isVariantId(param)) {
    try {
      window.sessionStorage.setItem(STORAGE_KEY, param)
    } catch {
      // Ignore storage failures.
    }
    return param
  }
  try {
    const stored = window.sessionStorage.getItem(STORAGE_KEY)
    if (isVariantId(stored)) return stored
  } catch {
    // Ignore storage failures.
  }
  return resolveEnvDefault()
}

export function VariantProvider({ children }: { children: ReactNode }) {
  const location = useLocation()
  const navigate = useNavigate()
  const [variant, setVariantState] = useState<VariantId>(() =>
    resolveInitialVariant(location.search),
  )

  useEffect(() => {
    const param = new URLSearchParams(location.search).get('variant')
    if (isVariantId(param) && param !== variant) {
      setVariantState(param)
      try {
        window.sessionStorage.setItem(STORAGE_KEY, param)
      } catch {
        // Ignore storage failures.
      }
    }
  }, [location.search, variant])

  useEffect(() => {
    document.documentElement.dataset.landingVariant = variant
  }, [variant])

  const setVariant = useCallback(
    (next: VariantId) => {
      setVariantState(next)
      try {
        window.sessionStorage.setItem(STORAGE_KEY, next)
      } catch {
        // Ignore storage failures.
      }
      const params = new URLSearchParams(location.search)
      params.set('variant', next)
      navigate(
        {
          pathname: location.pathname,
          search: `?${params.toString()}`,
          hash: location.hash,
        },
        { replace: true },
      )
    },
    [location.hash, location.pathname, location.search, navigate],
  )

  return (
    <VariantContext.Provider value={{ variant, setVariant }}>
      {children}
    </VariantContext.Provider>
  )
}

export function useLandingVariant(): VariantContextValue {
  const ctx = useContext(VariantContext)
  if (!ctx) {
    throw new Error('useLandingVariant must be used inside VariantProvider')
  }
  return ctx
}
