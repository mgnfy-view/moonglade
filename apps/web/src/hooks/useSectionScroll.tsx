import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react'
import Lenis from 'lenis'
import { useLocation } from 'react-router-dom'

export interface LandingSectionMeta {
  id: 'overview' | 'flows' | 'makers' | 'metrics' | 'faq'
  index: string
  label: string
}

export const LANDING_SECTIONS: readonly LandingSectionMeta[] = [
  { id: 'overview', index: '01', label: 'Overview' },
  { id: 'flows', index: '02', label: 'Flows' },
  { id: 'makers', index: '03', label: 'Makers' },
  { id: 'metrics', index: '04', label: 'Metrics' },
  { id: 'faq', index: '05', label: 'FAQ' },
] as const

interface LandingScrollContextValue {
  activeSection: LandingSectionMeta
  scrollProgress: number
  scrollToSection: (id: LandingSectionMeta['id']) => void
}

const LandingScrollContext = createContext<LandingScrollContextValue | null>(null)

const EASE_QUART_OUT = (t: number) => 1 - Math.pow(1 - t, 4)

export function LandingScrollProvider({ children }: { children: ReactNode }) {
  const { pathname } = useLocation()
  const isLanding = pathname === '/'
  const [activeSection, setActiveSection] = useState<LandingSectionMeta>(LANDING_SECTIONS[0])
  const [scrollProgress, setScrollProgress] = useState(0)
  const lenisRef = useRef<Lenis | null>(null)
  const lockUntilRef = useRef<number>(0)
  const wheelAccumRef = useRef<number>(0)
  const currentIdxRef = useRef<number>(0)

  const getTargets = useCallback((): HTMLElement[] => {
    const sections = LANDING_SECTIONS.map((s) => document.getElementById(s.id)).filter(
      (el): el is HTMLElement => el !== null,
    )
    const footer = document.querySelector('footer[data-landing-footer]')
    if (footer instanceof HTMLElement) sections.push(footer)
    return sections
  }, [])

  const scrollToTarget = useCallback((target: HTMLElement, duration = 1.3) => {
    const lenis = lenisRef.current
    if (lenis) {
      lenis.scrollTo(target, { duration, easing: EASE_QUART_OUT })
    } else {
      target.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }, [])

  const scrollToSection = useCallback(
    (id: LandingSectionMeta['id']) => {
      const idx = LANDING_SECTIONS.findIndex((s) => s.id === id)
      if (idx >= 0) {
        currentIdxRef.current = idx
        setActiveSection(LANDING_SECTIONS[idx])
      }
      const el = document.getElementById(id)
      if (el) {
        lockUntilRef.current = performance.now() + 900
        scrollToTarget(el, 1.35)
      }
    },
    [scrollToTarget],
  )

  useEffect(() => {
    if (!isLanding) {
      setActiveSection(LANDING_SECTIONS[0])
      setScrollProgress(0)
      currentIdxRef.current = 0
      return
    }

    const updateFromScroll = () => {
      const maxScroll = Math.max(1, document.documentElement.scrollHeight - window.innerHeight)
      setScrollProgress(Math.min(1, Math.max(0, window.scrollY / maxScroll)))

      const probeY = window.innerHeight * 0.36
      let bestIdx = 0
      for (let i = 0; i < LANDING_SECTIONS.length; i++) {
        const el = document.getElementById(LANDING_SECTIONS[i].id)
        if (!el) continue
        const rect = el.getBoundingClientRect()
        if (rect.top <= probeY) {
          bestIdx = i
        }
      }
      currentIdxRef.current = bestIdx
      setActiveSection(LANDING_SECTIONS[bestIdx])
    }

    updateFromScroll()

    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    const isDesktop = window.innerWidth >= 768

    if (reducedMotion || !isDesktop) {
      window.addEventListener('scroll', updateFromScroll, { passive: true })
      return () => window.removeEventListener('scroll', updateFromScroll)
    }

    const lenis = new Lenis({
      duration: 1.35,
      easing: EASE_QUART_OUT,
      smoothWheel: true,
      wheelMultiplier: 0.9,
    })
    lenisRef.current = lenis

    let rafId = 0
    const onRaf = (time: number) => {
      lenis.raf(time)
      rafId = window.requestAnimationFrame(onRaf)
    }
    rafId = window.requestAnimationFrame(onRaf)

    lenis.on('scroll', updateFromScroll)

    const onWheel = (event: WheelEvent) => {
      if (event.ctrlKey || event.metaKey) return
      if (document.querySelector('[role="dialog"]')) return

      const targets = getTargets()
      if (targets.length === 0) return

      event.preventDefault()

      const now = performance.now()
      if (now < lockUntilRef.current) {
        wheelAccumRef.current = 0
        return
      }

      wheelAccumRef.current += event.deltaY
      if (Math.abs(wheelAccumRef.current) < 28) return

      const direction = wheelAccumRef.current > 0 ? 1 : -1
      wheelAccumRef.current = 0

      // Determine closest current target index by viewport top
      let closestIdx = 0
      let closestDist = Infinity
      for (let i = 0; i < targets.length; i++) {
        const dist = Math.abs(targets[i].getBoundingClientRect().top)
        if (dist < closestDist) {
          closestDist = dist
          closestIdx = i
        }
      }

      const nextIdx = Math.max(0, Math.min(targets.length - 1, closestIdx + direction))
      if (nextIdx === closestIdx) return

      lockUntilRef.current = now + 950
      if (nextIdx < LANDING_SECTIONS.length) {
        currentIdxRef.current = nextIdx
        setActiveSection(LANDING_SECTIONS[nextIdx])
      }
      lenis.scrollTo(targets[nextIdx], {
        duration: 1.35,
        easing: EASE_QUART_OUT,
      })
    }

    const onKeyDown = (event: KeyboardEvent) => {
      if (document.querySelector('[role="dialog"]')) return
      const tag = (event.target as HTMLElement | null)?.tagName
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return
      if (event.key !== 'PageDown' && event.key !== 'PageUp') return

      const targets = getTargets()
      if (targets.length === 0) return

      event.preventDefault()
      const direction = event.key === 'PageDown' ? 1 : -1
      const nextIdx = Math.max(0, Math.min(targets.length - 1, currentIdxRef.current + direction))
      lockUntilRef.current = performance.now() + 950
      if (nextIdx < LANDING_SECTIONS.length) {
        currentIdxRef.current = nextIdx
        setActiveSection(LANDING_SECTIONS[nextIdx])
      }
      lenis.scrollTo(targets[nextIdx], { duration: 1.35, easing: EASE_QUART_OUT })
    }

    window.addEventListener('wheel', onWheel, { passive: false })
    window.addEventListener('keydown', onKeyDown)

    return () => {
      window.cancelAnimationFrame(rafId)
      window.removeEventListener('wheel', onWheel)
      window.removeEventListener('keydown', onKeyDown)
      lenis.destroy()
      lenisRef.current = null
    }
  }, [isLanding, getTargets])

  return (
    <LandingScrollContext.Provider value={{ activeSection, scrollProgress, scrollToSection }}>
      {children}
    </LandingScrollContext.Provider>
  )
}

export function useLandingScroll(): LandingScrollContextValue {
  const ctx = useContext(LandingScrollContext)
  if (!ctx) {
    throw new Error('useLandingScroll must be used inside LandingScrollProvider')
  }
  return ctx
}
