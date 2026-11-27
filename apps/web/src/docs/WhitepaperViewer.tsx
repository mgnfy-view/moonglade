import { ArrowUpRight, Download, FileText } from 'lucide-react'

export function WhitepaperViewer({ pdfUrl }: { pdfUrl: string }) {
  const viewerSrc = `${pdfUrl}#navpanes=0&view=FitH`

  return (
    <div>
      <div className="mb-5 flex flex-wrap items-center justify-between gap-4 border border-hairline bg-surface p-5">
        <div className="flex items-center gap-3">
          <FileText size={20} className="text-accent" aria-hidden="true" />
          <div>
            <div className="text-[15px] font-medium text-ink">Moonglade Whitepaper</div>
            <div className="text-xs text-ink-muted">
              Mechanism design, YieldSpace pricing, and Midnight settlement
            </div>
          </div>
        </div>
        <div className="flex flex-wrap gap-2.5">
          <a className="swiss-btn-secondary min-h-[40px] py-2" href={pdfUrl} download>
            <Download size={15} aria-hidden="true" />
            <span>Download PDF</span>
          </a>
          <a
            className="swiss-btn-primary min-h-[40px] py-2"
            href={pdfUrl}
            target="_blank"
            rel="noreferrer"
          >
            <span>Open in new tab</span>
            <ArrowUpRight size={15} aria-hidden="true" />
          </a>
        </div>
      </div>

      <div className="h-[80vh] min-h-[600px] border border-hairline bg-surface">
        <object
          data={viewerSrc}
          type="application/pdf"
          width="100%"
          height="100%"
          aria-label="Moonglade Whitepaper PDF"
        >
          <div className="p-8 text-sm text-ink-secondary">
            Inline PDF preview is unavailable in this browser.{' '}
            <a
              href={pdfUrl}
              target="_blank"
              rel="noreferrer"
              className="text-accent underline underline-offset-4"
            >
              Open the Moonglade Whitepaper PDF directly.
            </a>
          </div>
        </object>
      </div>
    </div>
  )
}
