# WudCar — وُد كار

تطبيق iPhone مع CarPlay: الترفيه (اختصارات مواقع ومتصفح) + Xtream Codes IPTV، مع بث الفيديو عبر AirPlay وCarPlay Video.

---

## ما يعمل عبر CarPlay Video (المسار الرسمي من أبل)

حسب وثائق أبل، تطبيق CarPlay Video:
- يعرض واجهة تصفح من **قوالب CarPlay** فقط (قوائم)، بدون WebView على شاشة السيارة.
- يشغّل الفيديو من iPhone، وCarPlay يعرضه على شاشة السيارة **وهي متوقفة**. أثناء القيادة يتحول تلقائياً لصوت فقط.
- يظهر في CarPlay فقط في السيارات التي تدعم ميزة الفيديو (Video in Car).

| في CarPlay | ماذا يحدث |
|---|---|
| تبويب **الترفيه** | قائمة اختصاراتك. الاختيار يفتح الموقع على iPhone، والفيديو يُبث للسيارة عبر AirPlay. |
| تبويب **Xtream** | الحسابات ← الأقسام (مباشر/أفلام) ← القنوات. كل قناة معلنة كفيديو عبر `CPPlaybackConfiguration(preferredPresentation: .video)` (iOS 26.4+)، فيعرضها CarPlay فيديو بملء شاشة السيارة. |

تحقق إن كانت السيارة تدعم الفيديو يتم عبر `CPSessionConfiguration.supportsVideoPlayback`. إذا لم تدعم، تُشغَّل القناة صوتاً مع شاشة Now Playing.

> متصفح السيارة الكامل (`CarBrowserViewController`) موجود في المشروع، لكنه لا يعمل إلا إذا أعطى النظام نافذة حرة، وهذا خاص بتطبيقات الملاحة. مع صلاحية الفيديو، النظام يستخدم القوالب.

## لماذا لا يظهر متصفح على شاشة السيارة؟ (نتيجة التحليل)

ما تحققنا منه من مصادر أبل وصفحة CarTV:

- **جلسة WWDC26 رقم 212 من أبل:** تطبيق الفيديو يبني تصفحه بقوالب CarPlay فقط، والفيديو يُبث من iPhone عبر AirPlay إلى شاشة السيارة وهي متوقفة. لا يُذكر WebView ولا نافذة مخصصة.
- **شرط الظهور:** تطبيق الفيديو لا يظهر على شاشة CarPlay الرئيسية إلا إذا كانت السيارة تدعم Video in Car. لذلك أضفنا صلاحية الصوت ليظهر التطبيق دائماً.
- **«الصوت فقط»:** إذا لم تعلن السيارة دعم الفيديو، فشاشتها لا تظهر كوجهة AirPlay للفيديو، ويصل الصوت فقط. هذا قيد من السيارة وليس خطأ في التطبيق.
- **CarTV:** موقعه الرسمي (cartv.app) يذكر ثلاث طرق: واجهة خاصة على شاشة السيارة، واستقبال البث بـ DLNA/UPnP، ومرآة شاشة iPhone. كلها تحتاج رسم واجهة خاصة على شاشة السيارة، والنافذة الحرة لا تعطيها أبل إلا لفئة الملاحة. لا نستطيع معرفة الصلاحيات الفعلية داخل CarTV من الخارج.
- **سابقة Sidecar (أبريل 2025):** تطبيق مرّ مراجعة App Store بمتصفح على CarPlay، ثم طلبت أبل إزالته.

الخلاصة: بصلاحية CarPlay Video لا يوجد طريق رسمي لمتصفح كامل على شاشة السيارة. الطريق الرسمي هو قوائم CarPlay + AirPlay للفيديو، ويعمل على سيارة تعلن دعم الفيديو.

## تشخيص الفيديو في السيارة

- في CarPlay، تبويب «الترفيه» يبدأ بصف **الفيديو في السيارة** (مدعوم / غير مدعوم). والقراءة نفسها في الرئيسية والإعدادات على iPhone.
- القيمة تأتي من `CPSessionConfiguration.supportsVideoPlayback` كما تعلنها السيارة (تظهر بعد ثوانٍ من الاتصال).
- **مدعوم:** شغّل الفيديو على iPhone، اضغط زر AirPlay، واختر شاشة السيارة والسيارة متوقفة.
- **غير مدعوم:** لا يوجد حل داخل التطبيق. جرّب سيارة أو شاشة أخرى تدعم Video in Car.

