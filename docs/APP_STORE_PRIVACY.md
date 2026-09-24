# App Store Connect — réponses de confidentialité (v1.0)

À recopier dans **App Store Connect › ton app › Confidentialité de l'app**. Ces réponses doivent rester alignées avec `AquApp/PrivacyInfo.xcprivacy` et `docs/PRIVACY.md` : si le code change ce qui quitte l'iPhone, mets à jour les trois.

Rappel de la règle d'Apple : une donnée est **« collectée »** seulement si elle est **transmise hors de l'appareil**. Ce qui reste sur l'iPhone (SwiftData, Keychain, HealthKit lu localement) n'est pas collecté.

---

## 1. URL de la politique de confidentialité

`https://github.com/HarpeLm/AquApp/blob/main/docs/PRIVACY.md`

(Une page web dédiée est plus agréable pour les utilisateurs, mais cette URL est acceptée.)

---

## 2. « Collectez-vous des données à partir de cette app ? » → **Oui**

Un seul type de données est concerné.

### Localisation › **Position approximative**

| Question | Réponse |
|---|---|
| Utilisation | **Fonctionnalité de l'app** uniquement |
| Liée à l'identité de l'utilisateur ? | **Non** |
| Utilisée pour le suivi (tracking) ? | **Non** |

Justification : `WeatherManager` envoie la latitude et la longitude **arrondies à 2 décimales (~1 km)** à `api.open-meteo.com` pour obtenir la température et adapter l'objectif en cas de canicule. Aucun identifiant n'accompagne la requête. C'est facultatif : sans autorisation de localisation, rien n'est envoyé.

> Pourquoi « Oui » plutôt que « Non » : Apple exempte les données traitées en temps réel et non conservées, mais nous ne contrôlons pas la conservation côté Open-Meteo. Déclarer est la réponse prudente, et c'est cohérent avec `PrivacyInfo.xcprivacy`.

---

## 3. Toutes les autres catégories → **non collectées**

| Catégorie App Store | Réponse | Pourquoi |
|---|---|---|
| Santé et forme physique | Non collectée | HealthKit est lu et écrit **sur l'iPhone** ; rien n'est transmis. |
| Coordonnées (nom, email…) | Non collectée | Le prénom reste dans le Keychain ; pas de compte ni d'email. |
| Contenu utilisateur (photos…) | Non collecté | La photo de profil reste dans le dossier privé de l'app. |
| Historique d'achats | Non collecté | StoreKit est géré par Apple ; aucun envoi vers un serveur AquApp. |
| Données financières | Non collectées | Aucune donnée de paiement reçue. |
| Localisation précise | Non collectée | Seule une position arrondie à ~1 km est envoyée (voir §2). |
| Données sensibles | Non collectées | — |
| Contacts | Non collectés | — |
| Historique de navigation / de recherche | Non collectés | — |
| Identifiants (utilisateur, appareil) | Non collectés | Aucun identifiant, pas d'IDFA. |
| Données d'utilisation | Non collectées | Aucun outil d'analyse. |
| Diagnostics | Non collectés | Aucun SDK de crash. (Les rapports de plantage partagés par les utilisateurs via Apple ne comptent pas.) |
| Autres données | Non collectées | — |

---

## 4. Autres rubriques de la soumission

**Chiffrement (export)** : l'app n'utilise que le chiffrement standard d'Apple (HTTPS, Keychain). `ITSAppUsesNonExemptEncryption = NO` est déclaré dans `Info.plist`, donc la question ne sera plus posée.

**Classification d'âge** : l'app sert notamment à suivre sa consommation d'alcool. Dans le questionnaire, la rubrique « Alcool, tabac ou drogues » doit être renseignée honnêtement (références fréquentes à l'alcool). Cela relève l'âge minimum ; c'est un choix à faire en connaissance de cause, pas à minimiser.

**Notes pour l'équipe de validation (App Review)** — à coller dans « Informations de validation › Notes » :

> AquApp is a hydration tracker that works fully offline, with no account.
> • Apple Health: requested at the end of onboarding, after an explanation screen. The app writes water intake, and reads steps, workouts, sleep and water only to validate specific challenges/achievements. Health data never leaves the device.
> • Location (optional): an approximate position (~1 km) is sent to Open-Meteo to raise the daily goal during heatwaves.
> • Siri: App Shortcuts “Add water in AquApp”, “Log a drink in AquApp”, “My progress in AquApp”.
> • Premium: not available for purchase in this version (the app is free at launch).

---

## 5. Points à trancher avant de soumettre

1. **Contact pour les demandes RGPD** : la politique renvoie vers GitHub Issues (public). Ajoute une adresse email dédiée si tu préfères que les demandes de suppression restent privées.
2. **Open-Meteo** : l'API gratuite est réservée à un usage **non commercial**. Avec un abonnement Premium, il faudra un plan payant Open-Meteo ou passer à **WeatherKit** (inclus avec le compte développeur Apple, 500 000 appels/mois).
3. **Suppression des données** : les éléments du Keychain survivent à la désinstallation. Un bouton « Supprimer mes données » dans l'app rendrait le droit à l'effacement effectif sans passer par toi.
