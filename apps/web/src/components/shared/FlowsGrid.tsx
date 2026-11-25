import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { FLOW_SPECS, MATURITY_NOTE } from '../../content/landing'

export function FlowsGrid() {
  return (
    <section
      id="flows"
      aria-labelledby="flows-heading"
      className="border-t border-hairline px-[var(--page-gutter)] py-16 md:py-24"
    >
      <div className="mx-auto max-w-[var(--container-max)]">
        <h2
          id="flows-heading"
          className="mb-10 text-[clamp(30px,3.4vw,48px)] font-medium leading-[1.1] text-ink"
        >
          Fixed-rate loans. Swap-simple.
        </h2>

        <div className="grid grid-cols-1 gap-8 md:grid-cols-3">
          {FLOW_SPECS.map((flow) => (
            <article
              key={flow.id}
              className="flex flex-col border-t border-hairline pt-6"
            >
              <h3 className="mb-3 text-[21px] font-medium text-ink">{flow.label}</h3>
              <p className="mb-4 text-sm font-medium text-accent">{flow.pathLabel}</p>
              <p className="mb-6 text-[15px] leading-[1.65] text-ink-secondary">
                {flow.summary}
              </p>
              <Link
                to={flow.route}
                className="mt-auto inline-flex min-h-[44px] items-center gap-2.5 text-sm font-medium text-ink hover:text-accent hover:underline hover:underline-offset-4"
              >
                <span>{flow.ctaLabel}</span>
                <ArrowRight size={15} aria-hidden="true" />
              </Link>
            </article>
          ))}
        </div>

        <p className="mt-10 border-t border-hairline pt-5 text-sm leading-relaxed text-ink-muted">
          {MATURITY_NOTE}
        </p>
      </div>
    </section>
  )
}
