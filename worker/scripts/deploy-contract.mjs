// Biên dịch và triển khai contracts/TuleTrace.sol lên VBSN Besu.
//
// Chạy bằng tay, không nằm trong luồng deploy worker: hợp đồng chỉ triển khai
// một lần, và địa chỉ của nó trở thành biến môi trường TRACE_CONTRACT.
//
//   node scripts/deploy-contract.mjs            # dùng .dev.vars
//   node scripts/deploy-contract.mjs --dry-run  # chỉ biên dịch, không gửi
//
// Khoá ký đọc từ .dev.vars (local) hoặc biến môi trường PRIVATE_KEY. Script
// không in khoá ra màn hình.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import solc from 'solc';
import { createPublicClient, createWalletClient, http, formatEther } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { besuChain, readLocalVars } from './chain-config.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..', '..');
const source = path.join(root, 'contracts', 'TuleTrace.sol');
const outDir = path.join(root, 'contracts', 'out');

const vars = readLocalVars(path.join(root, 'worker', '.dev.vars'));
const privateKey = process.env.PRIVATE_KEY || vars.PRIVATE_KEY;
const dryRun = process.argv.includes('--dry-run');

function compile() {
  const input = {
    language: 'Solidity',
    sources: { 'TuleTrace.sol': { content: fs.readFileSync(source, 'utf8') } },
    settings: {
      // Node Besu của VBSN chạy EVM trước Shanghai: bytecode có PUSH0 (0x5f)
      // bị từ chối ngay ở bước ước lượng gas. Biên dịch theo 'paris' để hợp
      // đồng chạy được trên đúng máy ảo mà mạng đang có.
      evmVersion: 'paris',
      optimizer: { enabled: true, runs: 200 },
      outputSelection: { '*': { '*': ['abi', 'evm.bytecode.object'] } },
    },
  };
  const output = JSON.parse(solc.compile(JSON.stringify(input)));
  const fatal = (output.errors ?? []).filter((e) => e.severity === 'error');
  for (const warning of (output.errors ?? []).filter((e) => e.severity !== 'error')) {
    console.warn(warning.formattedMessage.trim());
  }
  if (fatal.length > 0) {
    console.error(fatal.map((e) => e.formattedMessage).join('\n'));
    process.exit(1);
  }
  const artifact = output.contracts['TuleTrace.sol'].TuleTrace;
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(
    path.join(outDir, 'TuleTrace.json'),
    `${JSON.stringify({ abi: artifact.abi, bytecode: `0x${artifact.evm.bytecode.object}` }, null, 2)}\n`,
  );
  return { abi: artifact.abi, bytecode: `0x${artifact.evm.bytecode.object}` };
}

const { abi, bytecode } = compile();
console.log('Đã biên dịch, bytecode', (bytecode.length - 2) / 2, 'byte');
console.log('ABI lưu ở contracts/out/TuleTrace.json');

if (dryRun) process.exit(0);
if (!privateKey) {
  console.error('Thiếu PRIVATE_KEY (đặt trong worker/.dev.vars hoặc biến môi trường).');
  process.exit(1);
}

const account = privateKeyToAccount(privateKey);
const pub = createPublicClient({ chain: besuChain, transport: http() });
const wallet = createWalletClient({ account, chain: besuChain, transport: http() });

const balance = await pub.getBalance({ address: account.address });
console.log('Ví triển khai:', account.address, '-', formatEther(balance), 'VNX');
if (balance === 0n) {
  console.error('Ví không có VNX để trả gas.');
  process.exit(1);
}

const hash = await wallet.deployContract({
  abi,
  bytecode,
  args: ['Tu Le Lab'],
});
console.log('Đã gửi giao dịch:', hash);

const receipt = await pub.waitForTransactionReceipt({ hash });
if (receipt.status !== 'success') {
  console.error('Giao dịch thất bại:', receipt);
  process.exit(1);
}

console.log('');
console.log('Hợp đồng:', receipt.contractAddress);
console.log('Khối    :', receipt.blockNumber.toString());
console.log('Gas dùng:', receipt.gasUsed.toString());
console.log('Explorer:', `${besuChain.blockExplorers.default.url}/address/${receipt.contractAddress}`);
console.log('');
console.log('Đặt địa chỉ này vào wrangler.jsonc (vars.TRACE_CONTRACT) rồi deploy lại worker.');
