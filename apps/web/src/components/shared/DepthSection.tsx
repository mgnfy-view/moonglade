import { Link } from 'react-router-dom'
import { ArrowRight, ArrowUpRight, Plus } from 'lucide-react'
import { FAQ_ITEMS } from '../../content/landing'

export function DepthSection() {
  return (
    <section
      id="depth"
      aria-labelledby="depth-heading"
      className="border-t border-hairline px-[var(--page-gutter)] py-16 md:py-24"
    >
      <div className="mx-auto grid max-w-[var(--container-max)] grid-cols-1 items-start gap-12 md:grid-cols-[0.85fr_1.15fr] md:gap-16">
        <div>
          <h2
            id="depth-heading"
            className="mb-4 text-[clamp(28px,3.2vw,42px)] font-medium leading-[1.15] text-ink"
          >
            Whitepaper, math &amp; source.
          </h2>
          <p className="mb-7 max-w-[40ch] text-[15px] leading-[1.65] text-ink-secondary">
            Read the protocol overview, inspect the Base mainnet math checks, or review the Solidity
            contracts.
          </p>

          <div className="border-t border-hairline">
            <Link
              to="/docs/overview"
              className="flex min-h-[50px] items-center justify-between gap-3 border-b border-hairline text-sm font-medium text-ink transition-colors hover:text-accent"
            >
              <span>Protocol overview &amp; demo guide</span>
              <ArrowRight size={15} aria-hidden="true" />
            </Link>
            <Link
              to="/docs/whitepaper"
              className="flex min-h-[50px] items-center justify-between gap-3 border-b border-hairline text-sm font-medium text-ink transition-colors hover:text-accent"
            >
              <span>Moonglade Whitepaper (PDF)</span>
              <ArrowRight size={15} aria-hidden="true" />
            </Link>
            <Link
              to="/docs/mainnet-proof"
              className="flex min-h-[50px] items-center justify-between gap-3 border-b border-hairline text-sm font-medium text-ink transition-colors hover:text-accent"
            >
              <span>Base mainnet receipts &amp; math</span>
              <ArrowRight size={15} aria-hidden="true" />
            </Link>
            <a
              href="https://github.com/mgnfy-view/moonglade"
              target="_blank"
              rel="noreferrer"
              className="flex min-h-[50px] items-center justify-between gap-3 border-b border-hairline text-sm font-medium text-ink transition-colors hover:text-accent"
            >
              <span>GitHub repository</span>
              <ArrowUpRight size={15} aria-hidden="true" />
            </a>
          </div>
        </div>

        <div className="border-t border-hairline" aria-label="Frequently asked questions">
          {FAQ_ITEMS.map((item, idx) => (
            <details
              key={item.question}
              open={idx === 0}
              className="group border-b border-hairline"
            >
              <summary className="flex min-h-[56px] cursor-pointer list-none items-center justify-between gap-4 py-4 text-[16px] font-medium text-ink [&::-webkit-details-marker]:hidden">
                <span>{item.question}</span>
                <Plus
                  size={17}
                  aria-hidden="true"
                  className="shrink-0 text-accent transition-transform duration-200 group-open:rotate-45"
                />
              </summary>
              <p className="mb-5 max-w-[64ch] text-sm leading-[1.7] text-ink-secondary">
                {item.answer}
              </p>
            </details>
          ))}
        </div>
      </div>
    </section>
  )
}
