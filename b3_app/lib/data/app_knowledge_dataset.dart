const String appKnowledgeBase = '''
{
  "systems": [
    {"id": "elec", "name": "Réseau Électrique"},
    {"id": "eau", "name": "Eau du réseau"},
    {"id": "internet", "name": "Internet fixe"},
    {"id": "reseau_mobile", "name": "Réseau Mobile"},
    {"id": "reseau_gaz", "name": "Réseau Gaz de ville"}
  ],
  "resources": [
    {"id": "gaz_bouteille", "name": "Bouteille/Cartouche de gaz"},
    {"id": "bois", "name": "Bois de chauffage (bûches)"},
    {"id": "granules", "name": "Granulés de bois (pellets)"},
    {"id": "charbon", "name": "Charbon de bois"},
    {"id": "batterie", "name": "Batterie rechargeable"},
    {"id": "reserve_eau", "name": "Réserve d'eau (bouteilles/cuve)"}
  ],
  "assets": [
    {"id": "plaque_elec", "name": "Plaque électrique", "requires": ["elec"]},
    {"id": "four_elec", "name": "Four électrique", "requires": ["elec"]},
    {"id": "gaziniere_ville", "name": "Gazinière (gaz de ville)", "requires": ["reseau_gaz"]},
    {"id": "gaziniere_bouteille", "name": "Gazinière (bouteille)", "requires": ["gaz_bouteille"]},
    {"id": "rechaud_gaz", "name": "Réchaud gaz portable", "requires": ["gaz_bouteille"]},
    {"id": "barbecue", "name": "Barbecue extérieur", "requires": ["charbon"]},
    {"id": "cuisiniere_bois", "name": "Cuisinière à bois", "requires": ["bois"]},

    {"id": "lampe_secteur", "name": "Lampe sur secteur", "requires": ["elec"]},
    {"id": "lampe_batterie", "name": "Lampe rechargeable", "requires": ["batterie"]},

    {"id": "radiateur_elec", "name": "Radiateur électrique", "requires": ["elec"]},
    {"id": "pompe_chaleur", "name": "Pompe à chaleur", "requires": ["elec"]},
    {"id": "chaudiere_gaz", "name": "Chaudière gaz", "requires": ["reseau_gaz", "elec"]},
    {"id": "chaudiere_bois", "name": "Chaudière bois / granulés", "requires": ["bois", "elec"]}, 
    {"id": "poele_bois", "name": "Poêle à bûches (autonome)", "requires": ["bois"]},
    {"id": "poele_granules", "name": "Poêle à granulés", "requires": ["granules", "elec"]},

    {"id": "robinet_eau", "name": "Robinet (réseau d'eau)", "requires": ["eau"]},
    {"id": "stock_eau", "name": "Stock d'eau", "requires": ["reserve_eau"]},

    {"id": "box_internet", "name": "Box Internet", "requires": ["internet", "elec"]},
    {"id": "smartphone", "name": "Smartphone", "requires": ["reseau_mobile", "batterie"]}
  ],
  "capabilities": [
    {"id": "cuisiner", "name": "Cuisiner", "assets": ["plaque_elec", "four_elec", "gaziniere_ville", "gaziniere_bouteille", "rechaud_gaz", "cuisiniere_bois", "barbecue"]},
    {"id": "eclairage", "name": "S'éclairer", "assets": ["lampe_secteur", "lampe_batterie"]},
    {"id": "chauffer", "name": "Chauffer le logement", "assets": ["radiateur_elec", "pompe_chaleur", "chaudiere_gaz", "chaudiere_bois", "poele_bois", "poele_granules"]},
    {"id": "disposer_eau", "name": "Disposer d'eau", "assets": ["robinet_eau", "stock_eau"]},
    {"id": "acceder_internet", "name": "Accéder à Internet", "assets": ["box_internet"]},
    {"id": "communiquer", "name": "Communiquer", "assets": ["smartphone"]}
  ],
  "scenarios": [
    {"id": "panne_elec", "name": "Panne électrique prolongée", "duration": 48, "overrides": {"elec": "failed"}},
    {"id": "panne_gaz", "name": "Coupure réseau gaz", "duration": 48, "overrides": {"reseau_gaz": "failed"}},
    {"id": "coupure_eau", "name": "Coupure d'eau", "duration": 48, "overrides": {"eau": "failed"}},
    {"id": "panne_internet", "name": "Panne Internet fixe", "duration": 48, "overrides": {"internet": "failed"}},
    {"id": "panne_mobile", "name": "Panne réseau mobile", "duration": 48, "overrides": {"reseau_mobile": "failed"}}
  ]
}
''';
