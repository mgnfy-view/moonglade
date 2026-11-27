import { useRef, useState } from 'react'
import {
  motion,
  useMotionValue,
  useReducedMotion,
  useScroll,
  useSpring,
  useTransform,
} from 'motion/react'

interface BarSpec {
  index: number
  y: number
  height: number
  widthFactor: number
  baseOpacity: number
}

const BARS: readonly BarSpec[] = [
  { index: 0, y: 274, height: 3, widthFactor: 1.0, baseOpacity: 0.95 },
  { index: 1, y: 304, height: 4, widthFactor: 0.91, baseOpacity: 0.72 },
  { index: 2, y: 336, height: 6, widthFactor: 0.84, baseOpacity: 0.66 },
  { index: 3, y: 370, height: 9, widthFactor: 0.77, baseOpacity: 0.52 },
  { index: 4, y: 406, height: 12, widthFactor: 0.71, baseOpacity: 0.42 },
  { index: 5, y: 444, height: 15, widthFactor: 0.65, baseOpacity: 0.32 },
  { index: 6, y: 484, height: 18, widthFactor: 0.6, baseOpacity: 0.24 },
  { index: 7, y: 526, height: 22, widthFactor: 0.55, baseOpacity: 0.16 },
]

function ReflectionBar({
  bar,
  width,
  pointerX,
  pointerY,
  scrollProgress,
  hoveredBand,
  reducedMotion,
}: {
  bar: BarSpec
  width: number
  pointerX: ReturnType<typeof useSpring>
  pointerY: ReturnType<typeof useSpring>
  scrollProgress: ReturnType<typeof useScroll>['scrollYProgress']
  hoveredBand: number | null
  reducedMotion: boolean | null
}) {
  const depth = (bar.index + 1) / BARS.length
  const barWidth = width * bar.widthFactor
  const baseX = (width - barWidth) / 2
  const waveSign = bar.index % 2 === 0 ? 1 : -0.75

  const shiftX = useTransform(pointerX, [-1, 1], [-28 * depth * waveSign, 28 * depth * waveSign])
  const pointerShiftY = useTransform(pointerY, [-1, 1], [-10 * depth, 10 * depth])
  const scrollShiftY = useTransform(scrollProgress, [0, 0.4], [0, -24 * depth])
  const combinedY = useTransform(
    [pointerShiftY, scrollShiftY],
    ([py, sy]: number[]) => py + sy,
  )
  const scaleX = useTransform(pointerX, [-1, 0, 1], [0.95, 1, 0.95])

  const isHighlighted =
    hoveredBand !== null && Math.abs(hoveredBand - bar.index) <= 1
  const fill =
    bar.index === 0
      ? 'var(--moon-line-strong)'
      : isHighlighted
        ? 'var(--moon-line-accent)'
        : bar.index === 1
          ? 'var(--moon-line-accent)'
          : 'var(--moon-line-soft)'
  const targetOpacity = isHighlighted
    ? Math.min(0.95, bar.baseOpacity + 0.28)
    : bar.baseOpacity

  if (reducedMotion) {
    return (
      <rect
        x={baseX}
        y={bar.y}
        width={barWidth}
        height={bar.height}
        fill={fill}
        opacity={bar.baseOpacity}
      />
    )
  }

  return (
    <motion.rect
      x={baseX}
      y={bar.y}
      width={barWidth}
      height={bar.height}
      fill={fill}
      initial={{ scaleX: 0.2, opacity: 0 }}
      animate={{ scaleX: 1, opacity: targetOpacity }}
      transition={{
        duration: 0.55,
        delay: 0.04 * bar.index,
        ease: [0.22, 1, 0.36, 1],
      }}
      style={{
        transformOrigin: 'center center',
        x: shiftX,
        y: combinedY,
        scaleX,
      }}
    />
  )
}

/**
 * Open, borderless Moonglade moon-and-water reflection artwork.
 * Pointer movement drives horizontal wave ripple, vertical horizon compression,
 * and active reflection-band highlighting across the bars.
 */
export function KineticMoonHorizon() {
  const containerRef = useRef<HTMLDivElement>(null)
  const reducedMotion = useReducedMotion()
  const [hoveredBand, setHoveredBand] = useState<number | null>(null)

  const rawPointerX = useMotionValue(0)
  const rawPointerY = useMotionValue(0)
  const pointerX = useSpring(rawPointerX, { stiffness: 150, damping: 20 })
  const pointerY = useSpring(rawPointerY, { stiffness: 150, damping: 22 })

  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ['start end', 'end start'],
  })

  const moonScale = useTransform(scrollYProgress, [0, 0.5], [1, 0.94])
  const moonShiftX = useTransform(pointerX, [-1, 1], [-8, 8])
  const moonShiftY = useTransform(pointerY, [-1, 1], [-8, 8])

  const viewWidth = 560
  const viewHeight = 560
  const moonCx = 280
  const moonCy = 138
  const moonR = 108
  const barAreaWidth = 460
  const barOffsetX = (viewWidth - barAreaWidth) / 2

  return (
    <div
      ref={containerRef}
      className="relative w-full select-none"
      onPointerMove={(event) => {
        if (reducedMotion || !containerRef.current) return
        const rect = containerRef.current.getBoundingClientRect()
        const nx = ((event.clientX - rect.left) / rect.width) * 2 - 1
        const ny = ((event.clientY - rect.top) / rect.height) * 2 - 1
        rawPointerX.set(Math.max(-1, Math.min(1, nx)))
        rawPointerY.set(Math.max(-1, Math.min(1, ny)))

        const relY = (event.clientY - rect.top) / rect.height
        if (relY > 0.44) {
          const idx = Math.min(BARS.length - 1, Math.max(0, Math.floor(((relY - 0.44) / 0.54) * BARS.length)))
          setHoveredBand(idx)
        } else {
          setHoveredBand(null)
        }
      }}
      onPointerLeave={() => {
        rawPointerX.set(0)
        rawPointerY.set(0)
        setHoveredBand(null)
      }}
    >
      <svg
        className="block h-auto w-full overflow-visible"
        viewBox={`0 0 ${viewWidth} ${viewHeight}`}
        role="img"
        aria-label="Moonglade moon and horizontal water reflection geometry"
      >
        <motion.circle
          cx={moonCx}
          cy={moonCy}
          r={moonR}
          fill="var(--moon-fill)"
          initial={reducedMotion ? undefined : { scale: 0.92, opacity: 0 }}
          animate={reducedMotion ? undefined : { scale: 1, opacity: 1 }}
          transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
          style={
            reducedMotion
              ? undefined
              : {
                  transformOrigin: `${moonCx}px ${moonCy}px`,
                  scale: moonScale,
                  x: moonShiftX,
                  y: moonShiftY,
                }
          }
        />

        <g transform={`translate(${barOffsetX}, 0)`}>
          {BARS.map((bar) => (
            <ReflectionBar
              key={bar.index}
              bar={bar}
              width={barAreaWidth}
              pointerX={pointerX}
              pointerY={pointerY}
              scrollProgress={scrollYProgress}
              hoveredBand={hoveredBand}
              reducedMotion={reducedMotion}
            />
          ))}
        </g>
      </svg>
    </div>
  )
}
