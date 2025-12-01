# ============================================================================
# TRELLO – Trello Card Seeder (générique, compatible PowerShell ISE 5.1)
# - Demande : KEY, TOKEN, Board (URL/shortLink), Nom de liste, Nom du label, Couleur (menu).
# - GET corrigé : key/token en query string (évite 404).
# - Gère le cas Trello 400 sur /labels si la couleur existe déjà sur le board :
#     * cherche par nom, puis par couleur
#     * si couleur existante => tentative de renommage ; sinon réutilise
#     * fallback : crée label sans couleur si tout échoue
# - Crée chaque carte + description + checklist "DoD", applique le label si fourni.
# - NOUVEAU : Sauvegarde l'URL du board et sélection interactive des listes/labels
# - PRESET KANBAN : Création automatique de listes Kanban standard
# ============================================================================

<# ===============================================================
  AutoTrello - Création automatique de cartes Trello
  Version corrigée avec appels API fonctionnels
  =============================================================== #>

# === CONFIG ===
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# === VARIABLES GLOBALES ===
$script:Key = $null
$script:Token = $null
$script:Base = "https://api.trello.com/1"
$script:ConfigPath = Join-Path $PSScriptRoot "trello-config.json"

# ============================================================================
# FONCTIONS DE CONFIGURATION
# ============================================================================

