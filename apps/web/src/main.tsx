import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import '@rainbow-me/rainbowkit/styles.css'
import './styles/tokens.css'
import './styles/base.css'
import './styles/trade.css'
import { Providers } from './providers'
import { ErrorBoundary } from './ErrorBoundary'
import App from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ErrorBoundary>
      <Providers>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </Providers>
    </ErrorBoundary>
  </React.StrictMode>,
)
