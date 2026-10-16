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

      // ---------- ملء الشاشة ----------
      function ensureStyle() {
        if (document.getElementById('wd-style')) { return; }
        var s = document.createElement('style');
        s.id = 'wd-style';
        s.textContent = [
          'html.wd-fs, html.wd-fs body { overflow: hidden !important; background: #000 !important; }',
          'html.wd-fs body * { visibility: hidden !important; }',
          'html.wd-fs .wd-fs-video { visibility: visible !important; position: fixed !important; left: 0 !important; top: 0 !important; right: auto !important; bottom: auto !important; width: 100vw !important; height: 100vh !important; max-width: none !important; max-height: none !important; margin: 0 !important; transform: none !important; z-index: 2147483647 !important; background: #000 !important; object-fit: var(--wd-fit, contain) !important; }'
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
        state.fsVideo = null;
        state.fsTarget = null;
        post({ type: 'fullscreen', on: false });
        if (was) { fireChange(); }
      }

      window.__wdEnterFS = function () { return enter(null); };
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
