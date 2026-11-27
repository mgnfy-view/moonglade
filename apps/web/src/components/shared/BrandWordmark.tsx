import { Link } from 'react-router-dom'

export function BrandWordmark({ size = 'md' }: { size?: 'sm' | 'md' | 'lg' }) {
  const sizeClass = size === 'sm' ? 'text-[20px]' : size === 'lg' ? 'text-[26px]' : 'text-[22px]'
  return (
    <Link
      to="/"
      aria-label="Moonglade home"
      className={`inline-flex min-h-[44px] items-center font-semibold leading-none tracking-[-0.01em] text-ink ${sizeClass}`}
    >
      Moonglade
    </Link>
  )
}
