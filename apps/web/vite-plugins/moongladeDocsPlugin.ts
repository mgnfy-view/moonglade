import fs from 'node:fs'
import path from 'node:path'
import type { Plugin } from 'vite'

export interface DocHeading {
  id: string
  text: string
  depth: 2 | 3
}

export interface DocsEntryConfig {
  slug: string
  title: string
  group: 'Protocol' | 'Verification' | 'Engineering'
  description: string
  kind: 'markdown' | 'pdf'
  repoPath: string
  pdfUrl?: string
}

export interface DocsEntry extends DocsEntryConfig {
  content: string
  headings: DocHeading[]
  githubUrl: string
}

const GITHUB_REPO_BLOB = 'https://github.com/mgnfy-view/moonglade/blob/dev'
const VIRTUAL_ID = 'virtual:moonglade-docs'
const RESOLVED_VIRTUAL_ID = `\0${VIRTUAL_ID}`

const DOC_SOURCES: readonly DocsEntryConfig[] = [
  {
    slug: 'overview',
    title: 'Overview & Architecture',
    group: 'Protocol',
    description:
      'How Moonglade adds an AMM half to Morpho Midnight, live Base transactions, demo commands, and contract map.',
    kind: 'markdown',
    repoPath: 'README.md',
  },
  {
    slug: 'whitepaper',
    title: 'Whitepaper (PDF)',
    group: 'Protocol',
    description:
      'Complete Moonglade mechanism design, YieldSpace pricing, tick snapping, and economic model.',
    kind: 'pdf',
    repoPath: 'docs/Moonglade-Whitepaper.pdf',
    pdfUrl: '/Moonglade-Whitepaper.pdf',
  },
  {
    slug: 'mainnet-proof',
    title: 'Base Mainnet Proof',
    group: 'Verification',
    description:
      'Confirmed Base mainnet receipts, block numbers, amounts, and 90-digit YieldSpace math verification.',
    kind: 'markdown',
    repoPath: 'packages/contracts/demo/mainnet-output.md',
  },
  {
    slug: 'web-setup',
    title: 'Web App Setup',
    group: 'Engineering',
    description:
      'Workspace commands, environment variables, and Vercel preview configuration.',
    kind: 'markdown',
    repoPath: 'apps/web/README.md',
  },
  {
    slug: 'contracts',
    title: 'Contracts Workspace',
    group: 'Engineering',
    description:
      'Foundry and Soldeer toolchain, unit tests, and Base fork demo scripts.',
    kind: 'markdown',
    repoPath: 'packages/contracts/README.md',
  },
]

const REPO_PATH_TO_DOC_SLUG = new Map<string, string>([
  ['README.md', 'overview'],
  ['docs/Moonglade-Whitepaper.pdf', 'whitepaper'],
  ['packages/contracts/demo/mainnet-output.md', 'mainnet-proof'],
  ['apps/web/README.md', 'web-setup'],
  ['packages/contracts/README.md', 'contracts'],
])

function githubSlug(text: string, counts: Map<string, number>): string {
  const cleaned = text
    .replace(/`([^`]*)`/g, '$1')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/[*_~]/g, '')
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s-]/gu, '')
    .replace(/\s+/g, '-')

  const base = cleaned || 'section'
  const seen = counts.get(base) ?? 0
  counts.set(base, seen + 1)
  return seen === 0 ? base : `${base}-${seen}`
}

function stripInlineMarkdown(text: string): string {
  return text
    .replace(/`([^`]*)`/g, '$1')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/[*_~]/g, '')
    .trim()
}

