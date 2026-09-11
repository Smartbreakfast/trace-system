/// Toàn bộ CSS của trang tra cứu, nhúng thẳng vào HTML.
///
/// Vì sao nhúng chứ không để file riêng: cả bảng nén lại còn khoảng 4KB, mà
/// tách file là thêm một vòng đi về trước khi trang có hình hài. Trang này
/// sinh ra để mở nhanh trên điện thoại giữa chợ, không phải để tiết kiệm vài
/// KB cho lượt vào thứ hai.

export const pageCss = `
:root{
  --ink:#17352A;--leaf:#8BBF76;--cream:#F7F5ED;--orange:#E2703A;
  --orange-ink:#A84B1B;--muted:#5A6560;--line:rgba(23,53,41,.10);
  --panel:#E8F0E5;--ground-1:#F6F6F1;--ground-2:#EEF0E7;
  --teal:#007E88;--teal-bright:#0096A0;--teal-ink:#00666E;
  --l-ink:#14201F;--l-ink-2:#4E5B59;--l-ink-3:#7C8785;
  --l-line:#E6E1D6;--l-line-2:#D3CCBD;
  --container:1600px;--bar:1200px;--gutter:20px;
}
@media (min-width:640px){:root{--gutter:32px}}
@media (min-width:900px){:root{--gutter:55px}}

@font-face{font-family:BeVietnamPro;src:url(/f/BeVietnamPro-Regular.woff2)format('woff2');font-weight:400;font-display:swap}
@font-face{font-family:BeVietnamPro;src:url(/f/BeVietnamPro-SemiBold.woff2)format('woff2');font-weight:500 600;font-display:swap}
@font-face{font-family:BeVietnamPro;src:url(/f/BeVietnamPro-Bold.woff2)format('woff2');font-weight:700 900;font-display:swap}
@font-face{font-family:Lora;src:url(/f/Lora-SemiBold.woff2)format('woff2');font-weight:600;font-display:swap}

*{box-sizing:border-box}
[hidden]{display:none!important}
html{-webkit-text-size-adjust:100%}
body{
  margin:0;font-family:BeVietnamPro,system-ui,-apple-system,"Segoe UI",sans-serif;
  color:var(--ink);background:linear-gradient(var(--ground-1),var(--ground-2))fixed;
  font-size:15px;line-height:1.5;
}
img{max-width:100%;display:block}
a{color:inherit}
button{font:inherit;cursor:pointer}

/* ---------------------------------------------------------- thanh trên */
.hdr{background:#fff;border-bottom:1px solid var(--l-line)}
.hdr-in{max-width:var(--bar);margin:0 auto;padding:8px 24px;min-height:68px;display:flex;align-items:center;gap:24px}
.brand{display:flex;align-items:center;gap:10px;text-decoration:none;flex:none}
.brand img{width:40px;height:40px}
.brand b{display:block;font-size:16px;font-weight:800;letter-spacing:-.32px;line-height:1.15;color:var(--l-ink)}
.brand span{display:block;font-size:11px;letter-spacing:1.54px;color:var(--l-ink-3);font-weight:600;line-height:1.1}
.nav{margin-left:auto;display:flex;align-items:center;gap:18px}
.nav a{font-size:15px;font-weight:500;color:var(--l-ink-2);text-decoration:none;padding:6px 0;border-bottom:2px solid transparent}
.nav a:hover{color:var(--teal-ink)}
.nav a[aria-current=page]{color:var(--l-ink);border-bottom-color:var(--teal-bright);font-weight:600}
.cta{display:inline-flex;align-items:center;background:var(--teal);border:1.5px solid var(--teal);border-radius:999px;
  padding:11px 18px;color:#fff;font-size:15px;font-weight:600;text-decoration:none;line-height:1}
.cta:hover{background:var(--teal-ink);border-color:var(--teal-ink)}
.menu-btn{display:none;margin-left:auto;background:none;border:1.5px solid var(--l-line-2);border-radius:999px;
  padding:9px 15px;font-size:15px;font-weight:600;color:var(--l-ink)}
.m-nav{display:none;max-width:var(--bar);margin:0 auto;padding:0 24px 10px}
.m-nav a{display:block;padding:12px 0;font-size:18px;font-weight:500;text-decoration:none;border-bottom:1px solid var(--l-line)}
.m-nav a[aria-current=page]{color:var(--teal-ink);font-weight:700}
.hdr.open .m-nav{display:block}
@media (max-width:1219px){
  .nav{display:none}
  .menu-btn{display:inline-flex}
  .hdr-in .cta{display:none}
}
@media (max-width:559px){.hdr-in{gap:12px}}

/* ------------------------------------------------------------ tra cứu */
.search-band{padding:20px var(--gutter) 18px}
.search{max-width:620px;margin:0 auto}
.search form{display:flex;align-items:center;gap:8px;background:#fff;border:1px solid var(--l-line-2);
  border-radius:27px;padding:5px 5px 5px 0;box-shadow:0 4px 10px rgba(20,32,31,.05)}
.search form:focus-within{border-color:var(--teal);border-width:1px;box-shadow:0 4px 18px rgba(20,32,31,.10)}
.search .qr{width:52px;display:grid;place-items:center;background:none;border:0;padding:0;color:var(--muted)}
.search input{flex:1;min-width:0;border:0;outline:0;background:none;font-size:15.5px;font-weight:700;
  letter-spacing:.6px;color:var(--ink);padding:13px 0}
.search input::placeholder{font-weight:500;letter-spacing:0;font-size:14.5px;color:var(--muted)}
.search button[type=submit]{border:0;background:var(--teal);color:#fff;border-radius:22px;height:44px;
  padding:0 18px;font-size:14px;font-weight:700;display:grid;place-items:center}
.search button[type=submit] .i{display:none}
.search .err{margin:8px 0 0 18px;font-size:12.5px;font-weight:600;color:#A02A22}
@media (max-width:639px){
  .search input{font-size:15px}
  .search button[type=submit]{padding:0;width:44px}
  .search button[type=submit] .t{display:none}
  .search button[type=submit] .i{display:block}
}

/* --------------------------------------------------------- khung trang */
.wrap{max-width:var(--container);margin:0 auto;padding:6px var(--gutter) 56px}
.card{background:#fff;border:1px solid var(--line);border-radius:18px}
.eyebrow{margin:0;font-size:11px;font-weight:700;letter-spacing:1.6px;text-transform:uppercase;color:var(--orange-ink)}
.sec-head{display:flex;align-items:center;gap:10px;margin:0;font-size:15px;font-weight:800;color:var(--ink)}
.sec-bar{width:3px;height:16px;border-radius:2px;background:var(--orange)}
.pill-row{display:flex;flex-wrap:wrap;gap:12px 20px}
.ic{flex:none}
.pill-l{display:flex;align-items:center;gap:5px;font-size:10.5px;font-weight:700;letter-spacing:1.2px;
  color:var(--muted);text-transform:uppercase}
.pill-l .ic{opacity:.7}
.pill-v{display:block;font-size:14px;font-weight:700;color:var(--ink);margin-top:2px}

/* ------------------------------------------------------------- các mục */
.tabs{display:flex;gap:0;background:#fff;border:1px solid var(--line);border-radius:13px;padding:4px;
  width:max-content;max-width:100%}
.tabs a{display:flex;align-items:center;gap:8px;padding:10px 16px;border-radius:10px;text-decoration:none;
  font-size:14px;font-weight:700;color:var(--muted);white-space:nowrap}
.tabs .ic{opacity:.85}
.tabs a[aria-current=page]{background:var(--ink);color:#fff}
.tabs .badge{display:inline-block;min-width:20px;text-align:center;padding:2px 7px;border-radius:999px;
  background:#EDEFE7;color:var(--muted);font-size:11px;font-weight:700}
.tabs a[aria-current=page] .badge{background:rgba(255,255,255,.22);color:#fff}
.tabs .short{display:none}
@media (max-width:639px){
  .tabs{width:100%}
  .tabs a{flex:1;justify-content:center;padding:10px 6px;font-size:13px;gap:6px}
  .tabs .full{display:none}
  .tabs .short{display:inline}
}

/* ----------------------------------------------------- thông tin chung */
.general{display:grid;gap:20px;margin-top:18px}
.general .shot{border-radius:18px;overflow:hidden;background:#EDEFE9;height:240px}
.general .shot img{width:100%;height:100%;object-fit:cover}
.general .facts{padding:20px}
.title{font-family:Lora,Georgia,serif;font-weight:600;font-size:28px;line-height:1.25;margin:8px 0 0}
.desc{font-size:14.5px;line-height:1.6;margin:18px 0 0}
@media (min-width:900px){
  .general{grid-template-columns:96fr 104fr;align-items:stretch}
  .general .shot{height:600px}
  .general .facts{height:600px;overflow:auto}
}

/* Thẻ nào cuộn bên trong thì đáy mờ dần, để người đọc biết còn nội dung phía
   dưới. Cuộn tới đáy rồi thì bỏ vệt mờ đi, chứ không làm nhoè dòng cuối. */
.scroll-wrap{position:relative;min-width:0}
@media (min-width:900px){
  .scroll-wrap::after{content:"";position:absolute;left:1px;right:1px;bottom:1px;height:52px;
    border-radius:0 0 17px 17px;pointer-events:none;opacity:1;transition:opacity .2s ease;
    background:linear-gradient(rgba(255,255,255,0),#fff 78%)}
  .scroll-wrap.ended::after,.scroll-wrap.fits::after{opacity:0}
}

/* thẻ "đã xác minh" */
.verify{display:flex;gap:10px;align-items:flex-start;border-radius:14px;padding:12px 14px;margin-top:14px;max-width:340px}
.verify.ok{background:var(--panel)}
.verify.warn{background:#FFF1E2}
.verify.bad{background:#FBE6E4}
.verify .t{font-size:11.5px;font-weight:800;letter-spacing:.8px;text-transform:uppercase}
.verify.ok .t{color:#2C6B3F}.verify.warn .t{color:var(--orange-ink)}.verify.bad .t{color:#A02A22}
.verify p{margin:4px 0 0;font-size:12.5px;color:var(--muted);line-height:1.45}

.facts-row{display:flex;flex-wrap:wrap;gap:0;border:1px solid var(--line);border-radius:14px;margin-top:18px;overflow:hidden}
.facts-row>div{flex:1 1 150px;padding:12px 16px;border-left:1px solid var(--line)}
.facts-row .pill-v{display:flex;align-items:center;gap:6px}
.facts-row .pill-v .ic{color:var(--muted);opacity:.7}
.facts-row>div:first-child{border-left:0}
.strip{display:flex;gap:10px;flex-wrap:wrap;margin-top:12px}
.strip a{width:96px;height:96px;border-radius:12px;overflow:hidden;border:1px solid var(--line);background:#EDEFE9}
.strip img{width:100%;height:100%;object-fit:cover}

/* --------------------------------------------------------- nguồn gốc */
.origin{display:grid;gap:18px;margin-top:18px}
@media (min-width:900px){.origin{grid-template-columns:70fr 30fr;align-items:start}}
.origin .scroll-wrap{min-width:0}
.canvas{background:#fff;border:1px solid var(--line);border-radius:18px;overflow:hidden;position:relative;height:380px}
@media (min-width:900px){.canvas{height:620px}}
.canvas svg{width:100%;height:100%;display:block;touch-action:none}
/* Nút phóng to nằm trên đầu khung: ở góc dưới nó đè lên hàng ô vùng nguyên
   liệu, mà đó là hàng người xem hay bấm nhất. */
.canvas .zoom{position:absolute;right:12px;top:12px;display:flex;gap:4px;
  background:rgba(255,255,255,.92);border:1px solid var(--line);border-radius:12px;padding:4px}
.canvas .zoom button{width:30px;height:30px;border-radius:8px;border:0;background:none;
  color:var(--muted);font-size:15px;line-height:1;display:grid;place-items:center}
.canvas .zoom button:hover{background:#F1F3ED;color:var(--ink)}
.node{cursor:pointer;text-decoration:none}
.node rect{fill:#fff;stroke:rgba(23,53,41,.16);stroke-width:1}
.node text{font-size:12px;font-weight:600;fill:var(--ink)}
.node:hover rect{stroke:var(--c);stroke-opacity:.55}
/* Chỉ ô đang chọn mới có viền đậm. Ô nằm trên đường đi đậm hơn một nhịp, đủ
   để dõi theo mà không ai tưởng mình vừa chọn năm ô một lúc. */
.node.path rect{stroke:var(--c);stroke-opacity:.45}
.node.on rect{stroke:var(--c);stroke-opacity:1;stroke-width:2.2;fill:#F7F9F5}
.node.on text{font-weight:800}
.node:focus-visible rect{stroke:var(--c);stroke-opacity:1;stroke-width:2.2}
.node.product rect{fill:#17352A;stroke:#17352A}
.node.product text{fill:#fff;font-weight:800}
.node.product.on rect{fill:#0F2A20}

/* Chi tiết một ô trên sơ đồ. Không có JS thì :target lo việc đóng mở. */
.detail{display:none}
.detail:target{display:block}
.detail.on{display:block}
.dfl{display:block}
.dfl.off{display:none}
.detail:target~.dfl{display:none}
.detail .back{text-decoration:none}
.step-row,.doc,.strip a,.samples a,.tabs a{text-decoration:none;color:inherit}
.step-row{cursor:pointer}
.step-row:hover .t{color:var(--orange-ink)}
.origin-band{fill:rgba(23,53,41,.035)}
.edge{fill:none;stroke-width:1.5;opacity:.32}
.edge.on{opacity:1;stroke-width:2.4}

.panel{background:#fff;border:1px solid var(--line);border-radius:18px;padding:20px}
@media (min-width:900px){.panel{height:620px;overflow:auto}}
.panel .back{display:inline-flex;align-items:center;gap:4px;border:0;background:none;padding:0;margin-bottom:14px;
  color:var(--orange-ink);font-size:13px;font-weight:700}
.panel .back:hover{color:var(--ink)}

/* Thanh cuộn mảnh, cùng tông với thẻ. Thanh mặc định của Windows rộng 17px
   màu xám, đặt cạnh một thẻ bo tròn thì nhìn như thẻ bị khoét mất một dải. */
.panel,.general .facts{scrollbar-width:thin;scrollbar-color:rgba(23,53,41,.15) transparent}
.panel::-webkit-scrollbar,.general .facts::-webkit-scrollbar{width:10px}
.panel::-webkit-scrollbar-track,.general .facts::-webkit-scrollbar-track{background:transparent}
.panel::-webkit-scrollbar-thumb,.general .facts::-webkit-scrollbar-thumb{
  background:rgba(23,53,41,.13);border-radius:99px;border:3px solid #fff}
.panel:hover::-webkit-scrollbar-thumb,.general .facts:hover::-webkit-scrollbar-thumb{background:rgba(23,53,41,.26)}

.badge-ic{width:34px;height:34px;border-radius:11px;display:grid;place-items:center;flex:none}
.detail-head{display:flex;gap:12px;align-items:center}
.detail-head .t{font-size:17px;font-weight:800;line-height:1.25}
.detail-head .s{font-size:12.5px;color:var(--muted)}
.dot{width:10px;height:10px;border-radius:3px;flex:none}
.step-row{display:flex;gap:12px;align-items:flex-start;padding:10px 0;border-top:1px solid var(--line);width:100%;
  text-align:left;background:none;border-left:0;border-right:0;border-bottom:0}
.step-row .n{font-size:11px;font-weight:800;color:var(--muted);min-width:18px}
.step-row .t{font-size:14px;font-weight:700}
.step-row .s{font-size:12px;color:var(--muted)}
.op{display:flex;align-items:center;gap:10px;margin-top:16px}
.op img{width:38px;height:38px;border-radius:50%;object-fit:cover;background:var(--panel)}
.op .r{font-size:11px;color:var(--muted)}
.op .badge-ic{background:rgba(23,53,41,.06);color:var(--muted)}
.integrity .link .ic,.doc .open .ic{opacity:.85}
.shotbox{border-radius:12px;overflow:hidden;margin-top:16px;max-height:320px}
.shotbox img{width:100%;height:100%;object-fit:cover}
.cap{font-size:12px;color:var(--muted);margin:6px 0 0}

/* ------------------------------------------------------------ kiểm định */
.docs{display:grid;gap:16px;grid-template-columns:1fr;margin-top:14px}
@media (min-width:620px){.docs{grid-template-columns:repeat(2,1fr)}}
@media (min-width:1000px){.docs{grid-template-columns:repeat(3,1fr)}}
.doc{background:#fff;border:1px solid var(--line);border-radius:16px;overflow:hidden;text-decoration:none;display:block}
.doc .pic{aspect-ratio:4/3;background:#EDEFE9;position:relative;overflow:hidden;display:grid;place-items:center}
.doc .pic img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}
.doc .meta{padding:14px 16px}
.doc .n{font-size:15px;font-weight:800;display:flex;align-items:center;gap:8px}
.doc .n .ic{color:var(--orange-ink)}
.doc .open{display:flex;align-items:center;gap:6px}
.doc .m{font-size:12.5px;color:var(--muted);margin:4px 0 0}
.doc .open{font-size:13px;font-weight:600;color:var(--orange-ink);margin:10px 0 0}
.empty{background:#fff;border:1px solid var(--line);border-radius:18px;padding:28px;text-align:center;color:var(--muted)}

/* --------------------------------------------------------- dải kiểm chứng */
.integrity{margin-top:20px;background:#fff;border:1px solid var(--line);border-radius:18px;padding:16px 20px;
  display:flex;flex-wrap:wrap;gap:18px 28px;align-items:center}
.integrity .ico{width:38px;height:38px;border-radius:50%;background:var(--ink);color:#fff;display:grid;place-items:center;flex:none}
.integrity .lead{flex:1 1 260px}
.integrity .lead b{display:block;font-size:14.5px}
.integrity .lead span{font-size:12.5px;color:var(--muted)}
.integrity .f{font-size:10.5px;font-weight:700;letter-spacing:1.2px;color:var(--muted);text-transform:uppercase}
.integrity .f b{display:block;font-size:14px;color:var(--ink);letter-spacing:0;margin-top:2px;text-transform:none}
.integrity .tx{font-variant-numeric:tabular-nums}
.integrity .link{margin-left:auto;display:inline-flex;align-items:center;gap:8px;border:1px solid var(--line);
  border-radius:12px;padding:10px 14px;text-decoration:none;font-size:13.5px;font-weight:700}

/* ----------------------------------------------------------------- chân */
.ft{max-width:var(--container);margin:0 auto;padding:0 var(--gutter) 40px;display:flex;flex-wrap:wrap;gap:10px 20px;
  align-items:center;font-size:12.5px;color:var(--muted)}
.ft b{color:var(--ink);font-weight:800;letter-spacing:.6px}

/* ------------------------------------------------------------ trang chủ */
.home{display:grid;gap:20px;margin-top:18px}
@media (min-width:900px){.home{grid-template-columns:70fr 30fr;align-items:start}}
.home .hero{border-radius:18px;overflow:hidden;background:#F2F4EE;height:380px;display:grid;place-items:center}
@media (min-width:900px){.home .hero{height:620px}}
.home .hero img{width:100%;height:100%;object-fit:contain}
.home .side{background:#fff;border:1px solid var(--line);border-radius:18px;padding:20px}
.home .side .cover{border-radius:14px;overflow:hidden;margin-bottom:18px}
.samples{margin-top:10px;display:grid;gap:8px}
.samples a{display:flex;align-items:center;gap:10px;justify-content:space-between;border:1px solid var(--line);
  border-radius:12px;padding:11px 14px;text-decoration:none}
.samples .c{display:block;font-weight:700;letter-spacing:.6px;font-variant-numeric:tabular-nums}
.samples .s{display:block;font-size:12px;color:var(--muted);margin-top:2px}
.hr{height:1px;background:var(--line);margin:22px 0 16px}

.notice{background:#fff;border:1px solid var(--line);border-radius:18px;padding:28px;margin-top:18px;max-width:560px}
.notice h2{font-family:Lora,Georgia,serif;font-size:22px;margin:0 0 8px}
.notice p{color:var(--muted);margin:0 0 16px}
.notice a{display:inline-flex;align-items:center;gap:8px;background:var(--ink);color:#fff;border-radius:12px;
  padding:11px 16px;text-decoration:none;font-size:14px;font-weight:700}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
`;
