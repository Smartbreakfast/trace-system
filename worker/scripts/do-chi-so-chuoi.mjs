// Đo các con số thật của việc neo mã băm lên VBSN Besu, để báo cáo khỏi phải
// đoán: thời gian ra khối, gas và phí của từng giao dịch neo, độ trễ từ lúc
// công bố tới lúc có trên chuỗi.
//
//   node scripts/do-chi-so-chuoi.mjs
//
// Chỉ đọc: gọi eth_getBlock, eth_getTransactionReceipt và API công khai của
// chính hệ thống. Không cần PRIVATE_KEY, không gửi giao dịch nào.

import { createPublicClient, formatEther, formatGwei, http } from 'viem';

import { besuChain } from './chain-config.mjs';

const API = process.env.TRACE_API || 'https://tule-trace.sontm.workers.dev';
const SAMPLE = 200n; // số khối lấy mẫu để tính thời gian ra khối

const client = createPublicClient({ chain: besuChain, transport: http() });

const chainId = await client.getChainId();
const head = await client.getBlock();
const earlier = await client.getBlock({ blockNumber: head.number - SAMPLE });
const seconds =
  Number(head.timestamp - earlier.timestamp) / Number(SAMPLE);
const gasPrice = await client.getGasPrice();

console.log('Mạng           :', besuChain.name, `(chainId ${chainId})`);
console.log('Khối hiện tại  :', head.number.toString());
console.log(
  'Thời gian khối :',
  seconds.toFixed(2),
  'giây/khối (trung bình', SAMPLE.toString(), 'khối gần nhất)',
);
console.log('Giá gas        :', formatGwei(gasPrice), 'gwei');
console.log('Hợp đồng       :', process.env.TRACE_CONTRACT || '(xem wrangler.jsonc)');
console.log('');

// limit=20: mặc định của endpoint là 6 lô cho trang chủ, lấy đúng 6 thì đếm
// thiếu lô đã neo.
const batches = await (await fetch(`${API}/api/public/batches?limit=20`)).json();
const rows = [];

for (const batch of batches) {
  const verify = await (
    await fetch(`${API}/api/public/traces/${batch.code}/verify`)
  ).json();
  const txHash = verify?.chain?.txHash;
  if (!txHash) continue;

  const receipt = await client.getTransactionReceipt({ hash: txHash });
  const block = await client.getBlock({ blockNumber: receipt.blockNumber });
  const fee = receipt.gasUsed * receipt.effectiveGasPrice;
  // Độ trễ gồm cả thời gian chờ hàng đợi, không chỉ thời gian của chuỗi.
  const published = Date.parse(verify.publishedAt);
  const mined = Number(block.timestamp) * 1000;

  rows.push({
    code: batch.code,
    status: verify.status,
    block: receipt.blockNumber.toString(),
    gasUsed: receipt.gasUsed.toString(),
    feeVNX: formatEther(fee),
    hashLength: (verify.snapshotHash ?? '').length,
    delaySeconds: Number.isFinite(published)
      ? Math.round((mined - published) / 1000)
      : null,
  });
}

console.log('Giao dịch neo của từng lô:');
for (const row of rows) {
  console.log(
    `  ${row.code.padEnd(18)} khối ${row.block.padStart(8)}  gas ${row.gasUsed.padStart(7)}` +
      `  phí ${row.feeVNX} VNX  trạng thái ${row.status}` +
      (row.delaySeconds === null ? '' : `  trễ ${row.delaySeconds}s`),
  );
}

const gas = rows.map((row) => Number(row.gasUsed));
if (gas.length) {
  const average = gas.reduce((sum, value) => sum + value, 0) / gas.length;
  console.log('');
  console.log('Số lô đã neo   :', rows.length);
  console.log('Gas trung bình :', Math.round(average), 'đơn vị/giao dịch');
  console.log('Độ dài mã băm  :', rows[0].hashLength, 'ký tự hexa (256 bit)');
}
