const String b3KnowledgeBase = '''
{
  "systems": [
    {"id": "unk_sys", "name": "Système Inconnu"},
    {"id": "elec", "name": "Électricité"},
    {"id": "eau", "name": "Eau du réseau"},
    {"id": "internet", "name": "Internet"},
    {"id": "reseau_mobile", "name": "Réseau Mobile"}
  ],
  "resources": [
    {"id": "gaz", "name": "Cartouche gaz"},
    {"id": "bois", "name": "Bois"},
    {"id": "batterie", "name": "Batterie rechargeable"}
  ],
  "assets": [
    {"id": "unknown_cuisiner", "name": "Moyen inconnu", "requires": ["unk_sys"]},
    {"id": "plaque_elec", "name": "Plaque électrique", "requires": ["elec"]},
    {"id": "four_elec", "name": "Four électrique", "requires": ["elec"]},
    {"id": "rechaud_gaz", "name": "Réchaud gaz", "requires": ["gaz"]},
    {"id": "rechaud_bois", "name": "Réchaud bois", "requires": ["bois"]},
    {"id": "lampe_secteur", "name": "Lampe secteur", "requires": ["elec"]},
    {"id": "lampe_batterie", "name": "Lampe rechargeable", "requires": ["batterie"]},
    {"id": "poele_bois", "name": "Poêle à bois", "requires": ["bois"]},
    {"id": "radiateur_elec", "name": "Radiateur électrique", "requires": ["elec"]},
    {"id": "robinet", "name": "Robinet (direct)", "requires": ["eau"]},
    {"id": "telephone_mobile", "name": "Téléphone Mobile", "requires": ["reseau_mobile", "batterie"]},
    {"id": "voip", "name": "Téléphone Internet", "requires": ["internet", "elec"]},
    {"id": "frigo", "name": "Réfrigérateur", "requires": ["elec"]}
  ],
  "capabilities": [
    {"id": "cuisiner", "name": "Cuisiner", "assets": ["unknown_cuisiner", "plaque_elec", "four_elec", "rechaud_gaz", "rechaud_bois"]},
    {"id": "eclairage", "name": "S'éclairer", "assets": ["lampe_secteur", "lampe_batterie"]},
    {"id": "chauffer", "name": "Chauffer", "assets": ["radiateur_elec", "poele_bois"]},
    {"id": "boire", "name": "Boire", "assets": ["robinet"]},
    {"id": "communiquer", "name": "Communiquer", "assets": ["telephone_mobile", "voip"]},
    {"id": "conserver", "name": "Conserver les aliments", "assets": ["frigo"]}
  ],
  "scenarios": [
    {"id": "panne_elec", "name": "Panne électrique", "duration": 48, "overrides": {"elec": "failed"}},
    {"id": "panne_elec_gaz", "name": "Panne électrique et pénurie gaz", "duration": 48, "overrides": {"elec": "failed", "gaz": "failed"}},
    {"id": "panne_internet", "name": "Coupure Internet", "duration": 24, "overrides": {"internet": "failed"}}
  ]
}
''';
