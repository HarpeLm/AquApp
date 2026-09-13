AquApp 💧

Votre compagnon quotidien pour mieux vous hydrater.

AquApp est une application iOS de suivi d’hydratation conçue pour rendre la consommation d’eau simple, motivante et personnalisée.

Suivez votre eau et votre consommation d’alcool, atteignez vos objectifs, construisez vos séries, débloquez des succès et analysez vos habitudes — sans compte, sans serveur et sans tracking.

⸻

📱 Aperçu

Accueil	Statistiques	Défis	Profil
			

Captures réalisées sur iPhone — modes clair et sombre.

⸻

✨ Fonctionnalités

💧 Hydratation

* Ajout d’eau en un tap avec préréglages
* Quantité personnalisée
* Objectif quotidien personnalisé
* Calcul basé sur le profil et le niveau d’activité
* Ajustement de l’objectif en cas de forte chaleur
* Rappels d’hydratation configurables
* Suivi quotidien et historique

🍷 Alcool

* Enregistrement des consommations
* Compensation en eau selon le type de boisson
* Suivi des tendances et volumes consommés
* Séries de jours sans alcool

🎮 Gamification

* Système d’XP et 8 niveaux
* 16 succès permanents et saisonniers
* 10 défis quotidiens
* Badges équipables
* Séries d’objectifs
* Séries de jours sans alcool
* Animations et progression visuelle

📊 Statistiques

* Historique sur 7 jours
* Statistiques mensuelles
* Historique complet
* Grille annuelle inspirée des contributions GitHub
* Analyse de la consommation d’alcool
* Suivi de la compensation en eau
* AquApp Wrapped : bilan annuel partageable

🎨 Personnalisation

* 8 icônes alternatives
* Thème clair, sombre ou système
* Photo de profil
* Badges personnalisables
* Fonctionnalités Premium via StoreKit

🔌 Intégration iOS

* Widgets Home Screen
* Live Activities
* Dynamic Island
* Intégration Siri & Raccourcis avec App Intents
* Intégration HealthKit (lecture pas/sommeil + écriture volumes eau)
* Notifications locales
* Support de plusieurs langues

⸻

🔒 Privacy first

AquApp est conçu autour d’un principe simple :

Vos données vous appartiennent.

Dans la version actuelle :

* ❌ Aucun compte
* ❌ Aucun serveur applicatif
* ❌ Aucun analytics
* ❌ Aucun tracking publicitaire
* ❌ Aucune collecte comportementale
* ✅ Données stockées localement
* ✅ HealthKit utilisé après autorisation
* ✅ Écriture HealthKit pour les données concernées
* ✅ Données sensibles stockées dans le Keychain lorsque nécessaire

L’objectif est de permettre une expérience complète sans avoir besoin d’envoyer vos habitudes d’hydratation vers un serveur.

⸻

🛠️ Technologies

AquApp est développé nativement pour Apple avec :

* Swift
* SwiftUI
* SwiftData
* HealthKit
* WidgetKit
* ActivityKit
* App Intents / Siri
* StoreKit 2
* UserNotifications
* Keychain Services
* GitHub Actions

Architecture basée sur des ObservableObject injectés dans l’environnement, avec séparation entre modèles, données, managers et vues.

⸻

🏗️ Architecture

AquApp/
├── AquAppApp.swift
│
├── Data/
│   ├── AppDataStore.swift
│   ├── XPManager.swift
│   └── StoreKitManager.swift
│
├── Models/
│   ├── WaterEntry.swift
│   ├── WaterAlcoholEntry.swift
│   └── DayRecord.swift
│
├── Utils/
│   ├── HealthDataManager.swift
│   ├── KeychainManager.swift
│   ├── PremiumManager.swift
│   ├── AppIconManager.swift
│   └── HealthKitWriter.swift
│
├── Views/
│   ├── Home/
│   ├── Stats/
│   ├── Challenges/
│   ├── Achievements/
│   ├── Profile/
│   ├── Wrapped/
│   └── Onboarding/
│
├── Widgets/
│   ├── WidgetKit
│   └── ActivityKit
│
├── Localizable.xcstrings
│
├── AquAppTests/
└── AquAppUiTests/

Principes

* SwiftUI pour l’interface
* SwiftData pour la persistance
* Keychain pour les données nécessitant un stockage sécurisé
* App Groups pour la communication avec les widgets
* Managers spécialisés pour les intégrations système
* Logique métier testée indépendamment lorsque possible

⸻

🧪 Tests & qualité

AquApp dispose d’une suite de tests unitaires et UI couvrant notamment :

* Formules d’hydratation
* Compensation liée à l’alcool
* XP et progression
* Streaks
* Persistance SwiftData
* Migration des données
* Formatage des unités
* Logique météo
* Onboarding
* Navigation
* Statistiques
* Succès
* Premium
* Stabilité générale

L’intégration continue exécute automatiquement le build et les tests sur GitHub Actions.

Lancer les tests

Dans Xcode :

⌘U

Ou en ligne de commande :

xcodebuild test \
  -scheme AquApp \
  -project AquApp.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:AquAppTests

⸻

🚀 Installation

Prérequis

Outil	Version
macOS	Sonoma 14+
Xcode	15.4+
iOS	17.0+
Apple Developer Account	Requis pour certaines capabilities

Installation

git clone https://github.com/HarpeLm/AquApp.git
cd AquApp
open AquApp.xcodeproj

Puis :

1. Sélectionnez la target AquApp
2. Configurez votre Team dans Signing & Capabilities
3. Sélectionnez un simulateur ou un iPhone
4. Lancez avec ⌘R

Certaines fonctionnalités nécessitent les capabilities Apple correspondantes, notamment :

* HealthKit
* App Groups
* In-App Purchase
* Widgets
* Live Activities

⸻

🗺️ Roadmap

✅ Disponible

* Suivi de l’eau
* Suivi de l’alcool
* Compensation en eau
* Objectifs personnalisés
* Ajustement météo
* XP et niveaux
* Succès
* Défis
* Badges
* Statistiques
* Wrapped annuel
* Widgets
* Live Activities
* Siri / App Intents
* HealthKit
* Personnalisation
* Stockage sécurisé

🚧 En cours

* v1.0 — Soumission App Store
* Activation des abonnements Premium
* Tests et optimisation finale App Store
* Finalisation des traductions

🔮 À venir

* Synchronisation iCloud / CloudKit
* Nouveaux formats de widgets
* Partage avancé du Wrapped
* Version watchOS

⸻

🧭 Statut

Pré-release active

AquApp est actuellement en préparation pour sa première publication sur l’App Store.

La version pré-release est gratuite. Les fonctionnalités Premium seront activées progressivement après la sortie de la v1.0.

⸻

🤝 Contribuer

Les contributions sont les bienvenues.

1. Forkez le projet
2. Créez une branche :

git checkout -b feature/ma-fonctionnalite

3. Implémentez votre modification
4. Ajoutez ou mettez à jour les tests
5. Vérifiez que la CI passe
6. Ouvrez une Pull Request

Merci de conserver les tests verts avant toute PR.

⸻

👤 Auteur

Fabian Dargaud

GitHub : @HarpeLm

⸻

📄 Licence

AquApp est distribué sous licence MIT.

Voir LICENSE pour plus d’informations.

⸻

<div align="center">

💧 Fait avec Swift, SwiftUI et beaucoup d’eau.

</div>
