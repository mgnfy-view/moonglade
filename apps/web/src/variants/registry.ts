import { lazy, type ComponentType } from 'react'
import type { VariantId, VariantShellProps } from './types'

const SHELL_MAP: Record<VariantId, ComponentType<VariantShellProps>> = {
  v1: lazy(() => import('./v1-hairline-rail/V1Shell')),
  v3: lazy(() => import('./v3-morphing-strip/V3Shell')),
}

const LANDING_MAP: Record<VariantId, ComponentType> = {
  v1: lazy(() => import('./v1-hairline-rail/V1Landing')),
  v3: lazy(() => import('./v3-morphing-strip/V3Landing')),
}

export function getLazyShell(variant: VariantId): ComponentType<VariantShellProps> {
  return SHELL_MAP[variant]
}

export function getLazyLanding(variant: VariantId): ComponentType {
  return LANDING_MAP[variant]
}