## AirPlay

- مشغل Xtream على الهاتف (`AVPlayerViewController`) فيه زر AirPlay وصورة داخل صورة.
- `AVPlayer.allowsExternalPlayback = true` و`usesExternalPlaybackWhileExternalScreenIsActive = true`.
- متصفح الهاتف: `allowsAirPlayForMediaPlayback = true`، وزر AirPlay في رأس الشاشة.
- معلومات Now Playing وأوامر التحكم منشورة (العنوان، الشعار، مباشر/مدة، تشغيل/إيقاف، ±15 ث).

---

## البناء عبر Codemagic (بدون Mac)

1. **GitHub:** ارفع المجلد إلى فرع `wudcar`.
2. **Codemagic:** أضف المستودع ← سيقرأ `codemagic.yaml` تلقائياً.
3. **مفتاح App Store Connect API:** في App Store Connect ← Users and Access ← Integrations ← App Store Connect API، أنشئ مفتاحاً بصلاحية *App Manager*. ارفعه في Codemagic ← Team settings ← Integrations ← Developer Portal باسم `WudCar ASC Key`.
4. **Apple Developer:** أنشئ App ID بالمعرّف `com.azstudio.wudcar` وفعّل عليه **CarPlay** (Video).
5. **App Store Connect:** أنشئ سجل تطبيق جديداً بنفس المعرّف، واسم WudCar.
6. **Codemagic ← Code signing identities:** أنشئ شهادة Apple Distribution (أو استورد الحالية)، ثم اجلب ملف التعريف للمعرّف الجديد.
7. **متغيرات Codemagic** (مجموعة `wudcar`): `TEAM_ID` و`APP_STORE_ID`.
8. شغّل workflow **WudCar → TestFlight**.

## الفرق بين المصطلحات

- **Bundle ID:** النص الفريد للتطبيق، مثل `com.azstudio.wudcar`.
- **App ID:** سجل Bundle ID في حساب Apple Developer، وعليه تُفعَّل الصلاحيات مثل CarPlay.
- **شهادة التوزيع (Apple Distribution):** تثبت أن البناء صادر من حسابك. شهادة واحدة تكفي لكل تطبيقاتك.
- **Provisioning Profile:** يربط App ID + الشهادة + الصلاحيات. كل تطبيق له ملف خاص.

لذلك تطبيق مستقل = Bundle ID وApp ID وProfile جديدة، مع إمكانية استخدام نفس الشهادة.

---

## ملفات المشروع الرئيسية

| المجال | الملفات |
|---|---|
| الانترو والهوية | `Phone/IntroView.swift`، `Resources/Intro/`، `App/Brand.swift` |
| الرئيسية والإعدادات (اللغة، وضع العرض، البيانات، الخصوصية) | `Phone/HomeView.swift`، `Phone/SettingsView.swift` |
| الترفيه (متصفح + اختصارات + تعديل وترتيب) | `Phone/PhoneBrowserScreen.swift`، `Phone/ShortcutsGridView.swift` |
| Xtream Codes | `Xtream/` (الحسابات في Keychain، العميل، الواجهات) |
| المشغل وAirPlay وNow Playing | `Shared/PlaybackManager.swift` |
| CarPlay Video | `CarPlay/CarTemplateUI.swift`، `CarPlay/CarSceneDelegate.swift` |

## ملاحظات

- الكود لم يُبنَ بعد. أول بناء في Codemagic سيكشف الأخطاء، وأصلحها من سجل البناء.
- `NSAllowsArbitraryLoads` مفعّل لأن سيرفرات IPTV التي يضيفها المستخدم غالباً تستخدم http. اذكر هذا السبب في ملاحظات المراجعة.
- القنوات المباشرة تعمل في CarPlay بصيغة HLS (m3u8). بعض الأفلام بصيغة MKV قد لا يشغّلها AVPlayer.
