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
    name: 'Hairline Bar',
    summary: 'Sticky Swiss hairline header with scroll hairline',
  },
  {
    id: 'v3',
    shortLabel: 'v3',
    name: 'Morphing Strip + ⌘K',
    summary: 'Flush header morphing into centered floating pill with ⌘K',
  },
] as const
