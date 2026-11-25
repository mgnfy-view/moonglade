import { MorphoMidnightLogo, OneInchAquaLogo, SwapVmLogo } from './BrandLogos'

const PARTNERS = [
  { name: '1inch Aqua', Logo: OneInchAquaLogo },
  { name: 'SwapVM', Logo: SwapVmLogo },
  { name: 'Morpho Midnight', Logo: MorphoMidnightLogo },
] as const

export function BuiltOnStrip() {
  return (
    <div
      aria-label="Built on"
      className="flex flex-col gap-4 border-t border-hairline py-5 sm:flex-row sm:items-center sm:gap-10"
    >
      <span className="shrink-0 text-xs font-medium uppercase tracking-[0.08em] text-ink-muted">
        Built on
      </span>

      <div className="grid flex-1 grid-cols-1 gap-4 sm:grid-cols-3 sm:items-center">
        {PARTNERS.map(({ name, Logo }, idx) => (
          <div
            key={name}
            className={`flex items-center gap-2.5 text-sm font-medium text-ink ${
              idx === 1 ? 'sm:justify-center' : idx === 2 ? 'sm:justify-end' : 'sm:justify-start'
            }`}
          >
            <Logo />
            <span>{name}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
