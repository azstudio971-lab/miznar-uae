# WudCar — التحديث 3 (الإصدار 1.3.0)

## ما اكتشفناه من ملف CarTV (تم التحقق من IPA الرسمي)
- صلاحياته: `carplay-video` + `carplay-audio` فقط. **لا توجد صلاحية ملاحة.**
- يعلن في Info.plist عن مشهد **شاشة خارجية** (`UIWindowSceneSessionRoleExternalDisplay` و `...NonInteractive`).
- مع ميزة الفيديو في CarPlay تظهر شاشة السيارة للتطبيق كشاشة خارجية عبر AirPlay، فيرسم عليها واجهته (متصفح WKWebView، مشغّل، تبويبات).
- يستخدم قوالب CarPlay الرسمية فقط (قائمة، تبويبات، Now Playing، CPPlaybackConfiguration، CPSessionConfiguration).
- إضافات أخرى: ScreenRelay (ReplayKit لمرآة الشاشة)، Widget، استقبال بث عبر الشبكة المحلية.

## ما تغيّر في WudCar
| الملف | التغيير |
|---|---|
| `Config/WdCar.entitlements` | تفعيل الفيديو + الصوت (مثل CarTV تماماً) |
| `Config/Info.plist` | إضافة مشهدَي الشاشة الخارجية |
| `CarPlay/CarExternalDisplaySceneDelegate.swift` | جديد: يعرض متصفح ود كار الكامل على شاشة السيارة |
| `CarPlay/CarScreenLauncher.swift` | جديد: يحاول فتح وضع الفيديو من CarPlay مباشرة |
| `CarPlay/CarTemplateUI.swift` | عنصر «المتصفح على شاشة السيارة» + الاختصارات تفتح على شاشة السيارة عند تشغيلها |
| `App/WdCarApp.swift` | توجيه مشهد الشاشة الخارجية للمفوّض الجديد |
| `App/AppState.swift` | حالة شاشة السيارة |
| `Phone/CarScreenSheet.swift` | جديد: نافذة على الهاتف بزر AirPlay لاختيار شاشة السيارة |
| `Phone/HomeView.swift`، `Phone/SettingsView.swift` | عرض حالة شاشة السيارة وزر التشغيل |
| `Shared/WDLog.swift` | جديد: سجلات تشخيص تظهر في Console بكلمة `WUDCAR` |
| `Shared/PlaybackManager.swift` | تسجيل حالة البث الخارجي |
| `codemagic.yaml` | خطوة تتحقق أن IPA وملف التعريف فيهما صلاحيتا الفيديو والصوت ومشهد الشاشة الخارجية |
| `project.yml` | الإصدار 1.3.0 |

## طريقة التجربة في السيارة
1. افتح ود كار في CarPlay ← تبويب «الترفيه» ← **المتصفح على شاشة السيارة**.
2. إذا لم يظهر المتصفح خلال ثوانٍ: على الهاتف ستظهر نافذة «شاشة السيارة» ← اضغط زر AirPlay ← اختر شاشة السيارة.
3. عند ظهور المتصفح: افتح المواقع من الاختصارات في CarPlay أو من زر «إرسال للسيارة» في الهاتف.

## إذا لم يعمل — السجلات
iMazing ← الأدوات ← عرض وحدة التحكم ← اكتب في البحث **WUDCAR** ← كرر التجربة ← صوّر الأسطر.
أهم الأسطر:
- `scene connecting role=...` — أي مشهد طلبه النظام.
- `external display CONNECTED` — شاشة السيارة اتصلت (النجاح).
- `launcher: no external display after 12s` — وضع الفيديو من CarPlay لم يفتح الشاشة (نستخدم AirPlay).
- `supportsVideoPlayback=` — هل السيارة تعلن دعم الفيديو.

## ما لم يُتحقق منه بعد
- الكود لم يُبنَ بعد (لا يوجد Xcode هنا) — Codemagic يكشف أي خطأ.
- اللحظة الدقيقة التي ينشئ فيها النظام الشاشة الخارجية (من CarPlay أو من AirPlay) — السجلات تكشفها.
- مرآة الشاشة (ScreenRelay) واستقبال البث غير مضافين بعد — مرحلة قادمة.
