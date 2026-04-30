
SET client_encoding = 'UTF8';
-- =================================================================
-- NETTOYAGE (DROP) - A AJOUTER AU DÉBUT DU FICHIER
-- =================================================================
DROP VIEW IF EXISTS VUES_VERIFICATION_AVIS CASCADE;
DROP VIEW IF EXISTS VUES_STATS_SPECIALITES CASCADE;
DROP VIEW IF EXISTS VUES_RELEVE_HEBDO_VILLES CASCADE;
DROP VIEW IF EXISTS VUES_RELEVE_HEBDO_STATS CASCADE;

DROP TABLE IF EXISTS Avis CASCADE;
DROP TABLE IF EXISTS Commande_Plat CASCADE;
DROP TABLE IF EXISTS Commande CASCADE;
DROP TABLE IF EXISTS Menu CASCADE;
DROP TABLE IF EXISTS Plat CASCADE;
DROP TABLE IF EXISTS Resto_MotsCles CASCADE;
DROP TABLE IF EXISTS MotsCles CASCADE;
DROP TABLE IF EXISTS Restaurant CASCADE;
DROP TABLE IF EXISTS Livreur_Ville CASCADE;
DROP TABLE IF EXISTS Livreur CASCADE;
DROP TABLE IF EXISTS Client CASCADE;
DROP TABLE IF EXISTS Adresse CASCADE;
DROP TABLE IF EXISTS Ville CASCADE;

DROP TYPE IF EXISTS statut_cmd CASCADE;
DROP TYPE IF EXISTS etat_livreur CASCADE;

-- =================================================================
-- CRÉATION DES TYPES ENUM 
-- =================================================================
CREATE TYPE etat_livreur AS ENUM('hors_service', 'en_service_attente', 'en_service_course');
CREATE TYPE statut_cmd AS ENUM('en_attente', 'en_preparation', 'en_livraison', 'livree', 'annulee');

-- =================================================================
-- CRÉATION DES TABLES
-- =================================================================

CREATE TABLE Ville (
  id_ville SERIAL PRIMARY KEY, 
  nom_ville VARCHAR(100) NOT NULL,
  code_postal VARCHAR(10) NOT NULL
);

CREATE TABLE Adresse (
  id_adresse SERIAL PRIMARY KEY, 
  num_rue VARCHAR(20),
  nom_rue VARCHAR(255) NOT NULL,
  id_ville INT NOT NULL,
  FOREIGN KEY (id_ville) REFERENCES Ville(id_ville) ON DELETE RESTRICT
);

CREATE TABLE Client (
  id_client SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL, 
  mot_de_passe VARCHAR(255) NOT NULL,
  nom VARCHAR(100), 
  prenom VARCHAR(100), 
  telephone VARCHAR(20),
  carte_bancaire VARCHAR(255), 
  points_fidelite INT DEFAULT 0, 
  id_adresse INT NOT NULL,
  id_parrain INT NULL, 
  FOREIGN KEY (id_adresse) REFERENCES Adresse(id_adresse) ON DELETE RESTRICT,
  FOREIGN KEY (id_parrain) REFERENCES Client(id_client) ON DELETE SET NULL
);

CREATE TABLE Livreur (
  id_livreur SERIAL PRIMARY KEY, 
  matricule VARCHAR(50) UNIQUE NOT NULL,
  mot_de_passe VARCHAR(255) NOT NULL, 
  nom VARCHAR(100),
  prenom VARCHAR(100),
  telephone VARCHAR(20), 
  etat_service etat_livreur DEFAULT 'hors_service' NOT NULL 
);

CREATE TABLE Livreur_Ville (
  id_livreur INT NOT NULL,
  id_ville INT NOT NULL,
  PRIMARY KEY (id_livreur, id_ville),
  FOREIGN KEY (id_livreur) REFERENCES Livreur(id_livreur) ON DELETE CASCADE,
  FOREIGN KEY (id_ville) REFERENCES Ville(id_ville) ON DELETE CASCADE
);

