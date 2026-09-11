// Cấu hình chuỗi dùng chung cho các script chạy bằng Node.
//
// Worker có bản riêng trong src/chain.ts vì nó đọc cấu hình từ biến môi trường
// của Cloudflare; ở đây thì đọc từ .dev.vars cho tiện chạy tay.

import fs from 'node:fs';
import { defineChain } from 'viem';

/// VBSN Besu, chuỗi đang dùng để neo mã băm.
export const besuChain = defineChain({
  id: 84001,
  name: 'VBSN Besu',
  nativeCurrency: { name: 'VNX', symbol: 'VNX', decimals: 18 },
  rpcUrls: { default: { http: ['https://besu-rpc.vbsn.vn'] } },
  blockExplorers: {
    default: { name: 'VBSN Explorer', url: 'https://besu-explorer.vbsn.vn' },
  },
});

/// Khối triển khai hợp đồng TuleTrace trên VBSN Besu. Script đọc log bắt đầu
/// từ đây thay vì từ khối 0: RPC của mạng giới hạn bề rộng khoảng khối.
export const deployBlock = 4410749n;

/// Tên cũ, giữ lại để các script chưa đổi tên vẫn chạy.
export const chain = besuChain;

/// Đọc file kiểu dotenv. Trả về object rỗng nếu chưa có file, để script còn
/// chạy được bằng biến môi trường thuần.
export function readLocalVars(file) {
  if (!fs.existsSync(file)) return {};
  return Object.fromEntries(
    fs
      .readFileSync(file, 'utf8')
      .split(/\r?\n/)
      .filter((line) => line.trim() && !line.trim().startsWith('#') && line.includes('='))
      .map((line) => {
        const i = line.indexOf('=');
        return [line.slice(0, i).trim(), line.slice(i + 1).trim()];
      }),
  );
}
