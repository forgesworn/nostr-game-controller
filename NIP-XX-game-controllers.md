NIP-XX: Declarative game controllers
===================================

`draft` `optional`

This is an experimental proposal, published for interoperability review. No NIP number has been assigned. Kind **30393 is a provisional candidate**, not an allocation; deployments must agree on a kind and migrate if review assigns another. Registry checks do not reserve a kind.

A game describes the controls it needs and their presentation. A player can use any compatible controller client: browser/PWA, iPhone, iPad, Android or another implementation. The game interprets the inputs; the controller renders declarative data. Profiles do not contain executable code, player identities, private pairing credentials or signing grants.

Public profile discovery
------------------------

A publisher MAY publish a NIP-01 signed addressable event:

```json
{
  "kind": 30393,
  "created_at": 1791936000,
  "tags": [
    ["d", "rocket-rally"],
    ["protocol", "nostr-game-controller", "1"]
  ],
  "content": "<JSON controller profile>",
  "pubkey": "<publisher public key>",
  "id": "<NIP-01 event id>",
  "sig": "<NIP-01 signature>"
}
```

`d` MUST appear exactly once and identify the game using 1–128 lowercase ASCII letters, digits, dots, underscores or hyphens, beginning with a letter or digit. `protocol` MUST appear exactly once with the values above. A catalogue or game pins the expected publisher and game identifier independently of relay search results. Clients MUST verify the event id and signature, kind, publisher, identifier and protocol before using the content. Select the latest valid event for that address using NIP-01 addressable-event ordering. A signature establishes authorship; it does not establish that a publisher or game is trusted.

Profiles can also be supplied directly by a game over its already-authorised controller session. Session-specific labels may differ from the published default. The public event advertises the profile, never a live session token or host credential. Private application data in NIP-78 is not the discovery mechanism for this interoperable profile.

Profile
-------

The complete working example is [Rocket Rally](examples/rocket-rally.json); the structural schema is [controller-profile.schema.json](controller-profile.schema.json). Implementations MUST also enforce the semantic limits below.

```json
{
  "version": 1,
  "name": "Rocket Rally",
  "theme": {"background": "#080B22", "accent": "#b48cff"},
  "slots": {
    "joyL": {"mode": "xy", "label": "Steer"},
    "A": {"label": "Boost", "icon": "↑", "colour": "#ffc975"}
  },
  "layout": {
    "version": 1,
    "portrait": {
      "joyL": {"x": 0.24, "y": 0.78, "size": 144},
      "A": {"x": 0.78, "y": 0.8, "size": 72}
    },
    "landscape": {
      "joyL": {"x": 0.16, "y": 0.68, "size": 144},
      "A": {"x": 0.86, "y": 0.7, "size": 72}
    }
  }
}
```

The known slots are `joyL`, `joyR`, `A`, `B`, `X`, `Y`, `L1`, `L2`, `R1`, `R2`, `start`, `select`, `dpadU`, `dpadD`, `dpadL`, `dpadR`. Omitted slots are not rendered. A profile MUST contain `version: 1`, a name of at most 128 UTF-16 code units and a slots object with at most 16 known slots. Each slot can specify a label (48 code units), a text glyph/icon (64), a colour, stick mode and `tapAction` identifying a known slot. Colours MUST be `#RGB` or `#RRGGBB`. Default stick mode is `heading`. Button slots emit binary input regardless of mode metadata.

For bespoke artwork, `graphic: {"png": "<base64 PNG>"}` replaces the glyph or stick knob artwork. A graphic MUST be an inline PNG with width and height from 1 to 256 pixels and at most 12,288 base64 characters, including padding. Total artwork across a profile MUST not exceed 32,768 characters. Clients MUST check the PNG signature, IHDR and dimensions before decoding, and retain the text label when decoding fails. Remote URLs, SVG, HTML, fonts and scripts are not supported. This avoids tracking requests and executable artwork. Graphics are decorative; the label remains the accessible control name.

The complete profile MUST fit in 49,152 UTF-8 bytes. Unknown extension fields MAY be ignored within that limit. Unknown versions, slots, modes, invalid known fields or oversized profiles MUST be rejected. Keep the last valid controls or stop the session safely; do not render partially parsed controls.

Layouts
-------

`layout` is optional. If present it has `version: 1` and at least one orientation map. Every supplied map MUST place every declared slot exactly once. A missing map uses the client's default ergonomic layout with every declared control retained.

