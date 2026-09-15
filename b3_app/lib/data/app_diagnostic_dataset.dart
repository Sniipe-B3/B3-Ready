const String appDiagnosticQuestionsJson = '''
[
  {
    "id": "q_heat_main",
    "text": "Comment chauffez-vous principalement votre logement ?",
    "type": "multiple_choice",
    "options": [
      {"id": "opt_rad_elec", "text": "Radiateurs électriques", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "radiateur_elec"}]},
      {"id": "opt_pac", "text": "Pompe à chaleur", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "pompe_chaleur"}]},
      {"id": "opt_chaudiere_gaz", "text": "Chaudière gaz", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "chaudiere_gaz"}]},
      {"id": "opt_chaudiere_bois", "text": "Chaudière bois ou granulés", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "chaudiere_bois"}]},
      {"id": "opt_poele_granules", "text": "Poêle à granulés", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "poele_granules"}]},
      {"id": "opt_poele_bois", "text": "Poêle à bûches (autonome sans électricité)", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "poele_bois"}]}
    ]
  },
  {
    "id": "q_heat_bois_reserve",
    "text": "Disposez-vous d'une réserve de bois utilisable ?",
    "condition": {"dependsOn": "q_heat_main", "hasAnswer": "opt_poele_bois"},
    "type": "single_choice",
    "options": [
      {"id": "opt_bois_yes", "text": "Oui, pour plusieurs jours", "facts": [{"type": "add_resource", "value": "bois"}, {"type": "assess_resource", "value": "bois"}, {"type": "add_resource_duration", "value": "bois", "duration": 72}]},
      {"id": "opt_bois_limit", "text": "Oui, mais peu (moins de 48h)", "facts": [{"type": "add_resource", "value": "bois"}, {"type": "assess_resource", "value": "bois"}, {"type": "add_resource_duration", "value": "bois", "duration": 24}]},
      {"id": "opt_bois_no", "text": "Non (ou insuffisante)", "facts": [{"type": "assess_resource", "value": "bois"}]},
      {"id": "opt_bois_unk", "text": "Je ne sais pas", "facts": []}
    ]
  },
  {
    "id": "q_cook_main",
    "text": "De quels équipements disposez-vous pour cuisiner ?",
    "type": "multiple_choice",
    "options": [
      {"id": "opt_plaque_elec", "text": "Plaque électrique / induction", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "plaque_elec"}]},
      {"id": "opt_four_elec", "text": "Four électrique", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "four_elec"}]},
      {"id": "opt_gaz_ville", "text": "Cuisinière au gaz de ville", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "gaziniere_ville"}]},
      {"id": "opt_gaz_bouteille", "text": "Cuisinière ou réchaud sur bouteille de gaz", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "rechaud_gaz"}]},
      {"id": "opt_barbecue", "text": "Barbecue extérieur", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "barbecue"}]}
    ]
  },
  {
    "id": "q_cook_gaz_reserve",
    "text": "Avez-vous une bouteille de gaz de rechange utilisable (actuellement connectée ou en stock) ?",
    "condition": {"dependsOn": "q_cook_main", "hasAnswer": "opt_gaz_bouteille"},
    "type": "single_choice",
    "options": [
      {"id": "opt_gaz_yes", "text": "Oui", "facts": [{"type": "add_resource", "value": "gaz_bouteille"}, {"type": "assess_resource", "value": "gaz_bouteille"}]},
      {"id": "opt_gaz_no", "text": "Non", "facts": [{"type": "assess_resource", "value": "gaz_bouteille"}]},
      {"id": "opt_gaz_unk", "text": "Je ne sais pas", "facts": []}
    ]
  },
  {
    "id": "q_cook_gaz_duration",
    "text": "Combien de temps environ pouvez-vous cuisiner avec cette réserve de gaz ?",
    "condition": {"dependsOn": "q_cook_gaz_reserve", "hasAnswer": "opt_gaz_yes"},
    "type": "single_choice",
    "options": [
      {"id": "opt_gaz_short", "text": "Moins de 24h", "facts": [{"type": "add_resource_duration", "value": "gaz_bouteille", "duration": 12}]},
      {"id": "opt_gaz_long", "text": "Plusieurs jours", "facts": [{"type": "add_resource_duration", "value": "gaz_bouteille", "duration": 72}]},
      {"id": "opt_gaz_dur_unk", "text": "Je ne sais pas", "facts": []}
    ]
  },
  {
    "id": "q_light_main",
    "text": "De quoi disposez-vous pour l'éclairage en cas de coupure électrique ?",
    "type": "multiple_choice",
    "options": [
      {"id": "opt_lampe_secteur", "text": "Rien de spécifique (luminaires branchés sur secteur)", "facts": [{"type": "assess_capability", "value": "eclairage"}, {"type": "add_asset", "value": "lampe_secteur"}]},
      {"id": "opt_lampe_bat", "text": "Lampes torches ou de secours (à piles ou batterie)", "facts": [{"type": "assess_capability", "value": "eclairage"}, {"type": "add_asset", "value": "lampe_batterie"}]}
    ]
  },
  {
    "id": "q_light_bat_reserve",
    "text": "Vos lampes de secours sont-elles actuellement fonctionnelles et disposent-elles de piles/batteries de rechange ?",
    "condition": {"dependsOn": "q_light_main", "hasAnswer": "opt_lampe_bat"},
    "type": "single_choice",
    "options": [
      {"id": "opt_bat_yes", "text": "Oui, de quoi tenir plusieurs soirs", "facts": [{"type": "add_resource", "value": "batterie"}, {"type": "assess_resource", "value": "batterie"}, {"type": "add_resource_duration", "value": "batterie", "duration": 48}]},
      {"id": "opt_bat_no", "text": "Non, ou très peu", "facts": [{"type": "assess_resource", "value": "batterie"}, {"type": "add_resource_duration", "value": "batterie", "duration": 4}]},
      {"id": "opt_bat_unk", "text": "Je ne sais pas", "facts": []}
    ]
  }
]
''';
