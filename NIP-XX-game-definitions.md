NIP-XX: Gamestr game definitions
==============================

`draft` `optional` `proposed extension`

A game definition is the publisher's portable `game.json`: the game's identity,
launch URL, catalogue artwork, supported inputs, player limits, scoring contract,
requested capabilities, and optional phone controller presentation. The controller
profile is a section of this definition, not a separately published game identity.
This proposal is not adopted by gamestr.io or assigned an official NIP number.

The existing [Arcade manifest v2](game-definition.schema.json) is the starting
contract. The complete [Rocket Rally game definition](examples/rocket-rally-game.json)
illustrates it. Gamestr.io currently keeps its catalogue metadata in
[`GameMetadata`](https://github.com/teamgamestr/gamestr/blob/master/src/lib/gameConfig.ts)
and documents scores separately in its [game-score draft](https://github.com/teamgamestr/gamestr/blob/master/NIP.md).
Using this portable definition there requires an importer and upstream adoption;
publishing it does not make an unmodified client understand the extension.

One definition
--------------

```json
{
  "manifestVersion": 2,
  "gameId": "rocket-rally",
  "name": "Rocket Rally",
  "url": "https://play.example.com/rocket-rally",
  "players": {"min": 1, "max": 4},
  "inputModes": ["gamepad", "touch"],
  "scoreKind": 30762,
  "scoreDir": "desc",
  "capabilities": {"nostrSign": false, "walletPay": false},
  "controller": {
    "adapter": "native",
    "phoneProtocol": "gamestr-controller-v1",
    "profile": {
      "version": 1,
      "name": "Rocket Rally",
      "slots": {
        "joyL": {"mode": "xy", "label": "Steer"},
        "A": {"label": "Boost", "icon": "↑"}
      }
    }
  }
}
```

`gameId` identifies the game and its score stream. For public discovery it is
1–64 lowercase ASCII letters, digits or hyphens, beginning with a letter or digit.
`manifestVersion: 2` versions the definition. The nested `profile.version: 1`
versions its controller contract; these are independent of the live transport.

Catalogue metadata includes name, description/tagline, developer, genres,
`logoUrl` and `heroUrl`. The definition also carries `players`, `network`,
`inputModes`, `controlHints`, score kind/field/direction/authorities, and requested
capabilities. A declaration is not a signature, publisher trust, editorial
approval, controller compatibility certification, or signing/payment permission.
Local cabinet execution settings are operator configuration; accepting a public
manifest never authorises downloading or running an executable.

`controller.profile` contains sticks/buttons, labels, glyphs or bounded inline
PNG graphics, theme colours and portrait/landscape layouts. Its full rules and
semantic limits are in [the controller section](NIP-XX-game-controllers.md).
The standalone profile schema remains reusable by other game hosts.

The complete public definition is bounded to 65,536 UTF-8 bytes. Its controller
section retains the 49,152-byte profile and 32,768-character artwork limits.
Clients validate the complete definition with the schema and the profile with
its semantic validator. An invalid supplied profile is a definition error, not
permission to render a partial set of controls. A valid definition without a
phone profile remains usable by older/catalogue-only clients.

Publication over Nostr
----------------------

Arcade already publishes developer submissions using [NIP-89](https://github.com/nostr-protocol/nips/blob/master/89.md)
application-handler information (`kind: 31990`). Extend that existing record;
this proposal introduces no new event kind:

```json
{
  "kind": 31990,
  "tags": [
    ["d", "gamestr-game:rocket-rally"],
    ["k", "30762"],
    ["web", "https://play.example.com/rocket-rally"],
    ["t", "gamestr-game"],
    ["alt", "Gamestr game definition: Rocket Rally"]
  ],
  "content": "<metadata JSON with gamestr_manifest holding the complete game.json>",
  "pubkey": "<publisher public key>",
  "id": "<NIP-01 event id>",
  "sig": "<NIP-01 signature>",
  "created_at": 1791936000
}
```

The metadata content retains NIP-89's name/about/picture/website conventions;
`gamestr_manifest` is the proposed game-definition extension. `k` advertises the
handled score kind (currently 30762 or 5555 in the reference submission flow).
Scores remain separate game-score events; controller samples are not scores.

A reader pins the expected publisher and game identifier independently of relay
search results, verifies the NIP-01 event id/signature, checks one exact `d` tag,
the `gamestr-game` category, and agreement between the definition, URL and score-kind
tags, then validates the definition. Addressable-event ordering follows NIP-01.
A signed event proves authorship; a catalogue still needs its own trust policy.
The controller-section event reader deliberately returns only the validated
profile; it does not launch the game or grant any capability.

Static HTTPS hosting of the same `game.json` is useful for existing catalogues
and publisher builds. A catalogue may retain a reviewed cached copy. The publisher
file is the authoring source; the game code derives its controller defaults from
that file instead of maintaining another layout constant.

From definition to controller
-----------------------------

1. A catalogue reads the game definition to list and launch the chosen game.
2. Its host selects `controller.profile` and sends that section over the reviewed,
   authorised controller session. Joystick's PWA, iPhone/iPad and Android clients
   already render this same profile contract.
3. A compatible running game may supply a session-specific profile, for example
   lobby buttons followed by racing controls. It remains scoped to that active
   game; switching profile releases held input before applying it.
4. Input continues over the negotiated [live transport](session-v2.md), independently
   of Nostr discovery and identity/payment approval. No room code, resume credential,
   host secret or high-frequency input is published in the game definition.

The initial standalone controller-discovery candidate (`30393`) is superseded
for new Gamestr discovery. Its legacy reader is retained for compatibility with
early reference adopters; new definitions use the existing 31990 submission path.

Adoption
--------

The reference supplies the definition schema/example, TypeScript definition and
signed-event controller-section readers, and browser/Swift/Kotlin profile
implementations. Arcade's schema, publisher UI, public catalogue and cabinet
consume the same embedded profile. Gamestr.io integration is proposed, not claimed.
Independent implementation, publisher/discovery interoperability and community
review are still required before this extension becomes a shared standard.
