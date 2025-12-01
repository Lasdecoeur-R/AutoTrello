# 🚀 AutoTrello - Créateur Automatique de Cartes Trello

Un script PowerShell intelligent qui automatise la création de cartes Trello avec descriptions, checklists et labels. Parfait pour les projets, la gestion de tâches et l'organisation d'équipe.

## ✨ Fonctionnalités

- 🔐 **Authentification sécurisée** avec sauvegarde des identifiants
- 🎯 **Sélection interactive** de tous vos boards Trello disponibles
- 📋 **Preset Kanban** : Création automatique d'un tableau Kanban complet (Backlog, To Do, In Progress, Review, Done)
- 🏗️ **Création automatique** de listes simples (Inbox, In Progress, Done)
- 🎨 **Deux modes de création** :
  - **Mode par défaut** : Cartes prédéfinies avec labels automatiques
  - **Mode personnalisé** : Création manuelle carte par carte
- 💾 **Configuration persistante** sauvegardée localement
- 📝 **Création automatique** de cartes avec descriptions détaillées
- ✅ **Checklists de tâches** intégrées
- 🏷️ **Gestion intelligente des labels** avec création/réutilisation automatique
- 🔄 **Gestion robuste** des erreurs et fallbacks

## 📋 Prérequis

- **PowerShell 5.1+** (Windows 10/11, Windows Server 2016+)
- **Compte Trello** actif
- **Connexion Internet** pour l'API Trello
- **Permissions d'écriture** sur le board cible

## 🔑 Récupération des Identifiants Trello

### 1. Obtenir votre API Key

