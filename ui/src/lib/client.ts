import { createPublicClient, http } from 'viem';
import { CHAIN } from './contracts';

export const publicClient = createPublicClient({
  chain: CHAIN,
  transport: http(import.meta.env.VITE_BASE_RPC_URL || 'https://base-rpc.publicnode.com', {
    batch: { wait: 20, batchSize: 8 },
    retryCount: 1,
    timeout: 15_000,
  }),
});
