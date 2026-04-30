import db
from flask import Flask, render_template, request, redirect, url_for, session
from passlib.hash import bcrypt
app = Flask(__name__)

app.secret_key = b'33840009dd69bd5e6b02333893181380dc6d5ed16a4a0011878bf532b239a0f2'


@app.route("/")
@app.route("/accueil")
def accueil():
    if "prenom" in session:
        statut_connexion = session["prenom"]
        with db.connect() as conn:
            with conn.cursor() as cur:
                cur.execute("select * from MotsCles")
                mot_cle = cur.fetchall()

                cur.execute("""SELECT R.id_resto, R.nom, R.horaires, R.frais_livraison, R.photo_url,ROUND(AVG(A.note), 1) AS note_moyenne FROM Restaurant R natural join Adresse LEFT JOIN Commande C ON R.id_resto = C.id_resto LEFT JOIN Avis A ON C.id_commande = A.id_commande where id_ville=%s GROUP BY R.id_resto, R.nom, R.horaires, R.frais_livraison, R.photo_url""",(session["id_ville"],))
                result = cur.fetchall()
    else:        
        statut_connexion = None
        
        with db.connect() as conn:
            with conn.cursor() as cur:
                cur.execute("select * from MotsCles")
                mot_cle = cur.fetchall()

                cur.execute("""SELECT R.id_resto, R.nom, R.horaires, R.frais_livraison, R.photo_url,ROUND(AVG(A.note), 1) AS note_moyenne FROM Restaurant R  LEFT JOIN Commande C ON R.id_resto = C.id_resto LEFT JOIN Avis A ON C.id_commande = A.id_commande  GROUP BY R.id_resto, R.nom, R.horaires, R.frais_livraison, R.photo_url""")
                result = cur.fetchall()

    return render_template("accueil.html", restaurants = result,etat_connexion=statut_connexion,mot_cle=mot_cle)

@app.route("/recherche")
def recherche():
    recherche = request.args.get('q')
    note_min = request.args.get('note_min')    
    mot_cle_filter = request.args.get('mot_cle') 
    
    if "prenom" in session:
        statut_connexion = session["prenom"]
    else:
        statut_connexion = None
    
    with db.connect() as conn:
        with conn.cursor() as cur:

            cur.execute("select * from MotsCles")
            liste_mots_cles = cur.fetchall()
            sql = """
                SELECT R.id_resto, R.nom, R.horaires, R.frais_livraison, R.photo_url, 
                       COALESCE(ROUND(AVG(A.note), 1), 0) AS note_moyenne
                FROM Restaurant R
                LEFT JOIN Resto_MotsCles RM ON R.id_resto = RM.id_resto
                LEFT JOIN Commande C ON R.id_resto = C.id_resto
                LEFT JOIN Avis A ON C.id_commande = A.id_commande
                WHERE 1=1 
            """
            param = []

            if recherche:
                sql += " AND R.nom ILIKE %s"
                param.append(f"%{recherche}%")

            if mot_cle_filter:
                sql += " AND RM.libelle_mot_cle = %s"
                param.append(mot_cle_filter)

            sql += " GROUP BY R.id_resto,R.nom,R.horaires,R.frais_livraison,R.photo_url"
            if note_min:
                sql += " HAVING COALESCE(ROUND(AVG(A.note), 1), 0) >= %s"
                param.append(int(note_min))

            cur.execute(sql, tuple(param))
            result = cur.fetchall()

    return render_template("accueil.html", 
                           restaurants=result, 
                           etat_connexion=statut_connexion,
                           mot_cle=liste_mots_cles)



@app.route('/restaurant/<int:id_resto>', methods=["GET"])
def detail_restaurant(id_resto):
    with db.connect() as conn:
        with conn.cursor() as cur:

            requete_info = """
                SELECT R.*, A.num_rue, A.nom_rue, V.nom_ville, V.code_postal
                FROM Restaurant R
                JOIN Adresse A ON R.id_adresse = A.id_adresse
                JOIN Ville V ON A.id_ville = V.id_ville
                WHERE R.id_resto = %s
            """
            cur.execute(requete_info, (id_resto,))
            infos = cur.fetchone()

            requete_menu = """
                SELECT P.* FROM Plat P
                JOIN Menu M ON P.id_plat = M.id_plat
                WHERE M.id_resto = %s
            """
            cur.execute(requete_menu, (id_resto,))
            menu = cur.fetchall()


            requete_avis = """
                SELECT A.note, A.commentaire, Cl.prenom
                FROM Avis A
                JOIN Commande Cmd ON A.id_commande = Cmd.id_commande
                JOIN Client Cl ON A.id_client = Cl.id_client
                WHERE Cmd.id_resto = %s
            """
            cur.execute(requete_avis, (id_resto,))
            avis = cur.fetchall()
    return render_template('restaurant.html', info=infos, menu=menu, avis=avis)


