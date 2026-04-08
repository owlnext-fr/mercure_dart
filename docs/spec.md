# mercure_dart

Implémentation from-scratch du protocole Mercure (https://mercure.rocks/spec) en Dart pur.
Zéro dépendance externe. Multi-plateforme : mobile, desktop, server (dart:io) et web (dart:html/EventSource natif).
Conditional imports pour la couche transport — le parsing SSE et les modèles sont du pur Dart partagé.

## Spec de référence

La spec complète est à https://mercure.rocks/spec — elle fait autorité sur tout ce document.
En cas de doute, la spec prime.

## Structure du package

```
lib/
  mercure.dart                          # barrel export
  src/
    auth/
      mercure_auth.dart                 # sealed class : Bearer | Cookie | QueryParam
    models/
      mercure_event.dart                # event SSE parsé (id, type, data, retry)
      publish_options.dart              # params du POST publish (topics, data, private, id, type, retry)
      subscription_info.dart            # objet JSON-LD de la Subscription API
    sse/
      sse_parser.dart                   # StreamTransformer<String, MercureEvent> — pur Dart, partagé
      sse_line_decoder.dart             # StreamTransformer<List<int>, String> — pur Dart, partagé
    transport/
      mercure_transport.dart            # interface abstraite (subscribe stream + publish + discovery)
      mercure_transport_stub.dart       # stub qui throw — import par défaut si aucune plateforme matchée
      mercure_transport_io.dart         # implem dart:io (HttpClient, gestion manuelle SSE + reconnexion)
      mercure_transport_web.dart        # implem dart:html (EventSource natif + fetch pour publish)
      mercure_transport_factory.dart    # conditional import : export stub if (dart.library.io) io if (dart.library.html) web
    subscriber/
      mercure_subscriber.dart           # façade : délègue au transport, expose Stream<MercureEvent>
    publisher/
      mercure_publisher.dart            # façade : délègue au transport, expose publish()
    discovery/
      mercure_discovery.dart            # parse les Link headers — délègue le GET au transport
    subscriptions_api/
      mercure_subscriptions_api.dart    # GET subscriptions — délègue le GET au transport
test/
  unit/                                 # tests purs sans I/O réseau
  integration/                          # tests contre un vrai hub Mercure Docker (dart:io uniquement)
  helpers/
    hub.dart                            # helper pour start/stop le hub Docker + génération JWT
```

## Modules — contrat de chaque composant

### Auth (`mercure_auth.dart`)

Sealed class avec 3 variantes : `Bearer(String token)`, `Cookie(String value, {String name = 'mercureAuthorization'})`, `QueryParam(String token)`.
Priorité spec : header Authorization > query param `authorization` > cookie.
Pur Dart, pas de dépendance plateforme — c'est le transport qui applique l'auth sur la requête.

### SSE Line Decoder (`sse/sse_line_decoder.dart`)

`StreamTransformer<List<int>, String>`. Pur Dart, partagé entre toutes les plateformes.
Splitte les bytes en lignes. Délimiteurs : `\r\n`, `\r`, `\n` (les 3, y compris split entre chunks).
Utilisé uniquement par le transport io (le web n'en a pas besoin, EventSource parse nativement).

### SSE Parser (`sse/sse_parser.dart`)

`StreamTransformer<String, MercureEvent>`. Pur Dart, partagé.
Stateful : accumule les champs jusqu'à une ligne vide → émet un `MercureEvent`.
Règles :
- Lignes commençant par `:` = commentaires, ignorées
- `data:` multiples → concaténées avec `\n`
- `id:` ne doit PAS contenir `\0` (spec SSE)
- `retry:` uniquement des digits → parse en int (millisecondes)
- Champ inconnu → ignoré
Utilisé uniquement par le transport io. Le transport web reçoit des events déjà parsés via EventSource.

### Transport (`transport/`)

Interface abstraite qui isole toute la couche réseau :

```dart
abstract class MercureTransport {
  /// Ouvre un flux SSE. Retourne un Stream<MercureEvent>.
  /// Gère la reconnexion automatique et le Last-Event-ID.
  Stream<MercureEvent> subscribe({
    required Uri hubUrl,
    required List<String> topics,
    MercureAuth? auth,
    String? lastEventId,
  });

  /// Publie un update. Retourne l'ID assigné par le hub.
  Future<String> publish({
    required Uri hubUrl,
    required MercureAuth auth,
    required PublishOptions options,
  });

  /// GET HTTP brut (utilisé par discovery et subscriptions API).
  Future<TransportResponse> get(Uri url, {MercureAuth? auth});

  /// Libère les ressources.
  void close();
}
```

**`mercure_transport_factory.dart`** — le conditional import :
```dart
export 'mercure_transport_stub.dart'
    if (dart.library.io) 'mercure_transport_io.dart'
    if (dart.library.html) 'mercure_transport_web.dart';
```

**`mercure_transport_io.dart`** (dart:io) :
- Subscribe : `HttpClient` GET avec `Accept: text/event-stream`, pipe le response body dans `SseLineDecoder` → `SseParser` → `Stream<MercureEvent>`
- Reconnexion manuelle : sur coupure, attend `retryDelay` puis reconnecte avec `Last-Event-ID` header
- Publish : `HttpClient` POST, form-urlencoded
- HTTP/2 si disponible (SHOULD dans la spec, transparent via dart:io sur les runtimes récents)
- Gère le header `Last-Event-ID` de la réponse pour la détection de data loss

**`mercure_transport_web.dart`** (dart:html) :
- Subscribe : `EventSource` natif du navigateur — parsing SSE, reconnexion auto, Last-Event-ID gérés nativement. Mappe les events vers `MercureEvent`
- Publish : `window.fetch()` ou `HttpRequest` pour le POST
- Auth cookie : fonctionne nativement via `withCredentials: true` sur EventSource
- Auth bearer/query param : EventSource ne supporte pas les headers custom → utiliser query param `authorization` comme fallback (la spec le prévoit explicitement pour ce cas)
- Pas besoin de `SseLineDecoder` ni `SseParser` côté web

**`mercure_transport_stub.dart`** :
- Throw `UnsupportedError` — sécurité si aucune plateforme n'est détectée

### Subscriber (`subscriber/mercure_subscriber.dart`)

Façade publique. Délègue au transport. Contrat :
- Constructeur : `hubUrl`, `topics` (List<String>), `auth` (MercureAuth?), `lastEventId` (String?), `transport` (MercureTransport? — injecté ou créé via factory)
- Expose un `Stream<MercureEvent>` via `.subscribe()`
- Expose `.close()` pour couper proprement

### Publisher (`publisher/mercure_publisher.dart`)

Façade publique. Délègue au transport. Contrat :
- Constructeur : `hubUrl`, `auth` (MercureAuth), `transport` (MercureTransport?)
- Méthode `publish(PublishOptions) → Future<String>` (retourne l'ID assigné par le hub)
- Gère les erreurs HTTP (403 → unauthorized, etc.)

### Discovery (`discovery/mercure_discovery.dart`)

- Fonction `discover(String resourceUrl, {MercureTransport? transport}) → Future<DiscoveryResult>`
- Utilise `transport.get()` pour le GET initial
- Parse les `Link` headers de la réponse :
  - `rel=mercure` → hub URL(s)
  - `rel=self` → canonical topic URL
  - Attributs optionnels : `last-event-id`, `content-type`, `key-set`
- Si pas de `rel=self`, fallback sur l'URL de la resource
- Pur Dart pour le parsing, seul le GET passe par le transport

### Subscriptions API (`subscriptions_api/mercure_subscriptions_api.dart`)

- `getSubscriptions(hubUrl, {topic?, subscriber?, auth, transport}) → Future<SubscriptionsResponse>`
- GET sur `/.well-known/mercure/subscriptions[/{topic}[/{subscriber}]]`
- Parse le JSON-LD : `lastEventID`, liste de `SubscriptionInfo` (id, topic, subscriber, active, payload)
- Requiert auth (le JWT doit matcher les topic selectors)

## Support plateforme

| Plateforme                    | Transport                     | SSE parsing                         | Reconnexion            | Auth bearer                                                      | Auth cookie           | Auth query param |
| ----------------------------- | ----------------------------- | ----------------------------------- | ---------------------- | ---------------------------------------------------------------- | --------------------- | ---------------- |
| Mobile (iOS/Android)          | dart:io HttpClient            | SseLineDecoder + SseParser (custom) | Manuelle (retry delay) | Header Authorization                                             | Cookie header         | Query param      |
| Desktop (macOS/Linux/Windows) | dart:io HttpClient            | SseLineDecoder + SseParser (custom) | Manuelle (retry delay) | Header Authorization                                             | Cookie header         | Query param      |
| Server (Dart CLI)             | dart:io HttpClient            | SseLineDecoder + SseParser (custom) | Manuelle (retry delay) | Header Authorization                                             | Cookie header         | Query param      |
| Web (Flutter web / Dart web)  | dart:html EventSource + fetch | Natif navigateur                    | Natif EventSource      | ❌ (pas de headers custom sur EventSource) → fallback query param | withCredentials: true | Query param      |

Point clé web : `EventSource` ne permet pas de setter des headers custom. Pour l'auth bearer côté subscriber web, le token est passé en query param `authorization` (prévu par la spec, mais déconseillé pour des raisons de sécurité — tokens dans les logs). L'auth cookie fonctionne nativement avec `withCredentials: true`. Côté publisher web, `fetch` supporte les headers custom donc bearer fonctionne normalement.

## Stratégie de test

### Unit tests (sans réseau)

- `sse_line_decoder_test.dart` : bytes → lignes, tous les cas de délimiteurs (\r\n, \r, \n, split entre chunks, lignes vides)
- `sse_parser_test.dart` : lignes → events, cas limites (multi data, commentaires, champs inconnus, id avec \0, retry non-numérique)
- `mercure_auth_test.dart` : vérification de la construction des variantes (pas de test I/O, l'application sur requête se teste en intégration)
- `discovery_test.dart` : parsing de Link headers (multiples hubs, attributs, fallback self) — tester le parser pur, pas le GET
- `publish_options_test.dart` : encodage form-urlencoded (topics multiples, private, caractères spéciaux)
- `transport_test.dart` : vérifier que le conditional import résout bien le bon transport selon la plateforme

### Integration tests (hub Docker — dart:io uniquement)

Utiliser l'image officielle `dunglas/mercure` (ou `dunglas/mercure:latest`).

Le helper `test/helpers/hub.dart` doit :
- Démarrer un container Mercure avec `docker run` (port dynamique, JWT_KEY configurable)
- Générer les JWT publisher/subscriber avec les bons claims `mercure.publish` / `mercure.subscribe`
- Exposer `hubUrl`, `publisherToken`, `subscriberToken`
- Cleanup : stop + rm du container en tearDown

Tests d'intégration à couvrir :
- **Publish + Subscribe basique** : publish un event, vérifier qu'un subscriber le reçoit avec le bon data/type/id
- **Topics multiples** : subscriber sur plusieurs topics, vérifier le dispatch correct
- **Private updates** : subscriber sans auth ne reçoit pas, subscriber avec bon JWT reçoit
- **Reconnexion + reconciliation** : subscriber se connecte, reçoit des events, on kill la connexion, on publie pendant la déco, on vérifie que les events manqués arrivent au reconnect via Last-Event-ID
- **lastEventID=earliest** : subscriber demande tout l'historique
- **Discovery** : requête sur une resource qui expose les Link headers, vérifier le parsing
- **Subscriptions API** : vérifier qu'on récupère les souscriptions actives, filtrage par topic/subscriber
- **Erreurs auth** : publish sans token → 401/403, subscribe private sans token → pas de dispatch
- **Retry hint** : le hub envoie retry:, vérifier que le subscriber met à jour son délai

## Conventions

- Dart 3.x, sound null safety
- Sealed classes pour les unions (auth, résultats)
- `final class` partout sauf besoin d'héritage
- Pas de code generation, pas d'annotations
- Doc comments sur chaque classe/méthode publique
- Nommage : snake_case fichiers, PascalCase classes, camelCase méthodes/variables
- Zéro dépendance dans le pubspec.yaml — pas de package:http, pas de package:web
- Conditional imports uniquement dans `mercure_transport_factory.dart` — c'est le seul point de branchement plateforme
- Le code dans `models/`, `sse/`, `auth/` ne doit JAMAIS importer dart:io ni dart:html
- Les tests d'intégration sont dart:io only (Docker), les tests unitaires sont pur Dart et passent sur toutes les plateformes