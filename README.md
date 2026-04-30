Voici un modèle de `README.md` structuré et professionnel, basé sur les informations de ton rapport de projet. Il met particulièrement en valeur l'architecture de ta base de données et tes choix techniques.

***

# Enjoy! Restauration à domicile 🍔

Ce projet universitaire consiste en la création d'un site web fonctionnel inspiré d'applications comme UberEats. L'objectif principal est de mettre en relation des restaurants, des livreurs et des clients autour d'un système de commande fluide et efficace. L'interface a été pensée pour être épurée, avec peu de boutons, afin de ne pas perdre l'utilisateur.

## 🎯 Fonctionnalités Principales

### Espace Client
*   Recherche de restaurants grâce à une barre de recherche avancée intégrant des filtres par mots-clés et notes.
*   Prise de commande avec gestion intelligente du panier : sauvegarde temporaire automatique des articles si le client navigue vers un autre restaurant.
*   Possibilité de laisser un avis (unique par commande).
*   Système de parrainage avec attribution de points de fidélité lors de la livraison.
*   Annulation de commande (si celle-ci est toujours "en attente"), avec restitution automatique des points de fidélité.

### Espace Livreur
*   Tableau de bord permettant de visualiser l'ensemble des commandes en attente dans les villes géographiques couvertes par le livreur.
*   Choix libre de la commande à prendre en charge.
*   Gestion des statuts en temps réel (`hors_service`, `en_service_attente`, `en_service_course`).

## 🗄️ Architecture & Modélisation de la Base de Données

Une attention particulière a été portée sur la robustesse du modèle relationnel (PostgreSQL) et l'intégrité des données :

*   **Cœur du système :** L'entité `Commande` centralise l'action, passée par un `Client` à un `Restaurant` et assignée à un `Livreur` (un seul livreur par commande pour simplifier la logistique).
*   **Historisation des prix :** L'association `Commande_Plat` détaille chaque commande et capture le prix exact au moment de l'achat.
*   **Contraintes d'intégrité strictes :** 
    *   Utilisation de clés primaires (`SERIAL`) et d'unicité (ex: `email`, `matricule`).
    *   Gestion fine des clés étrangères (`FOREIGN KEY`) avec des règles de suppression adaptées (`RESTRICT` pour protéger les entités, `CASCADE` pour nettoyer les tables associatives, `SET NULL` pour conserver l'historique).
*   **Typage précis :** Utilisation de types `ENUM` pour sécuriser les statuts (`etat_service`, `statut_commande`), de `DECIMAL(8,2)` pour la précision monétaire, et de contraintes `CHECK` (ex: note des avis obligatoirement comprise entre 0 et 5.

### Vues Analytiques (Reporting)
Quatre vues SQL ont été développées pour l'analyse des données :
1.  `VUES_RELEVE_HEBDO_STATS` : Calcule le nombre total et le prix moyen des commandes sur les 7 derniers jours.
2.  `VUES_RELEVE_HEBDO_VILLES` : Identifie les zones géographiques les plus actives.
3.  `VUES_STATS_SPECIALITES` : Compte les commandes par spécialité culinaire.
4.  `VUES_VERIFICATION_AVIS` : Fournit un export sécurisé pour des vérifications externes.

## 💻 Détails Techniques & Logique Applicative (Back-end)

Le back-end (Python/Flask) gère la logique métier complexe qui ne peut être déléguée à la base de données :

*   **Moteur de recherche dynamique :** La recherche concatène des conditions SQL de manière dynamique (`WHERE 1=1`) et utilise la fonction `COALESCE` pour attribuer une note par défaut (0) aux restaurants non notés.
  
*   **Gestion du Panier via Session :** Le panier utilise une structure de dictionnaire stockée dans la session Flask (avec les `id_plat` comme clés), permettant une recherche et une mise à jour très rapide en mémoire.
  
*   **Sécurité :** Les mots de passe des clients et des livreurs sont hachés à l'aide de la bibliothèque `bcrypt` avant stockage.
  
*   **Inscription en cascade :** L'algorithme d'inscription vérifie l'existence préalable de la ville et de l'adresse avant la création pour éviter toute duplication de données.