@app.route("/profil")
def profil():
    if "prenom" not in session:
        return render_template("connexion.html")
    id_client = session["id_client"]
    with db.connect() as conn: 
        with conn.cursor() as cur: 
            cur.execute("select prenom, points_fidelite from client where id_client = %s",(id_client,))
            point = cur.fetchone()

            req = """
                SELECT 
                    C.id_commande,C.date_heure_commande, C.montant_total,C.statut_commande,R.nom AS nom_resto, A.id_avis
                    FROM Commande C 
                    JOIN Restaurant R on C.id_resto = R.id_resto
                    LEFT JOIN Avis A ON A.id_commande = C.id_commande
                    WHERE C.id_client = %s
                    ORDER BY C.date_heure_commande DESC
            """
            cur.execute(req,(id_client,))
            commandes = cur.fetchall()
    return render_template("profil.html", client=point, historique=commandes)



@app.route("/confirmer_livraison/<int:id_commande>", methods=["POST"])
def confirmer_livraison(id_commande):
    with db.connect() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT id_livreur 
                FROM Commande 
                WHERE id_commande = %s AND id_client = %s AND statut_commande = 'en_livraison'
            """, (id_commande, session["id_client"]))
            livreur=cur.fetchone()
            cur.execute("""
                UPDATE Commande 
                SET statut_commande = 'livree', 
                    date_heure_livraison = CURRENT_TIMESTAMP 
                WHERE id_commande = %s AND id_client = %s AND statut_commande = 'en_livraison'
            """, (id_commande, session["id_client"]))
            cur.execute("""UPDATE Livreur SET etat_service = %s WHERE id_livreur = %s""", ('en_service_attente', int(livreur.id_livreur)))
            
    return redirect(url_for('profil'))

@app.route("/avis/<int:id_commande>", methods = ["POST"])
def avis(id_commande):
    return render_template("avis.html",id_commande = id_commande )

@app.route("/avis_verif/<int:id_commande>", methods =["POST"])
def avis_verif(id_commande):
    note = request.form.get('note')
    commentaire = request.form.get('commentaire')
    id_client = session["id_client"]
    with db.connect() as conn:
        with conn.cursor() as cur:
            cur.execute("""
                    INSERT INTO Avis(note,commentaire,id_client,id_commande)
                        VALUES(%s,%s,%s,%s)
                    """,(note,commentaire,id_client,id_commande))
    return redirect(url_for('accueil'))

@app.route("/connexion")
def connexion():
    if "prenom" not in session:
        return render_template("connexion.html")
    return redirect(url_for('accueil',etat_connexion=session["prenom"]))
 

@app.route("/deconnexion")
def deconnexion():
    session.clear()
    return redirect(url_for('accueil')) 

@app.route('/panier')
def panier():
    if "panier" not in session:
        session["panier"] = {}
        session["prix_total"] = 0
        session["frais"]=0

    print(session["panier"])
    etat_connexion = session.get("prenom", None)
    prix_total = float(session["prix_total"])
    frais=float(session["frais"]) 
    return render_template("panier.html", panier=session["panier"], etat_connexion=etat_connexion, prix_total=prix_total,frais=frais)

@app.route('/ajout_panier/<id_resto>',methods=["POST"])
def ajout_panier(id_resto):
    with db.connect() as conn: 
        with conn.cursor() as cur:
            id_resto_int=int(id_resto)
            cur.execute("select frais_livraison from restaurant where id_resto =%s",(id_resto_int,))
            resto=cur.fetchone()
            cur.execute("select id_plat,nom,prix,photo_url from Plat natural join Menu where id_resto= %s",(id_resto_int,))
            plats=cur.fetchall()
            panier_dictv0=None
            prix_totalv0=None
            fraisv0=None
            if "panier" in session and "prix_total" in session and "frais" in session:
                panier_dict = session["panier"]
                prix_total = float(session["prix_total"])
                frais=float(session["frais"])
                if panier_dict and len(panier_dict)>0 :  
                    
                    for plat_panier in panier_dict.values():
                        if plat_panier["id_resto"] != id_resto_int:
                            panier_dictv0=panier_dict
                            prix_totalv0=prix_total
                            fraisv0=frais
                            panier_dict = {}
                            prix_total = 0
                        break  
            else:
                panier_dict = {}
                prix_total = 0
            quantite_total=0
            for plat in plats:
                quantite_str = request.form.get(f"qte_{plat.id_plat}")
                if quantite_str:
                    quantite = int(quantite_str)
                    if quantite > 0:
                        prix_quantite = float(plat.prix) * quantite
                        if str(plat.id_plat) in panier_dict:
                            panier_dict[str(plat.id_plat)]["prix_quantite"] = float(panier_dict[str(plat.id_plat)]["prix_quantite"]) + prix_quantite
                            panier_dict[str(plat.id_plat)]["quantite"] = int(panier_dict[str(plat.id_plat)]["quantite"]) + quantite
                        else:
                            panier_dict[str(plat.id_plat)] = {"id_plat": plat.id_plat,"id_resto": id_resto_int,"quantite": quantite,"photo_url": plat.photo_url,"prix": float(plat.prix),"nom": plat.nom,"prix_quantite": prix_quantite}
                        
                        prix_total += prix_quantite
                        quantite_total+=quantite
            if quantite_total==0 and  panier_dictv0!=None:
                panier_dict=panier_dictv0
                prix_total=prix_totalv0
                frais=fraisv0
            elif quantite_total>0:
                session["id_resto_panier"]=id_resto_int
                frais=float(resto.frais_livraison)
                     
            
            session["panier"] = panier_dict
            session["prix_total"] = prix_total
            session["frais"]=frais

            print(session["panier"])
            
    return redirect(url_for("panier"))

@app.route("/valide_commande",methods=["POST"])
def valide_commande():
    if  "panier" in session and "prenom" in session:
        with db.connect() as conn: 
             with conn.cursor() as cur:
                 cur.execute("insert into Commande(date_heure_commande,montant_total,id_client,id_resto)  values (CURRENT_TIMESTAMP,%s,%s,%s) returning id_commande ",(float(session["prix_total"])+float(session["frais"]),int(session["id_client"]),int(session["id_resto_panier"])))
                 id_commande=cur.fetchone().id_commande
                 for plat in session["panier"]:
                     id_plat=int(plat)
                     quantite=int(session["panier"][plat]["quantite"])
                     prix_total=float(session["panier"][plat]["prix_quantite"])
                     cur.execute("insert into Commande_plat(id_commande,id_plat,quantite,montant_plat) values (%s,%s,%s,%s)",(id_commande,id_plat,quantite,prix_total))
                 point_parraine=(int(session["prix_total"])/10)*50
                 cur.execute("update Client set points_fidelite= points_fidelite+%s where id_client=%s",(point_parraine,int(session["id_client"])))
                 if "parrain" in session:
                    cur.execute("update Client set points_fidelite=points_fidelite+%s where id_client=%s",(point_parraine,int(session["parrain"])))
                 session.pop("panier",None)
                 session.pop("prix_total",None)
                 session.pop("id_resto_panier",None)
                 session.pop("frais",None)
    return redirect(url_for("profil"))

            
                 





@app.route("/verif",methods=["POST"])
def verif():
    email=request.form.get('email')
    mdp=request.form.get('mdp')
    
    with db.connect() as conn: 
        with conn.cursor() as cur: 
            cur.execute('select id_parrain,prenom,id_client,email,mot_de_passe ,id_ville from Client natural join Adresse where email=%s',(email,))
            resultat=cur.fetchone()
            
            if resultat:
                if bcrypt.verify(mdp,resultat.mot_de_passe):
                    session["prenom"]=resultat.prenom 
                    session["id_client"] = resultat.id_client
                    session["id_ville"]=resultat.id_ville
                    if resultat.id_parrain:
                        session["parrain"]=resultat.id_parrain
                    return redirect(url_for('accueil'))

    return render_template("connexion.html", error="Email ou mot de passe incorrect.")
    


@app.route("/inscription")
def inscription():
    return render_template("inscription.html")   



@app.route("/inscription_complete", methods=["POST"])
def inscription_complete():
    prenom = request.form.get('prenom')
    email = request.form.get('email_in')
    mdp = request.form.get('mdp_in')
    nom = request.form.get('nom')
    numero = request.form.get('numero')
    num_rue = request.form.get('num_rue')
    nom_rue = request.form.get('nom_rue')  
    nom_ville = request.form.get('nom_ville')
    code_postal = request.form.get('code_postal')
    nom_parrain = request.form.get('parrain_nom')
    
   
    mdp_hash = bcrypt.hash(mdp)
    
    with db.connect() as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT email FROM Client WHERE email = %s', (email,))
            if cur.fetchone():
                return render_template("inscription.html", error="Cet email est déjà utilisé")
            
        
            cur.execute('SELECT id_ville FROM Ville WHERE code_postal = %s AND nom_ville = %s', 
                       (code_postal, nom_ville))
            ville_result = cur.fetchone()
            
            if ville_result:
               
                id_ville = ville_result.id_ville
            else:
             
                cur.execute('INSERT INTO Ville (nom_ville, code_postal) VALUES (%s, %s) RETURNING id_ville',
                           (nom_ville, code_postal))
                id_ville = cur.fetchone().id_ville
            

            cur.execute('''SELECT id_adresse FROM Adresse WHERE num_rue = %s AND nom_rue = %s AND id_ville = %s''',(num_rue, nom_rue, id_ville))
            adresse_result = cur.fetchone()
            
            if adresse_result:
      
                id_adresse = adresse_result.id_adresse
            else:
          
                cur.execute('''INSERT INTO Adresse (num_rue, nom_rue, id_ville) VALUES (%s, %s, %s) RETURNING id_adresse''',(num_rue, nom_rue, id_ville))
                id_adresse = cur.fetchone().id_adresse
            
       
            id_parrain = None
            if nom_parrain:
                cur.execute('SELECT id_client FROM Client WHERE nom = %s OR email = %s',
                           (nom_parrain, nom_parrain))
                parrain_result = cur.fetchone()
                if parrain_result:
                    id_parrain = parrain_result.id_client
            
    
            cur.execute('''INSERT INTO Client (email, mot_de_passe, nom, prenom, telephone, id_adresse, id_parrain) VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING id_client''',(email, mdp_hash, nom, prenom, numero, id_adresse, id_parrain))
            
            id_client = cur.fetchone().id_client
            
           
            session["id_client"] = id_client
            session["email"] = email
            session["prenom"]=prenom
    return redirect(url_for('accueil'))


@app.route("/privateconnexion")
def privateconnexion():
    if "nom_liv" in session:
        statut_connexion = session["nom_liv"]
    else:
        statut_connexion = None
    return render_template('privateconnexion.html',etat_connexion=statut_connexion)
    
@app.route("/verif_pro", methods=["POST"])
def verif_pro():
    matricule = request.form.get('Matricule')
    mdp_pro = request.form.get('mdp_pro')
    
    with db.connect() as conn: 
        with conn.cursor() as cur:
            cur.execute(
                'SELECT id_livreur, matricule, mot_de_passe, nom, prenom, telephone, etat_service FROM Livreur WHERE matricule = %s',
                (matricule,)
            )
            resultat = cur.fetchone()
            
            if resultat:
                if bcrypt.verify(mdp_pro, resultat.mot_de_passe):
                    
                    session["matricule"] = matricule
                    session["nom_liv"] = resultat.nom
                    session["id_livreur"] = resultat.id_livreur
                    
                    
                    return redirect(url_for('page_pro'))
                
                return render_template("privateconnexion.html", erreur="Mot de passe incorrect")
            
            return render_template("privateconnexion.html", erreur="Matricule inexistant")
@app.route("/annuler_commande/<id_commande>",methods=["POST"])
def annuler_commande(id_commande):
    if "id_client" not in session:
        return redirect(url_for('connexion'))
    
    with db.connect() as conn: 
        with conn.cursor() as cur:
            cur.execute("""SELECT statut_commande, montant_total FROM Commande WHERE id_commande = %s AND id_client = %s""", (id_commande, session["id_client"]))
            
            commande = cur.fetchone()

            if not commande:
                return redirect(url_for('profil'))
            
            
            if commande.statut_commande == 'en_attente':
                cur.execute(""" UPDATE Commande SET statut_commande = 'annulee' WHERE id_commande = %s  """, (id_commande,))
                
                points = (int(commande.montant_total) / 10) * 50
                cur.execute("""UPDATE Client SET points_fidelite = points_fidelite - %s WHERE id_client = %s""", (points, session["id_client"]))
                
                if "parrain" in session:
                    cur.execute("""UPDATE Client SET points_fidelite = points_fidelite - %s WHERE id_client = %s""", (points, session["parrain"]))
            print(id_commande)
    return redirect(url_for('profil'))
@app.route("/page_pro")
def page_pro():
    if "matricule" not in session:
        return redirect(url_for('privateconnexion'))
    
    with db.connect() as conn:
        with conn.cursor() as cur:
            
            cur.execute(
                'SELECT id_livreur, nom, etat_service FROM Livreur WHERE matricule = %s',
                (session["matricule"],)
            )
            resultat = cur.fetchone()
            
            if not resultat:
                return redirect(url_for('privateconnexion'))
            
           
            cur.execute(
                "SELECT id_ville FROM Livreur_Ville WHERE id_livreur = %s",
                (resultat.id_livreur,)
            )
            villes_livreur = cur.fetchall()
            
            commandes_completes = []
            commande_a_livrer = None
            
            if villes_livreur:
                ids_villes = tuple(v.id_ville for v in villes_livreur)
                
                
                if resultat.etat_service in ('hors_service', 'en_service_attente'):
                    cur.execute("""SELECT id_commande, nom, date_heure_commande, statut_commande, montant_total, id_client, id_resto, photo_url, nom_ville FROM Commande NATURAL JOIN Restaurant NATURAL JOIN Adresse NATURAL JOIN Ville WHERE statut_commande IN %s AND id_ville IN %s ORDER BY date_heure_commande""", (('en_preparation', 'en_attente'), ids_villes))
                    
                    commandes = cur.fetchall()
                    
                    for commande in commandes:
                        cur.execute("""SELECT nom, num_rue, nom_rue FROM Client JOIN Adresse ON Client.id_adresse = Adresse.id_adresse WHERE Client.id_client = %s""", (commande.id_client,))
                        info_client = cur.fetchone()
                        
                        cur.execute("""SELECT p.nom, cp.quantite, p.prix  FROM Commande_Plat cp  JOIN Plat p ON cp.id_plat = p.id_plat  WHERE cp.id_commande = %s""", (commande.id_commande,))
                        plats = cur.fetchall()
                        
                        commandes_completes.append({'id_commande': commande.id_commande,'nom_client': info_client.nom,'Lieu_client': f"{info_client.num_rue} {info_client.nom_rue}",'nom_resto': commande.nom,'date': commande.date_heure_commande,'montant': commande.montant_total,'ville': commande.nom_ville,'photo': commande.photo_url ,'id_client': commande.id_client,'plats': plats})
                
                
                elif resultat.etat_service == 'en_service_course':
                    cur.execute(""" SELECT id_commande, nom, date_heure_commande, statut_commande,  montant_total, id_client, id_resto, photo_url, nom_ville  FROM Commande NATURAL JOIN Restaurant NATURAL JOIN Adresse  NATURAL JOIN Ville  WHERE statut_commande = %s AND id_livreur = %s ORDER BY date_heure_commande""", ('en_livraison', resultat.id_livreur))
                    
                    commande = cur.fetchone()
                    
                    if commande:
                        cur.execute("""SELECT nom, num_rue, nom_rue FROM Client JOIN Adresse ON Client.id_adresse = Adresse.id_adresse WHERE Client.id_client = %s """, (commande.id_client,))
                        info_client = cur.fetchone()
                        
                        cur.execute("""SELECT p.nom, cp.quantite, p.prix  FROM Commande_Plat cp  JOIN Plat p ON cp.id_plat = p.id_plat WHERE cp.id_commande = %s""", (commande.id_commande,))
                        plats = cur.fetchall()
                        
                        commande_a_livrer = {'id_commande': commande.id_commande,'nom_client': info_client.nom,'Lieu_client': f"{info_client.num_rue} {info_client.nom_rue}",'nom_resto': commande.nom,  'date': commande.date_heure_commande,'montant': commande.montant_total,'ville': commande.nom_ville,'photo': commande.photo_url,'id_client': commande.id_client,'plats': plats}
            
            return render_template("page_pro.html",  commandes=commandes_completes,commande_a_livrer=commande_a_livrer,nom=resultat.nom,etat=resultat.etat_service)

@app.route("/prend_commande/<id_commande>", methods=["POST"])
def prend_commande(id_commande):
    if "matricule" not in session:
        return redirect(url_for('privateconnexion'))
    
    with db.connect() as conn: 
        with conn.cursor() as cur:
            cur.execute("""UPDATE Commande SET statut_commande = %s, id_livreur = %s WHERE id_commande = %s""", ('en_livraison', session["id_livreur"], id_commande))
            
            cur.execute("""UPDATE Livreur SET etat_service = %s WHERE id_livreur = %s""", ('en_service_course', session['id_livreur']))
    
  
    return redirect(url_for('page_pro'))

@app.route("/perso_pro")
def perso_pro():
    pass


if __name__ == '__main__':
    app.run()