// Đọc ngược từ chuỗi: một mã băm có thật sự nằm trên VBSN Besu hay không.
//
//   node scripts/chain-verify.mjs <contract> <sha256>
//
// Đây là bài kiểm tra quan trọng nhất của phần neo dữ liệu: nếu script này
// không tìm thấy sự kiện, thì cái nhãn "đã lưu lên blockchain" là nói suông.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createPublicClient, http, parseAbiItem } from 'viem';
import { besuChain, deployBlock } from './chain-config.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
// Cắt khoảng trắng và ký tự xuống dòng: mã băm hay được nối vào từ pipe,
// dính một ký tự thừa là viem báo "bytes33" rất khó hiểu.
const [contract, hash] = process.argv.slice(2).map((value) => (value ?? '').trim());

if (!contract || !hash) {
  console.error('Cách dùng: node scripts/chain-verify.mjs <contract> <sha256>');
  process.exit(1);
}

const artifactPath = path.resolve(here, '..', '..', 'contracts', 'out', 'TuleTrace.json');
if (!fs.existsSync(artifactPath)) {
  console.error('Chưa có ABI. Chạy: node scripts/deploy-contract.mjs --dry-run');
  process.exit(1);
}

const client = createPublicClient({ chain: besuChain, transport: http() });
const topic = hash.startsWith('0x') ? hash : `0x${hash}`;

const event = parseAbiItem(
  'event BatchAnchored(bytes32 indexed hash, address indexed by, string code, uint32 version, bytes32[] inputs, uint64 anchoredAt)',
);

// Node Besu của VBSN từ chối eth_getLogs quét cả chuỗi ("Requested range
// exceeds maximum RPC range limit"), nên quét từ khối triển khai hợp đồng trở
// đi và cắt thành từng đoạn. Khối bắt đầu đổi được bằng CHAIN_FROM_BLOCK khi
// triển khai lại hợp đồng ở chỗ khác.
const STEP = 5000n;
const from = BigInt(process.env.CHAIN_FROM_BLOCK ?? deployBlock);
const latest = await client.getBlockNumber();

const logs = [];
for (let start = from; start <= latest; start += STEP) {
  const end = start + STEP - 1n > latest ? latest : start + STEP - 1n;
  const part = await client.getLogs({
    address: contract,
    event,
    args: { hash: topic },
    fromBlock: start,
    toBlock: end,
  });
  logs.push(...part);
}

if (logs.length === 0) {
  console.log('KHÔNG tìm thấy mã băm này trên chuỗi.');
  process.exit(2);
}

for (const log of logs) {
  const { code, version, anchoredAt } = log.args;
  console.log('Tìm thấy trên chuỗi:');
  console.log('  lô        :', code, `(bản v${version})`);
  console.log('  người ký  :', log.args.by);
  console.log('  thời điểm :', new Date(Number(anchoredAt) * 1000).toISOString());
  console.log('  khối      :', log.blockNumber.toString());
  console.log('  giao dịch :', `${besuChain.blockExplorers.default.url}/tx/${log.transactionHash}`);
}