CREATE TABLE Restaurant (
  id_resto SERIAL PRIMARY KEY, 
  nom VARCHAR(255) NOT NULL, 
  horaires VARCHAR(255), 
  frais_livraison DECIMAL(5, 2) NOT NULL, 
  statut_exceptionnel BOOLEAN DEFAULT FALSE NOT NULL, 
  photo_url VARCHAR(255),
  id_adresse INT NOT NULL, 
  FOREIGN KEY (id_adresse) REFERENCES Adresse(id_adresse) ON DELETE RESTRICT
);


CREATE TABLE MotsCles (
  libelle_mot_cle VARCHAR(100) PRIMARY KEY 
);

CREATE TABLE Resto_MotsCles (
  id_resto INT NOT NULL,
  libelle_mot_cle VARCHAR(100) NOT NULL,
  PRIMARY KEY (id_resto, libelle_mot_cle),
  FOREIGN KEY (id_resto) REFERENCES Restaurant(id_resto) ON DELETE CASCADE,
  FOREIGN KEY (libelle_mot_cle) REFERENCES MotsCles(libelle_mot_cle) ON DELETE CASCADE
);

CREATE TABLE Plat (
  id_plat SERIAL PRIMARY KEY, 
  nom VARCHAR(255) NOT NULL, 
  prix DECIMAL(6, 2) NOT NULL, 
  description TEXT, 
  photo_url VARCHAR(255) 
);

CREATE TABLE Menu (
  id_resto INT NOT NULL,
  id_plat INT NOT NULL,
  PRIMARY KEY (id_resto, id_plat),
  FOREIGN KEY (id_resto) REFERENCES Restaurant(id_resto) ON DELETE CASCADE,
  FOREIGN KEY (id_plat) REFERENCES Plat(id_plat) ON DELETE CASCADE
);

CREATE TABLE Commande (
  id_commande SERIAL PRIMARY KEY, 
  date_heure_commande TIMESTAMPTZ NOT NULL, 
  date_heure_livraison TIMESTAMPTZ NULL,
  statut_commande statut_cmd NOT NULL DEFAULT 'en_attente', 
  montant_total DECIMAL(8, 2) NOT NULL, 
  id_client INT NOT NULL,
  id_livreur INT NULL,
  id_resto INT NOT NULL,
  FOREIGN KEY (id_client) REFERENCES Client(id_client) ON DELETE RESTRICT,
  FOREIGN KEY (id_livreur) REFERENCES Livreur(id_livreur) ON DELETE SET NULL,
  FOREIGN KEY (id_resto) REFERENCES Restaurant(id_resto) ON DELETE RESTRICT
);

CREATE TABLE Commande_Plat (
  id_commande INT NOT NULL,
  id_plat INT NOT NULL,
  quantite INT NOT NULL, 
  montant_plat DECIMAL(6, 2) NOT NULL,
  PRIMARY KEY (id_commande, id_plat),
  FOREIGN KEY (id_commande) REFERENCES Commande(id_commande) ON DELETE CASCADE,
  FOREIGN KEY (id_plat) REFERENCES Plat(id_plat) ON DELETE RESTRICT
);

CREATE TABLE Avis (
  id_avis SERIAL PRIMARY KEY, 
  note INT NOT NULL CHECK (note >= 0 AND note <= 5), 
  commentaire TEXT,
  id_client INT NOT NULL,
  id_commande INT NOT NULL UNIQUE,
  FOREIGN KEY (id_client) REFERENCES Client(id_client) ON DELETE CASCADE,
  FOREIGN KEY (id_commande) REFERENCES Commande(id_commande) ON DELETE CASCADE
);

-- =================================================================
-- CRÉATION DES VUES 
-- =================================================================

CREATE VIEW VUES_RELEVE_HEBDO_STATS AS(
SELECT
  COUNT(id_commande) AS nombre_commandes_semaine,
  AVG(montant_total) AS prix_moyen_commande_semaine
FROM Commande
WHERE
  date_heure_commande >= CURRENT_DATE - INTERVAL '7 DAY' 
);

CREATE VIEW VUES_RELEVE_HEBDO_VILLES AS (
SELECT
  V.nom_ville,
  COUNT(C.id_commande) AS total_commandes
FROM Commande C
JOIN Client CL ON C.id_client = CL.id_client
JOIN Adresse A ON CL.id_adresse = A.id_adresse
JOIN Ville V ON A.id_ville = V.id_ville
WHERE
  C.date_heure_commande >= CURRENT_DATE - INTERVAL '7 DAY' 
GROUP BY
  V.nom_ville
ORDER BY
  total_commandes DESC
);

