# Nostr game controller protocol

An experimental open NIP proposal for game-defined phone controllers. Games describe sticks, buttons, portrait and landscape placement, colours, labels and small inline PNG graphics. Browser/PWA, iPhone/iPad and Android clients can render the same profile.

**Draft only:** no NIP number has been assigned. Event kind 30393 is a provisional candidate, not an allocation or reserved kind. Independent adoption and community review are needed before proposing upstream acceptance.

- [Draft NIP](NIP-XX-game-controllers.md)
- [Controller profile schema](controller-profile.schema.json) and [working example](examples/rocket-rally.json)
- [Real-time WSS binding](session-v2.md)
- [TypeScript reference](reference/src), [Swift core](reference/swift), [Kotlin core](reference/kotlin) and [shared fixtures](fixtures)

The reference validates layout/data limits and signed profiles, with publisher trust supplied by the caller. The browser module includes an opt-in publisher-game bridge that provides a standard virtual gamepad and preserves physical input. Its input channel is separate from Nostr signing and wallet authority.

```ts
import {controllerProfileFromEvent} from './dist/index.js';
import {verifyEvent} from 'nostr-tools';
const profile = controllerProfileFromEvent(event, trustedPublisher, gameId, verifyEvent);
```

A publisher game can use the browser reference with its own profile and explicitly pinned Arcade origins:

```ts
import {installArcadeGameController} from './dist/browser.js';
installArcadeGameController({allowedOrigins: ['https://arcade.600.wtf'], profile});
```

The game reads `navigator.getGamepads()`. The bridge neutralises controls if its channel becomes stale. A cabinet preload can consume the same profile announcement. Native Joystick clients currently receive selected profiles through their game session; they do not independently browse relays.

Run `npm ci && npm run typecheck && npm test`. These checks include shared valid/malformed profiles, layout fallback, code formatting and real NIP-01 signature/tampering verification. Swift and Kotlin cores use the same fixture data in the Joystick application suites. Runtime validation is required in addition to the structural JSON schema.

Joysticks, app artwork and store submissions are separate application work. This repository contains the protocol/reference code under MIT. No registry/NPM publication or NIP acceptance is claimed.
