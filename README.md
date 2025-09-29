# MySQL-Database-Migration

## Description
Ce projet présente la migration d’une base de données **MySQL hébergée sur une instance Amazon EC2** vers **Amazon RDS for MySQL** en utilisant le service **AWS Database Migration Service (DMS)**.  
L’objectif est de démontrer comment déplacer une base de données autogérée vers une solution managée, tout en minimisant les temps d’arrêt et en garantissant la continuité des opérations.

## Architecture de la solution
L’architecture repose sur :
- Une base de données source MySQL sur **Amazon EC2**.
- Une instance **AWS DMS (Database Migration Service)** jouant le rôle de réplication.
- Une base de données cible sur **Amazon RDS for MySQL**.

Voir ----> (Data-Migration-Architecture.

## Workflow AWS DMS
1. **Créer une instance de réplication**  
   - Lancer une instance de réplication dans AWS DMS.  

2. **Créer les Endpoints source et cible**  
   - Définir l’endpoint de la base source (EC2) et celui de la base cible (RDS).  

3. **Créer la tâche de migration**  
   - Configurer la migration des données existantes et la réplication en temps réel des nouvelles données.  

## Étapes de l’implémentation
1. Création et configuration d’une instance EC2 avec MySQL (base source).  
2. Création de la base cible **Amazon RDS MySQL**.  
3. Mise en place d’une **instance de réplication** via AWS DMS.  
4. Création et test des **endpoints source et cible**.  
5. Lancement de la **tâche de réplication** pour migrer et synchroniser les données.  

## Objectif
- Réduire la complexité de gestion des bases de données autogérées.  
- Bénéficier des fonctionnalités managées d’Amazon RDS : haute disponibilité, sauvegardes automatiques, sécurité et scalabilité.  

## Prérequis
- Un compte AWS actif.  
- Notions de base sur EC2, RDS et DMS.  
- Git pour versionner et publier le projet.  

## Auteur
Projet réalisé par **Galilée.K**
LinkedIn: https://www.linkedin.com/in/kevin-maruis-kamdem-31273a237/ 
