# Final artwork and type

The final app contains an original anime-style illustration series with **three adult teammates**, a new duck-and-headphones App Icon, and bundled Montserrat fonts. The welcome illustrations contain no robot; robot annotations are retained only for hackathon venues on the map.

All four final raster assets were produced with the **built-in image generation tool**, inspected, copied into the project, and wired to the app. The icon was resized to 1024×1024 for the iOS asset catalog. The generated artwork is decorative and does not document an actual event or precise route.

| Asset | Project path | Standalone deliverable |
|---|---|---|
| Team / static system launch | `App/Assets.xcassets/LaunchTeam.imageset/LaunchTeam.png` | `Artwork/LaunchTeam.png` |
| Date planning | `App/Assets.xcassets/LaunchCalendar.imageset/LaunchCalendar.png` | `Artwork/LaunchCalendar.png` |
| Boston exploration | `App/Assets.xcassets/LaunchMap.imageset/LaunchMap.png` | `Artwork/LaunchMap.png` |
| App Icon | `App/Assets.xcassets/AppIcon.appiconset/AppIcon.png` | `Artwork/AppIcon.png` |

`WelcomeHero` is a compatibility alias of the final three-person team image. The static iOS launch screen uses `LaunchTeam`; the three-page SwiftUI introduction uses all three scenes. Montserrat comes from the official Google Fonts repository; its OFL license is bundled in `App/Fonts/OFL.txt`.

The colors combine the user's cool-blue Morandi palette with lavender for the start date and dusty pink for the end date. Navigation, list rows and SwiftData retain the classroom structure; the asset loading uses normal SwiftUI `Image` views.

## Final production prompts

### LaunchTeam

```text
Revise this welcome-screen anime illustration so there are EXACTLY THREE equally prominent young ADULT hackathon teammates collaborating at one laptop: two women and one man, diverse original character designs, all three faces clearly visible together in the central half of the composition. No robot. Keep the Boston Charles River setting, recognizable skyline, brownstones and bridge. Crisp contemporary anime ink outlines, refined cel shading and friendly expressions, muted Morandi slate blue, dusty lavender and powder pink, warm ivory. They wear stylish hoodies and headphones, collaborating enthusiastically. IMPORTANT app crop: all three heads and laptop should fit within a central square safe area so a near-square top hero crop shows all teammates; river and skyline behind. Portrait 4:5 overall, bottom15% fades pale blue/ivory for a rounded UI panel overlay. No words, symbols, letters, logo, watermark or UI. Polished production illustration.
```

### LaunchCalendar

```text
Create the SECOND welcome illustration in the SAME cohesive Boston hackathon anime illustration series as the reference. Theme: choosing time for a hackathon. Exactly THREE young ADULT teammates (same original two women and one man, hoodies and headphones) in a bright Boston studio, collaboratively planning on a large elegant physical desktop calendar and laptop. Show a subtle purple circular date highlight on the calendar's left page and a powder-pink date highlight on its right page, to symbolize start and end; no readable numbers or text. Through the window, Boston Charles River skyline/bridge. Crisp expressive anime lines and polished cel shading; muted Morandi blue, dusty lavender and powder pink, ivory light. Portrait4:5 art. Keep all three faces and planning props in the central square crop-safe region; bottom15% fades pale lavender/ivory for an app content panel. No robots, no words, no legible lettering, no logos, no watermark, no UI screenshot. Cohesive style and character identities with reference.
```

### LaunchMap

```text
Create the THIRD welcome illustration in the SAME Boston hackathon anime series as the reference, preserving exactly the same THREE young adult original teammates (two women and one man, stylish hoodies and headphones). Theme: exploring real Boston together to reach a hackathon. The three stand near the Charles River and point at a folded street map and smartphone with simple abstract location pins, no text. Around them are recognizable Boston brownstones, a bridge and skyline, a few little bronze-style ducklings on the park edge and a subtle red-brick strip suggesting Boston's Freedom Trail. Crisp expressive anime outlines and elegant cel shading. Muted Morandi slate blue, smoky lavender and powder pink, soft ivory sunlight. Portrait4:5 with ALLthreeheads/map in central square crop-safe area, Boston setting around them; bottom15% fades pale dusty-blue/ivory for app panel overlay. No robots, no words, no visible lettering, no logos, no watermark, no interface screenshot. Polished cohesive app onboarding art.
```

### App Icon

```text
Use case: logo-brand. Asset: iOS APP ICON, exactly square 1024x1024 composition, fully opaque edge-to-edge background, no pre-rounded corners because iOS applies its mask. Design a polished memorable minimal emblem for a Boston hackathon app: a friendly ivory/soft-gold duck head wearing over-ear coding headphones, framed by two clean code chevrons on either side. Subtle abstract Boston bridge arch suggested in the base of the emblem. Large bold simple shapes legible at tiny sizes, premium flat vector-like graphic with soft dimensional cel shading, consistent with a modern anime-inspired coding community brand, not photographic. Palette: muted Morandi deep slate blue #556A7F background with restrained dusty lavender and powder-pink headphone accents, warm ivory duck, dark navy outlines. Keep the main mark centered with generous safe margin. No words, no letters, no literal text, no watermark, no border, no phone or mockup, no extra scene. Icon must feel clean and native on an iPhone home screen.
```
