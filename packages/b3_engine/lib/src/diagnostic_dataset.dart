const String b3DiagnosticQuestionsJson = '''
[
  {
    "id": "q_cook_main",
    "text": "Comment cuisinez-vous principalement ?",
    "type": "single_choice",
    "options": [
      {"id": "opt_plaque", "text": "Plaque électrique", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "plaque_elec"}]},
      {"id": "opt_gaz", "text": "Gazinière", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "add_asset", "value": "rechaud_gaz"}, {"type": "add_resource", "value": "gaz"}, {"type": "assess_resource", "value": "gaz"}, {"type": "add_resource_duration", "value": "gaz", "duration": 72}]},
      {"id": "opt_unk", "text": "Je ne sais pas", "facts": [{"type": "assess_capability", "value": "cuisiner"}, {"type": "override_capability", "value": "cuisiner", "state": "unknown"}]}
    ]
  },
  {
    "id": "q_cook_alt_elec",
    "text": "En plus de votre plaque électrique, possédez-vous un four ?",
    "condition": {"dependsOn": "q_cook_main", "hasAnswer": "opt_plaque"},
    "type": "single_choice",
    "options": [
      {"id": "opt_yes_four", "text": "Oui, un four électrique", "facts": [{"type": "add_asset", "value": "four_elec"}]},
      {"id": "opt_no_four", "text": "Non", "facts": []}
    ]
  },
  {
    "id": "q_cook_secours",
    "text": "Avez-vous une solution de secours totalement indépendante (ex: réchaud camping) ?",
    "condition": {"dependsOn": "q_cook_main", "hasAnswer": "opt_plaque"},
    "type": "single_choice",
    "options": [
      {"id": "opt_yes_rechaud", "text": "Oui, un réchaud gaz", "facts": [{"type": "add_asset", "value": "rechaud_gaz"}, {"type": "add_resource", "value": "gaz"}, {"type": "assess_resource", "value": "gaz"}, {"type": "add_resource_duration", "value": "gaz", "duration": 72}]},
      {"id": "opt_no_secours", "text": "Non", "facts": []}
    ]
  },
  {
    "id": "q_heat_main",
    "text": "Comment chauffez-vous votre logement ?",
    "type": "single_choice",
    "options": [
      {"id": "opt_rad_elec", "text": "Radiateurs électriques", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "radiateur_elec"}]},
      {"id": "opt_poele", "text": "Poêle à bois", "facts": [{"type": "assess_capability", "value": "chauffer"}, {"type": "add_asset", "value": "poele_bois"}, {"type": "add_resource", "value": "bois"}, {"type": "assess_resource", "value": "bois"}, {"type": "add_resource_duration", "value": "bois", "duration": 72}]}
    ]
  },
  {
    "id": "q_light_main",
    "text": "Disposez-vous d'un éclairage de secours sur batterie ?",
    "type": "single_choice",
    "options": [
      {"id": "opt_lamp_bat", "text": "Oui", "facts": [{"type": "assess_capability", "value": "eclairage"}, {"type": "add_asset", "value": "lampe_batterie"}, {"type": "add_resource", "value": "batterie"}, {"type": "assess_resource", "value": "batterie"}, {"type": "add_resource_duration", "value": "batterie", "duration": 72}]},
      {"id": "opt_no_lamp", "text": "Non (secteur uniquement)", "facts": [{"type": "assess_capability", "value": "eclairage"}, {"type": "add_asset", "value": "lampe_secteur"}]},
      {"id": "opt_no_light_at_all", "text": "Je n'ai aucun éclairage (Absence réelle)", "facts": [{"type": "assess_capability", "value": "eclairage"}]}
    ]
  }
]
''';