CREATE VIEW VUES_STATS_SPECIALITES AS(
SELECT
  MC.libelle_mot_cle AS specialite,
  COUNT(DISTINCT C.id_commande) AS total_commandes_associees
FROM MotsCles MC
JOIN Resto_MotsCles RMC ON MC.libelle_mot_cle = RMC.libelle_mot_cle
JOIN Commande C ON RMC.id_resto = C.id_resto
GROUP BY
  MC.libelle_mot_cle
ORDER BY
  total_commandes_associees DESC
);

CREATE VIEW VUES_VERIFICATION_AVIS AS(
SELECT
  C.id_commande,
  C.montant_total AS prix_commande,
  AV.id_avis,
  AV.note,
  CL.id_client,
  V.nom_ville AS ville_client,
  C.id_resto
FROM Avis AV
JOIN Commande C ON AV.id_commande = C.id_commande
JOIN Client CL ON AV.id_client = CL.id_client
JOIN Adresse A ON CL.id_adresse = A.id_adresse
JOIN Ville V ON A.id_ville = V.id_ville
);

-- =================================================================
-- INSERTION DES DONNÉES 
-- =================================================================

-- 1. Villes
INSERT INTO Ville (nom_ville, code_postal) VALUES
('Paris', '75011'),
('Lyon', '69001'),
('Champs-sur-Marne', '77420'),
('Noisy-Le-Grand','93160'),
('Torcy','77200'),
('Bruyères-sur-Oise','95820'),
('Rosny-sous-Bois','93110'),
('Clichy-sous-Bois','93390'),
('Marseille', '13001'),
('Lille', '59000');

