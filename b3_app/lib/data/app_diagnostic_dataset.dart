const String appDiagnosticQuestionsJson = '''
[
  {
    "id": "q_cook_main",
    "text": "Comment pouvez-vous cuisiner actuellement ?",
    "type": "multiple_choice",
    "options": [
      {"id": "opt_plaque_elec", "text": "Plaque électrique", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "plaque_elec"}]},
      {"id": "opt_four_elec", "text": "Four électrique", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "four_elec"}]},
      {"id": "opt_gaz", "text": "Cuisinière / plaque / réchaud au gaz", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "rechaud_gaz"}]},
      {"id": "opt_bois", "text": "Poêle à bois / Barbecue", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "rechaud_bois"}]},
      {"id": "opt_none", "text": "Rien de tout cela", "facts": [{"type": "assess_capability", "value": "cuisiner"}]},
      {"id": "opt_unk", "text": "Je ne sais pas", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "override_capability", "value": "cuisiner", "state": "unknown"}]}
    ]
  },
  {
    "id": "q_cook_gaz_reserve",
    "text": "Votre équipement au gaz dispose-t-il actuellement d'une réserve de gaz utilisable ?",
    "condition": {"dependsOn": "q_cook_main", "hasAnswer": "opt_gaz"},
    "type": "single_choice",
    "options": [
      {"id": "opt_gaz_yes", "text": "Oui", "facts": [{"type": "add_resource", "value": "gaz"}, {"type": "assess_resource", "value": "gaz"}]},
      {"id": "opt_gaz_no", "text": "Non (bouteille vide)", "facts": [{"type": "assess_resource", "value": "gaz"}]},
      {"id": "opt_gaz_unk", "text": "Je ne sais pas", "facts": []}
    ]
  },
  {
    "id": "q_cook_gaz_duration",
    "text": "Environ combien de temps cette réserve de gaz pourrait-elle vous permettre de cuisiner régulièrement ?",
    "condition": {"dependsOn": "q_cook_gaz_reserve", "hasAnswer": "opt_gaz_yes"},
    "type": "single_choice",
    "options": [
      {"id": "opt_gaz_24h", "text": "Moins de 24 h", "facts": [{"type": "add_resource_duration", "value": "gaz", "duration": 12}]},
      {"id": "opt_gaz_48h", "text": "1 à 2 jours", "facts": [{"type": "add_resource_duration", "value": "gaz", "duration": 48}]},
      {"id": "opt_gaz_7d", "text": "Une semaine ou plus", "facts": [{"type": "add_resource_duration", "value": "gaz", "duration": 168}]},
      {"id": "opt_gaz_dur_unk", "text": "Je ne sais pas", "facts": []}
    ]
  },
  {
    "id": "q_heat_main",
    "text": "Comment chauffez-vous votre logement ?",
    "type": "multiple_choice",
    "options": [
      {"id": "opt_rad_elec", "text": "Radiateurs / pompe à chaleur électrique", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "radiateur_elec"}]},
      {"id": "opt_poele", "text": "Poêle ou chaudière à bois", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "poele_bois"}]}
    ]
  },
  {
    "id": "q_heat_bois_reserve",
    "text": "Disposez-vous d'une réserve de bois pour vous chauffer ?",
    "condition": {"dependsOn": "q_heat_main", "hasAnswer": "opt_poele"},
    "type": "single_choice",
    "options": [
      {"id": "opt_bois_yes", "text": "Oui", "facts": [{"type": "add_resource", "value": "bois"}, {"type": "assess_resource", "value": "bois"}, {"type": "add_resource_duration", "value": "bois", "duration": 168}]},
      {"id": "opt_bois_no", "text": "Non", "facts": [{"type": "assess_resource", "value": "bois"}]}
    ]
  },
  {
    "id": "q_light_main",
    "text": "De quoi disposez-vous pour l'éclairage de nuit ?",
    "type": "multiple_choice",
    "options": [
      {"id": "opt_lampe_secteur", "text": "Luminaires classiques (branchés sur secteur)", "facts": [{"type": "assess_capability", "value": "eclairage"}, {"type": "add_asset", "value": "lampe_secteur"}]},
      {"id": "opt_lampe_bat", "text": "Lampes torches ou de secours sur batterie", "facts": [{"type": "assess_capability", "value": "eclairage"}, {"type": "add_asset", "value": "lampe_batterie"}]},
      {"id": "opt_none_light", "text": "Je n'ai aucun éclairage de secours", "facts": [{"type": "assess_capability", "value": "eclairage"}]}
    ]
  },
  {
    "id": "q_light_bat_reserve",
    "text": "Vos lampes sur batterie sont-elles actuellement chargées et fonctionnelles ?",
    "condition": {"dependsOn": "q_light_main", "hasAnswer": "opt_lampe_bat"},
    "type": "single_choice",
    "options": [
      {"id": "opt_bat_yes", "text": "Oui", "facts": [{"type": "add_resource", "value": "batterie"}, {"type": "assess_resource", "value": "batterie"}, {"type": "add_resource_duration", "value": "batterie", "duration": 48}]},
      {"id": "opt_bat_no", "text": "Non (déchargées/hors d'usage)", "facts": [{"type": "assess_resource", "value": "batterie"}]},
      {"id": "opt_bat_unk", "text": "Je ne sais pas", "facts": []}
    ]
  }
]
''';