function extractHeadings(markdown: string): DocHeading[] {
  const lines = markdown.split(/\r?\n/)
  const headings: DocHeading[] = []
  const counts = new Map<string, number>()
  let inFence = false

  for (const line of lines) {
    if (/^\s*```/.test(line)) {
      inFence = !inFence
      continue
    }
    if (inFence) continue

    const match = /^(#{1,3})\s+(.+?)\s*#*\s*$/.exec(line)
    if (!match) continue

    const depth = match[1].length
    const text = stripInlineMarkdown(match[2])
    const id = githubSlug(match[2], counts)
    if (depth === 2 || depth === 3) {
      headings.push({ id, text, depth })
    }
  }

  return headings
}

function rewriteMarkdownLinks(markdown: string, sourceRepoPath: string): string {
  const sourceDir = path.posix.dirname(sourceRepoPath)
  const stripped = markdown.replace(
    /^!\[Moonglade:[^\]]*\]\(docs\/assets\/hero\.png\)\r?\n+/,
    '',
  )

  return stripped.replace(
    /(\[[^\]]+\]\()([^)\s]+)(\))/g,
    (_full, prefix: string, rawHref: string, suffix: string) => {
      if (
        rawHref.startsWith('http://') ||
        rawHref.startsWith('https://') ||
        rawHref.startsWith('mailto:') ||
        rawHref.startsWith('#') ||
        rawHref.startsWith('/')
      ) {
        return `${prefix}${rawHref}${suffix}`
      }

      const [pathname, hash] = rawHref.split('#')
      const resolvedRepoPath = path.posix.normalize(
        sourceDir === '.' ? pathname : path.posix.join(sourceDir, pathname),
      )

      const mappedSlug = REPO_PATH_TO_DOC_SLUG.get(resolvedRepoPath)
      if (mappedSlug) {
        const nextHash = hash ? `#${hash}` : ''
        return `${prefix}/docs/${mappedSlug}${nextHash}${suffix}`
      }

      const nextHash = hash ? `#${hash}` : ''
      return `${prefix}${GITHUB_REPO_BLOB}/${resolvedRepoPath}${nextHash}${suffix}`
    },
  )
}

function loadAllDocs(repoRoot: string): DocsEntry[] {
  return DOC_SOURCES.map((entry) => {
    if (entry.kind === 'pdf') {
      return {
        ...entry,
        content: '',
        headings: [],
        githubUrl: `${GITHUB_REPO_BLOB}/${entry.repoPath}`,
      }
    }

    const absolutePath = path.resolve(repoRoot, entry.repoPath)
    const raw = fs.readFileSync(absolutePath, 'utf8')
    const content = rewriteMarkdownLinks(raw, entry.repoPath)
    const headings = extractHeadings(content)

    return {
      ...entry,
      content,
      headings,
      githubUrl: `${GITHUB_REPO_BLOB}/${entry.repoPath}`,
    }
  })
}

export function moongladeDocsPlugin(): Plugin {
  const repoRoot = path.resolve(__dirname, '../../..')
  const watchedPaths = new Set(
    DOC_SOURCES.filter((doc) => doc.kind === 'markdown').map((doc) =>
      path.resolve(repoRoot, doc.repoPath),
    ),
  )

  return {
    name: 'moonglade-repo-docs',
    resolveId(id) {
      if (id === VIRTUAL_ID) return RESOLVED_VIRTUAL_ID
      return null
    },
    load(id) {
      if (id !== RESOLVED_VIRTUAL_ID) return null
      const entries = loadAllDocs(repoRoot)
      return [
        `export const DOCS_ENTRIES = ${JSON.stringify(entries)};`,
        `export function getDocBySlug(slug) { return DOCS_ENTRIES.find((entry) => entry.slug === slug) ?? DOCS_ENTRIES[0]; }`,
      ].join('\n')
    },
    configureServer(server) {
      for (const filePath of watchedPaths) {
        server.watcher.add(filePath)
      }
      const invalidate = (changedFile: string) => {
        if (!watchedPaths.has(path.resolve(changedFile))) return
        const mod = server.moduleGraph.getModuleById(RESOLVED_VIRTUAL_ID)
        if (mod) {
          server.moduleGraph.invalidateModule(mod)
          server.ws.send({ type: 'full-reload' })
        }
      }
      server.watcher.on('change', invalidate)
    },
  }
}
