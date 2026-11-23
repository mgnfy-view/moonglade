import { useEffect, useRef } from 'react'
import { ArrowUpRight, CircleCheck, X } from 'lucide-react'
import { formatUnits } from 'viem'
import type { CompletedTrade } from './hooks/useMoonglade'

export default function CompletionModal({ trade, onDismiss }: { trade: CompletedTrade; onDismiss: () => void }) {
  const dialogRef = useRef<HTMLDialogElement>(null)
  const title = trade.mode === 'lend' ? 'Lend complete.' : trade.mode === 'borrow' ? 'Borrow complete.' : 'Sale complete.'
  const inputToken = trade.mode === 'lend' ? 'USDC' : 'mgNOTE'
  const outputToken = trade.mode === 'lend' ? 'mgNOTE' : 'USDC'

  useEffect(() => {
    const dialog = dialogRef.current!
    const previousOverflow = document.body.style.overflow
    dialog.showModal()
    document.body.style.overflow = 'hidden'
    return () => {
      dialog.close()
      document.body.style.overflow = previousOverflow
    }
  }, [])

  return <dialog ref={dialogRef} className="completion-dialog" aria-labelledby="completion-title" aria-describedby="completion-description" onClose={() => { if (!dialogRef.current?.open) onDismiss() }} onClick={event => { if (event.target === event.currentTarget) event.currentTarget.close() }}>
    <div className="completion-content">
      <button type="button" className="completion-close" aria-label="Close confirmation" onClick={() => dialogRef.current?.close()}><X size={20} aria-hidden="true" /></button>
      <CircleCheck className="completion-check" size={48} strokeWidth={1.5} aria-hidden="true" />
      <h2 id="completion-title">{title}</h2>
      <p id="completion-description">Confirmed on Base.</p>
      {trade.amountIn !== undefined && trade.amountOut !== undefined && <dl className="completion-summary">
        <div><dt>{trade.mode === 'lend' ? 'Supplied' : 'Notes sold'}</dt><dd>{formatUnits(trade.amountIn, 6)} {inputToken}</dd></div>
        <div><dt>Received</dt><dd>{formatUnits(trade.amountOut, 6)} {outputToken}</dd></div>
      </dl>}
      <a className="primary-button" href={`https://basescan.org/tx/${trade.hash}`} target="_blank" rel="noreferrer">View transaction <ArrowUpRight size={18} aria-hidden="true" /></a>
      <button type="button" className="completion-done" onClick={() => dialogRef.current?.close()}>Done</button>
    </div>
  </dialog>
}
