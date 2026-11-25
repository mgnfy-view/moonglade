import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { BuiltOnStrip } from '../../components/shared/BuiltOnStrip'
import { FaqSection } from '../../components/shared/FaqSection'
import { FlowsGrid } from '../../components/shared/FlowsGrid'
import { KineticMoonHorizon } from '../../components/shared/KineticMoonHorizon'
import { MakerBand } from '../../components/shared/MakerBand'
import { ProtocolStats } from '../../components/shared/ProtocolStats'
import { HERO_COPY } from '../../content/landing'

export default function V1Landing() {
  return (
    <main>
      <section
        id="overview"
        data-landing-section="overview"
        aria-labelledby="v1-hero-heading"
        className="mx-auto flex min-h-[calc(100svh-76px)] max-w-[var(--container-max)] flex-col justify-between px-[var(--page-gutter)] pt-8 md:pt-12"
      >
        <div className="my-auto grid grid-cols-1 items-center gap-10 py-6 md:grid-cols-12 md:gap-12">
          <div className="min-w-0 md:col-span-7">
            <h1
              id="v1-hero-heading"
              className="mb-6 text-[clamp(46px,6.2vw,88px)] font-medium leading-[0.98] tracking-[-0.02em] text-ink"
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

          <div className="mx-auto w-full max-w-[420px] md:col-span-5 md:max-w-none">
            <KineticMoonHorizon />
          </div>
        </div>

        <BuiltOnStrip />
      </section>

      <FlowsGrid />
      <MakerBand />
      <ProtocolStats />
      <FaqSection />
    </main>
  )
}
