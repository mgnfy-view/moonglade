import { useEffect, useMemo, useRef } from 'react'

export interface RippleTriggerPayload {
  x: number
  y: number
  maxRadius: number
  durationMs: number
}

function buildRadialNormalMap(): string {
  if (typeof document === 'undefined') return ''
  const size = 256
  const canvas = document.createElement('canvas')
  canvas.width = size
  canvas.height = size
  const ctx = canvas.getContext('2d')
  if (!ctx) return ''

  const img = ctx.createImageData(size, size)
  const half = size / 2

  for (let py = 0; py < size; py++) {
    for (let px = 0; px < size; px++) {
      const dx = (px - half) / half
      const dy = (py - half) / half
      const dist = Math.hypot(dx, dy)
      const idx = (py * size + px) * 4

      // Concentrate a smooth radial sinusoidal crest near the expanding front (0.72..0.98)
      let wave = 0
      if (dist > 0.68 && dist < 0.98) {
        const local = (dist - 0.68) / 0.3
        const envelope = Math.sin(local * Math.PI)
        wave = Math.sin(local * Math.PI * 2.2) * envelope
      }

      const nx = dist > 0.001 ? dx / dist : 0
      const ny = dist > 0.001 ? dy / dist : 0

      img.data[idx] = Math.round(128 + nx * wave * 124)
      img.data[idx + 1] = Math.round(128 + ny * wave * 124)
      img.data[idx + 2] = 128
      img.data[idx + 3] = 255
    }
  }

  ctx.putImageData(img, 0, 0)
  return canvas.toDataURL('image/png')
}

export function ThemeRippleOverlay({
  registerTrigger,
}: {
  registerTrigger: (fn: (payload: RippleTriggerPayload) => void) => void
}) {
  const normalMapUrl = useMemo(buildRadialNormalMap, [])
  const feImageRef = useRef<SVGFEImageElement>(null)
  const dispRef = useRef<SVGFEDisplacementMapElement>(null)
  const crestRingRef = useRef<HTMLDivElement>(null)
  const rafRef = useRef<number>(0)

  useEffect(() => {
    registerTrigger(({ x, y, maxRadius, durationMs }) => {
      if (rafRef.current) window.cancelAnimationFrame(rafRef.current)
      const start = performance.now()

      const tick = (now: number) => {
        const rawT = Math.min(1, (now - start) / durationMs)
        const eased = 1 - Math.pow(1 - rawT, 3)
        // Map radius so the radial wave ring (at ~0.83 of map radius) tracks the clip-path front
        const currentFront = Math.max(4, maxRadius * eased)
        const boxRadius = currentFront / 0.83
        const size = boxRadius * 2

        if (feImageRef.current) {
          feImageRef.current.setAttribute('x', `${x - boxRadius}`)
          feImageRef.current.setAttribute('y', `${y - boxRadius}`)
          feImageRef.current.setAttribute('width', `${size}`)
          feImageRef.current.setAttribute('height', `${size}`)
        }

        if (dispRef.current) {
          // Gentle organic bell-curve refraction that settles cleanly to zero
          const bell = Math.sin(rawT * Math.PI)
          const amplitude = bell * 20 * (1 - rawT * 0.3)
          dispRef.current.setAttribute('scale', amplitude.toFixed(2))
        }

        if (crestRingRef.current) {
          const ringOpacity = Math.sin(rawT * Math.PI) * 0.45
          crestRingRef.current.style.opacity = ringOpacity.toFixed(3)
          crestRingRef.current.style.width = `${currentFront * 2}px`
          crestRingRef.current.style.height = `${currentFront * 2}px`
          crestRingRef.current.style.left = `${x - currentFront}px`
          crestRingRef.current.style.top = `${y - currentFront}px`
        }

        if (rawT < 1) {
          rafRef.current = window.requestAnimationFrame(tick)
        } else {
          if (dispRef.current) dispRef.current.setAttribute('scale', '0')
          if (crestRingRef.current) crestRingRef.current.style.opacity = '0'
          rafRef.current = 0
        }
      }

      rafRef.current = window.requestAnimationFrame(tick)
    })

    return () => {
      if (rafRef.current) window.cancelAnimationFrame(rafRef.current)
    }
  }, [registerTrigger])

  return (
    <>
      <svg
        width="0"
        height="0"
        aria-hidden="true"
        className="pointer-events-none absolute overflow-hidden"
      >
        <defs>
          <filter
            id="moonglade-water-ripple"
            filterUnits="userSpaceOnUse"
            x="0"
            y="0"
            width="100%"
            height="100%"
            colorInterpolationFilters="sRGB"
          >
            <feImage
              ref={feImageRef}
              href={normalMapUrl}
              preserveAspectRatio="none"
              x="0"
              y="0"
              width="1"
              height="1"
              result="waveMap"
            />
            <feDisplacementMap
              ref={dispRef}
              in="SourceGraphic"
              in2="waveMap"
              scale="0"
              xChannelSelector="R"
              yChannelSelector="G"
            />
          </filter>
        </defs>
      </svg>

      <div
        ref={crestRingRef}
        aria-hidden="true"
        className="pointer-events-none fixed z-[95] rounded-full border border-accent opacity-0"
        style={{
          boxShadow: 'inset 0 0 18px rgba(142, 134, 224, 0.22)',
        }}
      />
    </>
  )
}
