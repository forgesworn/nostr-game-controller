Joystick real-time binding v2
=============================

This records the existing interoperable session binding used by the draft controller profile. It is not an allocated Nostr event kind and does not require controller players to have Nostr keys.

The host and controller connect to a mutually selected WSS broker with `v=2`, `r=host` / `r=phone`, and the exact session identifier `s`. Hosts then send `{"type":"host-join","hostToken":"<64 hex characters>"}` with a cryptographically random private credential. The reference SDK owns/reuses that credential privately; it must never appear in a QR, public Nostr event, controller link or catalogue. The broker refuses a competing host without the credential. Controllers send `{"type":"controller-join"}` or include their previous `resumeToken`. They receive an opaque per-player `resumeToken` for reconnecting; it is private and is not a public room code.

The game displays a controller URL such as `https://pad.forgesworn.dev/?s=ABCDEF&v=2&w=wss%3A%2F%2Fcontroller.pallasite.app%2F`. A native client can open `joystick://join` with the same query fields. Link parsers preserve the exact identifier and endpoint, reject duplicate/downgraded versions and insecure or credential-bearing endpoints, and ask the player to review the session before connecting. Bare six-character codes use the default broker, display as `ABC DEF`, and accept `ABCDEF`, `ABC DEF` or `ABC-DEF`; grouping is presentation only. Alternative broker links must retain their endpoint.

The broker admits controller peers using the room invitation and assigns player indices. The reference SDK emits `controller-spec`, `controller-feedback`, player join/suspend/resume/leave and session status messages; input is routed only from controller peers to the authenticated host, with broker-owned player index `p`. `k`/`v` input meanings are defined in the [profile proposal](NIP-XX-game-controllers.md). Hosts must enforce declared controls, numeric ranges, rate limits and stale-input neutralisation. Suspend/Leave/disconnect release continuous game state. Resume does not replay input held before the interruption.

Pairing grants control of this game session. Any Nostr remote signing capability requires its separate explicit authorisation and revocation journey. A controller profile, input frame, claimed public key or successful pairing is not a signing grant. The reference protocol tests cover this distinction.

Implementations and exact frame definitions live in `packages/protocol/src/index.ts`, `packages/host/src/index.ts`, `packages/mobile/src/index.ts` and `packages/broker/server.js`. The broker and clients are required to agree on v2; this draft does not specify automatic transport downgrade.
