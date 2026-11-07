import { concatHex, toHex, type Hex } from 'viem';

/** Pinned SwapVM v1.0.2: ten uint16 tail offsets followed by uint16 flags. */
export function buildTakerTraits(exactIn: boolean, threshold: bigint, deadline: bigint): Hex {
  if (threshold < 0n || threshold >= 1n << 256n) throw new Error('Invalid swap limit.');
  if (deadline <= 0n || deadline >= 1n << 40n) throw new Error('Invalid swap deadline.');
  const thresholdEnd = 32n;
  const deadlineEnd = 37n;
  // No custom recipient, callbacks, signature, or instruction args are included.
  const offsets = [thresholdEnd, thresholdEnd, ...Array<bigint>(8).fill(deadlineEnd)];
  const indexes = offsets.reduce((packed, end, index) => packed | (end << BigInt(index * 16)), 0n);
  const firstTransferFromTaker = 0x20n;
  const transferFromAndAquaPush = 0x40n;
  const exactInFlag = exactIn ? 0x01n : 0n;
  const flags = firstTransferFromTaker | transferFromAndAquaPush | exactInFlag;
  return concatHex([toHex(indexes, { size: 20 }), toHex(flags, { size: 2 }), toHex(threshold, { size: 32 }), toHex(deadline, { size: 5 })]);
}