-- 2. Adresses
INSERT INTO Adresse (num_rue, nom_rue, id_ville) VALUES
('12', 'Rue Oberkampf', 1), 
('5', 'Place des Terreaux', 2), 
('31', 'Avenue des Tilleuls', 3), 
('10', 'Rue Mercière', 2),
('33','Avenue André-Marie Ampère',3),
('35','Avenue André-Marie Ampère',3),
('4','Allée Francis Poulenc',7),
('3','Allée des Tirailleurs Africains',8),
('10', 'Vieux Port', 9),
('15', 'Rue de la République', 2),
('1', 'Grand Place', 10),
('8', 'Rue de Paris', 1),
('14', 'Allée du Tacos', 7),
('22', 'Rue de Siam', 1),
('8', 'Boulevard de la Crêpe', 3),
('9', 'Rue du Liban', 2);
-- 3. Clients
/*(1, 'jean.dupont@mail.com', 'Bla12425', 'Dupont', 'Jean', '0123456789', 'cb_jean_dupont', 0, 1, NULL),
(2, 'marie.martin@mail.com', '123456', 'Martin', 'Marie', '0987654321', 'cb_marie_martin', 0, 2, 1),
(3, 'abi.pack@mail.com', 'Azerty', 'Abi', 'Packi', '0712345678', 'cb_abi_packi', 10, 7, NULL),
(4, 'danny.mith21@mail.com', 'Azerty93', 'Danny', 'MITH', '0712345358', 'cb_danny_mith', 50,8, NULL),
(5, 'bileb@gmail.com', 'campagnard', 'Bileb', 'Tarnagada', '0712456312', 'cb_bileb_tarnagada', 10, 6, NULL),
(6, 'pierre@gmail.com', 'villageois2018', 'pierre', 'jean', '0712451256', 'cb_pierre_jean', 0, 5, NULL),
(7, 'luc.durand@mail.com', 'Pass789', 'Durand', 'Luc', '0612121212', 'cb_luc', 20, 9, 1),
(8, 'claire.leroy@mail.com', 'Claire!45', 'Leroy', 'Claire', '0634343434', 'cb_claire', 0, 11, 2),
(9, 'paul.moreau@mail.com', 'PaulPaul', 'Moreau', 'Paul', '0656565656', 'cb_paul', 5, 12, NULL),
(10, 'sophie.petit@mail.com', 'Sophie2025', 'Petit', 'Sophie', '0678787878', 'cb_sophie', 100, 17, 7);*/
-- 3. Clients
INSERT INTO Client (email, mot_de_passe, nom, prenom, telephone, carte_bancaire, points_fidelite, id_adresse, id_parrain) VALUES
('jean.dupont@mail.com', '$2b$12$HRm35dyczXAAN01QOWORMOrtvwGaNARPCpvRYI.iTz7mgJJ/G6fXu', 'Dupont', 'Jean', '0123456789', 'cb_jean_dupont', 0, 1, NULL),
('marie.martin@mail.com', '$2b$12$a3GyDTcWxdO.XLkuQQIxBO6v59ri9oIfU.bscKrJM.784rLSgnHzm', 'Martin', 'Marie', '0987654321', 'cb_marie_martin', 0, 2, 1),
('abi.pack@mail.com', '$2b$12$Zuy6rQs/3uD/jQZB2a3nqeCL5xL9xi62EOE0jdNYqSyycu4ZB4NUi', 'Abi', 'Packi', '0712345678', 'cb_abi_packi', 10, 7, NULL),
('danny.mith21@mail.com', '$2b$12$4xOUvRW8NNzZs.OObM12K.T162ABCgZFWY9WFB3udyFxYeffg8qLm', 'Danny', 'MITH', '0712345358', 'cb_danny_mith', 50, 8, NULL),
('bileb@gmail.com', '$2b$12$Kb72IWEgHvJes3uGjFa76eALzz/pabOhDwEMWhRWVv0kf5Ctf.Vi6', 'Bileb', 'Tarnagada', '0712456312', 'cb_bileb_tarnagada', 10, 6, NULL),
('pierre@gmail.com', '$2b$12$H4RSZEzHW5F6eqDMvhECp.Llrc6nwBXUQZ.4LybFG6zg6H2Nsb3hq', 'pierre', 'jean', '0712451256', 'cb_pierre_jean', 0, 5, NULL),
('luc.durand@mail.com', '$2b$12$GJx.k2N7OCRGPM/IHfrchep9qSIZuSPFMv1eubOBKi1xN2ZgDc8s6', 'Durand', 'Luc', '0612121212', 'cb_luc', 20, 9, 1),
('claire.leroy@mail.com', '$2b$12$qzNcBquSyt9FRJggSnDaOeuixN06z8hHzIBSRvPyF1vmWUgWBmsmG', 'Leroy', 'Claire', '0634343434', 'cb_claire', 0, 10, 2),
('paul.moreau@mail.com', '$2b$12$t.oA0EqzIfCnxGUKPA9eUOzG0RCL3oE84qHpipeP1l6brTP1qi.zy', 'Moreau', 'Paul', '0656565656', 'cb_paul', 5, 11, NULL),
('sophie.petit@mail.com', '$2b$12$WLbeSk0YYkpGO.m6URjUX.BZ6Okk/tqLWwbkyHqFohUh1.tS4lMrW', 'Petit', 'Sophie', '0678787878', 'cb_sophie', 100, 12, 7);

