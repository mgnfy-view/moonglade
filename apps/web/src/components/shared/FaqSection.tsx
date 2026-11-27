import { useState } from 'react'
import { Plus } from 'lucide-react'
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { FAQ_ITEMS } from '../../content/landing'

export function FaqSection() {
  const [openIndex, setOpenIndex] = useState<number | null>(0)
  const reducedMotion = useReducedMotion()

  return (
    <section
      id="faq"
      data-landing-section="faq"
      aria-labelledby="faq-heading"
      className="flex min-h-[85svh] flex-col justify-center border-t border-hairline px-[var(--page-gutter)] py-20 md:min-h-[100svh]"
    >
      <div className="mx-auto w-full max-w-[920px]">
        <h2
          id="faq-heading"
          className="mb-10 text-[clamp(28px,3.4vw,46px)] font-medium leading-[1.12] text-ink"
        >
          Frequently asked questions.
        </h2>

        <div className="border-t border-hairline">
          {FAQ_ITEMS.map((item, idx) => {
            const isOpen = openIndex === idx
            const panelId = `faq-panel-${idx}`
            return (
              <div key={item.question} className="border-b border-hairline">
                <button
                  type="button"
                  aria-expanded={isOpen}
                  aria-controls={panelId}
                  onClick={() => setOpenIndex((prev) => (prev === idx ? null : idx))}
                  className="flex min-h-[60px] w-full items-center justify-between gap-4 py-4 text-left text-[16px] font-medium text-ink transition-colors hover:text-accent md:text-[17px]"
                >
                  <span>{item.question}</span>
                  <Plus
                    size={17}
                    aria-hidden="true"
                    className={`shrink-0 text-accent transition-transform duration-200 ${
                      isOpen ? 'rotate-45' : ''
                    }`}
                  />
                </button>

                <AnimatePresence initial={false}>
                  {isOpen && (
                    <motion.div
                      id={panelId}
                      initial={reducedMotion ? undefined : { height: 0, opacity: 0 }}
                      animate={reducedMotion ? undefined : { height: 'auto', opacity: 1 }}
                      exit={reducedMotion ? undefined : { height: 0, opacity: 0 }}
                      transition={{ duration: 0.24, ease: [0.22, 1, 0.36, 1] }}
                      className="overflow-hidden"
                    >
                      <p className="pb-5 pr-8 text-sm leading-[1.7] text-ink-secondary">
                        {item.answer}
                      </p>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
