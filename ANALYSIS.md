# dotto+ 1.0.6 — Full Decompilation & iOS 17 Rebuild Analysis

Binary analyzed: `me.conorthedev.dotto.deb` (v1.0.6, built 2020, BigBoss-era).

Toolchain used: `ar`/`tar` extraction, `llvm-objdump`/`llvm-nm` (arm64 slice), Ghidra 11.0.3
headless (`/opt/ghidra`, all three binaries decompiled to `ghidra/out_*/`), raw disassembly
verification of every struct-return hook, and the MTACS iOS-17-Runtime-Headers dump
(pinned iOS 17.1 SpringBoardHome/SpringBoard headers) to verify every hooked selector
still exists on iOS 17.

## Package contents

| File | Purpose |
|---|---|
| `Library/MobileSubstrate/DynamicLibraries/dotto.dylib` | SpringBoard tweak (stripped, arm64+arm64e, ~5.9 KB text) |
| `Library/MobileSubstrate/DynamicLibraries/dotto.plist` | Filter: `com.apple.springboard` only |
| `usr/local/lib/libdottoplus.dylib` | Shared library: `DottoPreferences`, `RGBPixel`, UIColor/UIImage categories |
| `Library/PreferenceBundles/dottoPrefs.bundle/dottoPrefs` | Settings bundle (`DottoRootListController` + color cells) |
| `Library/PreferenceBundles/dottoPrefs.bundle/Root.plist` | Specifiers (Appearance / Color / Opacity) |
| `Library/PreferenceLoader/Preferences/dottoPrefs.plist` | Settings entry |
| `Library/Application Support/dotto/badges/{normal,circle}/SBBadgeBG@2x/@3x.png` | Template badge images (tinted at runtime) |

Original linkage: CydiaSubstrate (mobilesubstrate), libcolorpicker, libappearancecell
(both by the author), libdottoplus, UIKit/Foundation/CoreFoundation.
Build path in the prefs binary: `/home/dreamhopping/dotto-master/.theos/obj/arm64e/...`
(source was never published publicly).

Preferences domain: `me.conorthedev.dotto.prefs`. Darwin notification:
`me.conorthedev.dotto/ReloadPrefs`. Keys: `kEnabled`, `kAppearanceStyle`,
`kSelectedColor` (keyed-archived `UIColor` `NSData`), `kAdaptiveColor`,
`kUsePastelColor`, `kTransparency` (10–100).

---

## 1. dotto.dylib (SpringBoard tweak) — complete reconstruction

### 1.1 Constructor (`__mod_init_func`)

1. Creates global `NSMutableArray` badge registry (`DAT_83e0`).
2. `DottoPreferences.sharedInstance` (`DAT_83e8`) + `reloadPreferences`.
3. Registers C callback `DottoUpdateBadges` on the Darwin notify center for
   `me.conorthedev.dotto/ReloadPrefs`.
4. Adds three associated-object properties to `SBIconBadgeView` via
   `class_addProperty`/`class_addMethod`:
   - `dottoIsIconFolder` (BOOL, boxed `NSValue`, `OBJC_ASSOCIATION_RETAIN_NONATOMIC` = 1)
   - `dottoApplicationIcon` (`SBApplicationIcon *`, 3)
   - `dottoInfoProvider` (`SBIconView *`-typed, 3)
5. Hooks `SBIconBadgeView`: `init`, `_applyParallaxSettings`, `bounds`, `center`,
   `badgeSize`, `sizeThatFits:`, `intrinsicContentSize`,
   `intrinsicContentSizeForTextImage:`, `_resizeForTextImage:`,
   `_crossfadeToTextImage:animator:`, `_zoomInWithTextImage:animator:`,
   `layoutSubviews`, `configureAnimatedForIcon:infoProvider:animator:`,
   `configureForIcon:infoProvider:`, `dealloc` (`_sel_registerName`).
6. Adds new methods `dottoBadgeColour` (`@@:`) and `applyDotto` (`v@:`) to
   `SBIconBadgeView`.
7. Hooks `SBIconView`: `_frameForAccessoryView:` and `_centerForAccessoryView:`

`DottoUpdateBadges()`: `reloadPreferences` → enumerate registry → `applyDotto` on each.

### 1.2 Hook semantics (verified against raw arm64 disassembly)