-- 4. Livreurs
/*
INSERT INTO Livreur (matricule, mot_de_passe, nom, prenom, telephone, etat_service) VALUES
('LIVR-001', '12rm091994', 'Durand', 'Paul', '0611223344', 'en_service_attente'),
('LIVR-002', 'SamanthaH.1704', 'Petit', 'Lucie', '0655667788', 'hors_service'),
('LIVR-003', 'Dannyintelligent2.0', 'Garnier', 'Alex', '0612345601', 'en_service_course'),
('LIVR-004', 'Azerty9', 'Moreau', 'Julie', '0612345602', 'en_service_attente'),
('LIVR-005', 'ABC12345', 'Simon', 'Lucas', '0612345603', 'hors_service'),
('LIVR-006', 'Village123', 'Lefevre', 'Emma', '0612345604', 'en_service_attente'),
('LIVR-007', 'CACALAND0111', 'Robert', 'Adam', '0612345605', 'en_service_course'),
('LIVR-008', 'Pipiproute', 'Richard', 'Camille', '0612345606', 'hors_service'),
('LIVR-009', 'Popotin21', 'Blanc', 'Hugo', '0612345607', 'en_service_attente'),
('LIVR-010', 'PouletMayo', 'David', 'Sarah', '0612345608', 'en_service_attente');
*/
INSERT INTO Livreur (matricule, mot_de_passe, nom, prenom, telephone, etat_service) VALUES
('LIVR-001', '$2b$12$O4jGV.bUSDcDOoMLtMhGEODhIeoqp2BX92cUoNR4dXIs5T4/LHCfa', 'Durand', 'Paul', '0611223344', 'en_service_attente'),
('LIVR-002', '$2b$12$y2p/oy.kSwLdZeRL5jmKO.ZpN2SWuKP2IDZObwLXGAtzufcbh/Vn2', 'Petit', 'Lucie', '0655667788', 'hors_service'),
('LIVR-003', '$2b$12$rnnXDsdZE4iT/fw9c7YY4ejtlsFRgTPyXKB3Z8ZOfIJiz1CrYBk8G', 'Garnier', 'Alex', '0612345601', 'en_service_course'),
('LIVR-004', '$2b$12$Zc/0gczniMYb2EsgOyyySuG3qJds7RjmGr9TQAh5fggy3DhIU45du', 'Moreau', 'Julie', '0612345602', 'en_service_attente'),
('LIVR-005', '$2b$12$IkqIuUbFjlI2jnjCL5tcCOiUQMoQKP6VQbd0eKVN8EqgrCX1IghOe', 'Simon', 'Lucas', '0612345603', 'hors_service'),
('LIVR-006', '$2b$12$QS1fvNqZuT.lnAxVyk4AgO4JQkO4ZzOBdFw1bNJEfUxs4fjcWxeF.', 'Lefevre', 'Emma', '0612345604', 'en_service_attente'),
('LIVR-007', '$2b$12$wmF.Djmi4h0vISI74bWuQOBaUgizrerPbwnXD5rKgAcZHb2K6TsiG', 'Robert', 'Adam', '0612345605', 'en_service_course'),
('LIVR-008', '$2b$12$8ShOq6dqxm7HolOSwwfSLuuJXHKRi54HXcr3QxrMqUWYnKTdo4K/C', 'Richard', 'Camille', '0612345606', 'hors_service'),
('LIVR-009', '$2b$12$ozuo5yPGsykVuYTPCH4d8.7BF4JDwUOXsQQs4mYOOoknN2SHehScm', 'Blanc', 'Hugo', '0612345607', 'en_service_attente'),
('LIVR-010', '$2b$12$346.LvPTKWz/nvjFdssCLOfjka7pB7d2XXsMHHAiR42u2CjVHOSPG', 'David', 'Sarah', '0612345608', 'en_service_attente');

-- 5. Association Livreur <-> Ville
INSERT INTO Livreur_Ville (id_livreur, id_ville) VALUES
(1, 1), (1, 3), (2, 2), (3, 1), (3, 4), (4, 9), (5, 10), (6, 5), (7, 7), (8, 8), (9, 1), (10, 2), (10, 9);


-- 6. Restaurants
INSERT INTO Restaurant (nom, horaires, frais_livraison, statut_exceptionnel, photo_url, id_adresse) VALUES
('Good food, fast food', '11h-23h', 3.50, FALSE, 'burger.jpg', 3),
('Le Bouchon Lyonnais', '12h-14h, 19h-22h', 4.80, FALSE, 'boeuf.jpg', 4),
('Pizza Della Mamma', '18h-23h', 2.50, FALSE, 'pizza.jpg', 5),
('Sushi Zen', '11h-15h, 18h-22h30', 0.00, FALSE, 'sushi.jpg', 6),
('Istanbul Kebab', '11h-00h', 1.50, FALSE, 'kebab.jpg', 7),
('Le Palais du Curry', '12h-14h30, 19h-23h', 3.00, FALSE, 'curry.jpg', 8),
('Burger Factory', '11h-23h', 2.00, FALSE, 'burger2.jpg', 9),
('Chez Mario', '18h-22h', 2.50, FALSE, 'pates.jpg', 10),
('Healthy Salad', '10h-16h', 1.00, FALSE, 'salade.jpg', 11),
('La Table des Canuts', '12h-14h, 19h-21h', 5.00, FALSE, 'Lamia.jpg', 12),
('O''Tacos Loco', '11h-02h', 2.00, TRUE, 'tacos_mix.jpg', 13),
('Siam Gourmet', '12h-15h, 19h-23h', 3.50, FALSE, 'pad_thai.jpg', 14),
('La Crêperie Bretonne', '11h30-21h', 4.00, FALSE, 'creperie.jpg', 15),
('Beirut Kitchen', '11h-22h', 2.50, TRUE, 'meze.jpg', 16);

