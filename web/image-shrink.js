// Thu nhỏ ảnh ngay trên trình duyệt, trước khi gửi lên worker.
//
// Vì sao phải làm lúc tải lên chứ không lúc phục vụ: khoá R2 là mã băm của
// chính nội dung file, và khoá đó nằm trong bản công bố đem đi băm. Nén lại
// một tấm ảnh sau khi đã công bố là đổi khoá, tức là làm hỏng đúng bản đã ghi
// lên blockchain. Thu nhỏ trước khi gửi thì file được băm chính là file được
// phục vụ, tính toàn vẹn không suy suyển.
//
// Định dạng ra là WebP khi trình duyệt mã hoá được, JPEG khi không. Đo trên
// đúng bộ ảnh của lô TL-2026-002: 6,95MB JPEG/PNG xuống 2,69MB WebP cùng kích
// thước hiển thị, riêng mấy ảnh PNG giảm hơn 90%.
//
// Trả về Uint8Array đã nén, hoặc null nếu nên giữ nguyên file gốc.
(function () {
  // Ảnh nhỏ cỡ này thì phần thắng được không bõ so với một lần mã hoá lại có
  // mất mát. Ngưỡng cũ là 600KB, và nó chính là chỗ mấy tấm PNG nửa MB lọt
  // qua mà không ai nén.
  const KEEP_UNDER_BYTES = 120 * 1024;

  async function encode(canvas, type, quality) {
    const blob = await canvas.convertToBlob({ type: type, quality: quality });
    // Trình duyệt không mã hoá được kiểu này thì nó lặng lẽ trả về PNG.
    if (blob.type !== type) return null;
    return new Uint8Array(await blob.arrayBuffer());
  }

  window.tuleShrinkImage = async function (bytes, maxEdge, quality) {
    try {
      if (typeof createImageBitmap !== 'function' ||
          typeof OffscreenCanvas !== 'function') {
        return null;
      }

      const bitmap = await createImageBitmap(new Blob([bytes]));
      const longest = Math.max(bitmap.width, bitmap.height);

      if (longest <= maxEdge && bytes.length <= KEEP_UNDER_BYTES) {
        bitmap.close();
        return null;
      }

      const scale = longest > maxEdge ? maxEdge / longest : 1;
      const width = Math.max(1, Math.round(bitmap.width * scale));
      const height = Math.max(1, Math.round(bitmap.height * scale));

      const canvas = new OffscreenCanvas(width, height);
      const ctx = canvas.getContext('2d');
      // Nền trắng: vùng trong suốt của PNG chuyển sang JPEG mà không có nền
      // thì thành đen.
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, width, height);
      ctx.drawImage(bitmap, 0, 0, width, height);
      bitmap.close();

      const out =
        (await encode(canvas, 'image/webp', quality)) ??
        (await encode(canvas, 'image/jpeg', quality));
      if (!out) return null;

      // Nén xong mà to hơn bản gốc thì dùng bản gốc.
      return out.length < bytes.length ? out : null;
    } catch (error) {
      console.warn('[tule] không thu nhỏ được ảnh:', error);
      return null;
    }
  };
})();
