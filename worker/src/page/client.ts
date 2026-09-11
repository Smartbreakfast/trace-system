/// Đoạn script nhúng thẳng vào trang. Mọi nội dung đã có sẵn trong HTML; chỗ
/// này chỉ làm cho thao tác mượt hơn: đổi mục không tải lại trang, chọn một ô
/// trên sơ đồ thì panel đổi tại chỗ, và phóng to sơ đồ được.
///
/// Tắt JS thì trang vẫn dùng được đủ: mục chuyển bằng liên kết thật, chi tiết
/// công đoạn hiện bằng `:target`, tra cứu bằng form.

export const clientJs = String.raw`
(function(){
  var d=document;

  // ------------------------------------------------------------ menu
  var mb=d.getElementById('menu-btn'),hdr=d.getElementById('hdr');
  if(mb&&hdr)mb.addEventListener('click',function(){
    var open=hdr.classList.toggle('open');
    mb.setAttribute('aria-expanded',open?'true':'false');
  });

  // ------------------------------------------------------- ô tra cứu
  var form=d.getElementById('search-form'),input=d.getElementById('code');
  if(form&&input){
    form.addEventListener('submit',function(e){
      var code=(input.value||'').trim().toUpperCase().replace(/\s+/g,'');
      if(!code){e.preventDefault();input.focus();return;}
      input.value=code;
    });
  }

  // Nút quét mã chỉ hiện khi máy thật sự quét được, không thì để nguyên
  // biểu tượng tĩnh cho đỡ hứa suông.
  var qrBtn=d.getElementById('qr-btn'),qrIcon=d.getElementById('qr-icon');
  if(qrBtn&&'BarcodeDetector'in window&&navigator.mediaDevices){
    qrBtn.hidden=false;if(qrIcon)qrIcon.hidden=true;
    qrBtn.addEventListener('click',function(){scan(qrBtn);});
  }
  function scan(btn){
    var video=d.createElement('video'),box=d.createElement('div');
    box.style.cssText='position:fixed;inset:0;background:#000;z-index:99;display:grid;place-items:center';
    video.style.cssText='max-width:100%;max-height:100%';
    video.setAttribute('playsinline','');
    var close=d.createElement('button');
    close.textContent='Đóng';
    close.style.cssText='position:absolute;top:16px;right:16px;padding:10px 16px;border:0;border-radius:10px';
    box.appendChild(video);box.appendChild(close);d.body.appendChild(box);
    var stream,stop=function(){if(stream)stream.getTracks().forEach(function(t){t.stop();});box.remove();};
    close.addEventListener('click',stop);
    navigator.mediaDevices.getUserMedia({video:{facingMode:'environment'}}).then(function(s){
      stream=s;video.srcObject=s;video.play();
      var det=new window.BarcodeDetector({formats:['qr_code']});
      var tick=function(){
        if(!d.body.contains(box))return;
        det.detect(video).then(function(codes){
          if(codes&&codes.length){
            var raw=codes[0].rawValue||'';
            var m=raw.match(/\/t\/([^/?#]+)/);
            var code=(m?m[1]:raw).trim().toUpperCase().replace(/\s+/g,'');
            stop();if(code)location.href='/t/'+encodeURIComponent(code);
            return;
          }
          requestAnimationFrame(tick);
        }).catch(function(){requestAnimationFrame(tick);});
      };
      requestAnimationFrame(tick);
    }).catch(function(){stop();});
  }

  // ------------------------------------------------------------ mục
  var tabs=d.querySelectorAll('.tabs a[data-tab]');
  if(tabs.length){
    Array.prototype.forEach.call(tabs,function(a){
      a.addEventListener('click',function(e){
        if(e.metaKey||e.ctrlKey||e.shiftKey)return;
        e.preventDefault();
        showTab(a.getAttribute('data-tab'),true);
      });
    });
  }
  function showTab(name,push){
    Array.prototype.forEach.call(d.querySelectorAll('[data-panel]'),function(p){
      p.hidden=p.getAttribute('data-panel')!==name;
    });
    Array.prototype.forEach.call(tabs,function(a){
      var on=a.getAttribute('data-tab')===name;
      if(on)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');
    });
    if(push&&history.pushState){
      var url=new URL(location.href);
      if(name==='general')url.searchParams.delete('tab');else url.searchParams.set('tab',name);
      url.hash='';
      history.pushState({tab:name},'',url);
    }
  }
  window.addEventListener('popstate',function(){
    var tab=new URL(location.href).searchParams.get('tab')||'general';
    showTab(tab,false);
  });

  // ------------------------------------------------- vệt mờ đáy thẻ cuộn
  function fade(el){
    var wrap=el.parentNode;
    if(!wrap||!wrap.classList.contains('scroll-wrap'))return;
    var fits=el.scrollHeight-el.clientHeight<4;
    wrap.classList.toggle('fits',fits);
    wrap.classList.toggle('ended',!fits&&el.scrollTop+el.clientHeight>=el.scrollHeight-4);
  }
  var scrollers=d.querySelectorAll('.scroll-wrap>.panel,.scroll-wrap>.facts');
  Array.prototype.forEach.call(scrollers,function(el){
    fade(el);
    el.addEventListener('scroll',function(){fade(el);});
  });
  window.addEventListener('resize',function(){
    Array.prototype.forEach.call(scrollers,function(el){fade(el);});
  });

  // ---------------------------------------------------------- sơ đồ
  var svg=d.querySelector('.canvas svg');
  var panel=d.getElementById('panel');
  if(panel){
    // Bấm một ô trên sơ đồ, hoặc một dòng công đoạn trong panel.
    d.addEventListener('click',function(e){
      var hit=e.target.closest?e.target.closest('[data-id],[data-goto]'):null;
      if(!hit)return;
      var id=hit.getAttribute('data-id')||hit.getAttribute('data-goto');
      if(!id)return;
      if(e.metaKey||e.ctrlKey)return;
      e.preventDefault();
      select(id);
    });
  }
  function select(id){
    var target=id?d.getElementById('n-'+id):null;
    Array.prototype.forEach.call(d.querySelectorAll('.detail'),function(el){
      el.classList.toggle('on',el===target);
    });
    var base=d.querySelector('.dfl');
    if(base)base.classList.toggle('off',!!target);
    // Tô đường đi từ thành phẩm xuống ô đang chọn.
    Array.prototype.forEach.call(d.querySelectorAll('.edge'),function(el){el.classList.remove('on');});
    Array.prototype.forEach.call(d.querySelectorAll('.node'),function(el){el.classList.remove('on');});
    // Chỉ ô đang chọn được tô viền. Các ô phía trên chỉ nằm trên đường đi,
    // tô viền cả loạt thì nhìn như đang chọn năm ô một lúc.
    Array.prototype.forEach.call(d.querySelectorAll('.node'),function(el){el.classList.remove('path');});
    var cursor=id,step=0;
    while(cursor){
      var node=d.querySelector('.node[data-id="'+cursor+'"]');
      if(!node)break;
      node.classList.add(step===0?'on':'path');
      var edge=d.querySelector('.edge[data-for="'+cursor+'"]');
      if(edge)edge.classList.add('on');
      cursor=node.getAttribute('data-parent');
      step+=1;
    }
    if(panel){panel.scrollTop=0;fade(panel);}
  }
  // Mở sẵn theo địa chỉ dạng #n-... khi người ta dán lại liên kết.
  if(location.hash.indexOf('#n-')===0)select(location.hash.slice(3));

  // -------------------------------------------------- phóng to sơ đồ
  if(svg){
    var vb=svg.getAttribute('viewBox').split(/\s+/).map(Number);
    var base={x:vb[0],y:vb[1],w:vb[2],h:vb[3]},cur={x:vb[0],y:vb[1],w:vb[2],h:vb[3]};
    var apply=function(){svg.setAttribute('viewBox',cur.x+' '+cur.y+' '+cur.w+' '+cur.h);};
    var zoom=function(f,cx,cy){
      var w=cur.w/f,h=cur.h/f;
      if(w<base.w/5||w>base.w*2.5)return;
      var rx=cx===undefined?.5:cx,ry=cy===undefined?.5:cy;
      cur.x+=(cur.w-w)*rx;cur.y+=(cur.h-h)*ry;cur.w=w;cur.h=h;apply();
    };
    var zi=d.getElementById('zoom-in'),zo=d.getElementById('zoom-out'),zf=d.getElementById('zoom-fit');
    if(zi)zi.addEventListener('click',function(){zoom(1.3);});
    if(zo)zo.addEventListener('click',function(){zoom(1/1.3);});
    if(zf)zf.addEventListener('click',function(){cur={x:base.x,y:base.y,w:base.w,h:base.h};apply();});
    svg.addEventListener('wheel',function(e){
      e.preventDefault();
      var r=svg.getBoundingClientRect();
      zoom(e.deltaY<0?1.12:1/1.12,(e.clientX-r.left)/r.width,(e.clientY-r.top)/r.height);
    },{passive:false});
    // Không dùng setPointerCapture: bắt con trỏ vào thẻ svg thì cú click sau
    // đó cũng tính là của svg, và bấm vào một ô trên sơ đồ không còn ăn.
    var drag=null,moved=0;
    svg.addEventListener('pointerdown',function(e){
      if(e.button!==0&&e.pointerType==='mouse')return;
      drag={x:e.clientX,y:e.clientY,vx:cur.x,vy:cur.y,r:svg.getBoundingClientRect()};moved=0;
    });
    window.addEventListener('pointermove',function(e){
      if(!drag)return;
      moved=Math.max(moved,Math.abs(e.clientX-drag.x)+Math.abs(e.clientY-drag.y));
      if(moved<4)return;
      var dx=(e.clientX-drag.x)*cur.w/drag.r.width,dy=(e.clientY-drag.y)*cur.h/drag.r.height;
      cur.x=drag.vx-dx;cur.y=drag.vy-dy;apply();
    });
    window.addEventListener('pointerup',function(){
      if(drag&&moved>6){
        // Vừa kéo thì đừng tính là một cú bấm chọn ô.
        var stop=function(ev){ev.stopPropagation();ev.preventDefault();};
        svg.addEventListener('click',stop,{capture:true,once:true});
      }
      drag=null;
    });
    window.addEventListener('pointercancel',function(){drag=null;});
  }
})();
`;
