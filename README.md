# AquApp 💧

[![iOS CI](https://github.com/HarpeLm/AquApp/actions/workflows/ci.yml/badge.svg)](https://github.com/HarpeLm/AquApp/actions/workflows/ci.yml)
[![iOS 17+](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![Xcode 15+](https://img.shields.io/badge/Xcode-15%2B-blueviolet.svg)](https://developer.apple.com/xcode/)
[![License MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Statut](https://img.shields.io/badge/statut-pré--release-yellow.svg)](https://github.com/HarpeLm/AquApp/projects)

**AquApp est votre compagnon quotidien d'hydratation** : suivez votre consommation d'eau (et d'alcool), atteignez vos objectifs, construisez des séries et découvrez vos statistiques — le tout dans une interface SwiftUI rapide, ludique et respectueuse de votre vie privée.

---

## 📱 Captures d'écran

| Accueil | Statistiques | Défis | Profil |
|:---:|:---:|:---:|:---:|
| ![Accueil](docs/screenshots/01-home.png) | ![Stats](docs/screenshots/02-stats.png) | ![Défis](docs/screenshots/03-challenges.png) | ![Profil](docs/screenshots/04-profile.png) |

> 📸 *Ajoutez vos captures dans `docs/screenshots/` (iPhone 17 Pro, mode sombre & clair).*

---

## ✨ Fonctionnalités

### 💧 Suivi intelligent
- Ajout d'eau en 1 tap (préréglages + quantité personnalisée au slider)
- Suivi de l'alcool avec **compensation en eau automatique** selon le type de boisson
- Objectif quotidien personnalisé (poids, taille, sexe, activité) et recalculable
- **Objectif canicule** : ajustement automatique selon la météo locale
- Rappels hydratation configurables (plage horaire, fréquence, messages)

### 🎮 Gamification
- **XP & 8 niveaux** (Goutte → Aqua Légende) avec barre de progression liquide animée
- **16 succès** permanents + mensuels (Dry January, Sober October…)
- **10 défis quotidiens** (Matinal, Cadence Parfaite, Flash Hydraté…)
- Badges équipables sur le profil (cosmétiques + succès + défis)
- Séries (streaks) d'objectifs et de jours sobres

### 📊 Statistiques
- Graphiques 7 jours / mois / historique complet
- Grille annuelle type « contributions GitHub »
- Analyse alcool (volume, compensation, tendances)
- **AquApp Wrapped** : bilan annuel partageable (story / carré)

### 🎨 Personnalisation & Premium
- 8 icônes d'app alternatives (Océan, Minuit, Givre, Lagon, Aurora…)
- Thème clair / sombre / système
- Photo de profil depuis la galerie
- Premium (StoreKit) : icônes exclusives, historique illimité, succès Pro

### 🔌 Intégrations système
- **Widgets** écran d'accueil & **Live Activities** (Dynamic Island / lock screen)
- **Siri & Raccourcis** (App Intents) : « Ajoute 250 ml d'eau »…
- **Santé Apple** (HealthKit, optionnel) : écriture des volumes bus
- Interface localisée en **40 langues**

### 🔒 Vie privée
- Données **100 % locales** : SwiftData + Keychain (statut Premium, totaux)
- Aucun compte, aucun analytics, aucun serveur
- HealthKit en écriture seule, sur autorisation explicite

---

## 🚀 Installation

### Prérequis
| Outil | Version minimale |
|---|---|
| macOS | Sonoma 14+ |
| Xcode | 15.4+ (recommandé : dernière version) |
| iOS (device/simulateur) | 17.0+ |
| Compte Apple Developer | Requis pour device physique, HealthKit & StoreKit |

### Étapes
```bash
git clone https://github.com/HarpeLm/AquApp.git
cd AquApp
open AquApp.xcodeproj
```
1. Sélectionnez la target **AquApp** → *Signing & Capabilities* → votre Team
2. Choisissez un simulateur iOS 17+ (ou votre iPhone)
3. `⌘R` — c'est parti !

> ⚠️ Sur device physique, les capabilities **HealthKit**, **App Groups** (widgets) et **In-App Purchase** nécessitent un provisioning valide. Le test StoreKit fonctionne en sandbox via le compte de test Xcode.

---

## 🏗️ Architecture technique

```
AquApp/
├── AquAppApp.swift            # Point d'entrée + injection des managers
├── Data/
│   ├── AppDataStore.swift     # Source de vérité SwiftData (entrées, streaks, stats)
│   ├── XPManager.swift        # XP, niveaux, sync eau réversible par jour
│   └── StoreKitManager.swift  # Achats & statut Premium
├── Models/                    # WaterEntry, WaterAlcoholEntry, DayRecord…
├── Utils/
│   ├── HealthDataManager.swift # Profil, totaux Keychain, succès persistés
│   ├── KeychainManager.swift   # Stockage sécurisé (Premium, totaux cumulés)
│   ├── PremiumManager.swift    # Source de vérité Premium (non spoofable)
│   ├── AppIconManager.swift    # Icônes alternatives (setAlternateIconName)
│   └── HealthKitWriter.swift   # Écriture HealthKit optionnelle
├── Views/
│   ├── Home/                  # Dashboard + sheets d'ajout (eau/alcool)
│   ├── Stats/                 # Graphiques + grille annuelle
│   ├── Challenges/  ├── Achievements/
│   ├── Profile/               # Sections / Components / Sheets dédiés
│   ├── Wrapped/               # Bilan annuel animé
│   └── Onboarding/            # Premier lancement (nom, profil, objectif)
├── Widgets/                   # WidgetKit + ActivityKit (Live Activities)
└── Localizable.xcstrings      # 40 langues

AquAppTests/                   # ~165 tests unitaires (formules, XP, stores…)
AquAppUiTests/                 # Tests UI (onboarding, navigation, stabilité)
.github/workflows/ci.yml       # CI : build + tests sur simulateur à chaque push
```

**Principes** : MVVM léger (managers `ObservableObject` injectés), persistance SwiftData, totaux cumulatifs O(1) en Keychain, synchronisation widget via App Group, et une règle d'or : *chaque vue de section vit dans son propre fichier*.

---

## 🧪 Tests

```bash
# Via Xcode
⌘U

# Ou en ligne de commande
xcodebuild test -scheme AquApp -project AquApp.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AquAppTests
```

- **~165 tests unitaires** : formules alcool & compensation, XP/cap quotidien, streaks, stores SwiftData en mémoire, migration v1.1, UnitFormatter, météo (contrat canicule)…
- **Tests UI** : onboarding, navigation, home, stats, succès, premium, stabilité
- **CI GitHub Actions** : build + tests à chaque push sur `main` (artefacts `.xcresult` téléchargeables)

---

## 🗺️ Roadmap

- [x] Suivi eau + alcool avec compensation
- [x] Gamification complète (XP, succès, défis, badges)
- [x] Widgets & Live Activities
- [x] Wrapped annuel
- [x] Sécurité : Premium & totaux migrés en Keychain
- [ ] **v1.0 — Soumission App Store** (en cours)
- [ ] Activation réelle des abonnements Premium
- [ ] Synchronisation iCloud (CloudKit)
- [ ] Nouveaux widgets (complications, grand format)
- [ ] Partage Wrapped vers réseaux sociaux
- [ ] Version watchOS (compagnon)

---

## 📌 Statut du projet

**Pré-release active** : l'app est complète et testée sur device, la soumission App Store est en préparation. L'application est entièrement gratuite pendant la phase de lancement ; le Premium arrivera juste après la v1.0.

---

## 🤝 Contribuer

Les contributions sont bienvenues !
1. Fork le projet
2. Créez une branche (`git checkout -b feature/ma-fonctionnalite`)
3. Committez (`git commit -m 'feat: ma fonctionnalité'`)
4. Pushez (`git push origin feature/ma-fonctionnalite`)
5. Ouvrez une Pull Request

Merci de garder les tests verts (`⌘U`) avant toute PR. 🙏

---

## 👤 Auteur

**Fabian Dargaud** — [GitHub](https://github.com/HarpeLm)

---

## 📄 Licence

Distribué sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus d'informations.

---

<div align="center">

**Fait avec 💙 et beaucoup d'eau — AquApp**

</div>
