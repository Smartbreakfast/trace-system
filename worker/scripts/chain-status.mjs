// Xem nhanh ví neo dữ liệu đang ở đâu: số dư, khối hiện tại, hợp đồng.
//
//   node scripts/chain-status.mjs

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPublicClient, http, formatEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { besuChain, readLocalVars } from './chain-config.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const vars = readLocalVars(path.resolve(here, '..', '.dev.vars'));
const privateKey = process.env.PRIVATE_KEY || vars.PRIVATE_KEY;

if (!privateKey) {
  console.error('Thiếu PRIVATE_KEY trong worker/.dev.vars.');
  process.exit(1);
}

const account = privateKeyToAccount(privateKey);
const client = createPublicClient({ chain: besuChain, transport: http() });

const [chainId, block, balance, nonce] = await Promise.all([
  client.getChainId(),
  client.getBlockNumber(),
  client.getBalance({ address: account.address }),
  client.getTransactionCount({ address: account.address }),
]);

console.log('Mạng     :', besuChain.name, `(chainId ${chainId})`);
console.log('Ví       :', account.address);
console.log('Số dư    :', formatEther(balance), 'VNX');
console.log('Giao dịch:', nonce, 'đã gửi');
console.log('Khối     :', block.toString());
console.log('Explorer :', `${besuChain.blockExplorers.default.url}/address/${account.address}`);