-- 7. Mots-clés
INSERT INTO MotsCles (libelle_mot_cle) VALUES
('pizza'), ('burger'), ('italien'), ('turc'), ('lyonnais'), ('salade'),
('japonais'), ('sushi'), ('végétalien'), ('indien'), ('chinois'), ('dessert'),('kebab'),
('mexicain'),
('tacos'),
('thaï'),
('épicé'),
('crêpe'),
('français'),
('libanais'),
('végétarien'),
('sans gluten');

-- 8. Association Restaurant <-> Mots-clés
INSERT INTO Resto_MotsCles (id_resto, libelle_mot_cle) VALUES
(1, 'pizza'), (1, 'burger'), (1, 'italien'), (1, 'turc'), 
(2, 'lyonnais'),(2,'dessert'),
(3,'pizza'),(3,'italien'),
(4,'sushi'),(4,'japonais'),
(5,'kebab'),(5,'turc'),
(6,'indien'),(6,'dessert'),
(7,'burger'),(7,'salade'),
(8,'italien'),(8,'végétalien'),
(9,'salade'),(9,'végétalien'),(9,'dessert'),
(10,'salade'),(10,'italien'),
(11, 'tacos'), (11, 'mexicain'), (11, 'burger'),
(12, 'thaï'), (12, 'épicé'), (12, 'chinois'), (12, 'végétalien'),
(13, 'crêpe'), (13, 'français'), (13, 'dessert'),
(14, 'libanais'), (14, 'végétarien'), (14, 'salade'), (14, 'kebab');

-- 9. Plats
INSERT INTO Plat (nom, prix, description, photo_url) VALUES
('Pizza 4 Saisons', 14.00, 'Tomate, mozza, jambon, champignons, olives', 'pizza_4saisons.jpg'),
('Cheeseburger', 12.50, 'Boeuf, cheddar, oignons, cornichons', 'cheeseburger.jpg'),
('Quenelle de Brochet', 19.00, 'Sauce Nantua maison', 'quenelle.jpg'),
('Salade Caesar', 11.00, 'Poulet, parmesan, croûtons', 'salade_caesar.jpg'),
('Sushi Set (12pcs)', 18.00, 'Assortiment de sushis (saumon, thon)', 'sushi_set.jpg'),
('Pizza Kebab', 13.00, 'Base crème, mozza, viande kebab, oignons', 'pizza_kebab.jpg'),
('Butter Chicken', 15.00, 'Poulet tandoori, sauce tomate crémée', 'butter_chicken.jpg'),
('Tiramisu', 6.50, 'Mascarpone, café, biscuits', 'tiramisu.jpg'),
('Coca-Cola (33cl)', 2.50, 'Boisson gazeuse sucrée', 'coca.jpg'),
('Eau Minérale (50cl)', 2.00, 'Eau de source', 'eau.jpg'),
('Poke Bowl Saumon', 14.50, 'Riz vinaigré, saumon, avocat, mangue', 'poke_saumon.jpg'),
('Nems (x4)', 5.50, 'Nems au porc et légumes', 'nems.jpg'),
('Grec des anciens',5,'Grec salade tomate jamais malade !','grec.jpg'),
('Tacos 3 Viandes', 11.50, 'Cordon bleu, tenders, merguez, sauce fromagère', 'tacos.jpg'),
('Nachos Guacamole', 6.00, 'Chips de maïs, guacamole maison, cheddar', 'nachos.jpg'),
('Pad Thaï Crevettes', 13.50, 'Nouilles sautées, crevettes, cacahuètes, citron vert', 'pad_thai2.jpg'),
('Curry Vert Poulet', 14.00, 'Lait de coco, curry vert, bambou, basilic thaï', 'curry_vert.jpg'),
('Galette Complète', 9.50, 'Sarrasin, œuf miroir, jambon, emmental', 'galette.jpg'),
('Crêpe Caramel Beurre Salé', 5.50, 'Crêpe froment, caramel maison', 'crepe_caramel.jpg'),
('Assiette Chawarma', 15.00, 'Émincé de poulet mariné, crème d''ail, pickles', 'chawarma.jpg'),
('Falafels (6pcs)', 7.00, 'Boulettes de pois chiches, sauce tahini', 'falafels.jpg'),
('Taboulé Libanais', 6.50, 'Persil plat, menthe, boulghour, tomates', 'taboule.jpg');

