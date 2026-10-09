# WudCar 1.1.1

رفيق مشاويرك — iPhone source, interactive phone/car design preview and connected administration.

- Preview: https://wudcar.netlify.app/
- Admin Studio: https://wudcar.netlify.app/admin
- Xcode project: `ios/WudCar.xcodeproj`
- Current requirements and activation: [docs/RELEASE-1.1.1.md](docs/RELEASE-1.1.1.md)

```sh
npm ci
npm run check
npm run dev
python3 scripts/generate_xcode.py
```

The approved WudCar logo and Spirit of the UAE artwork remain the source assets. Previous implementation documents are replaced by the versioned release document. History remains available through Git.

Public Supabase configuration is included. Administrator credentials and APNs private keys are **not** committed. Accounts and administrator roles are verified server-side; no local password gate is used.

The website car dashboard is a design preview. Native CarPlay uses Apple's audio templates once the entitlement is approved. Arbitrary web browsing/custom system wallpaper in CarPlay is not implemented or promised. Video uses native AVPlayer/AirPlay; in-car availability depends on supported Apple/vehicle capabilities. Payments remain disabled until App Store setup and server transaction verification are completed.
