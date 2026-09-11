import {
  createPublicClient,
  createWalletClient,
  defineChain,
  http,
  type Hex,
} from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

import type { Env } from './env';

/// ABI rút gọn: worker chỉ gọi hai hàm neo và đọc vai trò. Bản đầy đủ nằm ở
/// contracts/out/TuleTrace.json sau khi biên dịch.
export const traceAbi = [
  {
    type: 'function',
    name: 'anchorBatch',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'hash', type: 'bytes32' },
      { name: 'code', type: 'string' },
      { name: 'version', type: 'uint32' },
      { name: 'inputs', type: 'bytes32[]' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'anchorIngredient',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'hash', type: 'bytes32' },
      { name: 'ref', type: 'string' },
    ],
    outputs: [],
  },
  {
    type: 'function',
    name: 'roleOf',
    stateMutability: 'view',
    inputs: [{ name: '', type: 'address' }],
    outputs: [{ name: '', type: 'uint8' }],
  },
] as const;

export interface ChainConfig {
  rpcUrl: string;
  chainId: number;
  explorer: string;
  contract: `0x${string}`;
  privateKey: Hex;
}

/**
 * Cấu hình chuỗi là tuỳ chọn: thiếu bất kỳ mảnh nào thì hệ thống vẫn chạy
 * bình thường, chỉ là mã băm nằm lại trong hàng chờ. Không bao giờ được để
 * việc nối chuỗi làm hỏng đường nhập liệu của người vận hành.
 */
export function chainConfig(env: Env): ChainConfig | null {
  const rpcUrl = env.CHAIN_RPC_URL?.trim();
  const chainId = Number(env.CHAIN_ID ?? '');
  const contract = env.TRACE_CONTRACT?.trim();
  const privateKey = env.PRIVATE_KEY?.trim();
  if (!rpcUrl || !chainId || !contract || !privateKey) return null;
  if (!/^0x[0-9a-fA-F]{40}$/.test(contract)) return null;
  if (!/^0x[0-9a-fA-F]{64}$/.test(privateKey)) return null;
  return {
    rpcUrl,
    chainId,
    explorer: (env.CHAIN_EXPLORER ?? '').trim().replace(/\/$/, ''),
    contract: contract as `0x${string}`,
    privateKey: privateKey as Hex,
  };
}

function chainOf(config: ChainConfig) {
  return defineChain({
    id: config.chainId,
    name: 'VBSN Besu',
    nativeCurrency: { name: 'VNX', symbol: 'VNX', decimals: 18 },
    rpcUrls: { default: { http: [config.rpcUrl] } },
  });
}

export function explorerTxUrl(config: ChainConfig | null, txHash: string) {
  if (!config?.explorer || !txHash) return '';
  return `${config.explorer}/tx/${txHash}`;
}

/** SHA-256 dạng hex của snapshot đổi sang bytes32 mà hợp đồng nhận. */
function toBytes32(hash: string): `0x${string}` {
  const clean = hash.startsWith('0x') ? hash.slice(2) : hash;
  if (!/^[0-9a-fA-F]{64}$/.test(clean)) {
    throw new Error(`mã băm không hợp lệ: ${hash}`);
  }
  return `0x${clean.toLowerCase()}` as `0x${string}`;
}

export interface AnchorInput {
  hash: string;
  code: string;
  version: number;
  /** Mã băm của các lô nguyên liệu, để lô cha trỏ ngược về đúng bản ghi con. */
  inputs?: string[];
}

export interface AnchorResult {
  txHash: string;
  blockNumber: string;
  gasUsed: string;
}

/**
 * Gửi giao dịch neo và chờ tới khi có biên nhận.
 *
 * Người vận hành không phải ký gì cả: khoá của thương hiệu nằm trong secret
 * của worker, nên bấm "Hoàn thành lô" là xong. Đổi lại, chữ ký này là chữ ký
 * của thương hiệu chứ không phải của từng nhà cung cấp — muốn từng bên tự ký
 * thì xem BLOCKCHAIN.md.
 */
export async function anchorBatch(
  config: ChainConfig,
  input: AnchorInput,
): Promise<AnchorResult> {
  const chain = chainOf(config);
  const account = privateKeyToAccount(config.privateKey);
  const publicClient = createPublicClient({ chain, transport: http(config.rpcUrl) });
  const wallet = createWalletClient({ account, chain, transport: http(config.rpcUrl) });

  // Giá gas phải hỏi node chứ không để viem tự suy từ baseFee.
  //
  // Besu của VBSN để baseFeePerGas 7 wei nhưng chỉ nhận giao dịch từ 0,1 gwei
  // trở lên; viem nhìn baseFee rồi đặt maxFeePerGas 8 wei, và node trả về lỗi
  // cụt lủn "RPC Request failed" mà không nói vì sao. Lấy thẳng eth_gasPrice
  // rồi cộng biên 25% là hết chuyện, kể cả khi mạng chỉnh mức tối thiểu.
  const gasPrice = (await publicClient.getGasPrice()) * 5n / 4n;

  const txHash = await wallet.writeContract({
    address: config.contract,
    abi: traceAbi,
    functionName: 'anchorBatch',
    args: [
      toBytes32(input.hash),
      input.code,
      input.version,
      (input.inputs ?? []).map(toBytes32),
    ],
    gasPrice,
  });

  const receipt = await publicClient.waitForTransactionReceipt({
    hash: txHash,
    timeout: 60_000,
  });
  if (receipt.status !== 'success') {
    throw new Error(`giao dịch ${txHash} bị revert`);
  }
  return {
    txHash,
    blockNumber: receipt.blockNumber.toString(),
    gasUsed: receipt.gasUsed.toString(),
  };
}

export interface ChainStatus {
  configured: boolean;
  autoAnchor?: boolean;
  chainId?: number;
  address?: string;
  balance?: string;
  contract?: string;
  explorer?: string;
  blockNumber?: string;
  reachable: boolean;
  error?: string;
}

/** Trạng thái ví và mạng, để màn quản trị biết vì sao hàng chờ không chạy. */
export async function chainStatus(env: Env): Promise<ChainStatus> {
  const config = chainConfig(env);
  if (!config) return { configured: false, reachable: false };
  const account = privateKeyToAccount(config.privateKey);
  const base = {
    configured: true,
    chainId: config.chainId,
    address: account.address,
    contract: config.contract,
    explorer: config.explorer,
    autoAnchor: (env.CHAIN_AUTO_ANCHOR ?? 'true') === 'true',
  };
  try {
    const client = createPublicClient({
      chain: chainOf(config),
      transport: http(config.rpcUrl),
    });
    const [balance, blockNumber] = await Promise.all([
      client.getBalance({ address: account.address }),
      client.getBlockNumber(),
    ]);
    return {
      ...base,
      reachable: true,
      balance: balance.toString(),
      blockNumber: blockNumber.toString(),
    };
  } catch (error) {
    return {
      ...base,
      reachable: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}
