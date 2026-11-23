import type { ReactNode } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RainbowKitProvider, connectorsForWallets, darkTheme } from '@rainbow-me/rainbowkit'
import { injectedWallet, metaMaskWallet, rabbyWallet, walletConnectWallet } from '@rainbow-me/rainbowkit/wallets'
import { WagmiProvider, createConfig, http } from 'wagmi'
import { base } from 'wagmi/chains'

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID?.trim() || ''
const connectors = connectorsForWallets(
  [{
    groupName: 'Wallets',
    wallets: projectId ? [metaMaskWallet, rabbyWallet, walletConnectWallet, injectedWallet] : [injectedWallet],
  }],
  { appName: 'Moonglade', projectId },
)

export const walletConfig = createConfig({
  chains: [base],
  connectors,
  multiInjectedProviderDiscovery: true,
  transports: {
    [base.id]: http(import.meta.env.VITE_BASE_RPC_URL || 'https://base-rpc.publicnode.com'),
  },
})

const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 10_000, retry: 1, refetchOnWindowFocus: true } },
})

const theme = darkTheme({
  accentColor: '#4030de',
  accentColorForeground: '#f2f1f9',
  borderRadius: 'small',
  overlayBlur: 'small',
})
theme.fonts.body = 'Switzer, Arial, sans-serif'

export function Providers({ children }: { children: ReactNode }) {
  return (
    <WagmiProvider config={walletConfig}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider theme={theme} modalSize="compact" initialChain={base} appInfo={{ appName: 'Moonglade' }}>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
