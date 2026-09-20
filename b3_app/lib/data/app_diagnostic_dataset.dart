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
    "id": "q_heat_redundancy",
    "text": "En cas de coupure du système principal (ex. panne de réseau), avez-vous une autre façon de chauffer votre logement ?",
    "type": "single_choice",
    "metadata": {"purpose": "redundancy_check", "capability": "chauffer"},
    "options": [
      {"id": "opt_heat_alt_yes", "text": "Oui", "facts": []},
      {"id": "opt_heat_alt_no", "text": "Non", "facts": []},
      {"id": "opt_heat_alt_unk", "text": "Je ne sais pas", "facts": []}
    ]
  },
  {
    "id": "q_heat_alternative",
    "text": "Quelle autre solution utilisez-vous ?",
    "condition": {"dependsOn": "q_heat_redundancy", "hasAnswer": "opt_heat_alt_yes"},
    "type": "multiple_choice",
    "metadata": {"purpose": "alternative_discovery", "capability": "chauffer"},
    "options": [
      {"id": "opt_poele_bois", "text": "Poêle à bûches (autonome sans électricité)", "facts": [{"type": "add_asset", "value": "poele_bois"}]},
      {"id": "opt_poele_granules", "text": "Poêle à granulés", "facts": [{"type": "add_asset", "value": "poele_granules"}]},
      {"id": "opt_chaudiere_bois", "text": "Chaudière bois ou granulés", "facts": [{"type": "add_asset", "value": "chaudiere_bois"}]}
    ]
  },
  {
    "id": "q_heat_bois_reserve",
    "text": "Disposez-vous d'une réserve de bois utilisable ?",
    "type": "single_choice",
    "options": [
      {"id": "opt_bois_yes", "text": "Oui, pour plusieurs jours", "facts": [{"type": "add_resource", "value": "bois"}, {"type": "assess_resource", "value": "bois"}, {"type": "add_resource_duration", "value": "bois", "duration": 72}]},
      {"id": "opt_bois_limit", "text": "Oui, mais peu (moins de 48h)", "facts": [{"type": "add_resource", "value": "bois"}, {"type": "assess_resource", "value": "bois"}, {"type": "add_resource_duration", "value": "bois", "duration": 24}]},
      {"id": "opt_bois_no", "text": "Non (ou insuffisante)", "facts": [{"type": "assess_resource", "value": "bois"}]},
      {"id": "opt_bois_unk", "text": "Je ne sais pas", "facts": [{"type": "assess_resource_unknown", "value": "bois"}]}
    ]
  },
  {
    "id": "q_heat_granules_reserve",
    "text": "Disposez-vous d'une réserve de granulés utilisable ?",
    "type": "single_choice",
    "options": [
      {"id": "opt_gra_yes", "text": "Oui, pour plusieurs jours", "facts": [{"type": "add_resource", "value": "granules"}, {"type": "assess_resource", "value": "granules"}, {"type": "add_resource_duration", "value": "granules", "duration": 72}]},
      {"id": "opt_gra_no", "text": "Non (ou insuffisante)", "facts": [{"type": "assess_resource", "value": "granules"}]},
      {"id": "opt_gra_unk", "text": "Je ne sais pas", "facts": [{"type": "assess_resource_unknown", "value": "granules"}]}
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
    "id": "q_cook_redundancy",
    "text": "En cas de coupure (ex. électricité ou gaz de ville), avez-vous une autre façon de cuisiner (ex. réchaud) ?",
    "type": "single_choice",
    "metadata": {"purpose": "redundancy_check", "capability": "cuisiner"},
    "options": [
      {"id": "opt_cook_alt_yes", "text": "Oui", "facts": []},
      {"id": "opt_cook_alt_no", "text": "Non", "facts": []},
      {"id": "opt_cook_alt_unk", "text": "Je ne sais pas", "facts": []}
    ]
  },
  {
    "id": "q_cook_alternative",
    "text": "Quelle autre solution utilisez-vous ?",
    "condition": {"dependsOn": "q_cook_redundancy", "hasAnswer": "opt_cook_alt_yes"},
    "type": "multiple_choice",
    "metadata": {"purpose": "alternative_discovery", "capability": "cuisiner"},
    "options": [
      {"id": "opt_gaz_bouteille", "text": "Cuisinière ou réchaud sur bouteille de gaz", "facts": [{"type": "add_asset", "value": "rechaud_gaz"}]},
      {"id": "opt_barbecue", "text": "Barbecue extérieur", "facts": [{"type": "add_asset", "value": "barbecue"}]}
    ]
  },
  {
    "id": "q_cook_gaz_reserve",
    "text": "Avez-vous une bouteille de gaz de rechange utilisable (actuellement connectée ou en stock) ?",
    "type": "single_choice",
    "options": [
      {"id": "opt_gaz_yes", "text": "Oui", "facts": [{"type": "add_resource", "value": "gaz_bouteille"}, {"type": "assess_resource", "value": "gaz_bouteille"}]},
      {"id": "opt_gaz_no", "text": "Non", "facts": [{"type": "assess_resource", "value": "gaz_bouteille"}]},
      {"id": "opt_gaz_unk", "text": "Je ne sais pas", "facts": [{"type": "assess_resource_unknown", "value": "gaz_bouteille"}]}
    ]
  },
  {
    "id": "q_cook_gaz_duration",
    "text": "Combien de temps environ pouvez-vous cuisiner avec cette réserve de gaz ?",
    "type": "single_choice",
    "options": [
      {"id": "opt_gaz_short", "text": "Moins de 24h", "facts": [{"type": "add_resource_duration", "value": "gaz_bouteille", "duration": 12}]},
      {"id": "opt_gaz_long", "text": "Plusieurs jours", "facts": [{"type": "add_resource_duration", "value": "gaz_bouteille", "duration": 72}]},
      {"id": "opt_gaz_dur_unk", "text": "Je ne sais pas", "facts": []}
    ]
  },
  {
    "id": "q_cook_charbon_reserve",
    "text": "Disposez-vous de charbon utilisable pour le barbecue ?",
    "type": "single_choice",
    "options": [
      {"id": "opt_charbon_yes", "text": "Oui", "facts": [{"type": "add_resource", "value": "charbon"}, {"type": "assess_resource", "value": "charbon"}, {"type": "add_resource_duration", "value": "charbon", "duration": 48}]},
      {"id": "opt_charbon_no", "text": "Non", "facts": [{"type": "assess_resource", "value": "charbon"}]},
      {"id": "opt_charbon_unk", "text": "Je ne sais pas", "facts": [{"type": "assess_resource_unknown", "value": "charbon"}]}
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
    "type": "single_choice",
    "options": [
      {"id": "opt_bat_yes", "text": "Oui, de quoi tenir plusieurs soirs", "facts": [{"type": "add_resource", "value": "batterie"}, {"type": "assess_resource", "value": "batterie"}, {"type": "add_resource_duration", "value": "batterie", "duration": 48}]},
      {"id": "opt_bat_no", "text": "Non, ou très peu", "facts": [{"type": "assess_resource", "value": "batterie"}, {"type": "add_resource_duration", "value": "batterie", "duration": 4}]},
      {"id": "opt_bat_unk", "text": "Je ne sais pas", "facts": [{"type": "assess_resource_unknown", "value": "batterie"}]}
    ]
  },
  {
    "id": "q_water_main",
    "text": "Comment accédez-vous à l'eau courante ?",
    "type": "multiple_choice",
    "options": [
      {"id": "opt_robinet_eau", "text": "Robinet classique (réseau public)", "facts": [{"type": "assess_capability", "value": "disposer_eau"}, {"type": "add_asset", "value": "robinet_eau"}]},
      {"id": "opt_stock_eau", "text": "J'ai un stock d'eau / cuve", "facts": [{"type": "assess_capability", "value": "disposer_eau"}, {"type": "add_asset", "value": "stock_eau"}]}
    ]
  },
  {
    "id": "q_water_reserve",
    "text": "De quelle réserve d'eau disposez-vous (bouteilles, bidons...) ?",
    "type": "single_choice",
    "options": [
      {"id": "opt_water_yes", "text": "Oui, pour plusieurs jours", "facts": [{"type": "add_resource", "value": "reserve_eau"}, {"type": "assess_resource", "value": "reserve_eau"}, {"type": "add_resource_duration", "value": "reserve_eau", "duration": 72}]},
      {"id": "opt_water_no", "text": "Non, presque rien", "facts": [{"type": "assess_resource", "value": "reserve_eau"}]},
      {"id": "opt_water_unk", "text": "Je ne sais pas", "facts": [{"type": "assess_resource_unknown", "value": "reserve_eau"}]}
    ]
  },
  {
    "id": "q_com_main",
    "text": "Quels moyens de communication utilisez-vous ?",
    "type": "multiple_choice",
    "options": [
      {"id": "opt_box_internet", "text": "Box Internet fixe", "facts": [{"type": "assess_capability", "value": "acceder_internet"}, {"type": "add_asset", "value": "box_internet"}]},
      {"id": "opt_smartphone", "text": "Smartphone (réseau mobile)", "facts": [{"type": "assess_capability", "value": "communiquer"}, {"type": "add_asset", "value": "smartphone"}]}
    ]
  }
]
''';