`x` and `y` are normalised control centres in the usable controller surface, excluding safe-area insets, pairing/status/permission UI and the client's motion toolbar. Coordinates range from zero to one. Orientation is **landscape when that surface is wider than it is tall**, otherwise portrait. `size` is the circle diameter or rounded-square side in CSS pixels, iOS points or Android dp: 48–192 for buttons and 96–192 for sticks. `shape` defaults to `circle`, or can be `rounded`. Clients clamp the size to the surface and centres to leave a four-unit inset.

A stick can additionally have a floating capture `zone: {"x":0,"y":0.28,"width":0.52,"height":0.72}`. The zone origin/extent are normalised to the same surface; extents are 0.1–1 and the rectangle must fit inside it. The declared stick centre must lie in the zone. Without a zone the stick's square bounds are its capture area. Buttons have hit priority over stick areas; each pointer owns one control and simultaneous sticks/buttons work independently. Two stick capture areas must not overlap. Overlapping button bounds, or a clamped stick centre outside its zone, require default-layout fallback for that viewport. Clients must retain every action, never silently omit a conflicting control. A surface smaller than 200 by 160 units cannot render this profile layout.

A resize, rotation, profile replacement, background, disconnect or Leave MUST neutralise held input before applying new geometry. A game cannot hide the client's pairing review, Leave, permission controls or accessibility labels. Players MAY override visual layout/size for reach and accessibility; the input slot contract is unchanged.

Touch and motion
----------------

Touch remains available for every stick. `tilt` requests a motion-friendly presentation; motion still requires an explicit player choice and any platform permission. A player MAY use motion for `heading` or `xy` too. Motion is calibrated to the initial comfortable hold, mapped into screen coordinates for both landscape orientations, and recentred after rotation. Missing sensors, denied permission and stale samples must return safely to touch with neutral input. A game cannot request background sensor access through this profile.

Live input binding
------------------

Nostr distributes signed profiles; frame delivery is a negotiated real-time transport. The current interoperable reference binding is the Joystick version-2 WSS session, documented in [session-v2.md](session-v2.md). No Nostr event kind is assigned for high-frequency pointer samples in this draft. Other transports can adopt the same slot/input contract and explicitly negotiate their own lifecycle.

The host sends `{"type":"controller-spec","spec":<profile>}`. Controllers send string-valued slot frames `{"k":"A","v":"1"}` / `"0"`. `xy` sticks send `<slot>-x` and `<slot>-y`, integers in [-1000,1000], with right/down positive. Heading and tilt send the slot name with heading in radians × 1000, using `atan2(down,right)`, in [-3142,3142]. All sticks also send `<slot>-thrust` (`"0"`/`"1"`), `<slot>-power` (0–1000), `<slot>-end` (`"1"`) and optional `<slot>-tap` (`"1"` for a short tap configured by `tapAction`). A tap frame is a one-shot hint; the game maps it to the configured action.

Neutral means thrust/power zero, end one, and both axes zero for `xy`. Button release is zero. Hosts must reject undeclared slot input, clamp/range-check values, and expire stale continuous state. Reconnect is a new neutral baseline, never replay of a previously held input. Reference clients sample continuous movement at up to 20 Hz; hosts must not assume a fixed frame rate or use a stream as a liveness credential.

Compatibility and adoption
---------------------------

Layout, theme and graphics are additive to the existing version-1 ControllerSpec. Older clients can ignore them and keep their default controls; they may still reject a mode they do not support. A transport version is separate from a profile version. Future required behaviour needs a new profile version; optional extensions cannot change slot meanings.

Reference implementations: TypeScript validator/event adapter and browser renderer, Swift/iOS core and renderer, Kotlin/Android core and renderer, with shared malformed/valid profile and geometry fixtures. The event adapter requires the caller's NIP-01 signature verifier and trusted publisher. Native clients currently receive the selected profile through the game session; they do not independently browse relays.

Before proposing upstream acceptance: obtain an independent interoperating implementation, exercise signed publisher discovery and cross-client gameplay, agree on kind allocation and extension/transport negotiation, and invite community review. This repository is a working draft, not an accepted NIP.

Primary references: [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md), [NIP-78](https://github.com/nostr-protocol/nips/blob/master/78.md), [NIP acceptance criteria](https://github.com/nostr-protocol/nips#criteria-for-acceptance-of-nips).
