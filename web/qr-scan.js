// Quét mã QR bằng camera, chạy hẳn ở phía JavaScript.
//
// Flutter chỉ gọi một hàm và chờ kết quả; toàn bộ video, canvas và vòng lặp
// giải mã nằm ở đây. Làm cách này thì không phải dựng platform view trong
// Flutter, và lớp phủ vẫn là DOM thật nên bàn phím, nút bấm, vùng an toàn của
// điện thoại đều xử sự bình thường.
//
// Thư viện giải mã chỉ tải khi người dùng thật sự bấm quét: 250KB không có lý
// do gì nằm trong lần tải trang đầu tiên của người vừa quét QR ngoài chợ.
(function () {
  'use strict';

  var jsqrLoading = null;

  function loadJsQr() {
    if (window.jsQR) return Promise.resolve(window.jsQR);
    if (jsqrLoading) return jsqrLoading;
    jsqrLoading = new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src = 'vendor/jsqr/jsQR.js';
      script.onload = function () { resolve(window.jsQR); };
      script.onerror = function () { reject(new Error('không tải được bộ giải mã QR')); };
      document.head.appendChild(script);
    });
    return jsqrLoading;
  }

  window.tuleQrScanSupported = function () {
    return !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
  };

  window.tuleScanQr = function () {
    if (!window.tuleQrScanSupported()) return Promise.resolve(null);

    var overlay = document.createElement('div');
    overlay.setAttribute('style', [
      'position:fixed', 'inset:0', 'z-index:2147483647',
      'background:#0d1a15', 'display:flex', 'flex-direction:column',
      'align-items:center', 'justify-content:center',
      'font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif',
    ].join(';'));

    var video = document.createElement('video');
    video.setAttribute('playsinline', '');
    video.setAttribute('muted', '');
    video.muted = true;
    video.setAttribute('style', 'width:100%;height:100%;object-fit:cover;position:absolute;inset:0');

    // Khung ngắm: người dùng cần biết đưa mã vào đâu.
    var frame = document.createElement('div');
    frame.setAttribute('style', [
      'position:relative', 'width:min(70vw,260px)', 'height:min(70vw,260px)',
      'border:3px solid #8BBF76', 'border-radius:18px',
      'box-shadow:0 0 0 100vmax rgba(0,0,0,.45)',
    ].join(';'));

    var hint = document.createElement('p');
    hint.textContent = 'Đưa mã QR trên bao bì vào khung';
    hint.setAttribute('style', 'position:relative;color:#fff;margin:22px 16px 0;font-size:15px;text-align:center');

    var cancel = document.createElement('button');
    cancel.textContent = 'Đóng';
    cancel.setAttribute('style', [
      'position:relative', 'margin-top:20px', 'padding:12px 28px',
      'border:0', 'border-radius:999px', 'background:#F7F5ED', 'color:#19362B',
      'font-size:15px', 'font-weight:600', 'cursor:pointer',
    ].join(';'));

    overlay.appendChild(video);
    overlay.appendChild(frame);
    overlay.appendChild(hint);
    overlay.appendChild(cancel);
    document.body.appendChild(overlay);

    var canvas = document.createElement('canvas');
    var ctx = canvas.getContext('2d', { willReadFrequently: true });
    var stream = null;
    var frameRequest = null;
    var finished = false;

    return new Promise(function (resolve) {
      function stop(result) {
        if (finished) return;
        finished = true;
        if (frameRequest) cancelAnimationFrame(frameRequest);
        if (stream) stream.getTracks().forEach(function (track) { track.stop(); });
        overlay.remove();
        resolve(result);
      }

      cancel.addEventListener('click', function () { stop(null); });
      overlay.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') stop(null);
      });

      loadJsQr()
        .then(function () {
          return navigator.mediaDevices.getUserMedia({
            video: { facingMode: { ideal: 'environment' } },
            audio: false,
          });
        })
        .then(function (media) {
          if (finished) {
            media.getTracks().forEach(function (track) { track.stop(); });
            return;
          }
          stream = media;
          video.srcObject = media;
          return video.play();
        })
        .then(function () {
          function tick() {
            if (finished) return;
            if (video.readyState === video.HAVE_ENOUGH_DATA) {
              // Giải mã ở độ phân giải vừa phải: quét mỗi khung ở 1080p làm
              // máy yếu nóng lên mà không nhận nhanh hơn.
              var width = Math.min(video.videoWidth, 640);
              var scale = width / (video.videoWidth || 1);
              canvas.width = width;
              canvas.height = Math.round((video.videoHeight || 1) * scale);
              ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
              var image = ctx.getImageData(0, 0, canvas.width, canvas.height);
              var found = window.jsQR(image.data, image.width, image.height, {
                inversionAttempts: 'dontInvert',
              });
              if (found && found.data) {
                stop(found.data);
                return;
              }
            }
            frameRequest = requestAnimationFrame(tick);
          }
          tick();
        })
        .catch(function (error) {
          // Từ chối quyền camera, máy không có camera, hoặc trang chạy trên
          // http: báo một câu rồi đóng, đừng để người dùng nhìn màn đen.
          hint.textContent =
            error && error.name === 'NotAllowedError'
              ? 'Bạn chưa cho phép dùng camera. Nhập mã bằng tay cũng được.'
              : 'Không mở được camera trên máy này. Nhập mã bằng tay giúp mình.';
          setTimeout(function () { stop(null); }, 2600);
        });
    });
  };
})();
