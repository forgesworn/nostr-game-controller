# Gamestr game definitions and portable controllers

The proposed standard is one publisher-owned `game.json`: identity, launch URL,
artwork, players, scoring, capabilities and `controller.profile`. Joystick is a
consumer of that controller section. The publisher game and catalogue read the
same definition, instead of maintaining a separate controller-discovery identity.

- [Game definition proposal](NIP-XX-game-definitions.md), [schema](game-definition.schema.json) and [complete example](examples/rocket-rally-game.json).
- [Controller section](NIP-XX-game-controllers.md), [schema](controller-profile.schema.json) and [profile example](examples/rocket-rally.json).
- [Live session binding](session-v2.md); high-frequency input and private pairing credentials are not published on Nostr.

The reference extends Arcade's existing NIP-89 kind-31990 game submission. It
introduces no new discovery event kind. The initial standalone kind-30393 draft
is superseded for new Gamestr discovery; legacy readers remain for compatibility.
This game-definition extension is proposed, not an accepted NIP or a claim that
unmodified gamestr.io already imports it. Its present metadata registry is
[GameMetadata](https://github.com/teamgamestr/gamestr/blob/master/src/lib/gameConfig.ts).

## Reference

TypeScript exports `controllerProfileFromGameDefinition` and
`controllerProfileFromGameDefinitionEvent`. They extract the validated controller
section; the complete definition schema, publisher trust and catalogue launch
policy remain necessary. Signed discovery pins the independently trusted publisher,
game ID, signature, URL and score-kind tags. Signatures do not grant wallet or
signing permission. Browser, Swift and Kotlin render the same bounded profile.

```sh
npm ci
npm run check
```

Use the MIT-licensed tarball attached to the draft release directly. No npm
registry publication is claimed. Package entry points are the shared types/readers
and `@forgesworn/nostr-game-controller/browser` for the explicit publisher input
bridge. Native reference sources and shared fixtures are included in this repo.
Independent implementations and upstream review are needed for standard adoption.
