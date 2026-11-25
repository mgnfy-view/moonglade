declare module 'virtual:moonglade-docs' {
  export interface DocHeading {
    id: string
    text: string
    depth: 2 | 3
  }

  export interface DocsEntry {
    slug: string
    title: string
    group: 'Protocol' | 'Verification' | 'Engineering'
    description: string
    kind: 'markdown' | 'pdf'
    repoPath: string
    pdfUrl?: string
    content: string
    headings: DocHeading[]
    githubUrl: string
  }

  export const DOCS_ENTRIES: readonly DocsEntry[]
  export function getDocBySlug(slug?: string): DocsEntry
}