| Hook | Enabled behavior | Disabled behavior |
|---|---|---|
| `init` | `%orig`, then add self to registry | same |
| `dealloc` | remove self from registry, `%orig` | same |
| `_applyParallaxSettings` | `%orig`, then `applyDotto` | same |
| `bounds` | `CGRectMake(0,0,26,26)` | `%orig` |
| `center` | `CGPointMake(58, 2)` (disasm: `fmov d1,#2.0`, `0x404d…`=58.0) | `%orig` |
| `badgeSize` | `CGSizeMake(26,26)` | `%orig` |
| `sizeThatFits:` | `return self.badgeSize` (26×26) | `%orig` |
| `intrinsicContentSize` | `return self.badgeSize` | `%orig` |
| `intrinsicContentSizeForTextImage:` | `CGSizeZero`, no `%orig` | `%orig` |
| `_resizeForTextImage:` / `_crossfadeToTextImage:animator:` / `_zoomInWithTextImage:animator:` | no-op, no `%orig` | `%orig` |
| `layoutSubviews` | `%orig`, then `applyDotto` | same |
| `configureAnimatedForIcon:infoProvider:animator:` | replaced by `configureForIcon:infoProvider:` (no animation) | `%orig` |
| `configureForIcon:infoProvider:` | `%orig`, store icon/provider in associated objects, `applyDotto` | `%orig` only |
| `SBIconView._frameForAccessoryView:` | `CGRectMake(0,0,26,26)` | `%orig` |
| `SBIconView._centerForAccessoryView` | `CGPointMake(58, 2)` | `%orig` |

### 1.3 `applyDotto` (new method) — exact algorithm

```
backgroundView = [self valueForKey:@"backgroundView"]
textView       = [self valueForKey:@"textView"]

if (!tweakEnabled):                       # stock restore
    if (iOS < 14.0): bg = [self valueForKey:@"backgroundImage"]
    else:           bg = [[self valueForKey:@"backgroundImageTuple"] image]
    [backgroundView setImage:bg]
    [textView setHidden:NO]; [textView setNeedsLayout]; [backgroundView setNeedsLayout]
else:
    path = (appearanceStyle != 0) ? circle/SBBadgeBG@3x.png : normal/SBBadgeBG@3x.png
    image = [[UIImage imageWithContentsOfFile:path] imageWithRenderingMode:AlwaysTemplate]
    [backgroundView setImage:image]
    colour = (adaptiveColorEnabled && !dottoIsIconFolder) ? [self dottoBadgeColour]
                                                          : [prefs dottoSelectedColour]
    if (pastelColorsEnabled) colour = [colour lighterColor]
    [backgroundView setTintColor:colour]
    [backgroundView setFrame:CGRectMake(0,0,26,26)]
    [backgroundView setCenter:CGPointMake(13,13)]
    [backgroundView setAlpha:[prefs transparency]]        # transparency() = value*0.01
    [textView setHidden:YES]
```

### 1.4 `dottoBadgeColour` (new method) — adaptive color algorithm

```
if [dottoApplicationIcon isKindOfClass:SBFolderIcon]              → dottoSelectedColour
if [dottoInfoProvider isKindOfClass:SBForceTouchAppIconInfoProvider] → dottoSelectedColour
imageView = [dottoInfoProvider valueForKey:@"iconImageView"]
if [imageView respondsToSelector:@selector(contentsImage)]:
    img = [imageView contentsImage]
    if img: return [img dottoAverageColor]
return dottoSelectedColour
```

Notes from disassembly:
- `dottoIsIconFolder`'s setter is **never called anywhere** — the property is dead
  (always NO); folder handling relies on the `SBFolderIcon` check above.
- `_frameForAccessoryView:` is **gone on iOS 17** (removed from `SBIconView`);
  `_centerForAccessoryView` still exists. Rebuild drops the dead hook and adds the
  iOS 17 positioning-protocol hook `accessoryCenterForIconBounds:` (same value).

---

## 2. libdottoplus.dylib — complete reconstruction

### 2.1 `DottoPreferences` (singleton)

- `sharedInstance` — `dispatch_once`.
- `reloadPreferences` — `CFPreferencesAppSynchronize`; if `NSHomeDirectory() !=
  /var/mobile` (legacy rootless containers) read the plist file directly from
  `/var/mobile/Library/Preferences/me.conorthedev.dotto.prefs.plist`, else
  `CFPreferencesCopyKeyList`/`CopyMultiple`.
- `writeValue:forKey:` — `CFPreferencesSetValue(domain=me.conorthedev.dotto.prefs,
  user=mobile, anyHost)` → post Darwin `me.conorthedev.dotto/ReloadPrefs` →
  `reloadPreferences`.
