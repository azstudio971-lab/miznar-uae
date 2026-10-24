# Mandatory subscription correction — 2026-10-24

This instruction supersedes all earlier subscription changes and the earlier authorization to alter SubscriptionTests. The four protected subscription files are byte-identical to 6ca24bc877495dbaed55ff2aa833e687fa4e058f. The storeKitConfiguration entry in project.yml already matches that baseline and remains unchanged. No new product, plan, free limit or access-policy file is introduced.

LegalTextView now shows descriptive subscription terms only: no product name, live product data, price or separate subscription logic. SubscriptionView is unchanged. Library continues to use the existing SubscriptionGate and shared hasAccess.

Required command:
```sh
git diff --stat 6ca24bc -- WdCar/Shared/SubscriptionStore.swift WdCar/Phone/SubscriptionView.swift WdCarTests/SubscriptionTests.swift WdCarTests/WudCar.storekit
```
Output: empty.

The previous SubscriptionTests environment-skip modification has been removed. Historical results (35 passed / 4 skipped) describe the previous source only and do not validate the restored original SubscriptionTests. The original tests have NOT been rerun on macOS; their success cannot currently be claimed. Linux has no Xcode, and the last observed Codemagic account had exhausted build minutes. No test skip or weakening was added to the original SubscriptionTests.

The generated CI Test plan still binds the unchanged local StoreKit fixture to the Test action; it does not modify project.yml or the protected source files. A fresh native run must pass the original SubscriptionTests before subscription validation is reported as complete.
