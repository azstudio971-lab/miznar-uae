import WebKit

/// إعدادات WebKit المشتركة + السكربتات المحقونة في متصفح السيارة.
enum WebEngine {
    static let messageName = "wd"

    /// وكيل مستخدم سفاري ماك: المواقع تعرض نسخة سطح المكتب (مثل يوتيوب في CarTV)
    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Safari/605.1.15"

    static func makeConfiguration(for side: BrowserSide) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        // نفس مخزن البيانات للهاتف والسيارة: تسجيل الدخول والكوكيز مشتركة
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = (side == .phone)
        // في السيارة ملء الشاشة الأصلي لا يعمل (يظهر على الهاتف)، فنعترضه بسكربت
        configuration.preferences.isElementFullscreenEnabled = (side == .phone)
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        configuration.defaultWebpagePreferences.preferredContentMode = (side == .car ? WDSettings.carDesktopMode : WDSettings.phoneDesktopMode) ? .desktop : .mobile
        if side == .car {
            let script = WKUserScript(source: carScript, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            configuration.userContentController.addUserScript(script)
        }
        return configuration
    }

    /// يحوّل نص Swift إلى نص JavaScript آمن
    static func jsLiteral(_ text: String) -> String {
        let data = (try? JSONEncoder().encode(text)) ?? Data("\"\"".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    /// سكربت السيارة:
    /// 1) ملء شاشة وهمي: يعترض requestFullscreen ويكبّر عنصر الفيديو بـ CSS
    /// 2) جسر الكتابة: يكشف حقول الإدخال ويمنع ظهور كيبورد النظام، ويكتب النص القادم من التطبيق
    /// 3) حالة التشغيل: يرسل الوقت والمدة كل ثانية لمشغل ود كار
    static let carScript = #"""
    (function () {
      if (window.__wdInstalled) { return; }
      window.__wdInstalled = true;
      var state = { active: null, fsVideo: null, fsTarget: null, fit: 'contain', squelch: false };

      function post(msg) {
        try { window.webkit.messageHandlers.wd.postMessage(msg); } catch (e) {}
      }

      // Size only the app-owned video overlay in document coordinates.
      // DesktopViewportView fits the native view; site viewport/CSS stay untouched.
      var layoutQueued = false;
      function applyCarLayout() {
        if (window !== window.top || !document.documentElement) { return; }
        var viewport = window.visualViewport;
        var width = viewport ? viewport.width : window.innerWidth;
        var height = viewport ? viewport.height : window.innerHeight;
        if (!(width > 0 && height > 0)) { return; }
        var root = document.documentElement;
        var value = width.toFixed(2) + 'px';
        // Preserve the site viewport and responsive layout; only size our video overlay.
        root.style.setProperty('--wd-vw', value);
        root.style.setProperty('--wd-vh', height.toFixed(2) + 'px');
      }
      function scheduleCarLayout() {
        if (layoutQueued) { return; }
        layoutQueued = true;
        requestAnimationFrame(function () { layoutQueued = false; applyCarLayout(); });
      }
      window.__wdApplyCarLayout = scheduleCarLayout;
      document.addEventListener('DOMContentLoaded', scheduleCarLayout);
      window.addEventListener('resize', scheduleCarLayout);
      if (window.visualViewport) { window.visualViewport.addEventListener('resize', scheduleCarLayout); }

      // ---------- ملء الشاشة ----------
      function ensureStyle() {
        if (document.getElementById('wd-style')) { return; }
        var s = document.createElement('style');
        s.id = 'wd-style';
        s.textContent = [
          '#wd-expand-video::before { content: \"\"; position: absolute; inset: calc(-1 * var(--wd-hitpad, 11px)); }',
          'html.wd-fs, html.wd-fs body { overflow: hidden !important; background: #000 !important; }',
          'html.wd-fs body * { visibility: hidden !important; }',
          'html.wd-fs .wd-fs-ancestor { transform: none !important; filter: none !important; perspective: none !important; contain: none !important; will-change: auto !important; overflow: visible !important; }',
          'html.wd-fs .wd-fs-video { visibility: visible !important; position: fixed !important; left: 0 !important; top: 0 !important; right: auto !important; bottom: auto !important; width: var(--wd-vw, 100vw) !important; height: var(--wd-vh, 100vh) !important; max-width: none !important; max-height: none !important; margin: 0 !important; transform: none !important; z-index: 2147483647 !important; background: #000 !important; object-fit: var(--wd-fit, contain) !important; object-position: center center !important; }'
        ].join('\n');
        (document.head || document.documentElement).appendChild(s);
      }

      function biggestVideo() {
        var vids = Array.prototype.slice.call(document.querySelectorAll('video'));
        if (!vids.length) { return null; }
        var playing = vids.filter(function (v) { return !v.paused && v.readyState > 1; });
        var list = playing.length ? playing : vids;
        list.sort(function (a, b) { return (b.clientWidth * b.clientHeight) - (a.clientWidth * a.clientHeight); });
        return list[0];
      }

      function videoFor(el) {
        if (el && el.tagName === 'VIDEO') { return el; }
        if (el && el.querySelector) { var v = el.querySelector('video'); if (v) { return v; } }
        return biggestVideo();
      }

      function fireChange() {
        try {
          document.dispatchEvent(new Event('fullscreenchange'));
          document.dispatchEvent(new Event('webkitfullscreenchange'));
        } catch (e) {}
      }

      function enter(el) {
        var v = videoFor(el);
        if (!v) { return false; }
        ensureStyle();
        if (state.fsVideo && state.fsVideo !== v) { state.fsVideo.classList.remove('wd-fs-video'); }
        state.fsVideo = v;
        state.fsTarget = el || v;
        document.querySelectorAll('.wd-fs-ancestor').forEach(function (node) { node.classList.remove('wd-fs-ancestor'); });
        for (var parent = v.parentElement; parent; parent = parent.parentElement) { parent.classList.add('wd-fs-ancestor'); }
        v.classList.add('wd-fs-video');
        v.style.setProperty('--wd-fit', state.fit);
        document.documentElement.classList.add('wd-fs');
        post({ type: 'fullscreen', on: true });
        fireChange();
        return true;
      }

      function exit() {
        var was = !!state.fsVideo;
        if (state.fsVideo) { state.fsVideo.classList.remove('wd-fs-video'); }
        document.documentElement.classList.remove('wd-fs');
        document.querySelectorAll('.wd-fs-ancestor').forEach(function (node) { node.classList.remove('wd-fs-ancestor'); });
        state.fsVideo = null;
        state.fsTarget = null;
        post({ type: 'fullscreen', on: false });
        if (was) { fireChange(); }
      }

      window.__wdEnterFS = function () { return enter(null); };
      // A compact expansion control near the upper-left edge of the visible video.
      var expandButton = null;
      function updateExpandButton() {
        var video = biggestVideo();
        var rect = video ? video.getBoundingClientRect() : null;
        var viewport = window.visualViewport;
        var vw = viewport ? viewport.width : innerWidth;
        var vh = viewport ? viewport.height : innerHeight;
        var visible = !!rect && rect.width > 80 && rect.height > 60 &&
          rect.bottom > 0 && rect.top < vh && rect.right > 0 && rect.left < vw &&
          !state.fsVideo && !document.hidden;
        if (!visible) { if (expandButton) { expandButton.style.display = 'none'; } return; }
        if (!expandButton) {
          ensureStyle();
          expandButton = document.createElement('button');
          expandButton.id = 'wd-expand-video';
          expandButton.type = 'button';
          expandButton.textContent = '⛶';
          expandButton.setAttribute('aria-label', 'تكبير الفيديو / Expand video');
          expandButton.style.cssText = 'position:fixed!important;z-index:2147483646!important;display:block;border:1px solid rgba(255,255,255,.65);border-radius:5px;background:rgba(0,0,0,.78);color:white;line-height:1;cursor:pointer;padding:0;box-sizing:border-box;';
          expandButton.addEventListener('click', function (event) {
            event.preventDefault(); event.stopPropagation();
            if (enter(biggestVideo())) { expandButton.style.display = 'none'; }
          });
          (document.body || document.documentElement).appendChild(expandButton);
        }
        var factor = Number(window.__wdNativePageZoom) || 1;
        factor = factor > 0 ? factor : 1;
        var size = 21 / factor;
        var inset = 10 / factor;
        expandButton.style.display = 'block';
        expandButton.style.width = size + 'px';
        expandButton.style.height = size + 'px';
        expandButton.style.fontSize = (13.5 / factor) + 'px';
        expandButton.style.setProperty('--wd-hitpad', (11 / factor) + 'px');
        expandButton.style.left = Math.max(inset, Math.min(vw - size - inset, rect.left + inset)) + 'px';
        expandButton.style.top = Math.max(inset, Math.min(vh - size - inset, rect.top + inset)) + 'px';
      }
      setInterval(updateExpandButton, 500);
      window.addEventListener('scroll', updateExpandButton, true);
      window.addEventListener('resize', updateExpandButton);

      window.__wdExitFS = exit;
      window.__wdSetFit = function (f) {
        state.fit = f;
        if (state.fsVideo) { state.fsVideo.style.setProperty('--wd-fit', f); }
      };
      window.__wdTogglePlay = function () {
        var v = state.fsVideo || biggestVideo();
        if (!v) { return; }
        if (v.paused) { v.play(); } else { v.pause(); }
      };
      window.__wdSeek = function (d) {
        var v = state.fsVideo || biggestVideo();
        if (v) { v.currentTime = Math.max(0, (v.currentTime || 0) + d); }
      };
      window.__wdSeekTo = function (fraction) {
        var v = state.fsVideo || biggestVideo();
        if (v && isFinite(v.duration)) { v.currentTime = Math.max(0, Math.min(1, fraction)) * v.duration; }
      };

      function fakeRequest() { enter(this); return Promise.resolve(); }
      function fakeExit() { exit(); return Promise.resolve(); }

      try {
        Element.prototype.requestFullscreen = fakeRequest;
        Element.prototype.webkitRequestFullscreen = fakeRequest;
        Element.prototype.webkitRequestFullScreen = fakeRequest;
        if (window.HTMLVideoElement) {
          HTMLVideoElement.prototype.webkitEnterFullscreen = fakeRequest;
          HTMLVideoElement.prototype.webkitEnterFullScreen = fakeRequest;
        }
        Document.prototype.exitFullscreen = fakeExit;
        Document.prototype.webkitExitFullscreen = fakeExit;
        Document.prototype.webkitCancelFullScreen = fakeExit;
        var getters = {
          fullscreenEnabled: function () { return true; },
          webkitFullscreenEnabled: function () { return true; },
          fullscreenElement: function () { return state.fsTarget; },
          webkitFullscreenElement: function () { return state.fsTarget; },
          webkitCurrentFullScreenElement: function () { return state.fsTarget; },
          webkitIsFullScreen: function () { return !!state.fsVideo; },
          fullscreen: function () { return !!state.fsVideo; }
        };
        Object.keys(getters).forEach(function (k) {
          try { Object.defineProperty(Document.prototype, k, { configurable: true, get: getters[k] }); } catch (e) {}
        });
      } catch (e) {}

      setInterval(function () {
        var v = state.fsVideo;
        if (!v) { return; }
        post({ type: 'time', t: v.currentTime || 0, d: isFinite(v.duration) ? v.duration : 0, p: !v.paused });
      }, 1000);

      document.addEventListener('error', function (event) {
        var media = event.target;
        if (media && media.tagName === 'VIDEO' && media.error &&
            (media.error.code === 3 || media.error.code === 4)) {
          post({ type: 'mediaError' });
        }
      }, true);

      // ---------- الكتابة ----------
      function editable(el) {
        if (!el) { return false; }
        if (el.isContentEditable) { return true; }
        if (el.tagName === 'TEXTAREA') { return true; }
        if (el.tagName !== 'INPUT') { return false; }
        var t = (el.getAttribute('type') || 'text').toLowerCase();
        return ['text', 'search', 'email', 'url', 'tel', 'password', 'number'].indexOf(t) >= 0;
      }

      function silenceSystemKeyboard(el) {
        try { if (editable(el) && !el.isContentEditable) { el.setAttribute('inputmode', 'none'); } } catch (e) {}
      }

      function announce(el) {
        state.active = el;
        if (state.squelch) { return; }
        post({
          type: 'focus',
          value: el.isContentEditable ? (el.innerText || '') : (el.value || ''),
          placeholder: el.getAttribute('placeholder') || el.getAttribute('aria-label') || ''
        });
      }

      document.addEventListener('touchstart', function (e) { silenceSystemKeyboard(e.target); }, true);
      document.addEventListener('mousedown', function (e) { silenceSystemKeyboard(e.target); }, true);
      document.addEventListener('focusin', function (e) {
        var el = e.target;
        if (!editable(el)) { return; }
        silenceSystemKeyboard(el);
        announce(el);
      }, true);
      document.addEventListener('click', function (e) {
        var el = e.target;
        if (editable(el) && el === document.activeElement) { announce(el); }
      }, true);

      function withSquelch(fn) {
        state.squelch = true;
        try { fn(); } finally { setTimeout(function () { state.squelch = false; }, 400); }
      }

      window.__wdSetText = function (text) {
        var el = state.active;
        if (!el) { return false; }
        withSquelch(function () {
          try { el.focus(); } catch (e) {}
          if (el.isContentEditable) {
            el.innerText = text;
          } else {
            var proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
            var desc = Object.getOwnPropertyDescriptor(proto, 'value');
            if (desc && desc.set) { desc.set.call(el, text); } else { el.value = text; }
          }
          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
        });
        return true;
      };

      window.__wdSubmit = function () {
        var el = state.active;
        if (!el) { return; }
        withSquelch(function () {
          var opts = { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true };
          var notCancelled = el.dispatchEvent(new KeyboardEvent('keydown', opts));
          el.dispatchEvent(new KeyboardEvent('keypress', opts));
          el.dispatchEvent(new KeyboardEvent('keyup', opts));
          if (notCancelled) {
            if (el.form) {
              if (el.form.requestSubmit) { el.form.requestSubmit(); } else { el.form.submit(); }
            } else {
              var scope = el.closest('form, [role="search"], header, div') || document;
              var btn = scope.querySelector('button[type="submit"], button[aria-label*="Search" i], button[aria-label*="بحث"], #search-icon-legacy');
              if (btn) { btn.click(); }
            }
          }
          try { el.blur(); } catch (e) {}
        });
      };

      window.__wdBlur = function () {
        withSquelch(function () { try { if (state.active) { state.active.blur(); } } catch (e) {} });
      };
    })();
    """#
}

/// يمنع حلقة الاحتفاظ بين WKUserContentController والجلسة
final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
