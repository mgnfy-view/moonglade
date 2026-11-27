import type { ReactNode } from 'react'

export type VariantId = 'v1' | 'v3'

export interface VariantMeta {
  id: VariantId
  shortLabel: string
  name: string
  summary: string
}

export interface VariantShellProps {
  children: ReactNode
}

export const VARIANTS_META: readonly VariantMeta[] = [
  {
    id: 'v1',
    shortLabel: 'v1',
    name: 'Morphing Top Bar + ⌘K',
    summary: 'Context-aware top bar with dynamic section pill',
  },
  {
    id: 'v3',
    shortLabel: 'v3',
    name: 'Left Progress Rail',
    summary: 'Left-hand navigation rail tracking scroll progress',
  },
] as const
