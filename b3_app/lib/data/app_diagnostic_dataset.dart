const String appDiagnosticQuestionsJson = '''
[
  {
    "id": "q_heat_main",
    "text": "Comment chauffez-vous principalement votre logement ?",
    "type": "multiple_choice",
    "options": [
      {
        "id": "opt_rad_elec",
        "text": "Radiateurs \u00e9lectriques",
        "facts": [
          {
            "type": "assess_capability",
            "value": "chauffer"
          },
          {
            "type": "add_asset",
            "value": "radiateur_elec"
          }
        ]
      },
      {
        "id": "opt_pac",
        "text": "Pompe \u00e0 chaleur",
        "facts": [
          {
            "type": "assess_capability",
            "value": "chauffer"
          },
          {
            "type": "add_asset",
            "value": "pompe_chaleur"
          }
        ]
      },
      {
        "id": "opt_chaudiere_gaz",
        "text": "Chaudi\u00e8re gaz",
        "facts": [
          {
            "type": "assess_capability",
            "value": "chauffer"
          },
          {
            "type": "add_asset",
            "value": "chaudiere_gaz"
          }
        ]
      },
      {
        "id": "opt_chaudiere_bois",
        "text": "Chaudi\u00e8re bois ou granul\u00e9s",
        "facts": [
          {
            "type": "assess_capability",
            "value": "chauffer"
          },
          {
            "type": "add_asset",
            "value": "chaudiere_bois"
          }
        ]
      },
      {
        "id": "opt_poele_granules",
        "text": "Po\u00eale \u00e0 granul\u00e9s",
        "facts": [
          {
            "type": "assess_capability",
            "value": "chauffer"
          },
          {
            "type": "add_asset",
            "value": "poele_granules"
          }
        ]
      },
      {
        "id": "opt_poele_bois",
        "text": "Po\u00eale \u00e0 b\u00fbches (autonome sans \u00e9lectricit\u00e9)",
        "facts": [
          {
            "type": "assess_capability",
            "value": "chauffer"
          },
          {
            "type": "add_asset",
            "value": "poele_bois"
          }
        ]
      },
      {
        "id": "opt_none_q_heat_main",
        "text": "Aucun de ces \u00e9quipements",
        "facts": [
          {
            "type": "assess_capability",
            "value": "chauffer"
          }
        ]
      }
    ]
  },
  {
    "id": "q_heat_redundancy",
    "text": "En cas de coupure du syst\u00e8me principal (ex. panne de r\u00e9seau), avez-vous une autre fa\u00e7on de chauffer votre logement ?",
    "type": "single_choice",
    "metadata": {
      "purpose": "redundancy_check",
      "capability": "chauffer"
    },
    "options": [
      {
        "id": "opt_heat_alt_yes",
        "text": "Oui",
        "facts": []
      },
      {
        "id": "opt_heat_alt_no",
        "text": "Non",
        "facts": []
      },
      {
        "id": "opt_heat_alt_unk",
        "text": "Je ne sais pas",
        "facts": []
      }
    ]
  },
  {
    "id": "q_heat_alternative",
    "text": "Quelle autre solution utilisez-vous ?",
    "condition": {
      "dependsOn": "q_heat_redundancy",
      "hasAnswer": "opt_heat_alt_yes"
    },
    "type": "multiple_choice",
    "metadata": {
      "purpose": "alternative_discovery",
      "capability": "chauffer"
    },
    "options": [
      {
        "id": "opt_poele_bois",
        "text": "Po\u00eale \u00e0 b\u00fbches (autonome sans \u00e9lectricit\u00e9)",
        "facts": [
          {
            "type": "add_asset",
            "value": "poele_bois"
          }
        ]
      },
      {
        "id": "opt_poele_granules",
        "text": "Po\u00eale \u00e0 granul\u00e9s",
        "facts": [
          {
            "type": "add_asset",
            "value": "poele_granules"
          }
        ]
      },
      {
        "id": "opt_chaudiere_bois",
        "text": "Chaudi\u00e8re bois ou granul\u00e9s",
        "facts": [
          {
            "type": "add_asset",
            "value": "chaudiere_bois"
          }
        ]
      }
    ]
  },
  {
    "id": "q_heat_bois_reserve",
    "text": "Disposez-vous d'une r\u00e9serve de bois utilisable ?",
    "type": "single_choice",
    "options": [
      {
        "id": "opt_bois_yes",
        "text": "Oui, pour plusieurs jours",
        "facts": [
          {
            "type": "add_resource",
            "value": "bois"
          },
          {
            "type": "assess_resource",
            "value": "bois"
          },
          {
            "type": "add_resource_duration",
            "value": "bois",
            "duration": 72
          }
        ]
      },
      {
        "id": "opt_bois_limit",
        "text": "Oui, mais peu (moins de 48h)",
        "facts": [
          {
            "type": "add_resource",
            "value": "bois"
          },
          {
            "type": "assess_resource",
            "value": "bois"
          },
          {
            "type": "add_resource_duration",
            "value": "bois",
            "duration": 24
          }
        ]
      },
      {
        "id": "opt_bois_no",
        "text": "Non (ou insuffisante)",
        "facts": [
          {
            "type": "assess_resource",
            "value": "bois"
          }
        ]
      },
      {
        "id": "opt_bois_unk",
        "text": "Je ne sais pas",
        "facts": [
          {
            "type": "assess_resource_unknown",
            "value": "bois"
          }
        ]
      }
    ]
  },
  {
    "id": "q_heat_granules_reserve",
    "text": "Disposez-vous d'une r\u00e9serve de granul\u00e9s utilisable ?",
    "type": "single_choice",
    "options": [
      {
        "id": "opt_gra_yes",
        "text": "Oui, pour plusieurs jours",
        "facts": [
          {
            "type": "add_resource",
            "value": "granules"
          },
          {
            "type": "assess_resource",
            "value": "granules"
          },
          {
            "type": "add_resource_duration",
            "value": "granules",
            "duration": 72
          }
        ]
      },
      {
        "id": "opt_gra_no",
        "text": "Non (ou insuffisante)",
        "facts": [
          {
            "type": "assess_resource",
            "value": "granules"
          }
        ]
      },
      {
        "id": "opt_gra_unk",
        "text": "Je ne sais pas",
        "facts": [
          {
            "type": "assess_resource_unknown",
            "value": "granules"
          }
        ]
      }
    ]
  },
  {
    "id": "q_cook_main",
    "text": "De quels \u00e9quipements disposez-vous pour cuisiner ?",
    "type": "multiple_choice",
    "options": [
      {
        "id": "opt_plaque_elec",
        "text": "Plaque \u00e9lectrique / induction",
        "facts": [
          {
            "type": "assess_capability",
            "value": "cuisiner"
          },
          {
            "type": "add_asset",
            "value": "plaque_elec"
          }
        ]
      },
      {
        "id": "opt_four_elec",
        "text": "Four \u00e9lectrique",
        "facts": [
          {
            "type": "assess_capability",
            "value": "cuisiner"
          },
          {
            "type": "add_asset",
            "value": "four_elec"
          }
        ]
      },
      {
        "id": "opt_gaz_ville",
        "text": "Cuisini\u00e8re au gaz de ville",
        "facts": [
          {
            "type": "assess_capability",
            "value": "cuisiner"
          },
          {
            "type": "add_asset",
            "value": "gaziniere_ville"
          }
        ]
      },
      {
        "id": "opt_gaz_bouteille",
        "text": "Cuisini\u00e8re ou r\u00e9chaud sur bouteille de gaz",
        "facts": [
          {
            "type": "assess_capability",
            "value": "cuisiner"
          },
          {
            "type": "add_asset",
            "value": "rechaud_gaz"
          }
        ]
      },
      {
        "id": "opt_barbecue",
        "text": "Barbecue ext\u00e9rieur",
        "facts": [
          {
            "type": "assess_capability",
            "value": "cuisiner"
          },
          {
            "type": "add_asset",
            "value": "barbecue"
          }
        ]
      },
      {
        "id": "opt_none_q_cook_main",
        "text": "Aucun de ces \u00e9quipements",
        "facts": [
          {
            "type": "assess_capability",
            "value": "cuisiner"
          }
        ]
      }
    ]
  },
  {
    "id": "q_cook_redundancy",
    "text": "En cas de coupure (ex. \u00e9lectricit\u00e9 ou gaz de ville), avez-vous une autre fa\u00e7on de cuisiner (ex. r\u00e9chaud) ?",
    "type": "single_choice",
    "metadata": {
      "purpose": "redundancy_check",
      "capability": "cuisiner"
    },
    "options": [
      {
        "id": "opt_cook_alt_yes",
        "text": "Oui",
        "facts": []
      },
      {
        "id": "opt_cook_alt_no",
        "text": "Non",
        "facts": []
      },
      {
        "id": "opt_cook_alt_unk",
        "text": "Je ne sais pas",
        "facts": []
      }
    ]
  },
  {
    "id": "q_cook_alternative",
    "text": "Quelle autre solution utilisez-vous ?",
    "condition": {
      "dependsOn": "q_cook_redundancy",
      "hasAnswer": "opt_cook_alt_yes"
    },
    "type": "multiple_choice",
    "metadata": {
      "purpose": "alternative_discovery",
      "capability": "cuisiner"
    },
    "options": [
      {
        "id": "opt_gaz_bouteille",
        "text": "Cuisini\u00e8re ou r\u00e9chaud sur bouteille de gaz",
        "facts": [
          {
            "type": "add_asset",
            "value": "rechaud_gaz"
          }
        ]
      },
      {
        "id": "opt_barbecue",
        "text": "Barbecue ext\u00e9rieur",
        "facts": [
          {
            "type": "add_asset",
            "value": "barbecue"
          }
        ]
      }
    ]
  },
  {
    "id": "q_cook_gaz_reserve",
    "text": "Avez-vous une bouteille de gaz de rechange utilisable (actuellement connect\u00e9e ou en stock) ?",
    "type": "single_choice",
    "options": [
      {
        "id": "opt_gaz_yes",
        "text": "Oui",
        "facts": [
          {
            "type": "add_resource",
            "value": "gaz_bouteille"
          },
          {
            "type": "assess_resource",
            "value": "gaz_bouteille"
          }
        ]
      },
      {
        "id": "opt_gaz_no",
        "text": "Non",
        "facts": [
          {
            "type": "assess_resource",
            "value": "gaz_bouteille"
          }
        ]
      },
      {
        "id": "opt_gaz_unk",
        "text": "Je ne sais pas",
        "facts": [
          {
            "type": "assess_resource_unknown",
            "value": "gaz_bouteille"
          }
        ]
      }
    ]
  },
  {
    "id": "q_cook_gaz_duration",
    "text": "Combien de temps environ pouvez-vous cuisiner avec cette r\u00e9serve de gaz ?",
    "type": "single_choice",
    "options": [
      {
        "id": "opt_gaz_short",
        "text": "Moins de 24h",
        "facts": [
          {
            "type": "add_resource_duration",
            "value": "gaz_bouteille",
            "duration": 12
          }
        ]
      },
      {
        "id": "opt_gaz_long",
        "text": "Plusieurs jours",
        "facts": [
          {
            "type": "add_resource_duration",
            "value": "gaz_bouteille",
            "duration": 72
          }
        ]
      },
      {
        "id": "opt_gaz_dur_unk",
        "text": "Je ne sais pas",
        "facts": []
      }
    ]
  },
  {
    "id": "q_cook_charbon_reserve",
    "text": "Disposez-vous de charbon utilisable pour le barbecue ?",
    "type": "single_choice",
    "options": [
      {
        "id": "opt_charbon_yes",
        "text": "Oui",
        "facts": [
          {
            "type": "add_resource",
            "value": "charbon"
          },
          {
            "type": "assess_resource",
            "value": "charbon"
          },
          {
            "type": "add_resource_duration",
            "value": "charbon",
            "duration": 48
          }
        ]
      },
      {
        "id": "opt_charbon_no",
        "text": "Non",
        "facts": [
          {
            "type": "assess_resource",
            "value": "charbon"
          }
        ]
      },
      {
        "id": "opt_charbon_unk",
        "text": "Je ne sais pas",
        "facts": [
          {
            "type": "assess_resource_unknown",
            "value": "charbon"
          }
        ]
      }
    ]
  },
  {
    "id": "q_light_main",
    "text": "De quoi disposez-vous pour l'\u00e9clairage en cas de coupure \u00e9lectrique ?",
    "type": "multiple_choice",
    "options": [
      {
        "id": "opt_lampe_secteur",
        "text": "Rien de sp\u00e9cifique (luminaires branch\u00e9s sur secteur)",
        "facts": [
          {
            "type": "assess_capability",
            "value": "eclairage"
          },
          {
            "type": "add_asset",
            "value": "lampe_secteur"
          }
        ]
      },
      {
        "id": "opt_lampe_bat",
        "text": "Lampes torches ou de secours (\u00e0 piles ou batterie)",
        "facts": [
          {
            "type": "assess_capability",
            "value": "eclairage"
          },
          {
            "type": "add_asset",
            "value": "lampe_batterie"
          }
        ]
      },
      {
        "id": "opt_none_q_light_main",
        "text": "Aucun de ces \u00e9quipements",
        "facts": [
          {
            "type": "assess_capability",
            "value": "eclairage"
          }
        ]
      }
    ]
  },
  {
    "id": "q_light_bat_reserve",
    "text": "Vos lampes de secours sont-elles actuellement fonctionnelles et disposent-elles de piles/batteries de rechange ?",
    "type": "single_choice",
    "options": [
      {
        "id": "opt_bat_yes",
        "text": "Oui, de quoi tenir plusieurs soirs",
        "facts": [
          {
            "type": "add_resource",
            "value": "batterie"
          },
          {
            "type": "assess_resource",
            "value": "batterie"
          },
          {
            "type": "add_resource_duration",
            "value": "batterie",
            "duration": 48
          }
        ]
      },
      {
        "id": "opt_bat_no",
        "text": "Non, ou tr\u00e8s peu",
        "facts": [
          {
            "type": "assess_resource",
            "value": "batterie"
          },
          {
            "type": "add_resource_duration",
            "value": "batterie",
            "duration": 4
          }
        ]
      },
      {
        "id": "opt_bat_unk",
        "text": "Je ne sais pas",
        "facts": [
          {
            "type": "assess_resource_unknown",
            "value": "batterie"
          }
        ]
      }
    ]
  },
  {
    "id": "q_water_main",
    "text": "Comment acc\u00e9dez-vous \u00e0 l'eau courante ?",
    "type": "multiple_choice",
    "options": [
      {
        "id": "opt_robinet_eau",
        "text": "Eau du r\u00e9seau public",
        "facts": [
          {
            "type": "assess_capability",
            "value": "disposer_eau"
          },
          {
            "type": "add_asset",
            "value": "robinet_eau"
          }
        ]
      },
      {
        "id": "opt_stock_eau",
        "text": "J'ai un stock d'eau / cuve",
        "facts": [
          {
            "type": "assess_capability",
            "value": "disposer_eau"
          },
          {
            "type": "add_asset",
            "value": "stock_eau"
          }
        ]
      },
      {
        "id": "opt_none_q_water_main",
        "text": "Aucun / Je n'en ai pas",
        "facts": [
          {
            "type": "assess_capability",
            "value": "disposer_eau"
          }
        ]
      }
    ]
  },
  {
    "id": "q_water_reserve",
    "text": "De quelle r\u00e9serve d'eau disposez-vous (bouteilles, bidons...) ?",
    "type": "single_choice",
    "options": [
      {
        "id": "opt_water_yes",
        "text": "Oui, pour plusieurs jours",
        "facts": [
          {
            "type": "add_resource",
            "value": "reserve_eau"
          },
          {
            "type": "assess_resource",
            "value": "reserve_eau"
          },
          {
            "type": "add_resource_duration",
            "value": "reserve_eau",
            "duration": 72
          }
        ]
      },
      {
        "id": "opt_water_no",
        "text": "Non, presque rien",
        "facts": [
          {
            "type": "assess_resource",
            "value": "reserve_eau"
          }
        ]
      },
      {
        "id": "opt_water_unk",
        "text": "Je ne sais pas",
        "facts": [
          {
            "type": "assess_resource_unknown",
            "value": "reserve_eau"
          }
        ]
      }
    ]
  },
  {
    "id": "q_com_main",
    "text": "Quels moyens de communication utilisez-vous ?",
    "type": "multiple_choice",
    "options": [
      {
        "id": "opt_box_internet",
        "text": "Box Internet fixe",
        "facts": [
          {
            "type": "assess_capability",
            "value": "acceder_internet"
          },
          {
            "type": "add_asset",
            "value": "box_internet"
          }
        ]
      },
      {
        "id": "opt_smartphone",
        "text": "Smartphone (r\u00e9seau mobile)",
        "facts": [
          {
            "type": "assess_capability",
            "value": "communiquer"
          },
          {
            "type": "add_asset",
            "value": "smartphone"
          }
        ]
      },
      {
        "id": "opt_none_q_com_main",
        "text": "Aucun / Je n'en ai pas",
        "facts": [
          {
            "type": "assess_capability",
            "value": "acceder_internet"
          }
        ]
      }
    ]
  },
  {
    "id": "q_food_storage",
    "text": "Avez-vous des appareils de conservation des aliments n\u00e9cessitant de l'\u00e9lectricit\u00e9 ?",
    "type": "multiple_choice",
    "options": [
      {
        "id": "opt_frigo",
        "text": "Oui, un r\u00e9frig\u00e9rateur",
        "facts": [
          {
            "type": "assess_capability",
            "value": "conserver_aliments"
          },
          {
            "type": "add_asset",
            "value": "refrigerateur"
          }
        ]
      },
      {
        "id": "opt_congel",
        "text": "Oui, un cong\u00e9lateur",
        "facts": [
          {
            "type": "assess_capability",
            "value": "conserver_aliments"
          },
          {
            "type": "add_asset",
            "value": "congelateur"
          }
        ]
      },
      {
        "id": "opt_none_q_food_storage",
        "text": "Aucun de ces \u00e9quipements",
        "facts": [
          {
            "type": "assess_capability",
            "value": "conserver_aliments"
          }
        ]
      }
    ]
  },
  {
    "id": "q_charge_main",
    "text": "Disposez-vous d'une batterie externe (powerbank) ou d'une station d'\u00e9nergie portable ?",
    "type": "multiple_choice",
    "options": [
      {
        "id": "opt_powerbank",
        "text": "Oui, une ou plusieurs batteries externes",
        "facts": [
          {
            "type": "assess_capability",
            "value": "recharger_appareils"
          },
          {
            "type": "add_asset",
            "value": "batterie_externe"
          }
        ]
      },
      {
        "id": "opt_powerstation",
        "text": "Oui, une station d'\u00e9nergie portable",
        "facts": [
          {
            "type": "assess_capability",
            "value": "recharger_appareils"
          },
          {
            "type": "add_asset",
            "value": "station_energie_portable"
          }
        ]
      },
      {
        "id": "opt_none_q_charge_main",
        "text": "Aucun de ces \u00e9quipements",
        "facts": [
          {
            "type": "assess_capability",
            "value": "recharger_appareils"
          }
        ]
      }
    ]
  },
  {
    "id": "q_charge_bat_status",
    "text": "Connaissez-vous l'autonomie ou l'\u00e9tat de charge actuel de ces batteries / stations ?",
    "condition": {
      "dependsOn": "q_charge_main",
      "hasAnswer": "opt_powerbank"
    },
    "type": "single_choice",
    "options": [
      {
        "id": "opt_charge_yes",
        "text": "Oui, elles sont charg\u00e9es et pr\u00eates",
        "facts": [
          {
            "type": "add_resource",
            "value": "charge_powerbank"
          },
          {
            "type": "assess_resource",
            "value": "charge_powerbank"
          }
        ]
      },
      {
        "id": "opt_charge_no",
        "text": "Non, elles sont probablement vides",
        "facts": [
          {
            "type": "assess_resource",
            "value": "charge_powerbank"
          }
        ]
      },
      {
        "id": "opt_charge_unk",
        "text": "Je ne sais pas",
        "facts": [
          {
            "type": "assess_resource_unknown",
            "value": "charge_powerbank"
          }
        ]
      }
    ]
  },
  {
    "id": "q_charge_station_status",
    "text": "Connaissez-vous l'autonomie de votre station d'\u00e9nergie ?",
    "condition": {
      "dependsOn": "q_charge_main",
      "hasAnswer": "opt_powerstation"
    },
    "type": "single_choice",
    "options": [
      {
        "id": "opt_station_yes",
        "text": "Oui, elle est charg\u00e9e et pr\u00eate",
        "facts": [
          {
            "type": "add_resource",
            "value": "charge_station_energie"
          },
          {
            "type": "assess_resource",
            "value": "charge_station_energie"
          }
        ]
      },
      {
        "id": "opt_station_no",
        "text": "Non, elle est vide",
        "facts": [
          {
            "type": "assess_resource",
            "value": "charge_station_energie"
          }
        ]
      },
      {
        "id": "opt_station_unk",
        "text": "Je ne sais pas",
        "facts": [
          {
            "type": "assess_resource_unknown",
            "value": "charge_station_energie"
          }
        ]
      }
    ]
  },
  {
    "id": "q_sanitary",
    "text": "Vos toilettes (WC) utilisent-elles l'eau du r\u00e9seau pour la chasse d'eau ?",
    "type": "single_choice",
    "options": [
      {
        "id": "opt_wc_reseau",
        "text": "Oui",
        "facts": [
          {
            "type": "assess_capability",
            "value": "utiliser_sanitaires"
          },
          {
            "type": "add_asset",
            "value": "wc_chasse_eau"
          }
        ]
      },
      {
        "id": "opt_wc_autre",
        "text": "Non (ou pas concern\u00e9)",
        "facts": [
          {
            "type": "assess_capability",
            "value": "utiliser_sanitaires"
          }
        ]
      }
    ]
  },
  {
    "id": "q_info_main",
    "text": "Comment recevez-vous les informations importantes en temps normal ?",
    "type": "multiple_choice",
    "options": [
      {
        "id": "opt_info_tv",
        "text": "T\u00e9l\u00e9vision / Box",
        "facts": [
          {
            "type": "assess_capability",
            "value": "recevoir_informations"
          },
          {
            "type": "add_asset",
            "value": "tv_box"
          }
        ]
      },
      {
        "id": "opt_info_smartphone",
        "text": "Smartphone",
        "facts": [
          {
            "type": "assess_capability",
            "value": "recevoir_informations"
          },
          {
            "type": "add_asset",
            "value": "smartphone"
          }
        ]
      },
      {
        "id": "opt_none_q_info_main",
        "text": "Aucun de ces \u00e9quipements",
        "facts": [
          {
            "type": "assess_capability",
            "value": "recevoir_informations"
          }
        ]
      }
    ]
  },
  {
    "id": "q_info_alt",
    "metadata": {
      "purpose": "alternative_discovery",
      "capability": "recevoir_informations"
    },
    "text": "Avez-vous une radio autonome \u00e0 manivelle ou solaire pour recevoir les informations d'urgence ?",
    "type": "single_choice",
    "options": [
      {
        "id": "opt_radio_yes",
        "text": "Oui",
        "facts": [
          {
            "type": "add_asset",
            "value": "radio_manivelle_solaire"
          },
          {
            "type": "assess_capability",
            "value": "recevoir_informations"
          }
        ]
      },
      {
        "id": "opt_radio_no",
        "text": "Non",
        "facts": [
          {
            "type": "assess_capability",
            "value": "recevoir_informations"
          }
        ]
      },
      {
        "id": "opt_radio_unk",
        "text": "Je ne sais pas",
        "facts": [
          {
            "type": "assess_capability",
            "value": "recevoir_informations"
          }
        ]
      }
    ]
  }
]
''';
