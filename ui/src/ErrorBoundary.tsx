import { Component } from 'react'
import type { ErrorInfo, ReactNode } from 'react'

export class ErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false }

  static getDerivedStateFromError() { return { failed: true } }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error('Moonglade could not render', error, info.componentStack)
  }

  render() {
    if (!this.state.failed) return this.props.children
    return (
      <main style={{ padding: '10vh 8vw', color: '#f2f1f9', background: '#080156', minHeight: '100vh', fontFamily: 'Switzer, Arial, sans-serif' }}>
        <p>MOONGLADE / BASE</p>
        <h1>The app couldn’t load.</h1>
        <p>Reload the page to reconnect. Your assets remain in your wallet or on Midnight.</p>
        <button onClick={() => window.location.reload()}>Reload</button>
      </main>
    )
  }
}
