import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { DepthSection } from '../../components/shared/DepthSection'
import { FlowsGrid } from '../../components/shared/FlowsGrid'
import { KineticMoonHorizon } from '../../components/shared/KineticMoonHorizon'
import { MakerBand } from '../../components/shared/MakerBand'
import { ProofLedger } from '../../components/shared/ProofLedger'
import { HERO_COPY, STACK_ITEMS } from '../../content/landing'

export default function V3Landing() {
  return (
    <main>
      <section aria-labelledby="v3-hero-heading" className="mx-auto max-w-[var(--container-max)] px-[var(--page-gutter)]">
        <div className="grid grid-cols-1 items-center gap-8 md:grid-cols-12 md:gap-0">
          <div className="min-w-0 py-10 md:col-span-7 md:border-r md:border-hairline md:py-16 md:pr-12">
            <h1
              id="v3-hero-heading"
              className="mb-6 text-[clamp(44px,6vw,84px)] font-medium leading-[0.98] tracking-[-0.02em] text-ink"
            >
              {HERO_COPY.headlinePrimary}
              <span className="mt-2 block text-[0.68em] text-ink-secondary">
                {HERO_COPY.headlineSecondary}
              </span>
            </h1>
            <p className="mb-8 max-w-[44ch] text-base leading-[1.6] text-ink-secondary md:text-lg">
              {HERO_COPY.description}
            </p>
            <div className="flex flex-wrap gap-3">
              <Link className="swiss-btn-primary min-w-[168px]" to={HERO_COPY.primaryTo}>
                <span>{HERO_COPY.primaryCta}</span>
                <ArrowRight size={16} aria-hidden="true" />
              </Link>
              <Link className="swiss-btn-secondary min-w-[168px]" to={HERO_COPY.secondaryTo}>
                <span>{HERO_COPY.secondaryCta}</span>
                <ArrowRight size={16} aria-hidden="true" />
              </Link>
            </div>
          </div>

          <div className="mx-auto w-full max-w-[420px] pb-8 md:col-span-5 md:max-w-none md:py-10 md:pl-10">
            <KineticMoonHorizon />
          </div>
        </div>

        <div
          aria-label="Protocol stack"
          className="flex flex-wrap items-center justify-between gap-x-8 gap-y-2 border-t border-hairline py-4 text-xs text-ink-muted"
        >
          <span className="font-medium uppercase tracking-[0.06em]">Built on</span>
          <div className="flex flex-wrap items-center gap-x-6 gap-y-1 text-sm font-medium text-ink">
            {STACK_ITEMS.map((item) => (
              <span key={item}>{item}</span>
            ))}
          </div>
        </div>
      </section>

      <FlowsGrid />
      <MakerBand />
      <ProofLedger />
      <DepthSection />
    </main>
  )
}
