# WudCar browser preview

Published privately on 2026-10-09:

- Phone interface: https://wudcar-live.vrcloud-971.chatgpt.site/app/
- Admin design: https://wudcar-live.vrcloud-971.chatgpt.site/admin-preview/
- Wide/compact theme preview: https://wudcar-live.vrcloud-971.chatgpt.site/preview/

Access uses the owner's ChatGPT account. There is no separate preview password. This publication does not create a Supabase administrator account or activate the production dashboard. The administration preview explicitly disables changes and saving. The connected Supabase account still had no project when checked.

The phone preview demonstrates navigation, preferred-name greeting, city and widget preferences, four theme periods, authorized HTTPS media and local browser file playback. Preferences and test media links stay in the browser. Native iPhone code remains in `ios/` and is run through Xcode.

Eight local checks passed after adding the preview, including preferred-name persistence and rejection of unsafe media URLs. Browser QA for this particular publication was unavailable in the Sites execution environment; publication success was confirmed by the hosting response.

Sites project: `appgprj_6ac8fd914f888191b06f8e130c796581`.
Published version: `appgprj_6ac8fd914f888191b06f8e130c796581~appgver_4337c79a55888191b07571ef41aaaeb6`.
Source commit in the Sites repository: `6222c97eed40f50af9fb4dfe12bd07ffedaf4521`.
GitHub implementation commit: `3c2ead510b3e584084957569a014f7a758247075`.

Keep the same private Site when updating the preview. Its checkout is `/workspace/sites/wudcar-live`; read `.openai/hosting.json` and use the Sites source helper for updates. Rebuild `dist` from the GitHub web source, then copy `index.html` into route entrypoint folders as used in this publication.
