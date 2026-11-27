import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Wallet } from 'lucide-react'

export function WalletSlot({ primary = false }: { primary?: boolean }) {
  return (
    <ConnectButton.Custom>
      {({ account, chain, mounted, openAccountModal, openChainModal, openConnectModal }) => {
        const connected = Boolean(mounted && account && chain)
        const label = !connected
          ? 'Connect wallet'
          : chain?.unsupported
            ? 'Switch network'
            : account?.displayName ?? 'Wallet'

        return (
          <button
            type="button"
            className={primary ? 'primary-button' : 'wallet-button'}
            onClick={
              !connected
                ? openConnectModal
                : chain?.unsupported
                  ? openChainModal
                  : openAccountModal
            }
          >
            <Wallet size={15} strokeWidth={1.6} aria-hidden="true" />
            <span className="wallet-label">{label}</span>
          </button>
        )
      }}
    </ConnectButton.Custom>
  )
}