1. Rendez-vous sur [https://trello.com/app-key](https://trello.com/app-key)
2. Connectez-vous à votre compte Trello
3. **Copiez la "API Key"** affichée (chaîne de 32 caractères)

### 2. Générer votre Token

1. Sur la même page, cliquez sur le lien **"Token"**
2. Ou utilisez cette URL (remplacez `YOUR_KEY` par votre API Key) :
   ```
   https://trello.com/1/authorize?expiration=never&name=AutoTrello&scope=read,write&response_type=token&key=YOUR_KEY
   ```
3. Autorisez l'application à accéder à votre compte Trello
4. **Copiez le "Token"** généré (chaîne commençant par "ATTA...")

## 🚀 Installation et Utilisation

### 1. Téléchargement

```bash
git clone https://github.com/votre-username/AutoTrello.git
cd AutoTrello
```

### 2. Première Exécution

```powershell
.\AutoTrello-FINAL-WORKING.ps1
```

### 3. Configuration Initiale

Le script vous demandera :
- **Votre API Key Trello**
- **Votre Token Trello**
- **Sauvegarder la configuration ?** → Répondez **"O"** (Oui)

### 4. Sélection du Board

Le script affiche **TOUS vos boards disponibles** :

```
📋 Récupération de vos boards disponibles...

Boards accessibles :
[1] Projet Principal
    ShortLink: ABC123
    URL: https://trello.com/b/ABC123/projet-principal
[2] Dashboard
    ShortLink: XYZ789
    URL: https://trello.com/b/XYZ789/dashboard
[3] Kanban Personnel
    ShortLink: DEF456
    URL: https://trello.com/b/DEF456/kanban-personnel

Tapez le numéro du board (1-3): 
```

### 5. Création des Listes (Nouveau Board Vide)

Si votre board est vide, le script propose **3 options** :

```
⚠️  Aucune liste trouvée sur ce board

💡 Ce board est vide. Que voulez-vous faire ?
  [1] Créer un tableau Kanban complet (Backlog, To Do, In Progress, Review, Done)
  [2] Créer des listes simples (Inbox, In Progress, Done)
  [3] Créer mes propres listes
  [4] Annuler

Votre choix (1-4): 
```

**Option 1 - Preset Kanban** (Recommandé) :
- 📥 **Backlog** - Toutes les idées et tâches futures
- 📝 **To Do** - Tâches prêtes à être commencées
- 🔄 **In Progress** - Travail en cours
- 👀 **Review** - En attente de validation
- ✅ **Done** - Tâches terminées

**Option 2 - Listes simples** :
- 📥 **Inbox** - Nouvelles tâches
- 🔄 **In Progress** - En cours
- ✅ **Done** - Terminé

**Option 3 - Personnalisé** :
Créez vos propres listes avec les noms de votre choix.

### 6. Choix du Mode de Création

Le script propose **deux modes** :

```
=== MODE DE CRÉATION ===
Choisissez le mode de création des cartes :
  [1] Mode par défaut (cartes + labels prédéfinis automatiquement)
  [2] Mode personnalisé (création manuelle carte par carte)

Votre choix (1/2): 
```

#### Mode Par Défaut (Option 1)

Crée automatiquement **3 cartes prédéfinies** avec leurs labels :
- **KPI par rôle** → Label "KPI" (vert)
- **Graphes** → Label "Graphiques" (orange)
- **Alertes** → Label "Alertes" (rouge)

Chaque carte contient :
- Description détaillée
- Checklist de tâches
- Label automatique

**Parfait pour** : Démarrage rapide, projets standardisés

#### Mode Personnalisé (Option 2)

Création **manuelle carte par carte** :
- Choisissez le nom
- Ajoutez une description (optionnel)
- Sélectionnez/créez des labels (plusieurs possibles)
- Ajoutez une checklist avec tâches (optionnel)
- Créez autant de cartes que nécessaire

**Parfait pour** : Projets spécifiques, besoins personnalisés

## 📊 Exemples d'Utilisation

### Exemple 1 : Nouveau Projet avec Kanban

```powershell
.\AutoTrello-FINAL-WORKING.ps1

# Sélectionnez votre board
> 1

# Board vide détecté
> 1  # Créer tableau Kanban

# Sélectionnez la liste
> 2  # To Do

# Mode de création
> 1  # Mode par défaut

✅ 3 cartes créées avec labels et checklists !
```

### Exemple 2 : Cartes Personnalisées

```powershell
.\AutoTrello-FINAL-WORKING.ps1

# Sélectionnez votre board existant
> 2

# Sélectionnez la liste
> 1  # Backlog

# Mode de création
> 2  # Mode personnalisé

# Créez vos cartes une par une
Nom : Bug urgent client
Description : Problème critique production
Labels : [Créer "Urgent" rouge]
Checklist : Oui
  Tâche 1 : Identifier la cause
  Tâche 2 : Corriger le bug
  Tâche 3 : Tester en preprod
  Tâche 4 : Déployer en production

Créer une autre carte ? O
[...]
```

## 📁 Structure des Fichiers

```
AutoTrello/
├── AutoTrello-FINAL-WORKING.ps1    # Script principal
├── trello-config.json               # Configuration globale (KEY, TOKEN)
└── README.md                        # Ce fichier
```

## 🎨 Personnalisation des Cartes (Mode Par Défaut)

Pour modifier les cartes créées en mode par défaut, éditez le script :

**📍 Localisation** : Cherchez la section `$CardsSpec` dans le script

**🔧 Structure d'une carte** :

```powershell
[PSCustomObject]@{
  Name = "Titre de votre carte"
  Desc = @"
Description détaillée
Multi-lignes
"@
  Tasks = @(
    "Tâche 1",
    "Tâche 2",
    "Tâche 3"
  )
}
```

## 🔧 Dépannage

### Erreur 401 (Non autorisé)

**Problème** : Identifiants Trello incorrects
**Solution** : 
1. Régénérez votre API Key et Token sur https://trello.com/app-key
2. Supprimez `trello-config.json`
3. Relancez le script

### Erreur 400 (Bad Request)

**Problème** : Requête mal formatée
**Solution** : Le script utilise maintenant la méthode correcte avec key/token dans le Body. Assurez-vous d'utiliser la dernière version.

### Board vide mais pas de proposition de création

**Problème** : Erreur dans la détection
**Solution** : 
1. Créez manuellement une liste sur Trello
2. Relancez le script
3. Ou choisissez l'option [3] pour créer vos listes

### Les labels ne se créent pas

**Problème** : Permissions insuffisantes ou couleur déjà utilisée
**Solution** : 
- Créez vos labels manuellement sur Trello avant d'exécuter le script
- Ou laissez le script gérer automatiquement (il cherche les labels existants)

## 🔒 Sécurité

- **Les identifiants sont sauvegardés localement** uniquement
- **Aucune transmission** vers des serveurs tiers
- **Permissions minimales** (read, write sur Trello uniquement)
- **Suppression facile** : Supprimez `trello-config.json`

## 💡 Bonnes Pratiques

### Pour les Équipes

- **Créez un board partagé** sur Trello
- **Définissez les listes** ensemble (Kanban recommandé)
- **Utilisez le mode personnalisé** pour des cartes spécifiques
- **Établissez des conventions** de nommage pour les labels

### Pour les Projets

- **Un board par projet** pour une meilleure organisation
- **Preset Kanban** pour les projets agiles
- **Mode par défaut** pour des templates répétitifs
- **Checklist complète** pour ne rien oublier

### Pour la Productivité

- **Sauvegardez vos identifiants** pour gagner du temps
- **Réutilisez les labels** existants
- **Créez des cartes en lot** en mode par défaut
- **Personnalisez au besoin** en mode manuel

## 🤝 Contribution

1. **Fork** le projet
2. **Créez une branche** pour votre fonctionnalité
3. **Commitez** vos changements
4. **Poussez** vers la branche
5. **Ouvrez une Pull Request**

## 📜 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 🆘 Support

- **Issues GitHub** : [Créer une issue](https://github.com/votre-username/AutoTrello/issues)
- **Wiki** : Documentation détaillée
- **Discussions** : Questions et réponses

## 🙏 Remerciements

- **Trello** pour leur API robuste
- **PowerShell** pour la puissance du scripting
- **Communauté open source** pour les contributions

---

**⭐ N'oubliez pas de mettre une étoile au projet si il vous est utile !**

**📝 Dernière mise à jour** : Octobre 2025  
**🔖 Version** : 3.0 - Preset Kanban & Modes de création