- Accessors (defaults in parentheses):
  - `tweakEnabled` — `kEnabled` (**YES** when missing)
  - `adaptiveColorEnabled` — `kAdaptiveColor` (**YES** when missing)
  - `pastelColorsEnabled` — `kUsePastelColor` (**NO** when missing)
  - `appearanceStyle` — `kAppearanceStyle` (**0** when missing; 1 = "dotto O's")
  - `transparency` — `kTransparency` (**100.0**, then × 0.01 → alpha)
  - `dottoSelectedColour` — `kSelectedColor` (`NSKeyedUnarchiver` from `NSData`);
    default `UIColor(red:232/255, green:53/255, blue:83/255)` = **#E83553**
    (constants `0x3fed1d1d1d1d1d1d`, `0x3fca9a9a9a9a9a9b`, `0x3fd4d4d4d4d4d4d5`).

### 2.2 `RGBPixel` — `r`, `g`, `b`, `d` (`int`) properties. `d` = dominance count.

### 2.3 `UIColor` category

- `lighterColor`: `colorWithHue:saturation:brightness:MIN(b*2, 1):alpha:` (nil if
  `getHue:…` fails — e.g. dynamic colors).
- `darkerColor`: same with `brightness * 0.75`.
- `pastelColor`: `(r+1)/3, (g+1)/3, (b+1)/3` (keeps alpha).

### 2.4 `UIImage` category — `dottoAverageColor` (dominant-color picker)

```
1. Downsample: if width*height > 2000:
       ratio = width/height
       width  = sqrt(ratio*2000);  height = 2000/sqrt(ratio*2000)   (ints)
2. Render into CGBitmapContext (RGBA premultiplied-last, 8bpc, bytesPerRow = w*4)
3. For every pixel with alpha >= 128 (signed check: alpha byte < 0):
       RGBPixel *p = {r,g,b}
       if any existing cluster pixel has manhattan distance (|Δr|+|Δg|+|Δb|) < 27:
           average the channel values into the cluster, d += 1   (merge)
       else: append new pixel
4. Sort by d descending; take first two.
   If count < 2 → [UIColor redColor]
5. If second.d > first.d * 0.125 AND (s2 + b2*0.5) > (s1 + b1*0.5) → return second
   (a meaningfully-present, lighter/more-saturated runner-up wins)
   else return first
```

Also `dottoColourDistance:andB:` — Manhattan distance between two `RGBPixel`s.

---

## 3. dottoPrefs (Settings bundle) — complete reconstruction

### 3.1 `DottoRootListController : PSListController`

- `init`: `preferences = DottoPreferences.sharedInstance` (+ `reloadPreferences`);
  nav-bar right item = `UISwitch` frame `(0,0,51,30)`, on = `tweakEnabled`,
  target `switchToggled:` (→ `writeValue:@(isOn) forKey:@"kEnabled"`).
- `specifiers`: `loadSpecifiersFromPlistName:@"Root"`.
- `setPreferenceValue:specifier:` / `readPreferenceValue:`: when the specifier key
  is `kAdaptiveColor`, sets row `(2, 0)` enabled = `!value` via
  `setCellForRowAtIndexPath:enabled:` (userInteractionEnabled + alpha
  `0.439216`/`1.0`). (Quirk preserved from the binary: row 2 is the adaptive switch
  itself.)

### 3.2 `DottoColorSelectionTableCell : PSTableCell` — the "Color" cell (height 90)

- Two `DottoColorRowStackView`s (first row: 6 colors; second row: 5 colors + clear
  "picker" swatch) inside a vertical `UIStackView` (spacing 10), centered,
  `preferredHeightForWidth:` = **90.0**.
- `updateCircles`: for every swatch, show/remove the 2.5pt white-outline border
  according to the current `_selectedColor` (custom-color picker swatch is outlined
  whenever the selected color ∉ the 11 standard colors).
- The 11 standard colors (decoded from `__const`):
  `#E83553, #FF3B30, #FF9500, #FFCC00, #34C759, #5AC8FA, #007AFF, #AF52DE,
  #FF2D55, white, #111111`. Second row adds `clearColor` (picker).

### 3.3 `DottoColorRowStackView : UIStackView`

- `initWithColors:forController:`: stores a lazily-created
  `UIColorPickerViewController` (`NSClassFromString`) for the host; sets the global
  11-color `_standardColors`; axis horizontal, alignment center, spacing
  `screenWidth/6.0 - 30.0` (verified in disasm: `bounds.width / 6 - 30`);
  30×30 item swatches with width/height constraints; `centerXAnchor` self-pin
  (inert); `heightAnchor` 30.
