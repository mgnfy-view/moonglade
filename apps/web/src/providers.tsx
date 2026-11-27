import type { ReactNode } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RainbowKitProvider, connectorsForWallets, darkTheme, lightTheme } from '@rainbow-me/rainbowkit'
import { injectedWallet, metaMaskWallet, rabbyWallet, walletConnectWallet } from '@rainbow-me/rainbowkit/wallets'
import { MotionConfig } from 'motion/react'
import { WagmiProvider, createConfig, http } from 'wagmi'
import { base } from 'wagmi/chains'
import { ThemeProvider, useTheme } from './theme/ThemeProvider'

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID?.trim() || ''
const connectors = connectorsForWallets(
  [
    {
      groupName: 'Wallets',
      wallets: projectId
        ? [metaMaskWallet, rabbyWallet, walletConnectWallet, injectedWallet]
        : [injectedWallet],
    },
  ],
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

const rainbowDark = darkTheme({
  accentColor: '#4030de',
  accentColorForeground: '#f2f1f9',
  borderRadius: 'small',
  overlayBlur: 'small',
})
rainbowDark.fonts.body = 'Switzer, Arial, sans-serif'

const rainbowLight = lightTheme({
  accentColor: '#4030de',
  accentColorForeground: '#f2f1f9',
  borderRadius: 'small',
  overlayBlur: 'small',
})
rainbowLight.fonts.body = 'Switzer, Arial, sans-serif'

function RainbowBridge({ children }: { children: ReactNode }) {
  const { theme } = useTheme()
  return (
    <RainbowKitProvider
      theme={theme === 'dark' ? rainbowDark : rainbowLight}
      modalSize="compact"
      initialChain={base}
      appInfo={{ appName: 'Moonglade' }}
    >
      {children}
    </RainbowKitProvider>
  )
}

export function Providers({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider>
      <MotionConfig reducedMotion="user">
        <WagmiProvider config={walletConfig}>
          <QueryClientProvider client={queryClient}>
            <RainbowBridge>{children}</RainbowBridge>
          </QueryClientProvider>
        </WagmiProvider>
      </MotionConfig>
    </ThemeProvider>
  )
}
