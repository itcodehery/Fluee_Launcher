# Fluee Launcher (Flutter)

A minimal, high-performance Android home screen launcher built with **Flutter** and a lightweight Kotlin platform bridge.

## Running on your phone

Connect your phone with USB debugging enabled and run:

```nu
flutter run
```

To set it as your default launcher:
- Press the **Home** button and select **Fluee Launcher**, or
- Go to **Settings → Apps → Default apps → Home app → Fluee Launcher**.

## Features & Architecture

- **Interactive First-Run Intro Flow**:
  - Automatically welcomes the user on first launch with an interactive introduction to Fluee Launcher.
  - Step-by-step onboarding asking the user to choose their favorite accent color first, featuring a **live interactive dock preview** that updates in real time as colors are selected.
  - One-tap button to open Android's default home app settings.
- **Top Half**: Minimal `h:mm` clock (respects 12/24h system setting). Tap the clock to open system Alarms; long-press the empty top area to customize the accent color.
- **Bottom Half**: Drag handle + 4-column scrollable grid of all installed apps (`#2E2E2E` rounded square tiles with monochrome/greyscale glyphs). Rows fade smoothly as they slide beneath the dock. Drag the handle up (or tap it) to expand the grid to full screen; drag down or press Back/Home to collapse.
- **Dock**: Up to 4 pinned apps on customizable accent-colored tiles (`#3ECB8B` mint green by default), with automatic black/white icon contrast.
- **Long-Press App Actions**: Pin/unpin to dock, change accent color, open system App Info, or uninstall.
- **Accent Customization**: Choose from 12 color presets, Material You wallpaper color (Android 12+), or custom Hue/Saturation/Brightness sliders.
- **Robust App Loading**: Dual-layer package deduplication and fallback error handling ensuring rock-solid stability across OEM devices.