- `updateCircles` → forwards to host controller (the cell).

### 3.4 `DottoColorItemView : UIView` — 30×30 rounded swatch (cornerRadius 15)

- `initWithColor:forController:`:
  - color == `clearColor` → shows `colourpicker.png` (30×30, aspect-fit), tap →
    `showColorPicker:`; type = 1. Outline shown iff selected color ∉ standard colors.
  - otherwise → filled with the color; if color == `dottoSelectedColour`, adds a
    2.5pt white outline (`(2.5,2.5,25,25)`, cornerRadius 12.5, border 2.5); main
    border = `labelColor` (iOS 13+) or `blackColor` (< 13) at alpha 0.2, width
    0.75; tap → `buttonTapped:`; type = 0.
- `buttonTapped:` → archive `self.color` → `writeValue:forKey:@"kSelectedColor"` →
  `_selectedColor = color` → `[hostController updateCircles]`.
- `showColorPicker:` — iOS ≥ 14: `UIColorPickerViewController` (delegate =
  self, `selectedColor` = current), presented from `keyWindow.rootViewController`;
  iOS < 14: `PFColorAlert` (libcolorpicker). Selection handling normalizes the
  color via `hexFromColor:` → `LCPParseColorString(_, @"#E83553")`, archives, and
  `updateCircles`.

### 3.5 `AppearanceSelectionTableCell` (from `libappearancecell`)

Not part of the deb (external dependency). The cell displays the two appearance
options (`dotto` / `dotto O's` with `__dotto_ignore_normal` / `__dotto_ignore_circle`
images) and persists `kAppearanceStyle` (0/1). Reimplemented in-bundle for the
rebuild (`DottoAppearanceSelectionTableCell`) to remove the external dependency.

---

## 4. iOS 17 compatibility audit (against iOS 17.1 runtime headers)

| Hook/access | iOS 17 status |
|---|---|
| `SBIconBadgeView` hooks (all 15 listed above) | **all present** (SpringBoardHome) |
| `_backgroundView` / `_textView` ivars (KVC) | **present** (`SBDarkeningImageView *`, `UIImageView *`) |
| `SBIconView._frameForAccessoryView:` | **REMOVED** — dropped in rebuild |
| `SBIconView._centerForAccessoryView` | **present** — kept |
| `accessoryCenterForIconBounds:` (protocol) | **present** — added to rebuild for deterministic iOS 17 positioning |
| `iconImageView` KVC on provider (`SBIconView._iconImageView`) | **present** |
| `contentsImage` on `SBIconImageView` | **present** |
| `SBForceTouchAppIconInfoProvider` / `SBFolderIcon` / `SBApplicationIcon` | **present** |
| `backgroundImageTuple` KVC (restore path) | **REMOVED** — would throw `NSUndefinedKeyException` on iOS 17; rebuild uses a captured stock-image restore instead |
| `UIColorPickerViewController` | **present** (iOS 14+) — replaces `PFColorAlert`/libcolorpicker |
| Preferences framework (`PSListController`/`PSTableCell`) | **present** |

Rebuild substitutions:
1. `CydiaSubstrate` → **ellekit** (Dopamine standard; theos auto-links substrate shim).
2. `CFPreferences` plumbing → **`NSUserDefaults` suite `me.conorthedev.dotto.prefs`**
   (same domain/plist via cfprefsd; works identically in SpringBoard and Settings).
3. `libcolorpicker` → **native `UIColorPickerViewController`** + in-bundle hex
   normalization (iOS < 14 path dropped; target is iOS 17).
4. `libappearancecell` → **in-bundle `DottoAppearanceSelectionTableCell`**.
5. `_frameForAccessoryView:` hook → removed; `accessoryCenterForIconBounds:` hook
   added (returns the same `(58, 2)`).
6. Stock-restore path → captured-stock-image restore (iOS 17-safe).
7. Paths: resources at `Library/Application Support/dotto/...` resolve on
   rootless via ellekit's `/var/jb` remap (same layout as the original deb).
8. Package scheme: **roothide** (`THEOS_PACKAGE_SCHEME = roothide`), arm64e,
   `Depends: ellekit, preferenceloader, firmware (>= 17.0)`.

## 5. Geometry

iPhone icon grid (measured on-device, iOS 17.1.1): home icons 60 pt (pitch 90),
dock 64 pt. Original badge geometry (26×26 badge, center (58,2) → frame (45,-11)
on a 60 pt icon) intentionally reproduces the dotto look: a dot hanging off the
icon's top-right corner (`SBIconView` does not clip subviews).
