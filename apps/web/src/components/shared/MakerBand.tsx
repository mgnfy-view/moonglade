import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { MAKER_PILLARS } from '../../content/landing'

export function MakerBand() {
  return (
    <section
      id="makers"
      aria-labelledby="makers-heading"
      className="border-t border-maker-border bg-maker-band px-[var(--page-gutter)] py-16 text-maker-ink md:py-24"
    >
      <div className="mx-auto max-w-[var(--container-max)]">
        <div className="mb-12 grid grid-cols-1 items-end gap-8 md:grid-cols-2">
          <h2
            id="makers-heading"
            className="text-[clamp(32px,3.8vw,52px)] font-medium leading-[1.08]"
          >
            Make markets in real loans.
          </h2>
          <div>
            <p className="mb-5 text-[16px] leading-[1.65] text-maker-muted">
              Run a fixed-rate bond desk from your own wallet. Ship a pricing curve once and quote
              every lend, borrow, and early exit without quoting bots.
            </p>
            <div className="flex flex-wrap gap-3">
              <Link
                to="/docs/overview#deploy-a-desk"
                className="inline-flex min-h-[44px] items-center gap-2.5 border border-maker-border px-4 py-2 text-[13px] font-medium text-maker-ink transition-colors hover:border-lavender hover:bg-maker-surface"
              >
                <span>Deploy a desk</span>
                <ArrowRight size={15} aria-hidden="true" />
              </Link>
              <Link
                to="/docs/whitepaper"
                className="inline-flex min-h-[44px] items-center gap-2.5 border border-maker-border px-4 py-2 text-[13px] font-medium text-maker-ink transition-colors hover:border-lavender hover:bg-maker-surface"
              >
                <span>Whitepaper</span>
                <ArrowRight size={15} aria-hidden="true" />
              </Link>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 border-t border-l border-maker-border md:grid-cols-3">
          {MAKER_PILLARS.map((pillar) => (
            <article
              key={pillar.index}
              className="group relative border-r border-b border-maker-border px-6 py-7 transition-colors hover:bg-maker-surface"
            >
              <span
                aria-hidden="true"
                className="absolute inset-x-0 -top-px h-0.5 origin-left scale-x-0 bg-accent transition-transform duration-200 group-hover:scale-x-100"
              />
              <span className="mb-4 block text-xs font-medium tabular-nums text-lavender">
                {pillar.index}
              </span>
              <h3 className="mb-2.5 text-[19px] font-medium">{pillar.title}</h3>
              <p className="text-sm leading-[1.65] text-maker-muted">{pillar.body}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}