-- 10. Menu
INSERT INTO Menu (id_resto, id_plat) VALUES
(1, 1), (1, 2),(1, 4), (1, 6), (1, 9),(1,13),
(2, 3), (2, 10),
(3, 1), (3, 8), (3, 9), (3, 10),
(4, 5), (4, 11), (4, 12),
(5, 6), (5, 9),(5,13),
(6, 7), (6, 10),
(7, 2), (7, 9), (7, 10),
(8, 1), (8, 8),
(9, 4), (9, 11), (9, 10),
(10, 3), (10, 4), (10, 8),(11, 14), 
(11, 15),(11, 9), 
(12, 16),(12, 17),(12, 12), (12, 10), 
(13, 18),(13, 19), (13, 10), 
(14, 20), (14, 21),(14, 22),(14, 9);

-- 11. Commandes
INSERT INTO Commande (date_heure_commande, date_heure_livraison, statut_commande, montant_total, id_client, id_livreur, id_resto) VALUES
('2025-11-01 19:30:00', '2025-11-01 20:10:00', 'livree', 16.00, 1, 1, 1), 
('2025-11-12 12:15:00', '2025-11-12 12:55:00', 'livree', 23.80, 2, 2, 2), 
('2025-11-13 19:00:00', NULL, 'en_preparation', 18.50, 3, NULL, 3),     
('2025-11-13 20:00:00', NULL, 'en_livraison', 25.00, 4, 3, 4),            
('2025-11-14 12:00:00', '2025-11-14 12:35:00', 'livree', 18.00, 5, 5, 5),  
('2025-11-14 13:00:00', '2025-11-14 13:40:00', 'livree', 19.00, 6, 6, 6),  
('2025-11-14 20:00:00', NULL, 'en_attente', 18.00, 7, NULL, 7),        
('2025-11-14 21:00:00', '2025-11-14 21:30:00', 'livree', 22.00, 8, 8, 8), 
('2025-11-15 11:00:00', NULL, 'en_preparation', 13.50, 9, NULL, 9),       
('2025-11-15 12:00:00', '2025-11-15 12:45:00', 'annulee', 19.00, 10, 10, 10);

-- 12. Contenu des Commandes
INSERT INTO Commande_Plat (id_commande, id_plat, quantite, montant_plat) VALUES
(1, 2, 1, 12.50),
(2, 3, 1, 19.00),
(3, 1, 1, 14.00), (3, 9, 1, 2.50),
(4, 5, 1, 18.00), (4, 10, 1, 2.00),
(5, 6, 1, 13.00), (5, 9, 1, 2.50),
(6, 7, 1, 15.00),
(7, 2, 1, 12.50), (7, 9, 1, 2.50),
(8, 1, 1, 14.00), (8, 8, 1, 6.50),
(9, 4, 1, 11.00),
(10, 3, 1, 19.00);

-- 13. Avis
INSERT INTO Avis (note, commentaire, id_client, id_commande) VALUES
(4, 'Burger très bon, mais livreur un peu en retard.', 1, 1),
(5, 'Excellent! La quenelle était incroyable.', 2, 2),
(3, 'OK, mais kebab un peu froid, dommage.', 5, 5),
(5, 'Très bon plat indien, je recommande.', 6, 6),
(4, 'Bonne pizza, dessert aussi. Livraison rapide.', 8, 8);