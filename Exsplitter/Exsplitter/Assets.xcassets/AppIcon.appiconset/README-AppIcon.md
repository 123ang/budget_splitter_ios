# Exsplitter App Icon — Manual Setup

You don’t have an icon yet. Follow these steps to add one so archiving and App Store upload work.

---

## Step 1 — Create one source image (1024×1024)

You need **one square image**:

- **Size:** 1024×1024 pixels  
- **Format:** PNG  
- **Color:** sRGB, no transparency (fully opaque)  
- **Shape:** Square (Apple adds rounded corners)

**Ways to get it:**

- Design in Figma/Sketch/Canva and export 1024×1024 PNG.  
- Use a free icon/logo generator (e.g. look for “app icon generator” or “logo maker”).  
- Use a simple placeholder (e.g. solid color + “Exsplitter” text) until you have a final logo.

---

## Step 2 — Generate all icon sizes (easiest)

Don’t resize by hand. Use a generator:

1. **Option A — App Icon Generator (recommended)**  
   - Open: **[appicon.co](https://appicon.co)** or search “App Icon Generator iOS 1024”.  
   - Upload your 1024×1024 PNG.  
   - Download the generated **iOS** set (zip).  
   - Unzip. You’ll get a folder with many PNGs (e.g. `Icon-App-60x60@2x.png`, `Icon-App-76x76@2x.png`, …).

2. **Option B — Xcode “Single Size” (if your Xcode supports it)**  
   - In **Assets.xcassets → AppIcon**, some Xcode versions let you drag **only** a 1024×1024 image into the “App Store” slot.  
   - If that option is there, you can use it and skip generating other sizes.  
   - If archive/upload still complains about 120×120 or 152×152, use Option A instead.

---

## Step 3 — Put the PNGs into this folder

1. Open your project in Xcode.  
2. In the Project Navigator: **Exsplitter → Assets.xcassets → AppIcon**.  
3. The generator usually gives filenames like:
   - `Icon-App-20x20@2x.png`
   - `Icon-App-60x60@2x.png`  ← **120×120 (required)**
   - `Icon-App-60x60@3x.png`  ← **180×180 (required)**
   - `Icon-App-76x76@2x.png`  ← **152×152 (required)**
   - `Icon-App-1024x1024.png` ← **1024×1024 (App Store, required)**
4. **Drag all generated PNGs** from the generator’s folder into the **AppIcon** set in Xcode (the same place where you see this README).  
5. If the generator uses different names, either:
   - Rename the files to match `Contents.json` (e.g. `Icon-App-60x60@2x.png`), or  
   - In Xcode, drag each image onto the correct slot (e.g. “iPhone App 60pt 2x”) and Xcode will use it.

**Minimum to fix the archive error:**  
At least provide:

- **120×120** (iPhone 60pt @2x)  
- **152×152** (iPad 76pt @2x)  
- **180×180** (iPhone 60pt @3x)  
- **1024×1024** (App Store)

---

## Step 4 — Check target and plist (already done for you)

These are already set in the project:

- **Target → General → App Icons and Launch Screen → App Icon:** `AppIcon`  
- **Build Settings → Asset Catalog App Icon Set Name:** `AppIcon`  
- **Info.plist (generated):** `CFBundleIconName` = `AppIcon`

You don’t need to change anything here unless you use a different asset name.

---

## Step 5 — Clean and archive again

1. **Clean:** `Shift + Cmd + K` (Product → Clean Build Folder).  
2. **Archive:** Product → Archive.  
3. **Upload:** Window → Organizer → Distribute App → App Store Connect → Upload.

---

## Quick checklist before upload

- [ ] At least one 1024×1024 PNG exists and is in the AppIcon set (App Store slot).  
- [ ] 120×120 and 152×152 (and ideally 180×180) are present in the AppIcon set.  
- [ ] All icon images are PNG, sRGB, no transparency.  
- [ ] App Icon in target is set to **AppIcon** (already done).  
- [ ] Clean + Archive + Upload.

Once you have the 1024×1024 image and the generated set in **AppIcon**, the “missing icon sizes” and “CFBundleIconName” issues should be resolved.
