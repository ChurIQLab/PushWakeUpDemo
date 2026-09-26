# PushWakeUpDemo

**English** · [Русский](README.ru.md)

An iOS demo app showing how a call push notification (e.g. from an intercom) delivers
its data to the app and how the app gets "woken up".

The goal is the **wake-up mechanics**, not the call itself. SIP, video and door opening
are out of scope: once the app is awake and has the payload, regular call logic takes over.

There is very little material on this topic, so the code and docs are intentionally detailed.
Code comments are in Russian.

## Contents

- [Roadmap](#roadmap)
- [How regular pushes work](#how-regular-pushes-work)
- [Payload](#payload)
- [Project structure](#project-structure)
- [Setup](#setup)
- [Testing on the simulator without a server](#testing-on-the-simulator-without-a-server)
- [Testing on an iPhone via Firebase](#testing-on-an-iphone-via-firebase)
- [FAQ](#faq)

## Roadmap

| Stage | What it shows | Status |
|---|---|---|
| 1 | Regular push (Firebase): payload, banner while the app is open, tap → preview screen, cold start | ✅ |
| 2 | Push action buttons (Answer / Decline) and handling a swipe-to-dismiss | ⏳ |
| 3 | Modifying the push on the device: Notification Service Extension | ⏳ |
| 4 | VoIP push: PushKit + CallKit — waking the app without user interaction | ⏳ |
| 5 | Settings: VoIP on/off, notification permission status | ⏳ |

## How regular pushes work

Key point: **a regular push does not wake the app by itself.** Until the user taps it,
the app knows nothing about it (unless it was already open).

| Situation | What happens |
|---|---|
| Push arrives, app is **open** | iOS calls `willPresent` asking how to present it. The demo logs it and answers "show a banner". No screen is opened. |
| Push arrives, app is **in background or killed** | iOS shows the push itself. The app is not launched and knows nothing. |
| User **taps the push** | If the app was killed, iOS launches it (`didFinishLaunching`), then calls `didReceive` with the payload → the preview screen opens. |
| User opens the app **from its icon** | The push is not passed to the app — it stays in Notification Center. |
| Badge on the icon | Set by `"badge": 1`. It never clears itself — the app resets it when opened. |

```mermaid
sequenceDiagram
    participant S as Server
    participant F as Firebase (FCM)
    participant A as APNs
    participant I as iOS
    participant App as App
    S->>F: message (data + apns)
    F->>A: APNs push
    A->>I: push
    alt app is open
        I->>App: willPresent
        App-->>I: show banner
    else background or killed
        I->>I: shows the push itself
    end
    Note over I: user taps the push
    I->>App: launch (if it was killed)
    I->>App: didReceive(payload)
    App->>App: preview screen
```

See `PushWakeUpDemo/App/AppDelegate+NotificationHandling.swift` for the commented code.

## Payload

This is how the server sends the push via **FCM HTTP v1** (`POST https://fcm.googleapis.com/v1/projects/<project-id>/messages:send`):

```
payload = {
        "message": {
            "token": "?",
            "data": {
                "service_url": "?",
                "panele_id": "?",
                "asterisk_url": "?",
                "addr": "TEST",
                "rtsp": "?",
                "type": "sip_call",
                "token": "?",
                "call_id": "?"
            },
            "apns": {
                "payload": {
                    "aps": {
                        "alert": {
                            "title": "Ожидайте звонка",
                            "body": "Домофон: TEST",
                        },
                        "sound": "customSound.wav",
                        "category": "CALL_NOTIFICATION",
                        "badge" : 1,
                    },
                },
            },
        }
    }
```

- `message.token` — the device's FCM token.
- `data` — our fields. `type = sip_call` tells the app it's a call.
- `apns.payload.aps` — what iOS displays: text, sound, category, badge.

### What the app receives

Firebase turns `message` into a regular APNs push. In the app (`userInfo`) it looks like this —
**the `data` fields are at the root**, next to `aps`:

```json
{
  "aps": { "alert": { "title": "...", "body": "..." }, "sound": "customSound.wav", "category": "CALL_NOTIFICATION", "badge": 1 },
  "type": "sip_call",
  "addr": "TEST",
  "call_id": "...",
  "gcm.message_id": "..."
}
```

Parsing: `PushWakeUpDemo/Push/PushNotificationData.swift`. A missing field doesn't break
parsing (it will be empty).

`customSound.wav` lives in the app bundle (`Resources/Sounds`). iOS only takes push sounds
from the bundle or `Library/Sounds` — a sound in Assets.xcassets won't play.

## Project structure

```
PushWakeUpDemo/
├── App/
│   ├── AppDelegate.swift                        — launch, window, badge reset
│   ├── AppDelegate+PushRegistration.swift       — permission, APNs token → FCM token
│   └── AppDelegate+NotificationHandling.swift   — push arrived / push tapped
├── Push/
│   ├── PushNotificationData.swift               — payload model
│   ├── NotificationType.swift                   — the "type" field
│   └── FCMTokenStore.swift                      — latest FCM token
├── EventLog/
│   └── EventLog.swift                           — event log (survives relaunch)
├── Screens/
│   ├── Main/MainViewController.swift            — FCM token + event log
│   └── CallPreview/CallPreviewViewController.swift — screen opened by tapping the push
└── Resources/
    ├── GoogleService-Info.plist                 — ⚠️ not in git, add your own
    ├── PushWakeUpDemo.entitlements              — aps-environment (Push Notifications)
    ├── Info.plist                               — remote-notification background mode
    └── Sounds/customSound.wav
Scripts/payloads/sip_call.apns                   — push file for the simulator
```

The **event log** on the main screen shows every event and the app state at that moment:
`активно` (active), `неактивно` (inactive), `в фоне` (background), plus `холодный старт`
(cold start) if the process has just been launched. This shows exactly what woke the app.

## Setup

Requirements: Xcode 15+, iOS 15+. The only dependency is `FirebaseMessaging` (Swift Package Manager).

### 1. GoogleService-Info.plist

The file is **not in the repository** — everyone uses their own Firebase project.

1. [Firebase Console](https://console.firebase.google.com/) → create a project (or open yours).
2. Add an iOS app with bundle ID `com.churiqlab.PushWakeUpDemo`
   (or your own — then change *Bundle Identifier* in Xcode).
3. Download `GoogleService-Info.plist` and put it into `PushWakeUpDemo/Resources/`.

Without it the build fails with
`Build input file cannot be found: '.../PushWakeUpDemo/Resources/GoogleService-Info.plist'`.

### 2. Signing

Xcode → *PushWakeUpDemo* target → *Signing & Capabilities* → select your *Team*.
*Push Notifications* are already enabled (`aps-environment` in the entitlements).

## Testing on the simulator without a server

The simulator receives real pushes only on Apple Silicon Macs (iOS 16+), and not always:
in our test no APNs token arrived, so there was no FCM token either.
So on the simulator we deliver the push directly — it looks the same as after Firebase:

```bash
xcrun simctl push booted com.churiqlab.PushWakeUpDemo Scripts/payloads/sip_call.apns
```

Or just drag `Scripts/payloads/sip_call.apns` onto the simulator window.

1. **App is open.** Send the push → a banner appears, the log shows
   "Пуш пришёл при открытом приложении" (push arrived while open). No screen opens by itself.
2. **Tap the banner** → "Домофон: TEST" opens with the payload fields,
   the log shows "Нажали на пуш звонка" → "Экран предпросмотра показан".
3. **App is killed.** Close it via the app switcher (⌘⇧H twice → swipe up).
   Send the push → tap **the push** (banner or Notification Center — drag down from the top edge).
   Log: "Приложение запущено · холодный старт" → "Нажали на пуш звонка" → "Экран предпросмотра показан".
4. **Badge.** Send the app to background, send the push → "1" on the icon. Open the app → the badge is gone.

## Testing on an iPhone via Firebase

### Once: APNs key in Firebase

Firebase delivers the push to APNs itself, so it needs an Apple key.

1. [developer.apple.com](https://developer.apple.com/account/resources/authkeys/list) → *Certificates, IDs & Profiles* → *Keys* → **+**
   → enable **Apple Push Notifications service (APNs)** → *Continue* → *Register* → **Download**.
   The `.p8` file can be downloaded **only once** — keep it safe (and never commit it).
   Note the **Key ID** (same page) and your **Team ID** (top right of your account).
2. Firebase Console → ⚙️ *Project settings* → *Cloud Messaging* → *Apple app configuration*
   → *APNs Authentication Key* → **Upload**: the `.p8` file, Key ID, Team ID.

One `.p8` key works for all apps of the team and both environments (development and production).

### Sending

1. Run the app on an iPhone from Xcode, allow notifications.
2. Log: "APNs-токен получен" → "FCM-токен получен". Tap the token on the main screen to copy it.
   If you see "Ошибка регистрации в APNs" — check signing and *Push Notifications* in *Signing & Capabilities*.
3. **From the Firebase console (quick):** *Messaging* → *New campaign* → *Notifications* → title and text
   → **Send test message** → paste the FCM token.
   In *Additional options* → *Custom data* add `type` = `sip_call`, `addr` = `TEST`, `call_id` = `1`.
   The console can't set `category` or a custom sound — not needed for stage 1.
4. **Exactly like the server:** the full production payload can only be sent via the FCM HTTP v1 API
   with a service account OAuth token (*Project settings → Service accounts*).

## FAQ

**Why doesn't the app open the screen by itself when a push arrives?**
By design: a regular push doesn't wake the app. Only a VoIP push can wake the app
without user interaction (stage 4).

**I opened the app but there's no preview screen.**
You probably opened it from the icon — then the push isn't passed to the app. Tap the push itself.

**Why didn't the badge disappear before?**
It is set by `"badge": 1` in the payload and never clears itself. The app has to reset it —
now this happens in `applicationDidBecomeActive`.

**No FCM token on the simulator.**
An FCM token is issued only after an APNs token. The simulator gets an APNs token only on
Apple Silicon Macs (iOS 16+), and not always. If the log has no "APNs-токен получен", test
Firebase on a real iPhone and use `simctl push` on the simulator.
