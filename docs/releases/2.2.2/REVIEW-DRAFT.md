# WudCar 2.2.2 — draft metadata, not approved for submission

Name: WudCar - M3U IPTV

Suggested category: Utilities, subject to the final product's primary use. Changing category does not change CarPlay entitlement requirements.

## الوصف العربي المقترح

نظّم وسائطك وشغّلها مع WudCar. أضف قوائم M3U وحسابات Xtream وروابط وسائطك، أو استورد فيديوهات تختارها من الصور والملفات على iPhone. الملفات المستوردة تُحفظ داخل التطبيق للتشغيل دون إنترنت، بينما تحتاج المصادر عبر الإنترنت إلى اتصال وتوفر المصدر.

تضم مكتبة الوسائط البحث والترتيب والمفضلة وسجل المشاهدة واستئناف التشغيل. استخدم المشغّل الأصلي للتحكم في الوسائط والمسارات المتوفرة، واستورد ترجمة SRT/VTT لعرضها على الهاتف. الترجمة الخارجية على الهاتف لا تنتقل إلى AirPlay أو CarPlay أو صورة داخل صورة؛ يعتمد العرض الخارجي للترجمة على المسارات المضمنة بالمصدر.

يتضمن التطبيق متصفحًا واختصارات مواقع وإعدادات تحكم. يدعم مسار إرسال الوسائط عبر AirPlay إلى أجهزة متوافقة. توفر الفيديو في السيارة وعرضه يعتمدان على دعم السيارة والنظام وحالة السماح. لا تشاهد الفيديو أثناء القيادة.

لا يوفر WudCar قنوات أو أفلامًا أو اشتراكات IPTV ولا يستضيف المحتوى. أضف فقط المصادر التي يحق لك استخدامها. اشتراك WudCar يتيح وظائف التطبيق ولا يشمل اشتراك محتوى.

لا تعلن هذه النسخة استقبال DLNA أو استقبال AirPlay العام أو مشاركة شاشة iPhone كوظائف مكتملة.

## English description

Organize and play your own media with WudCar. Add M3U playlists, Xtream accounts and direct media URLs, or import videos selected from Photos and Files on iPhone. Imported copies are stored in the app for offline playback. Internet sources require connectivity and source availability.

Search, sort, favorite and resume media in your library. Native playback exposes available media controls and tracks. Import SRT/VTT captions for display on iPhone; these external captions do not transfer to AirPlay, CarPlay or Picture in Picture. External subtitle playback requires embedded source tracks.

WudCar also includes a browser, site shortcuts and control settings. Media can be sent through AirPlay to compatible devices. In-car video depends on vehicle and system support and current playback permission. Do not watch video while driving.

WudCar provides no channels, movies or IPTV content subscriptions and does not host content. Use only sources you are entitled to access. WudCar subscriptions unlock app features, not media subscriptions.

## App Review Notes — draft, fill verified device results before sending

This update adds an on-device media library and native AVPlayer playback to the existing WudCar app. It provides no bundled IPTV content. The default build requests only com.apple.developer.carplay-audio, following your prior rejection message. We are not claiming that adding a player or Cast requires both entitlements.

Test paths:
1. iPhone Home → Media library → Import from Files or Photos. Select several videos you own. Play one, seek, close and reopen to verify resume. Disable networking to test an imported copy.
2. Library → Add media URL. Add a reviewer-provided compatible URL; mark live only for a live source. Library → Channels/M3U/Xtream exposes the existing source setup.
3. Swipe a library item to favorite it. CarPlay's Library list reads the same library and includes Favorites and Continue watching.
4. Settings → Player settings controls skip interval, resume, autoplay, embedded subtitle preferences and phone-only external subtitle styling. Import SRT/VTT from the player's menu.
5. Use the native player's AirPlay picker with compatible equipment. CarPlay uses list/tab/Now Playing templates and CPPlaybackConfiguration where available. No intro video is played to open the browser.
6. Entertainment includes the existing browser and website shortcuts. Mouse access is in Settings → Player and controls. This behavior is identical for reviewers and users.

Outstanding before submission: attach an entitled test-source account or legally shareable test files, confirmed subscription review access, final signed-IPA audit, exact iOS/car/display results, and actual screenshots. The retained custom external browser path and user-disableable GPS browser pause setting require explicit review resolution; default-on alone does not establish compliance. DLNA receiving and whole-screen sharing are not implemented or advertised as working.

## Draft reply to rejection — do not send as a completed fix until validated

Hello App Review,

We are preparing WudCar 2.2.2 based on your feedback for submission 7a22f1f0-d832-4fdc-b1a8-bccaff712726. The candidate's default entitlement configuration retains CarPlay Audio and removes CarPlay Video. Separate entitlement combinations exist solely for controlled internal comparison, not as a claim that both are required.

The update adds a user-supplied media library and native playback. We removed the intro-video bootstrap previously used to request an external browser display. The app still includes browser functionality, which we will disclose in full. Please clarify whether the retained custom external-display browser path is permitted for this app category; we do not assume that placing its entry in a standard CarPlay template authorizes it.

We will provide the final build number, signed entitlement audit and physical-device playback results with the submission. We are not claiming completion of those tests in this draft.

Thank you.

## Screenshots required from the actual candidate

- Arabic and English library with user-owned test files, import progress, Favorites and Continue watching.
- Actual native playback controls and phone-only subtitle example.
- Player settings and existing Entertainment/browser.
- CarPlay Library and TV templates, with exact vehicle/display/iOS details retained in the internal evidence.

No fabricated store screenshots are included. Capture only after the candidate builds and runs; remove private URLs and account credentials from screenshots.