function Get-TrelloConfig {
  Write-Host "`n=== CONFIGURATION TRELLO ===" -ForegroundColor Cyan
  Write-Host "Pour obtenir votre KEY et TOKEN, allez sur : https://trello.com/app-key" -ForegroundColor Yellow
  
  # Charger config existante
  Write-Host "Recherche du fichier de configuration : $script:ConfigPath" -ForegroundColor Gray
  if (Test-Path $script:ConfigPath) {
    Write-Host "Fichier de configuration trouvé" -ForegroundColor Green
    try {
      $config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json
      Write-Host "Configuration chargée avec succès" -ForegroundColor Green
      Write-Host "Configuration trouvée du $($config.LastUpdated)" -ForegroundColor Gray
      
      Write-Host "Options :" -ForegroundColor Yellow
      Write-Host "  [O] Utiliser les identifiants sauvegardés" -ForegroundColor White
      Write-Host "  [N] Saisir de nouveaux identifiants" -ForegroundColor White
      Write-Host "  [M] Modifier la configuration existante" -ForegroundColor White
      $choice = Read-Host "Votre choix (O/n/m)"
      
      if ($choice -eq "" -or $choice -eq "O" -or $choice -eq "o") {
        Write-Host "✅ Utilisation des identifiants sauvegardés" -ForegroundColor Green
        $script:Key = $config.Key
        $script:Token = $config.Token
        return
      } elseif ($choice -eq "M" -or $choice -eq "m") {
        Write-Host "Modification de la configuration..." -ForegroundColor Cyan
      }
    } catch {
      Write-Warning "Erreur lors du chargement de la configuration : $_"
    }
  } else {
    Write-Host "Fichier de configuration non trouvé" -ForegroundColor Yellow
    Write-Host "Aucune configuration sauvegardée trouvée." -ForegroundColor Gray
  }
  
  # Demander les identifiants
  $keyInput = Read-Host "Trello API KEY (laisser vide pour utiliser `$env:TRELLO_KEY)"
  $script:Key = if ([string]::IsNullOrWhiteSpace($keyInput)) { $env:TRELLO_KEY } else { $keyInput }
  
  $tokenInput = Read-Host "Trello TOKEN (laisser vide pour utiliser `$env:TRELLO_TOKEN)"
  $script:Token = if ([string]::IsNullOrWhiteSpace($tokenInput)) { $env:TRELLO_TOKEN } else { $tokenInput }
  
  if ([string]::IsNullOrWhiteSpace($script:Key) -or [string]::IsNullOrWhiteSpace($script:Token)) {
    throw "❌ Clé/Token manquants. Renseignez `$Key et `$Token."
  }
  
  # Sauvegarder
  $save = Read-Host "Sauvegarder ces identifiants pour la prochaine fois ? (O/n)"
  if ($save -eq "" -or $save -eq "O" -or $save -eq "o") {
    $configObj = @{
      Key = $script:Key
      Token = $script:Token
      LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $configObj | ConvertTo-Json | Set-Content $script:ConfigPath
    Write-Host "✅ Configuration Trello sauvegardée localement" -ForegroundColor Green
  }
}

# ============================================================================
# FONCTIONS D'APPEL API (MÉTHODE FONCTIONNELLE)
# ============================================================================

function Invoke-TrelloGet {
  param([string]$Uri)
  $authQuery = "key=$script:Key&token=$script:Token"
  $sep = if ($Uri -match '\?') { '&' } else { '?' }
  $fullUri = "$Uri$sep$authQuery"
  Invoke-RestMethod -Uri $fullUri -Method Get
}

function Invoke-TrelloPost {
  param(
    [string]$Uri,
    [hashtable]$Body
  )
  # CRITIQUE : key et token DANS le Body pour POST
  $postBody = @{
    key = $script:Key
    token = $script:Token
  }
  foreach ($key in $Body.Keys) {
    $postBody[$key] = $Body[$key]
  }
  
  Invoke-RestMethod `
    -Uri $Uri `
    -Method Post `
    -Body $postBody `
    -ContentType "application/x-www-form-urlencoded"
}

# ============================================================================
# FONCTIONS DE SÉLECTION DE BOARD
# ============================================================================

function Resolve-Board {
  param([string]$Input)
  
  $raw = if ($Input) { $Input.Trim() } else { "" }
  
  # Extraire shortLink si URL
  $candidate = $raw
  if ($candidate -match '^https?://.*?/b/([^/]+)') {
    $candidate = $Matches[1]
  }
  
  # Si vide -> proposer un choix parmi TOUS les boards
  if ([string]::IsNullOrWhiteSpace($candidate)) {
    Write-Host "`n📋 Récupération de vos boards disponibles..." -ForegroundColor Cyan
    $allBoards = Invoke-TrelloGet "$script:Base/members/me/boards?fields=id,name,shortLink,url"
    
    if (-not $allBoards -or $allBoards.Count -eq 0) {
      throw "❌ Aucun board accessible avec ce token."
    }
    
    Write-Host "`nBoards accessibles :" -ForegroundColor Yellow
    $i = 1
    foreach ($b in $allBoards) {
      Write-Host ("[{0}] {1}" -f $i, $b.name) -ForegroundColor White
      Write-Host ("    ShortLink: {0}" -f $b.shortLink) -ForegroundColor Gray
      Write-Host ("    URL: {0}" -f $b.url) -ForegroundColor Gray
      $i++
    }
    
    $idx = Read-Host "`nTapez le numéro du board (1-$($allBoards.Count))"
    if ($idx -match '^\d+$') {
      $sel = [int]$idx
      if ($sel -ge 1 -and $sel -le $allBoards.Count) {
        return $allBoards[$sel - 1]
      }
    }
    throw "❌ Sélection invalide."
  }
  
  # Tentative directe avec le shortLink ou ID
  try {
    return Invoke-TrelloGet "$script:Base/boards/$candidate?fields=id,name,shortLink,url"
  } catch {
    # Chercher par nom exact ou shortLink
    $allBoards = Invoke-TrelloGet "$script:Base/members/me/boards?fields=id,name,shortLink,url"
    $hit = $allBoards | Where-Object { $_.shortLink -eq $candidate -or $_.name -eq $raw } | Select-Object -First 1
    
    if ($hit) {
      return $hit
    }
    
    Write-Host "`n⚠️  Board '$raw' introuvable." -ForegroundColor Yellow
    Write-Host "Boards accessibles :" -ForegroundColor Yellow
    $i = 1
    foreach ($b in $allBoards) {
      Write-Host ("[{0}] {1}  (shortLink={2})" -f $i, $b.name, $b.shortLink)
      $i++
    }
    throw "❌ Utilisez un shortLink listé ou le nom exact."
  }
}

# ============================================================================
# FONCTIONS DE GESTION DES LISTES
# ============================================================================

function New-TrelloList {
  param(
    [string]$BoardId,
    [string]$Name,
    [string]$Position = "bottom"
  )
  
  Write-Host "🎯 Création de la liste '$Name'..." -ForegroundColor Cyan
  try {
    $list = Invoke-TrelloPost -Uri "$script:Base/lists" -Body @{
      name = $Name
      idBoard = $BoardId
      pos = $Position
    }
    Write-Host "✅ Liste créée avec succès : $Name" -ForegroundColor Green
    return $list
  } catch {
    Write-Warning "Impossible de créer la liste : $_"
    return $null
  }
}

function Create-DefaultLists {
  param([string]$BoardId)
  
  Write-Host "`n🏗️ Création des listes par défaut..." -ForegroundColor Cyan
  Write-Host "Voulez-vous créer des listes par défaut ? (O/n)" -ForegroundColor Yellow
  Write-Host "  Listes proposées : 📥 Inbox, 🔄 In Progress, ✅ Done" -ForegroundColor Gray
  
  $createDefault = Read-Host
  
  if ($createDefault -eq "" -or $createDefault -eq "O" -or $createDefault -eq "o") {
    $defaultLists = @(
      @{ name = "📥 Inbox"; pos = "bottom" }
      @{ name = "🔄 In Progress"; pos = "bottom" }
      @{ name = "✅ Done"; pos = "bottom" }
    )
    
    $created = @()
    foreach ($listDef in $defaultLists) {
      $list = New-TrelloList -BoardId $BoardId -Name $listDef.name -Position $listDef.pos
      if ($list) {
        $created += $list
      }
      Start-Sleep -Milliseconds 300
    }
    
    if ($created.Count -gt 0) {
      Write-Host "`n✅ $($created.Count) liste(s) créée(s) avec succès !" -ForegroundColor Green
      return $created
    }
  } else {
    Write-Host "Création personnalisée des listes..." -ForegroundColor Cyan
    $lists = @()
    do {
      $listName = Read-Host "`nNom de la liste (ou laissez vide pour terminer)"
      if (-not [string]::IsNullOrWhiteSpace($listName)) {
        $list = New-TrelloList -BoardId $BoardId -Name $listName
        if ($list) {
          $lists += $list
        }
        Start-Sleep -Milliseconds 300
      }
    } while (-not [string]::IsNullOrWhiteSpace($listName))
    
    return $lists
  }
  
  return @()
}

function Create-KanbanPreset {
  param([string]$BoardId)
  
  Write-Host "`n📋 CRÉATION D'UN TABLEAU KANBAN COMPLET" -ForegroundColor Cyan
  Write-Host "Ce preset va créer un tableau Kanban standard avec :" -ForegroundColor Yellow
  Write-Host "  • 📥 Backlog - Toutes les idées et tâches futures" -ForegroundColor Gray
  Write-Host "  • 📝 To Do - Tâches prêtes à être commencées" -ForegroundColor Gray
  Write-Host "  • 🔄 In Progress - Travail en cours" -ForegroundColor Gray
  Write-Host "  • 🔎 Testing - En attente de validation" -ForegroundColor Gray
  Write-Host "  • ✅ Done - Tâches terminées" -ForegroundColor Gray
  
  $confirm = Read-Host "`nCréer ce tableau Kanban ? (O/n)"
  
  if ($confirm -ne "" -and $confirm -ne "O" -and $confirm -ne "o") {
    Write-Host "❌ Création annulée" -ForegroundColor Yellow
    return @()
  }
  
  Write-Host "`n🚀 Création du tableau Kanban..." -ForegroundColor Cyan
  
  $kanbanLists = @(
    @{ name = "📥 Backlog"; pos = "bottom" }
    @{ name = "📝 To Do"; pos = "bottom" }
    @{ name = "🔄 In Progress"; pos = "bottom" }
    @{ name = "🔎 Testing"; pos = "bottom" }
    @{ name = "✅ Done"; pos = "bottom" }
  )
  
  $created = @()
  foreach ($listDef in $kanbanLists) {
    $list = New-TrelloList -BoardId $BoardId -Name $listDef.name -Position $listDef.pos
    if ($list) {
      $created += $list
    }
    Start-Sleep -Milliseconds 300
  }
  
  if ($created.Count -gt 0) {
    Write-Host "`n✅ Tableau Kanban créé avec succès !" -ForegroundColor Green
    Write-Host "   $($created.Count) listes créées" -ForegroundColor Gray
    return $created
  }
  
  return @()
}


function Select-ListFromBoard {
  param(
    [string]$BoardId,
    [bool]$AllowCreate = $true
  )
  
  Write-Host "`n📋 Récupération des listes disponibles..." -ForegroundColor Cyan
  try {
    $lists = Invoke-TrelloGet "$script:Base/boards/$BoardId/lists?fields=name,id,pos"
    
    # Si aucune liste
    if (-not $lists -or $lists.Count -eq 0) {
      Write-Host "⚠️  Aucune liste trouvée sur ce board" -ForegroundColor Yellow
      
      if ($AllowCreate) {
        Write-Host "`n💡 Ce board est vide. Que voulez-vous faire ?" -ForegroundColor Cyan
        Write-Host "  [1] Créer un tableau Kanban complet (Backlog, To Do, In Progress, Testing, Done)" -ForegroundColor White
        Write-Host "  [2] Créer des listes simples (Inbox, In Progress, Done)" -ForegroundColor White
        Write-Host "  [3] Créer mes propres listes" -ForegroundColor White
        Write-Host "  [4] Annuler" -ForegroundColor White
        
        $choice = Read-Host "`nVotre choix (1-4)"
        
        if ($choice -eq "1") {
          # Preset Kanban
          $newLists = Create-KanbanPreset -BoardId $BoardId
          if ($newLists.Count -gt 0) {
            $lists = Invoke-TrelloGet "$script:Base/boards/$BoardId/lists?fields=name,id,pos"
            Write-Host "`n✅ Listes Kanban créées et rechargées" -ForegroundColor Green
          } else {
            Write-Host "❌ Aucune liste n'a été créée" -ForegroundColor Red
            return $null
          }
        } elseif ($choice -eq "2") {
          # Listes simples
          $newLists = Create-DefaultLists -BoardId $BoardId
          if ($newLists.Count -gt 0) {
            $lists = Invoke-TrelloGet "$script:Base/boards/$BoardId/lists?fields=name,id,pos"
            Write-Host "`n✅ Listes créées et rechargées" -ForegroundColor Green
          } else {
            Write-Host "❌ Aucune liste n'a été créée" -ForegroundColor Red
            return $null
          }
        } elseif ($choice -eq "3") {
          # Listes personnalisées
          Write-Host "Création personnalisée des listes..." -ForegroundColor Cyan
          $customLists = @()
          do {
            $listName = Read-Host "`nNom de la liste (ou laissez vide pour terminer)"
            if (-not [string]::IsNullOrWhiteSpace($listName)) {
              $list = New-TrelloList -BoardId $BoardId -Name $listName
              if ($list) {
                $customLists += $list
              }
              Start-Sleep -Milliseconds 300
            }
          } while (-not [string]::IsNullOrWhiteSpace($listName))
          
          if ($customLists.Count -gt 0) {
            $lists = Invoke-TrelloGet "$script:Base/boards/$BoardId/lists?fields=name,id,pos"
            Write-Host "`n✅ $($customLists.Count) liste(s) créée(s)" -ForegroundColor Green
          } else {
            Write-Host "❌ Aucune liste n'a été créée" -ForegroundColor Red
            return $null
          }
        } else {
          Write-Host "❌ Impossible de continuer sans liste" -ForegroundColor Red
          return $null
        }
      } else {
        return $null
      }
    }
    
    # Afficher les listes
    Write-Host "`nListes disponibles sur le board :" -ForegroundColor Cyan
    if ($AllowCreate) {
      Write-Host "[0] 🆕 Créer une nouvelle liste" -ForegroundColor White
    }
    
    $i = 1
    foreach ($list in $lists) {
      Write-Host ("[{0}] {1}" -f $i, $list.name) -ForegroundColor White
      $i++
    }
    
    $maxChoice = $lists.Count
    $minChoice = if ($AllowCreate) { 0 } else { 1 }
    $choice = Read-Host "`nSélectionnez le numéro de la liste ($minChoice-$maxChoice)"
    $index = [int]$choice
    
    # Option : Créer une nouvelle liste
    if ($index -eq 0 -and $AllowCreate) {
      $newListName = Read-Host "Nom de la nouvelle liste"
      if (-not [string]::IsNullOrWhiteSpace($newListName)) {
        $newList = New-TrelloList -BoardId $BoardId -Name $newListName
        if ($newList) {
          Write-Host "✅ Liste créée et sélectionnée : $($newList.name)" -ForegroundColor Green
          return $newList
        } else {
          Write-Warning "Échec de la création. Sélection d'une liste existante..."
          return Select-ListFromBoard -BoardId $BoardId -AllowCreate $false
        }
      } else {
        Write-Warning "Nom de liste vide. Sélection d'une liste existante..."
        return Select-ListFromBoard -BoardId $BoardId -AllowCreate $false
      }
    }
    
    # Sélection d'une liste existante
    $index = $index - 1
    if ($index -ge 0 -and $index -lt $lists.Count) {
      $selectedList = $lists[$index]
      Write-Host "✅ Liste sélectionnée : $($selectedList.name)" -ForegroundColor Green
      return $selectedList
    } else {
      throw "Sélection invalide"
    }
    
  } catch {
    Write-Warning "Erreur lors de la récupération des listes : $_"
    return $null
  }
}

# ============================================================================
# FONCTIONS DE GESTION DES LABELS
# ============================================================================

function Get-BoardLabels {
  param([string]$BoardId)
  Invoke-TrelloGet "$script:Base/boards/$BoardId/labels?fields=name,color&limit=1000"
}

function Ensure-Label {
  param(
    [string]$BoardId,
    [ref]$ExistingLabels,
    [string]$Name,
    [string]$Color
  )
  
  $labels = $ExistingLabels.Value
  
  # Chercher label existant par nom
  $hit = $labels | Where-Object { $_.name -and ($_.name -ieq $Name) } | Select-Object -First 1
  if ($hit) {
    Write-Host "  ✅ Label existant trouvé : '$Name'" -ForegroundColor Green
    return $hit.id
  }
  
  # Créer le label
  Write-Host "  🎯 Création du label : '$Name' (couleur: $Color)" -ForegroundColor Cyan
  try {
    $newLabel = Invoke-TrelloPost -Uri "$script:Base/labels" -Body @{
      name = $Name
      color = $Color
      idBoard = $BoardId
    }
    
    Write-Host "  ✅ Label créé avec succès (ID: $($newLabel.id))" -ForegroundColor Green
    
    # Ajouter à la liste des labels existants
    $ExistingLabels.Value = @($labels) + @($newLabel)
    return $newLabel.id
  } catch {
    Write-Warning "  ⚠️ Impossible de créer le label : $_"
    return $null
  }
}

function Select-LabelFromBoard {
  param([string]$BoardId)
  
  Write-Host "`n🏷️ Récupération des labels disponibles..." -ForegroundColor Cyan
  $labels = Get-BoardLabels -BoardId $BoardId
  
  if ($labels) {
    Write-Host "✅ $($labels.Count) label(s) trouvé(s) sur le board" -ForegroundColor Green
  } else {
    Write-Host "✅ 0 label(s) trouvé(s) sur le board" -ForegroundColor Yellow
    $labels = @()
  }
  
  Write-Host "`nLabels disponibles sur le board :" -ForegroundColor Cyan
  Write-Host "[0] Créer un nouveau label" -ForegroundColor White
  
  $i = 1
  foreach ($label in $labels) {
    $labelName = if ($label.name) { $label.name } else { "Sans nom" }
    Write-Host ("[{0}] {1} (couleur: {2})" -f $i, $labelName, $label.color) -ForegroundColor White
    $i++
  }
  
  $choice = Read-Host "`nSélectionnez le numéro du label (0-$($labels.Count))"
  $index = [int]$choice
  
  # Option : Créer un nouveau label
  if ($index -eq 0) {
    Write-Host "✅ Création d'un nouveau label" -ForegroundColor Green
    $labelName = Read-Host "Nom du nouveau label"
    Write-Host "Couleurs disponibles : yellow, purple, blue, red, green, orange, black, sky, pink, lime, null" -ForegroundColor Gray
    $labelColor = Read-Host "Couleur du label"
    
    Write-Host "`n🎯 Gestion du label : '$labelName' (couleur: $labelColor)" -ForegroundColor Cyan
    $labelId = Ensure-Label -BoardId $BoardId -ExistingLabels ([ref]$labels) -Name $labelName -Color $labelColor
    
    if ($labelId) {
      Write-Host "✅ Label prêt à être utilisé" -ForegroundColor Green
      return @{ id = $labelId; name = $labelName; color = $labelColor }
    } else {
      Write-Warning "Échec de la création du label"
      return $null
    }
  }
  
  # Sélection d'un label existant
  $index = $index - 1
  if ($index -ge 0 -and $index -lt $labels.Count) {
    $selectedLabel = $labels[$index]
    Write-Host "✅ Label sélectionné : $($selectedLabel.name)" -ForegroundColor Green
    return $selectedLabel
  } else {
    Write-Warning "Sélection invalide"
    return $null
  }
}

# ============================================================================
# FONCTIONS DE CRÉATION DE CARTES
# ============================================================================

function New-TrelloCard {
  param(
    [string]$ListId,
    [string]$Name,
    [string]$Desc,
    [string[]]$LabelIds
  )
  
  $body = @{
    name = $Name
    desc = $Desc
    idList = $ListId
  }
  
  if ($LabelIds -and $LabelIds.Count -gt 0) {
    $body.idLabels = ($LabelIds -join ",")
  }
  
  Invoke-TrelloPost -Uri "$script:Base/cards" -Body $body
}

function New-TrelloChecklist {
  param(
    [string]$CardId,
    [string]$Name
  )
  
  $escapedName = [uri]::EscapeDataString($Name)
  $authQuery = "key=$script:Key&token=$script:Token"
  Invoke-RestMethod -Uri "$script:Base/cards/$CardId/checklists?name=$escapedName&$authQuery" -Method Post
}

function Add-TrelloCheckItem {
  param(
    [string]$ChecklistId,
    [string]$Name,
    [bool]$Checked = $false
  )
  
  $checkedStr = if ($Checked) { "true" } else { "false" }
  
  Invoke-TrelloPost -Uri "$script:Base/checklists/$ChecklistId/checkItems" -Body @{
    name = $Name
    pos = "bottom"
    checked = $checkedStr
  }
}

function Create-CustomCard {
  param(
    [string]$ListId,
    [string]$BoardId,
    [ref]$ExistingLabels
  )
  
  Write-Host "`n🎴 Création d'une carte personnalisée" -ForegroundColor Cyan
  
  # Nom de la carte
  $cardName = Read-Host "Nom de la carte"
  if ([string]::IsNullOrWhiteSpace($cardName)) {
    Write-Warning "Nom vide, carte ignorée"
    return $null
  }
  
  # Description
  Write-Host "Description de la carte (laissez vide pour ignorer) :" -ForegroundColor Gray
  $cardDesc = Read-Host
  
  # Labels
  Write-Host "`nVoulez-vous ajouter des labels à cette carte ? (O/n)" -ForegroundColor Yellow
  $addLabels = Read-Host
  $labelIds = @()
  
  if ($addLabels -eq "" -or $addLabels -eq "O" -or $addLabels -eq "o") {
    do {
      Write-Host "`nLabels existants :" -ForegroundColor Cyan
      $labels = $ExistingLabels.Value
      $i = 0
      Write-Host "[$i] Terminer (ne plus ajouter de labels)" -ForegroundColor White
      $i = 1
      foreach ($lbl in $labels) {
        $lblName = if ($lbl.name) { $lbl.name } else { "Sans nom" }
        Write-Host "[$i] $lblName (couleur: $($lbl.color))" -ForegroundColor White
        $i++
      }
      Write-Host "[$i] Créer un nouveau label" -ForegroundColor White
      
      $labelChoice = Read-Host "Sélectionnez un label (0-$i)"
      $labelIdx = [int]$labelChoice
      
      if ($labelIdx -eq 0) {
        break
      } elseif ($labelIdx -eq $i) {
        # Créer nouveau label
        $newLabelName = Read-Host "Nom du nouveau label"
        Write-Host "Couleurs : yellow, purple, blue, red, green, orange, black, sky, pink, lime, null" -ForegroundColor Gray
        $newLabelColor = Read-Host "Couleur"
        
        $newLabelId = Ensure-Label -BoardId $BoardId -ExistingLabels $ExistingLabels -Name $newLabelName -Color $newLabelColor
        if ($newLabelId) {
          $labelIds += $newLabelId
          Write-Host "✅ Label ajouté à la carte" -ForegroundColor Green
        }
      } elseif ($labelIdx -ge 1 -and $labelIdx -lt $i) {
        $selectedLabel = $labels[$labelIdx - 1]
        $labelIds += $selectedLabel.id
        Write-Host "✅ Label '$($selectedLabel.name)' ajouté" -ForegroundColor Green
      }
      
      $moreLabels = Read-Host "Ajouter un autre label ? (O/n)"
    } while ($moreLabels -eq "" -or $moreLabels -eq "O" -or $moreLabels -eq "o")
  }
  
  # Créer la carte
  try {
    $card = New-TrelloCard -ListId $ListId -Name $cardName -Desc $cardDesc -LabelIds $labelIds
    Write-Host "✅ Carte '$cardName' créée avec succès" -ForegroundColor Green
    
    # Ajouter une checklist ?
    Write-Host "`nVoulez-vous ajouter une checklist ? (O/n)" -ForegroundColor Yellow
    $addChecklist = Read-Host
    
    if ($addChecklist -eq "" -or $addChecklist -eq "O" -or $addChecklist -eq "o") {
      $checklistName = Read-Host "Nom de la checklist (défaut: Tâches)"
      if ([string]::IsNullOrWhiteSpace($checklistName)) {
        $checklistName = "Tâches"
      }
      
      $checklist = New-TrelloChecklist -CardId $card.id -Name $checklistName
      Write-Host "📋 Checklist '$checklistName' créée" -ForegroundColor Gray
      
      Write-Host "Ajoutez des tâches (laissez vide pour terminer) :" -ForegroundColor Gray
      $taskCount = 0
      do {
        $taskName = Read-Host "Tâche"
        if (-not [string]::IsNullOrWhiteSpace($taskName)) {
          Add-TrelloCheckItem -ChecklistId $checklist.id -Name $taskName | Out-Null
          $taskCount++
        }
      } while (-not [string]::IsNullOrWhiteSpace($taskName))
      
      if ($taskCount -gt 0) {
        Write-Host "✅ $taskCount tâche(s) ajoutée(s)" -ForegroundColor Green
      }
    }
    
    return $card
  } catch {
    Write-Host "❌ Erreur lors de la création : $_" -ForegroundColor Red
    return $null
  }
}

# ============================================================================
# SPÉCIFICATIONS DES CARTES PAR DÉFAUT
# ============================================================================

$CardsSpec = @(
  [PSCustomObject]@{
    Name = "KPI par rôle"
    Desc = @"
Créer des KPIs spécifiques pour chaque rôle dans le dashboard.

# Rôles à couvrir
- Administrateur
- Manager
- Utilisateur standard
- Client externe

# Métriques par rôle
Définir les métriques pertinentes pour chaque profil.
"@
    Tasks = @(
      "Identifier les rôles dans l'application",
      "Définir les KPIs pour chaque rôle",
      "Créer les requêtes de données nécessaires",
      "Implémenter l'affichage conditionnel selon le rôle",
      "Tester l'affichage pour chaque profil"
    )
  },
  
  [PSCustomObject]@{
    Name = "Graphes"
    Desc = @"
Intégrer des graphiques interactifs dans le dashboard.

# Types de graphiques
- Courbes d'évolution
- Histogrammes
- Camemberts
- Cartes de chaleur

# Bibliothèque : Chart.js ou Recharts
"@
    Tasks = @(
      "Choisir la bibliothèque de graphiques",
      "Installer les dépendances",
      "Créer les composants de base",
      "Implémenter la récupération de données",
      "Ajouter l'interactivité",
      "Optimiser les performances"
    )
  },
  
  [PSCustomObject]@{
    Name = "Alertes"
    Desc = @"
Système d'alertes pour notifier les événements importants.

# Types d'alertes
- Alertes critiques (rouge)
- Avertissements (orange)
- Informations (bleu)
- Succès (vert)

# Canaux de notification
Email, Push, In-app
"@
    Tasks = @(
      "Définir les règles d'alertes",
      "Créer le système de notification",
      "Implémenter l'interface utilisateur",
      "Configurer les canaux (email, push)",
      "Ajouter la gestion des préférences",
      "Tester les différents scénarios"
    )
  }
)

# ============================================================================
# SCRIPT PRINCIPAL
# ============================================================================

try {
  Write-Host @"
  
╔═══════════════════════════════════════════════════════════════╗
║                        AUTOTRELLO                             ║
║          Création automatique de cartes Trello                ║
╚═══════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

  # Configuration
  Get-TrelloConfig
  
  # Vérification de l'authentification
  Write-Host "`n=== VÉRIFICATION DE L'AUTHENTIFICATION ===" -ForegroundColor Cyan
  Write-Host "KEY: $($script:Key.Substring(0,10))..." -ForegroundColor Gray
  Write-Host "TOKEN: $($script:Token.Substring(0,10))..." -ForegroundColor Gray
  Write-Host "Vérification du compte…" -ForegroundColor Gray
  
  $me = Invoke-TrelloGet "$script:Base/members/me"
  Write-Host "✅ Connecté : $($me.fullName) (@$($me.username))" -ForegroundColor Green
  
  # Sélection du board
  Write-Host "`n=== SÉLECTION DU BOARD ===" -ForegroundColor Cyan
  $board = Resolve-Board -Input ""
  Write-Host "✅ Board : $($board.name) (shortLink=$($board.shortLink))" -ForegroundColor Green
  
  # Sélection de la liste
  $list = Select-ListFromBoard -BoardId $board.id -AllowCreate $true
  if (-not $list) {
    throw "❌ Aucune liste sélectionnée."
  }
  
  # Choix du mode
  Write-Host "`n=== MODE DE CRÉATION ===" -ForegroundColor Cyan
  Write-Host "Choisissez le mode de création des cartes :" -ForegroundColor Yellow
  Write-Host "  [1] Mode par défaut (cartes + labels prédéfinis automatiquement)" -ForegroundColor White
  Write-Host "  [2] Mode personnalisé (création manuelle carte par carte)" -ForegroundColor White
  
  $modeChoice = Read-Host "Votre choix (1/2)"
  
  if ($modeChoice -eq "1") {
    # ========== MODE PAR DÉFAUT ==========
    Write-Host "`n✅ Mode par défaut activé" -ForegroundColor Green
    Write-Host "Les labels et cartes seront créés automatiquement avec la configuration prédéfinie." -ForegroundColor Gray
    
    # Récupérer les labels existants
    $existingLabels = Get-BoardLabels -BoardId $board.id
    if (-not $existingLabels) {
      $existingLabels = @()
    }
    
    # Map des couleurs de labels
    $LabelColorMap = @{
      "Dashboard" = "blue"
      "KPI" = "green"
      "Graphiques" = "orange"
      "Alertes" = "red"
    }
    
    # Création des cartes avec leurs labels
    Write-Host "`n=== CRÉATION DES CARTES (MODE PAR DÉFAUT) ===" -ForegroundColor Cyan
    $created = @()
    $errors = @()
    
    $i = 1
    foreach ($spec in $CardsSpec) {
      Write-Host "[$i/$($CardsSpec.Count)] $($spec.Name)" -ForegroundColor Yellow
      
      try {
        # Déterminer le label pour cette carte
        $labelName = switch ($spec.Name) {
          "KPI par rôle" { "KPI" }
          "Graphes" { "Graphiques" }
          "Alertes" { "Alertes" }
          default { "Dashboard" }
        }
        $labelColor = $LabelColorMap[$labelName]
        
        # Créer/récupérer le label
        $labelId = Ensure-Label -BoardId $board.id -ExistingLabels ([ref]$existingLabels) -Name $labelName -Color $labelColor
        
        # Créer la carte
        $labelIds = if ($labelId) { @($labelId) } else { @() }
        $card = New-TrelloCard -ListId $list.id -Name $spec.Name -Desc $spec.Desc -LabelIds $labelIds
        Write-Host "  ✅ Carte créée" -ForegroundColor Green
        
        # Ajouter le label
        if ($labelId) {
          Write-Host "  🏷️ Label '$labelName' appliqué" -ForegroundColor Gray
        }
        
        # Créer la checklist
        if ($spec.Tasks) {
          $checklist = New-TrelloChecklist -CardId $card.id -Name "Tâches"
          Write-Host "  📋 Checklist créée" -ForegroundColor Gray
          
          foreach ($task in $spec.Tasks) {
            Add-TrelloCheckItem -ChecklistId $checklist.id -Name $task | Out-Null
          }
          Write-Host "  ✅ $($spec.Tasks.Count) tâche(s) ajoutée(s)" -ForegroundColor Gray
        }
        
        $created += $card
      } catch {
        Write-Host "  ❌ Erreur : $_" -ForegroundColor Red
        $errors += @{ Name = $spec.Name; Error = $_ }
      }
      
      $i++
    }
    
  } else {
    # ========== MODE PERSONNALISÉ ==========
    Write-Host "`n✅ Mode personnalisé activé" -ForegroundColor Green
    Write-Host "Vous allez créer les cartes une par une manuellement." -ForegroundColor Gray
    
    # Récupérer les labels existants
    $existingLabels = Get-BoardLabels -BoardId $board.id
    if (-not $existingLabels) {
      $existingLabels = @()
    }
    
    Write-Host "`n=== CRÉATION DES CARTES (MODE PERSONNALISÉ) ===" -ForegroundColor Cyan
    $created = @()
    $errors = @()
    
    do {
      $card = Create-CustomCard -ListId $list.id -BoardId $board.id -ExistingLabels ([ref]$existingLabels)
      
      if ($card) {
        $created += $card
      }
      
      Write-Host "`nCréer une autre carte ? (O/n)" -ForegroundColor Yellow
      $continueCreating = Read-Host
      
    } while ($continueCreating -eq "" -or $continueCreating -eq "O" -or $continueCreating -eq "o")
  }
  
  # Résumé
  Write-Host "`n=== RÉCAP ===" -ForegroundColor Cyan
  Write-Host "✅ Créées: $($created.Count) | ❌ Erreurs: $($errors.Count)" -ForegroundColor $(if ($errors.Count -eq 0) { "Green" } else { "Yellow" })
  
  if ($created.Count -gt 0) {
    Write-Host "`n--- CARTES CRÉÉES ---" -ForegroundColor Green
    $created | Format-Table @{
      Label = "Title"
      Expression = { $_.name }
    }, @{
      Label = "Url"
      Expression = { $_.shortUrl }
    } -AutoSize
  }
  
  if ($errors.Count -gt 0) {
    Write-Host "`n--- ERREURS ---" -ForegroundColor Red
    foreach ($err in $errors) {
      Write-Host "❌ $($err.Name) : $($err.Error)" -ForegroundColor Red
    }
  }
  
  Write-Host "`n🎉 Script terminé avec succès !" -ForegroundColor Green
  
} catch {
  Write-Host "`n❌ ERREUR FATALE" -ForegroundColor Red
  Write-Host $_ -ForegroundColor Red
  
  if ($_.Exception.Response) {
    try {
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      $errBody = $reader.ReadToEnd()
      Write-Host "Détails de l'erreur API :" -ForegroundColor Yellow
      Write-Host $errBody -ForegroundColor Red
    } catch {}
  }
  
  throw
}