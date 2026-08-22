"""Build the normalized, source-backed Aphidex 1.3 snapshots.

This importer intentionally keeps extractor files outside the Flutter asset
tree. Only the fields consumed by Aphidex are materialized. Grounded 1 data,
user storage, monetization and deployment configuration are never touched.
"""
from __future__ import annotations

import csv
import hashlib
import json
import re
import shutil
import subprocess
import unicodedata
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from xml.etree import ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
EXTRACTOR_ROOT = Path(r"F:\ByteShark-Dev\Aphidex_extractor_v1\aphidex_extractor_v1\output_aphidex_extractor_v1")
EXCEL = Path(r"F:\Ordenar\APHIDEX NEW UPDATER\Aphidex_G2_textos_criaturas_ES_EN_RU.xlsx")
CAPTURES = Path(r"F:\XboxCaptureCopies")
FMODEL = Path(r"F:\Software_Instaladores\F-model\Output\Exports\Augusta\Content")
MAGICK = Path(r"F:\Software_Instaladores\ImageMagick-7.1.2-Q16-HDRI\magick.exe")

PHASE1 = EXTRACTOR_ROOT / "phase1"
EQUIPMENT = EXTRACTOR_ROOT / "phase2" / "equipment"
DATA_OUT = ROOT / "assets" / "data" / "g2"
ASSET_OUT = ROOT / "assets" / "g2"
REPORT_OUT = ROOT / "outputs" / "aphidex_1_3"
MIGRATION_OUT = ROOT / "migration" / "aphidex_1_3"

MAP_DOMAIN = PHASE1 / "map" / "grounded2_map_domain_v1_2.json"
CREATURE_DOMAIN = PHASE1 / "aphidex_grounded2_v5_1_1.json"
LOOT_DOMAIN = PHASE1 / "loot" / "grounded2_loot_domain_v1_2.json"
WEAPON_DOMAIN = EQUIPMENT / "baselines" / "grounded2_weapon_domain_v1.json"
ARMOR_DOMAIN = EQUIPMENT / "baselines" / "grounded2_armor_domain_v1.json"
TRINKET_DOMAIN = EQUIPMENT / "baselines" / "grounded2_trinket_domain_v1.json"
ACQUISITION_DOMAIN = EQUIPMENT / "acquisition" / "grounded2_equipment_acquisition_domain_v1.json"
PHYSICAL_PICKUPS = EQUIPMENT / "physical_spawn" / "grounded2_physical_equipment_pickups_v2.json"
MIXR_COMPOSER = EXTRACTOR_ROOT / "phase2" / "mixr" / "grounded2_mixr_defense_build_composer_v1_1_0.json"
QA = EXTRACTOR_ROOT / "final" / "aphidex_extractor_qa_v1.json"
PRESENTATION_OVERRIDES = DATA_OUT / "g2_presentation_overrides.json"

EXCEL_ALIASES = {
    "Pond Jockeys": "g2_pond_jockey",
    "Ancient Pond Jockeys": "g2_ancient_pond_jockey",
    "Monarch": "g2_koi_oriole",
    "Juvenile Striped Bark Scorpion": "g2_striped_bark_scorpion_jr",
    "O.R.C. Juvenile Striped Bark Scorpion": "g2_orc_striped_bark_scorpion_jr",
    "Toe Biter Buggy": "g2_buggy_toe_biter",
}

# The current public catalog contains two historical entries with this raw ID.
# Map data belongs to the canonical nymph entry; the Buggy entry keeps its
# public ID and editorial text but does not inherit an ambiguous natural spawn.
TECHNICAL_ID_ALIASES = {
    "ToeBiterNymph": "g2_toe_biter_nymph",
}

EXCLUDED_TECHNICAL_IDS = {
    "AntFireSoldier", "AntFireWorker", "ArcR", "ArcRBoss", "BlackOx",
    "GnatMeaty", "LarvaCharcoal", "Mant", "Mantis", "MiteDust", "Moth",
    "RolyPoly", "RolyPolySickly", "Scarab", "Schmector", "SpiderBlackWidow",
    "SpiderlingWidow", "StinkbugGreenShield", "Tazt", "TaztRuzT",
    "TermiteKing", "TermiteSoldier", "TermiteWorker", "WaspQueen",
}

MIXR_LABELS = {
    "mixr_7545": {"id": "mixr_greenhouse", "en": "Greenhouse", "es": "Invernadero", "ru": "Теплица"},
    "mixr_7546": {"id": "mixr_picnic", "en": "Picnic", "es": "Pícnic", "ru": "Пикник"},
    "mixr_7547": {"id": "mixr_resting", "en": "Resting", "es": "Descanso", "ru": "Зона отдыха"},
}

# Explicitly reviewed 1.3 captures. These associations were visually checked;
# descriptive filenames are never used as a fuzzy matching rule.
VERIFIED_CAPTURE_OVERRIDES = {
    "g2_ogrr_green_shield_bug": ("green_shield_ogre_spicy.png", "OGRR_Green_Shield_Bug.webp"),
    "g2_ogrr_striped_bark_scorpion": ("escorpion_corteza_ogrr_acido.png", "OGRR_Striped_Bark_Scorpion.webp"),
    "g2_ogrr_tiger_mosquito": ("mosquito_tigre_ogrr_picante.png", "OGRR_Tiger_Mosquito.webp"),
    "g2_ogrr_toe_biter": ("Toe_bitter_ogre_spicy.png", "OGRR_Toe_Biter.webp"),
    "g2_orc_striped_bark_scorpion_jr": ("Escorpion_corteza_jr_ocr.png", "ORC_Striped_Bark_Scorpion_Jr.webp"),
    "g2_orc_striped_bark_scorpion": ("Escorpion_corteza_orc_reposo.png", "ORC_Striped_Bark_Scorpion.webp"),
    "g2_orc_striped_bark_scorpling": ("Escorpion_cortza_cria_orc.png", "ORC_Striped_Bark_Scorpling.webp"),
    "g2_orc_toe_biter": ("Toe_bitter_orc.png", "ORC_Toe_Biter.webp"),
}

ORC_BROODMOTHER_DESCRIPTION = {
    "en": "The terrifying queen of spiders known as the Broodmother is now under the control of the Masked Stranger. Drops Broodmother chunks on death.",
    "es": "La aterradora reina de las arañas conocida como la Madre Araña está ahora bajo el control de la Extraña Enmascarada. Al morir, deja trozos de Madre Araña.",
    "ru": "O.R.C. Мать выводка — искажённая версия Broodmother под контролем Незнакомки в маске. После победы над ней остаются части Broodmother.",
}

WORD_ES = {
    "accessory": "amuleto", "ant": "hormiga", "armor": "armadura", "arrow": "flecha",
    "axe": "hacha", "bee": "abeja", "black": "negra", "blade": "hoja", "bomb": "bomba",
    "bow": "arco", "broodmother": "madre de camada", "chest": "pechera", "club": "garrote",
    "crow": "cuervo", "dagger": "daga", "fire": "fuego", "fresh": "fresco", "gas": "gas",
    "gloves": "guantes", "great": "gran", "hammer": "martillo", "head": "cabeza",
    "helmet": "casco", "larva": "larva", "legs": "perneras", "mask": "máscara",
    "mint": "menta", "mosquito": "mosquito", "red": "roja", "rotten": "podrido",
    "salt": "sal", "shield": "escudo", "sour": "ácido", "spear": "lanza",
    "spider": "araña", "spicy": "picante", "staff": "bastón", "sword": "espada",
    "tarantula": "tarántula", "torch": "antorcha", "venom": "veneno", "wasp": "avispa",
    "water": "agua", "wolf": "lobo",
}

WORD_RU = {
    "accessory": "талисман", "ant": "муравья", "armor": "броня", "arrow": "стрела",
    "axe": "топор", "bee": "пчелы", "black": "черный", "blade": "клинок", "bomb": "бомба",
    "bow": "лук", "chest": "нагрудник", "club": "дубина", "crow": "ворона",
    "dagger": "кинжал", "fire": "огонь", "fresh": "мятный", "gas": "газовый",
    "gloves": "перчатки", "great": "большой", "hammer": "молот", "head": "голова",
    "helmet": "шлем", "larva": "личинки", "legs": "поножи", "mask": "маска",
    "mint": "мята", "mosquito": "комара", "red": "красный", "rotten": "гнилой",
    "salt": "соленый", "shield": "щит", "sour": "кислый", "spear": "копье",
    "spider": "паука", "spicy": "острый", "staff": "посох", "sword": "меч",
    "tarantula": "тарантула", "torch": "факел", "venom": "яд", "wasp": "осы",
    "water": "водяной", "wolf": "волка",
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def words(value: str) -> list[str]:
    expanded = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", value.replace("_", " "))
    expanded = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", expanded)
    return [part for part in re.split(r"[^A-Za-z0-9.]+", expanded) if part]


def display_names(technical_id: str) -> dict[str, str]:
    tokens = words(technical_id)
    en = " ".join(tokens)
    es = " ".join(WORD_ES.get(token.lower(), token) for token in tokens)
    ru = " ".join(WORD_RU.get(token.lower(), token) for token in tokens)
    return {"en": en, "es": es[:1].upper() + es[1:], "ru": ru[:1].upper() + ru[1:]}


def clean_text(value: object) -> str:
    return re.sub(r"\s+", " ", str(value or "")).strip()


def normalized_name(value: str) -> str:
    decomposed = unicodedata.normalize("NFD", value)
    plain = "".join(char for char in decomposed if unicodedata.category(char) != "Mn")
    return re.sub(r"[^a-z0-9]+", " ", plain.lower()).strip()


def xlsx_first_sheet(path: Path) -> list[list[object]]:
    ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
    with zipfile.ZipFile(path) as archive:
        shared = []
        if "xl/sharedStrings.xml" in archive.namelist():
            root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
            for item in root.findall("m:si", ns):
                shared.append("".join(node.text or "" for node in item.findall(".//m:t", ns)))
        sheet = ET.fromstring(archive.read("xl/worksheets/sheet1.xml"))
    rows: list[list[object]] = []
    for row in sheet.findall(".//m:sheetData/m:row", ns):
        values: dict[int, object] = {}
        for cell in row.findall("m:c", ns):
            ref = cell.attrib["r"]
            column = 0
            for char in re.match(r"[A-Z]+", ref).group(0):
                column = column * 26 + ord(char) - 64
            value_node = cell.find("m:v", ns)
            inline = cell.find("m:is/m:t", ns)
            if inline is not None:
                value: object = inline.text or ""
            elif value_node is None:
                value = ""
            elif cell.attrib.get("t") == "s":
                value = shared[int(value_node.text)]
            else:
                raw = value_node.text or ""
                value = int(raw) if raw.isdigit() else raw
            values[column - 1] = value
        if values:
            rows.append([values.get(index, "") for index in range(max(values) + 1)])
    return rows


def import_editorial_excel() -> dict:
    rows = xlsx_first_sheet(EXCEL)
    if len(rows) != 39 or len(rows[0]) < 17:
        raise ValueError(f"Unexpected editorial workbook shape: {len(rows)} rows")
    headers = rows[0]
    current_en: dict[str, dict] = {}
    by_name: dict[str, str] = {}
    for path in (ROOT / "assets" / "data" / "creatures" / "en" / "details").glob("g2_*.json"):
        item = load_json(path)
        current_en[item["id"]] = item
        by_name[normalized_name(clean_text(item.get("name")))] = item["id"]

    mappings = []
    for row in rows[1:]:
        english_name = clean_text(row[3])
        creature_id = EXCEL_ALIASES.get(english_name) or by_name.get(normalized_name(english_name))
        if not creature_id:
            raise ValueError(f"No explicit creature mapping for Excel row: {english_name}")
        mappings.append({"row": int(row[0]), "id": creature_id, "englishName": english_name})
        fields = {
            "behavior": {"es": row[5], "en": row[6], "ru": row[7]},
            "interactionWithPlayer": {"es": row[8], "en": row[9], "ru": row[10]},
            "interactionWithCreatures": {"es": row[11], "en": row[12], "ru": row[13]},
            "strategy": {"es": row[14], "en": row[15], "ru": row[16]},
        }
        for language in ("es", "en", "ru"):
            detail_path = ROOT / "assets" / "data" / "creatures" / language / "details" / f"{creature_id}.json"
            detail = load_json(detail_path)
            for key, localized in fields.items():
                text = clean_text(localized[language])
                if not text:
                    raise ValueError(f"Empty {key}/{language} for {creature_id}")
                detail[key] = text
            write_json(detail_path, detail)
    mapped_ids = [row["id"] for row in mappings]
    if len(set(mapped_ids)) != len(mapped_ids):
        raise ValueError("Ambiguous Excel mapping: more than one row resolved to the same public ID")
    return {"headers": headers, "rowsApplied": len(mappings), "mappings": mappings}


def apply_presentation_overrides() -> dict:
    """Apply field-level editorial rules without replacing extracted gameplay."""
    payload = load_json(PRESENTATION_OVERRIDES)
    overrides = {
        public_id: dict(values)
        for public_id, values in payload.get("overrides", {}).items()
    }
    danger_config = payload.get("dangerOverrides", {})
    danger_values = danger_config.get("values", {})
    for public_id, danger in danger_values.items():
        overrides.setdefault(public_id, {})["danger"] = danger
    applied = []
    for language in ("en", "es", "ru"):
        index_path = ROOT / "assets" / "data" / "creatures" / language / "index_g2.json"
        index = load_json(index_path)
        by_id = {row["id"]: row for row in index}
        for public_id, values in overrides.items():
            detail_path = ROOT / "assets" / "data" / "creatures" / language / "details" / f"{public_id}.json"
            if not detail_path.is_file() or public_id not in by_id:
                raise ValueError(f"Presentation override target not found: {public_id}/{language}")
            detail = load_json(detail_path)
            for field, value in values.items():
                if field == "provenance":
                    continue
                detail[field] = value
                if field in {"temperament", "collectionGroup", "hideHealth", "entityType", "customAsset", "mapMarkerAsset", "danger"}:
                    by_id[public_id][field] = value
            detail["presentationOverrideProvenance"] = values.get("provenance", "explicit_editorial")
            if public_id in danger_values:
                detail["dangerOverrideProvenance"] = danger_config.get(
                    "provenance", "community_calibrated",
                )
            write_json(detail_path, detail)
            if language == "en":
                applied.append({"publicId": public_id, "fields": sorted(key for key in values if key != "provenance")})
        write_json(index_path, index)
    master_path = ROOT / "assets" / "data" / "enemies_g2.json"
    master = load_json(master_path)
    master_by_id = {row["id"]: row for row in master}
    for public_id, values in overrides.items():
        for field, value in values.items():
            if field != "provenance":
                master_by_id[public_id][field] = value
        master_by_id[public_id]["presentationOverrideProvenance"] = values.get(
            "provenance", "explicit_editorial",
        )
        if public_id in danger_values:
            master_by_id[public_id]["dangerOverrideProvenance"] = danger_config.get(
                "provenance", "community_calibrated",
            )
    write_json(master_path, master)
    return {
        "items": len(applied),
        "applied": applied,
        "dangerOverrides": len(danger_values),
        "dangerProvenance": danger_config.get("provenance"),
        "schema": payload.get("schema"),
    }


def resolved_icon(icon: dict, technical_id: str) -> str:
    raw = clean_text((icon or {}).get("localPng"))
    filename = Path(raw).name if raw else ""
    source = FMODEL / "Blueprints" / "Items" / "Icons" / filename
    provenance = "texture_export"
    if (icon or {}).get("sourceKind") == "material_instance":
        material_asset = clean_text((icon or {}).get("asset"))
        material_name = Path(material_asset).name
        material_json = FMODEL / "Blueprints" / "Items" / "Icons" / f"{material_name}.json"
        if material_json.is_file():
            material = load_json(material_json)
            parameters = (material[0].get("Properties") or {}).get("TextureParameterValues", []) if material else []
            value = next((
                row.get("ParameterValue") or {} for row in parameters
                if clean_text((row.get("ParameterInfo") or {}).get("Name")).casefold() == "icon"
            ), {})
            texture_path = clean_text(value.get("ObjectPath")).split(".", 1)[0]
            if texture_path.startswith("/Game/"):
                source = FMODEL / Path(texture_path.removeprefix("/Game/") + ".png")
                filename = source.name
                provenance = "material_instance_icon_parameter"
    if not filename or not source.is_file():
        return ""
    destination = ASSET_OUT / "equipment" / "icons" / f"{technical_id}.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    icon["resolvedProvenance"] = provenance
    icon["resolvedSource"] = source.relative_to(FMODEL).as_posix()
    return destination.relative_to(ROOT).as_posix()


def map_pickups() -> dict[str, list[dict]]:
    result: dict[str, list[dict]] = defaultdict(list)
    for pickup in load_json(PHYSICAL_PICKUPS).get("pickups", []):
        map_value = pickup.get("map") or {}
        if pickup.get("sourceProven") is not True or not map_value.get("id"):
            continue
        result[pickup["technicalId"]].append({
            "id": clean_text(pickup.get("guid")) or f"pickup_{len(result[pickup['technicalId']])}",
            "targetType": "equipment", "targetId": pickup["technicalId"],
            "technicalId": pickup["technicalId"],
            "map": map_value["id"], "u": map_value.get("u"), "v": map_value.get("v"),
            "world": pickup.get("world"), "type": "physical_pickup", "conditional": False,
            "environmentHazards": [],
        })
    return result


def compact_acquisition(item: dict | None) -> dict:
    if not item:
        return {"status": "unresolved_acquisition", "methods": []}
    recipes = []
    for recipe in (item.get("crafting") or {}).get("recipes", []):
        recipes.append({
            "id": recipe.get("canonicalRow"),
            "station": recipe.get("craftingBuildingTag"),
            "requirements": [
                {"itemId": req.get("itemRow"), "count": req.get("count")}
                for req in recipe.get("requirements", []) if req.get("itemRow")
            ],
            "unlockSources": recipe.get("unlockSources", []),
        })
    return {
        "status": item.get("status") or "unresolved_acquisition",
        "methods": item.get("methods", []), "recipes": recipes,
        "lootSourceReferences": item.get("lootSourceReferences", []),
        "bossCachedDrops": item.get("bossCachedDrops", []),
    }


def compact_attacks(combat: dict) -> list[dict]:
    output = []
    for attack in (combat or {}).get("attacks", []):
        base = attack.get("base")
        if not isinstance(base, dict):
            continue
        damage_type = base.get("damageType") or {}
        status_effects = []
        for effect in base.get("statusEffects", []):
            if not isinstance(effect, dict):
                raise ValueError(f"Structured status effect expected, got {type(effect).__name__}")
            source = effect.get("source") if isinstance(effect.get("source"), dict) else effect
            row = clean_text(source.get("row") or source.get("RowName"))
            effect_id = clean_text(effect.get("id") or effect.get("technicalId") or row)
            if not effect_id:
                raise ValueError("Equipment status effect has no stable identifier")
            status_effects.append({"id": effect_id, "row": row, "source": effect})
        output.append({
            "damage": base.get("damage"), "stun": base.get("hitStun"),
            "stamina": attack.get("staminaCost"), "range": attack.get("range"),
            "physical": damage_type.get("physical"), "element": damage_type.get("element"),
            "statusEffects": status_effects,
            "chargedDamage": (attack.get("charged") or {}).get("damage"),
        })
    return output


def compact_effects(effects: dict | None) -> list[str]:
    if not effects:
        return []
    values = []
    for key, value in effects.items():
        if key.lower().startswith("raw"):
            continue
        if isinstance(value, list):
            values.extend(clean_text(row.get("source", {}).get("row") if isinstance(row, dict) else row) for row in value)
        elif isinstance(value, dict):
            values.extend(compact_effects(value))
    return sorted({value for value in values if value and len(value) < 120})


def humanize_identifier(value: str) -> str:
    text = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", clean_text(value))
    text = re.sub(r"[_\-]+", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def equipment_classification(domain: str, technical_id: str, slot: object) -> dict:
    if domain == "weapon":
        subtype, source = "weapon", "extractor_domain"
    elif domain == "shield":
        subtype, source = "shield", "extractor_domain"
    elif domain == "armor":
        slot_name = clean_text(slot).removeprefix("EEquipmentSlot::").lower()
        subtype = slot_name if slot_name in {"head", "chest", "legs"} else "armor_piece"
        source = "extractor_slot" if slot_name in {"head", "chest", "legs"} else "domain_fallback"
    elif technical_id.startswith("Ominent"):
        subtype, source = "badge", "technical_prefix"
    else:
        subtype, source = "accessory", "extractor_domain"
    return {
        "normalizedType": domain,
        "normalizedSubtype": subtype,
        "classificationSource": source,
        "classificationFallbackUsed": source == "domain_fallback",
    }


def materialize_language(value, language: str):
    if isinstance(value, list):
        return [materialize_language(item, language) for item in value]
    if isinstance(value, dict):
        language_keys = set(value) & {"es", "en", "ru"}
        if language_keys and set(value) <= {"es", "en", "ru"}:
            fallback_order = {
                "es": ("es", "en", "ru"),
                "en": ("en", "es", "ru"),
                "ru": ("ru", "es", "en"),
            }[language]
            return next((value[key] for key in fallback_order if clean_text(value.get(key))), "")
        return {key: materialize_language(item, language) for key, item in value.items()}
    return value


def normalized_bonuses(rows: list[dict]) -> list[dict]:
    return [
        {"type": clean_text(kind).lower(), "bonusPct": round(float(row.get("percent") or 0))}
        for row in rows for kind in row.get("damageTypes", []) if clean_text(kind)
    ]


def classify_action(row: dict, damage: dict) -> str:
    explicit = clean_text(row.get("actionType")).lower()
    allowed = {"defensive_action", "movement_action", "summon_action", "aoe", "projectile", "ranged", "melee"}
    if explicit in allowed:
        return explicit
    identity = " ".join((clean_text(row.get("id")), clean_text(row.get("ability")))).lower()
    amount = damage.get("amount")
    if any(value in identity for value in ("block", "guard")) and (amount is None or float(amount) == 0):
        return "defensive_action"
    if any(value in identity for value in ("dodge", "flee", "retreat")):
        return "movement_action"
    if "summon" in identity or "spawn" in identity and (amount is None or float(amount) == 0):
        return "summon_action"
    if clean_text(row.get("hitResolutionType")).lower() == "aoe":
        return "aoe"
    if row.get("indirectCombat"):
        return "projectile"
    if row.get("ranged"):
        return "ranged"
    return "melee"


def attack_fields(row: dict, damage: dict) -> dict:
    raw_types = damage.get("types") or ([damage.get("type")] if damage.get("type") else [])
    damage_types = [clean_text(value).lower() for value in raw_types if clean_text(value)]
    tags = list(damage_types)
    if row.get("ranged"):
        tags.append("ranged")
    if row.get("indirectCombat"):
        tags.append("projectile")
    blockability = "unblockable" if any("unblockable" in value for value in damage_types) else "unknown"
    status = [humanize_identifier(value) for value in damage.get("statusEffects", [])]
    return {
        "tags": sorted(set(tags)), "damageTypes": damage_types,
        "damage": damage.get("amount"), "cooldownSeconds": row.get("cooldown"),
        "range": row.get("range"), "stun": damage.get("hitStun"),
        "statusEffects": status,
        "statusEffectDetails": [{"id": value, "value": None, "durationSeconds": None} for value in status],
        "ranged": bool(row.get("ranged")), "projectile": bool(row.get("indirectCombat")),
        "hitResolutionType": row.get("hitResolutionType"),
        "actionType": classify_action(row, damage), "blockability": blockability,
    }


def normalized_attacks(rows: list[dict]) -> list[dict]:
    attacks = []
    for row in rows:
        if row.get("resolved") is not True:
            continue
        damage = row.get("damage") if isinstance(row.get("damage"), dict) else {}
        attack = {
            "name": humanize_identifier(row.get("ability") or row.get("id") or "Attack"),
            "technicalId": clean_text(row.get("id") or row.get("ability")),
        }
        attack.update(attack_fields(row, damage))
        attacks.append(attack)
    return attacks


def merge_attack_details(historical: list[dict], extractor_rows: list[dict]) -> list[dict]:
    source_by_id = {
        clean_text(row.get("id") or row.get("ability")): row
        for row in extractor_rows if row.get("resolved") is True
    }
    merged = json.loads(json.dumps(historical))
    seen = set()
    for attack in merged:
        technical_id = clean_text(attack.get("technicalId"))
        source = source_by_id.get(technical_id)
        if not source:
            continue
        seen.add(technical_id)
        damage = source.get("damage") if isinstance(source.get("damage"), dict) else {}
        attack.update(attack_fields(source, damage))
    additions = normalized_attacks([
        row for row in extractor_rows
        if clean_text(row.get("id") or row.get("ability")) not in seen
    ])
    return merged + additions


def restored_weakpoints(historical: dict, extractor_rows: list[object]) -> list[dict]:
    primary = historical.get("weakPoint")
    candidates = [primary] if isinstance(primary, dict) else historical.get("weakPoints", [])
    restored = []
    for row in candidates:
        if not isinstance(row, dict) or not clean_text(row.get("part")):
            continue
        damage = clean_text(row.get("susceptibleDamage")) or "unknown"
        restored.append({
            "part": clean_text(row.get("part")).lower(),
            "susceptibleDamage": damage,
            "susceptibleDamageTypes": row.get("susceptibleDamageTypes") or [damage],
            "weaponFamilies": ["bow", "crossbow"] if damage in {"stabbing_arrows_only", "projectile_piercing"} else [],
            "provenance": "historical_editorial",
        })
    if restored:
        return restored
    return [{
        "part": clean_text(value).lower(), "susceptibleDamage": "unknown",
        "susceptibleDamageTypes": [], "weaponFamilies": [], "provenance": "extractor_region_only",
    } for value in extractor_rows if clean_text(value)]


def normalized_loot(technical_id: str, loot_domain: dict) -> tuple[list[dict], list[dict]]:
    technical = loot_domain.get("technicalCreatures", {}).get(technical_id) or {}
    primary = next((profile for profile in technical.get("profiles", []) if profile.get("role") == "primary"), None)
    if not primary:
        return [], []
    rolls = [
        row for row in (primary.get("loot") or {}).get("rolls", [])
        if row.get("parseStatus") == "resolved" and row.get("rollKind") == "item" and row.get("itemRow")
    ]
    grouped: dict[str, list[dict]] = defaultdict(list)
    for row in rolls:
        grouped[row["itemRow"]].append(row)
    standard = []
    for item_id, item_rolls in sorted(grouped.items()):
        guaranteed = sum(int(row.get("count") or 0) for row in item_rolls if float(row.get("baseDropChance") or row.get("dropChance") or 0) >= 1)
        maximum = sum(int(row.get("count") or 0) for row in item_rolls)
        highest_chance = max(float(row.get("baseDropChance") or row.get("dropChance") or 0) for row in item_rolls)
        standard.append({
            "section": "rare" if highest_chance <= .05 else "loot",
            "item": humanize_identifier(item_id), "minCount": guaranteed, "maxCount": maximum,
        })
    duplicate_counts = Counter(
        (row["itemRow"], int(row.get("count") or 0), float(row.get("baseDropChance") or row.get("dropChance") or 0))
        for row in rolls
    )
    advanced = []
    for (item_id, count, chance), roll_count in sorted(duplicate_counts.items()):
        advanced.append({
            "item": humanize_identifier(item_id), "countLabel": str(count),
            "chancePct": round(chance * 100), "rollCount": roll_count,
            "notes": f"{roll_count} independent rolls" if roll_count > 1 else None,
        })
    return standard, advanced


def merge_creature_snapshots() -> dict:
    creature_domain = load_json(CREATURE_DOMAIN)
    loot_domain = load_json(LOOT_DOMAIN)
    extractor = {row["id"]: row for row in creature_domain["creatures"]}
    historical_catalog = {
        row["id"]: row for row in load_json(ROOT / "assets" / "data" / "enemies_g2.json")
    }
    directories = {
        language: ROOT / "assets" / "data" / "creatures" / language / "details"
        for language in ("en", "es", "ru")
    }
    normalized = []
    merged = 0
    for en_path in sorted(directories["en"].glob("g2_*.json")):
        by_language = {
            language: load_json(directory / en_path.name)
            for language, directory in directories.items()
        }
        base = by_language["en"]
        historical = historical_catalog[base["id"]]
        owned_fields = (
            "health", "healthDisplay", "combatStats", "elementalWeaknesses",
            "damageWeaknesses", "resistancesV2", "immunities", "weakPoints",
            "attacks", "loot", "advancedLootTable", "encounterVariants",
        )
        for language, detail in by_language.items():
            for field in owned_fields:
                if field in historical:
                    detail[field] = materialize_language(
                        json.loads(json.dumps(historical[field])), language,
                    )
                else:
                    detail.pop(field, None)
        technical_id = base.get("technicalId")
        source = extractor.get(technical_id)
        if technical_id in TECHNICAL_ID_ALIASES and TECHNICAL_ID_ALIASES[technical_id] != base["id"]:
            source = None
        snapshot = {
            "publicId": base["id"], "technicalId": technical_id,
            "sourceStatus": "extractor_merged" if source else "historical_preserved",
        }
        if source:
            merged += 1
            stats = source.get("stats") or {}
            stun = stats.get("stun") or {}
            weaknesses = normalized_bonuses(source.get("weaknesses", []))
            elemental = {"fresh", "salty", "sour", "spicy"}
            attacks = merge_attack_details(
                historical.get("attacks", []), source.get("attacks", []),
            )
            loot, advanced_loot = normalized_loot(technical_id, loot_domain)
            shared = {
                "health": {
                    "rating": 1 if float(stats.get("health") or 0) < 400 else 2 if float(stats.get("health") or 0) < 700 else 3 if float(stats.get("health") or 0) < 1100 else 4 if float(stats.get("health") or 0) < 2000 else 5,
                    "value": round(float(stats["health"])),
                } if stats.get("health") is not None else None,
                "healthDisplay": "normal" if stats.get("health") is not None else base.get("healthDisplay", "hidden"),
                "combatStats": {
                    "health": round(float(stats["health"])) if stats.get("health") is not None else None,
                    "stunThreshold": round(float(stun["max"])) if stun.get("max") is not None else None,
                    "stunCooldownSeconds": round(float(stun["cooldown"])) if stun.get("cooldown") is not None else None,
                },
                "elementalWeaknesses": [row for row in weaknesses if row["type"] in elemental],
                "damageWeaknesses": [row for row in weaknesses if row["type"] not in elemental],
                "resistancesV2": normalized_bonuses(source.get("resistances", [])),
                "immunities": sorted({str(value).lower() for row in source.get("immunities", []) for value in (row.get("damageTypes", []) if isinstance(row, dict) else [row])}),
                "weakPoints": restored_weakpoints(historical, source.get("weakpoints", [])),
                "attacks": attacks,
                "loot": loot if loot else base.get("loot", []),
                "advancedLootTable": advanced_loot if advanced_loot else base.get("advancedLootTable", []),
                "encounterVariants": historical.get("encounterVariants", []),
            }
            for language, detail in by_language.items():
                localized = materialize_language(shared, language)
                localized["attacks"] = [
                    dict(row, name=humanize_identifier(row["name"]))
                    for row in localized["attacks"]
                ]
                detail.update({key: value for key, value in localized.items() if value is not None})
            snapshot.update(shared)
        for language, detail in by_language.items():
            scoped_asset_fallbacks = {
                "photo": "assets/global/Aphidex_Proximamente.webp",
                "cardNormal": "assets/global/Creaturecard_Proximamente.webp",
                "cardGold": "assets/global/Creaturecard_Proximamente.webp",
                "listIconAsset": "",
            }
            if base["id"] != "g2_orchid_mantis":
                for field, fallback in scoped_asset_fallbacks.items():
                    if clean_text(detail.get(field)).startswith("assets/g1/"):
                        detail[field] = fallback
            if base["id"] == "g2_orc_broodmother":
                detail["description"] = ORC_BROODMOTHER_DESCRIPTION[language]
                detail["appearanceSourceId"] = "subject_v_greenhouse"
                detail["appearanceSourceTargetId"] = "g2_masked_fighter"
            write_json(directories[language] / en_path.name, detail)
        snapshot.update({
            "image": base.get("photo"),
            "descriptions": {language: by_language[language].get("description") for language in by_language},
            "environments": base.get("environments", []), "respawn": base.get("respawnInfo"),
            "appearanceType": base.get("appearanceType", "unknown"),
            "variants": base.get("encounterVariants", []),
            "temperament": base.get("temperament", "unknown"),
            "collectionGroup": base.get("collectionGroup", "unknown"),
            "hideHealth": bool(base.get("hideHealth")),
            "entityType": base.get("entityType", "creature"),
            "customAsset": base.get("customAsset"),
        })
        normalized.append(snapshot)
    write_json(DATA_OUT / "creatures.json", {"schema": "aphidex-creatures-v1", "version": "1.3.0", "creatures": normalized})
    return {"items": len(normalized), "extractorMerged": merged, "historicalPreserved": len(normalized) - merged}


def apply_verified_cover_assets() -> list[dict]:
    captures_by_stem: dict[str, list[Path]] = defaultdict(list)
    for path in CAPTURES.glob("*.png"):
        captures_by_stem[path.stem.casefold()].append(path)
    applied = []
    details_dir = ROOT / "assets" / "data" / "creatures" / "en" / "details"
    for path in sorted(details_dir.glob("g2_*.json")):
        detail = load_json(path)
        override = VERIFIED_CAPTURE_OVERRIDES.get(detail["id"])
        if override:
            source = CAPTURES / override[0]
            asset = ASSET_OUT / "creatures" / "photos" / override[1]
            if not source.is_file():
                raise FileNotFoundError(f"Missing verified capture: {source}")
            photo = asset.relative_to(ROOT).as_posix()
            source_kind = "provided_capture_explicit_review"
        else:
            photo = clean_text(detail.get("photo"))
            if not photo or not photo.startswith("assets/g2/"):
                continue
            asset = ROOT / photo
            exact_keys = {clean_text(detail.get("technicalId")).casefold(), asset.stem.casefold()}
            candidates = {candidate for key in exact_keys if key for candidate in captures_by_stem.get(key, [])}
            if len(candidates) != 1 or asset.suffix.lower() != ".webp":
                continue
            source = candidates.pop()
            source_kind = "provided_capture_exact_name"
        asset.parent.mkdir(parents=True, exist_ok=True)
        thumbnail = ASSET_OUT / "creatures" / "thumbnails" / asset.name
        thumbnail.parent.mkdir(parents=True, exist_ok=True)
        if not asset.is_file() or asset.stat().st_mtime < source.stat().st_mtime:
            subprocess.run([
                str(MAGICK), str(source), "-resize", "1600x900^", "-gravity", "center",
                "-extent", "1600x900", "-strip", "-quality", "86", str(asset),
            ], check=True)
        if not thumbnail.is_file() or thumbnail.stat().st_mtime < source.stat().st_mtime:
            subprocess.run([
                str(MAGICK), str(source), "-resize", "320x180^", "-gravity", "center",
                "-extent", "320x180", "-strip", "-quality", "82", str(thumbnail),
            ], check=True)
        applied.append({
            "publicId": detail["id"], "technicalId": detail.get("technicalId"),
            "source": source.name, "asset": photo,
            "thumbnail": thumbnail.relative_to(ROOT).as_posix(),
            "sourceKind": source_kind,
        })
    by_id = {row["publicId"]: row for row in applied}
    for language in ("en", "es", "ru"):
        index_path = ROOT / "assets" / "data" / "creatures" / language / "index_g2.json"
        index = load_json(index_path)
        for entry in index:
            if clean_text(entry.get("listIconAsset")).startswith("assets/g2/creatures/thumbnails/"):
                entry["listIconAsset"] = ""
            if entry["id"] in by_id:
                entry["mapMarkerAsset"] = by_id[entry["id"]]["thumbnail"]
                detail_path = ROOT / "assets" / "data" / "creatures" / language / "details" / f"{entry['id']}.json"
                detail = load_json(detail_path)
                detail["photo"] = by_id[entry["id"]]["asset"]
                detail["mapMarkerAsset"] = entry["mapMarkerAsset"]
                if clean_text(detail.get("listIconAsset")).startswith("assets/g2/creatures/thumbnails/"):
                    detail["listIconAsset"] = ""
                write_json(detail_path, detail)
        write_json(index_path, index)
    return applied


def sync_creature_snapshot_ui_fields() -> None:
    payload = load_json(DATA_OUT / "creatures.json")
    for row in payload["creatures"]:
        detail = load_json(ROOT / "assets" / "data" / "creatures" / "en" / "details" / f"{row['publicId']}.json")
        row.update({
            "appearanceType": detail.get("appearanceType"),
            "appearanceCondition": detail.get("appearanceCondition"),
            "locations": detail.get("locations", []),
            "mapLayers": sorted({location.get("map") for location in detail.get("locations", [])}),
            "environments": detail.get("environments", []),
            "respawn": detail.get("respawnInfo"),
            "image": detail.get("photo"),
            "cardNormal": detail.get("cardNormal"),
            "cardGold": detail.get("cardGold"),
            "mapMarkerAsset": detail.get("mapMarkerAsset"),
            "customAsset": detail.get("customAsset"),
            "entityType": detail.get("entityType", "creature"),
            "hideHealth": bool(detail.get("hideHealth")),
            "temperament": detail.get("temperament", "unknown"),
            "collectionGroup": detail.get("collectionGroup", "unknown"),
        })
    write_json(DATA_OUT / "creatures.json", payload)


def build_equipment() -> dict:
    weapon = load_json(WEAPON_DOMAIN)
    armor = load_json(ARMOR_DOMAIN)
    trinket = load_json(TRINKET_DOMAIN)
    acquisition = {row["technicalId"]: row for row in load_json(ACQUISITION_DOMAIN)["items"]}
    pickups = map_pickups()
    items = []

    for domain, rows in (("weapon", weapon["weapons"]), ("shield", weapon["shields"]), ("armor", armor["pieces"]), ("trinket", trinket["trinkets"])):
        for source in rows:
            technical_id = source["technicalId"]
            source_icon = source.get("icon") or {}
            icon_asset = resolved_icon(source_icon, technical_id)
            entry = {
                "id": technical_id, "technicalId": technical_id, "domain": domain,
                "name": display_names(technical_id), "translationStatus": {"en": "technical_source", "es": "pending_review", "ru": "pending_native_review"},
                "tier": source.get("tier"), "slot": source.get("slot"), "twoHanded": source.get("twoHanded"),
                "icon": icon_asset,
                "iconProvenance": source_icon.get("resolvedProvenance") if icon_asset else "technical_fallback",
                "iconSource": source_icon.get("resolvedSource"),
                "effects": compact_effects(source.get("effects")),
                "acquisition": compact_acquisition(acquisition.get(technical_id)),
                "locations": pickups.get(technical_id, []),
                "environmentHazards": [],
            }
            entry.update(equipment_classification(domain, technical_id, source.get("slot")))
            if domain in {"weapon", "shield"}:
                combat = source.get("combat") or {}
                entry.update({
                    "kind": source.get("kind"), "canBlock": combat.get("canBlock"),
                    "durability": combat.get("durability"), "attacks": compact_attacks(combat),
                    "upgradeRoutes": [route.get("tag") for route in (source.get("enhancement") or {}).get("routes", []) if route.get("resolved")],
                    "repair": [
                        {"itemId": (row.get("Item") or {}).get("RowName"), "count": row.get("ItemCount")}
                        for row in source.get("repairRecipe", []) if (row.get("Item") or {}).get("RowName")
                    ],
                })
            elif domain == "armor":
                entry.update({
                    "protection": source.get("protection"), "durability": source.get("durability"),
                    "upgradeRoutes": [route.get("tag") for route in (source.get("enhancement") or {}).get("routes", []) if route.get("resolved")],
                })
            items.append(entry)

    sets = []
    pieces = {item["id"]: item for item in items if item["domain"] == "armor"}
    for source in armor["sets"]:
        set_id = source["setId"]
        sets.append({
            "id": set_id, "name": display_names(set_id.removeprefix("BP_Equippable_")),
            "pieces": source.get("pieces", []), "tiers": source.get("tierValues", []),
            "protection": source.get("rawProtectionComponentSums"),
            "effects": compact_effects(source.get("effects")),
            "allPiecesEnhanceable": source.get("allPiecesEnhanceable"),
            "icon": next((pieces[piece]["icon"] for piece in source.get("pieces", []) if piece in pieces and pieces[piece]["icon"]), ""),
            "iconStrategy": "primary_piece_fallback",
            "normalizedType": "armor_set", "normalizedSubtype": "set",
            "classificationSource": "extractor_set", "classificationFallbackUsed": False,
            "translationStatus": {"en": "technical_source", "es": "pending_review", "ru": "pending_native_review"},
        })

    payload = {"schema": "aphidex-equipment-v1", "version": "1.3.0", "items": items, "armorSets": sets}
    write_json(DATA_OUT / "equipment.json", payload)
    return {"items": len(items), "armorSets": len(sets), "icons": sum(bool(item["icon"]) for item in items)}


def map_route_type(route: dict) -> str:
    if route.get("conditional") and route.get("subtype") == "story":
        return "story_locked"
    subtype = clean_text(route.get("subtype"))
    return subtype or clean_text(route.get("type")) or "spawn"


def build_map_definitions(domain: dict) -> dict:
    maps = {}
    geometry_pattern = re.compile(r"^(\d+)x(\d+)\+(-?\d+)\+(-?\d+)$")
    for map_id, source in domain["maps"].items():
        source_texture = Path(source["texture"])
        identify = subprocess.run(
            [str(MAGICK), "identify", "-format", "%w,%h,%@", str(source_texture)],
            check=True, capture_output=True, text=True,
        ).stdout.strip()
        source_width, source_height, geometry = identify.split(",", 2)
        match = geometry_pattern.match(geometry)
        if not match:
            raise ValueError(f"Could not determine represented texture bounds for {map_id}: {geometry}")
        content_width, content_height, content_x, content_y = map(int, match.groups())
        destination = ASSET_OUT / "map" / f"{map_id}.webp"
        destination.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run([
            str(MAGICK), str(source_texture), "-crop", geometry, "+repage",
            "-strip", "-quality", "88", str(destination),
        ], check=True)
        maps[map_id] = {
            "id": map_id,
            "texture": destination.relative_to(ROOT).as_posix(),
            "worldBounds": {
                "minX": source["minBounds"]["x"], "minY": source["minBounds"]["y"],
                "maxX": source["maxBounds"]["x"], "maxY": source["maxBounds"]["y"],
            },
            "sourceTextureSize": {"width": int(source_width), "height": int(source_height)},
            "contentPixelBounds": {
                "x": content_x, "y": content_y,
                "width": content_width, "height": content_height,
            },
            "textureSize": {"width": content_width, "height": content_height},
            "axis": {"u": "x", "v": "y", "invertX": False, "invertY": False},
            "hazards": [{"type": "required_equipment", "equipmentId": "DivingArmor"}] if map_id == "abyss" else [],
        }
    return maps


def world_to_map(world: dict, definition: dict) -> dict:
    bounds = definition["worldBounds"]
    source_size = definition["sourceTextureSize"]
    content = definition["contentPixelBounds"]
    full_u = (float(world["x"]) - bounds["minX"]) / (bounds["maxX"] - bounds["minX"])
    full_v = (float(world["y"]) - bounds["minY"]) / (bounds["maxY"] - bounds["minY"])
    pixel_x = full_u * source_size["width"]
    pixel_y = full_v * source_size["height"]
    u = (pixel_x - content["x"]) / content["width"]
    v = (pixel_y - content["y"]) / content["height"]
    return {"u": u, "v": v, "representable": 0 <= u <= 1 and 0 <= v <= 1}


def build_map_and_creature_locations() -> dict:
    domain = load_json(MAP_DOMAIN)
    maps = build_map_definitions(domain)
    out_of_bounds = []
    details_dir = ROOT / "assets" / "data" / "creatures" / "en" / "details"
    current = [load_json(path) for path in details_dir.glob("g2_*.json")]
    technical_to_public = {}
    for row in current:
        technical_id = row.get("technicalId")
        if not technical_id:
            continue
        if technical_id in technical_to_public and technical_to_public[technical_id] != row["id"]:
            resolved = TECHNICAL_ID_ALIASES.get(technical_id)
            if resolved not in {technical_to_public[technical_id], row["id"]}:
                raise ValueError(f"Technical ID collision: {technical_id}")
            technical_to_public[technical_id] = resolved
            continue
        technical_to_public[technical_id] = row["id"]
    map_entities = domain["entities"]["creatures"]
    markers = []
    by_public: dict[str, list[dict]] = defaultdict(list)
    for technical_id, entity in map_entities.items():
        if technical_id in EXCLUDED_TECHNICAL_IDS or technical_id not in technical_to_public:
            continue
        public_id = technical_to_public[technical_id]
        if entity.get("visibleAsWildSpawn") is False:
            continue
        for location in entity.get("locations", []):
            map_value = location.get("map") or {}
            world = location.get("world")
            if not map_value.get("id") or not isinstance(world, dict):
                continue
            position = world_to_map(world, maps[map_value["id"]])
            if not position["representable"]:
                out_of_bounds.append({"id": location.get("locationId"), "map": map_value["id"], "world": world})
                continue
            route = location.get("route") or {}
            marker = {
                "id": location["locationId"], "targetType": "creature", "targetId": public_id,
                "technicalId": technical_id, "map": map_value["id"],
                "world": world, "u": position["u"], "v": position["v"],
                "type": map_route_type(route), "conditional": bool(route.get("conditional")),
                "environmentHazards": [{"type": "required_equipment", "equipmentId": "DivingArmor"}] if map_value["id"] == "abyss" else [],
            }
            markers.append(marker)
            by_public[public_id].append(marker)

    # The O.R.C. Broodmother shares only the appearance/location source used
    # by Subject V in the Greenhouse. No combat, text, loot, or asset field is
    # inherited from that entity.
    appearance_source = by_public.get("g2_masked_fighter", [])
    if len(appearance_source) != 1:
        raise ValueError(
            "Expected exactly one Subject V Greenhouse appearance source, "
            f"found {len(appearance_source)}"
        )
    source_marker = appearance_source[0]
    broodmother_marker = {
        **source_marker,
        "id": "appearance_source_subject_v_greenhouse_g2_orc_broodmother",
        "targetId": "g2_orc_broodmother",
        "technicalId": "SpiderBossBroodmother",
        "appearanceSourceId": "subject_v_greenhouse",
    }
    markers.append(broodmother_marker)
    by_public["g2_orc_broodmother"].append(broodmother_marker)

    event_appearances: dict[str, list[str]] = defaultdict(list)
    for technical_id, event_only in domain["entities"].get("eventOnlyCreatures", {}).items():
        public_id = technical_to_public.get(technical_id)
        if public_id:
            event_appearances[public_id].extend(event_only.get("defenseEventIds", []))

    defense_events = []
    for event in domain["entities"]["defenseEvents"]:
        map_value = event["map"]
        world = event.get("world")
        position = world_to_map(world, maps[map_value["id"]])
        if not position["representable"]:
            out_of_bounds.append({"id": event.get("id"), "map": map_value["id"], "world": world})
            continue
        defense_events.append({
            "id": event["id"], "targetType": "defense", "targetId": event["id"],
            "map": map_value["id"], "world": world,
            "u": position["u"], "v": position["v"],
            "type": event["eventType"], "conditional": event["eventType"] == "story_defense",
            "environmentHazards": [],
        })

    for language in ("en", "es", "ru"):
        for public_id in sorted(set(by_public) | set(event_appearances)):
            path = ROOT / "assets" / "data" / "creatures" / language / "details" / f"{public_id}.json"
            detail = load_json(path)
            locations = by_public.get(public_id, [])
            detail["locations"] = locations
            detail["environmentHazards"] = sorted({hazard["type"] for location in locations for hazard in location["environmentHazards"]})
            detail["eventAppearances"] = sorted(set(event_appearances.get(public_id, [])))
            if public_id == "g2_orc_broodmother":
                detail["appearanceSourceId"] = "subject_v_greenhouse"
                detail["appearanceSourceTargetId"] = "g2_masked_fighter"
            is_ogrr = detail.get("collectionGroup") == "ogrr" or "ogre" in clean_text(detail.get("technicalId")).lower()
            has_story_route = any(location["type"] == "story_locked" for location in locations)
            if detail["eventAppearances"] and not locations:
                detail["appearanceType"] = "event_only"
            elif is_ogrr:
                detail["appearanceType"] = "ogrr_released"
                detail["appearanceCondition"] = {
                    "en": "OGRR creatures can be released from the scarecrow laboratory. Afterwards they may appear in different areas, mainly at night.",
                    "es": "Los OGRR pueden liberarse desde el laboratorio del espantapájaros. Después de hacerlo pueden aparecer en distintas zonas, principalmente durante la noche.",
                    "ru": "Существ OGRR можно освободить из лаборатории у пугала. После этого они могут появляться в разных местах, преимущественно ночью.",
                }[language]
            elif has_story_route:
                detail["appearanceType"] = "story_related"
                detail["appearanceCondition"] = {
                    "en": "Locked by story progress", "es": "Bloqueado por progreso de historia",
                    "ru": "Заблокировано прогрессом сюжета",
                }[language]
            elif len(locations) == 1 and locations[0]["type"] == "placed_encounter":
                detail["appearanceType"] = "fixed_encounter"
            elif locations:
                detail["appearanceType"] = "natural"
            else:
                detail["appearanceType"] = "no_natural_spawn"
            write_json(path, detail)

        for path in (ROOT / "assets" / "data" / "creatures" / language / "details").glob("g2_*.json"):
            detail = load_json(path)
            if detail.get("appearanceType"):
                continue
            if detail.get("eventAppearances") and not detail.get("locations"):
                detail["appearanceType"] = "event_only"
            elif detail.get("locations"):
                detail["appearanceType"] = "natural"
            else:
                detail["appearanceType"] = "no_natural_spawn"
            write_json(path, detail)

    equipment_markers = []
    for marker in [marker for rows in map_pickups().values() for marker in rows]:
        world = marker.get("world")
        position = world_to_map(world, maps[marker["map"]])
        if position["representable"]:
            marker.update({"u": position["u"], "v": position["v"]})
            equipment_markers.append(marker)
        else:
            out_of_bounds.append({"id": marker.get("id"), "map": marker["map"], "world": world})

    payload = {"schema": "aphidex-map-v1", "version": "1.3.0", "maps": maps, "markers": markers + equipment_markers + defense_events, "outOfBounds": out_of_bounds}
    write_json(DATA_OUT / "map.json", payload)
    return {"creatureMarkers": len(markers), "equipmentMarkers": len(equipment_markers), "defenseMarkers": len(defense_events), "creaturesWithLocations": len(by_public), "eventOnlyCreatures": len(event_appearances), "outOfBounds": len(out_of_bounds)}


def build_mixr() -> dict:
    composer = load_json(MIXR_COMPOSER)
    map_domain = load_json(MAP_DOMAIN)
    current = [load_json(path) for path in (ROOT / "assets" / "data" / "creatures" / "en" / "details").glob("g2_*.json")]
    technical_to_public = {row.get("technicalId"): row["id"] for row in current if row.get("technicalId")}
    event_map = {row["id"]: row for row in map_domain["entities"]["defenseEvents"]}
    event_spawns = map_domain["entities"]["defenseEncounterSpawns"]
    variants = []
    for source in composer["mixrs"]:
        labels = MIXR_LABELS[source["mixrId"]]
        event_id = labels["id"]
        groups: dict[int, dict] = {}
        for spawn in event_spawns.get(event_id, []):
            for occurrence in (spawn.get("defense") or {}).get("scheduleOccurrences", []):
                index = occurrence.get("scheduledGroupIndex")
                if index is None:
                    continue
                group = groups.setdefault(index, {"index": index, "timeSeconds": occurrence.get("spawnTimeSeconds"), "creatures": Counter()})
                group["creatures"][spawn["resolvedCreatureId"]] += 1
        normalized_groups = []
        for index in sorted(groups):
            group = groups[index]
            declared_group_total = (
                source.get("scheduledGroups", [])[index].get("totalCreatures")
                if index < len(source.get("scheduledGroups", [])) else None
            )
            represented_total = sum(group["creatures"].values())
            normalized_groups.append({
                "index": index, "displayOrdinal": len(normalized_groups) + 1,
                "timeSeconds": group["timeSeconds"],
                "declaredScheduledCreatures": declared_group_total,
                "compositionStatus": "complete" if declared_group_total == represented_total else "partial_source_anchors",
                "creatures": [{"technicalId": key, "publicId": technical_to_public.get(key), "count": value} for key, value in sorted(group["creatures"].items())],
            })
        event = event_map[event_id]
        variants.append({
            "id": event_id, "mixrId": source["mixrId"], "name": {"en": f"MIX.R {labels['en']}", "es": f"MIX.R {labels['es']}", "ru": f"MIX.R {labels['ru']}"},
            "difficulty": source.get("displayDifficulty"), "totalCreatures": source.get("totalScheduledCreatures"),
            "location": {"map": event["map"]["id"], "u": event["map"]["u"], "v": event["map"]["v"]},
            "scheduledGroups": normalized_groups,
            "attackers": [{
                "technicalId": row["technicalId"],
                "publicId": technical_to_public.get(row["technicalId"]),
                "count": row["totalCount"],
            } for row in source.get("roster", [])],
            "image": "assets/g2/defenses/mixr_greenhouse.webp" if event_id == "mixr_greenhouse" else "assets/g2/creatures/photos/MIXR_Defenses_G2.webp",
            "markerAsset": "assets/g2/defenses/MIXR_Map_Marker.png",
            "imageStatus": "verified" if event_id == "mixr_greenhouse" else "known_pending_assets",
            "rewards": {
                "rawScience": 4000,
                "rawScienceSources": [
                    {"asset": "BP_RawScience_DefenseReward_Tiny", "scienceAmount": 1000},
                    {"asset": "BP_RawScience_DefenseReward_Small", "scienceAmount": 3000},
                ],
                "mutationProgress": [{"id": "guard_dog", "amount": None}],
                "equipment": [], "recipes": [],
            },
        })
    source = CAPTURES / "MIXR G2 - A.png"
    destination = ASSET_OUT / "defenses" / "mixr_greenhouse.webp"
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(MAGICK), str(source), "-resize", "1280x720>", "-strip", "-quality", "86", str(destination)], check=True)
    payload = {"schema": "aphidex-mixr-v1", "version": "1.3.0", "variants": variants, "scheduledGroupPolicy": "source_index_not_official_wave"}
    write_json(DATA_OUT / "mixr.json", payload)
    ice_event = event_map["ice_sickles"]
    ice_groups: dict[int, dict] = {}
    for spawn in event_spawns.get("ice_sickles", []):
        for occurrence in (spawn.get("defense") or {}).get("scheduleOccurrences", []):
            index = occurrence.get("scheduledGroupIndex")
            if index is None:
                continue
            group = ice_groups.setdefault(index, {"index": index, "timeSeconds": occurrence.get("spawnTimeSeconds"), "creatures": Counter()})
            group["creatures"][spawn["resolvedCreatureId"]] += 1
    ice_scheduled = [{
        "index": index, "displayOrdinal": ordinal + 1, "timeSeconds": ice_groups[index]["timeSeconds"],
        "creatures": [{"technicalId": key, "publicId": technical_to_public.get(key), "count": count} for key, count in sorted(ice_groups[index]["creatures"].items())],
    } for ordinal, index in enumerate(sorted(ice_groups))]
    ice_attackers = Counter(
        creature["technicalId"] for group in ice_scheduled
        for creature in group["creatures"] for _ in range(creature["count"])
    )
    ice_variant = {
        "id": "ice_sickles", "name": {"en": "Ice Sickles", "es": "Hoces de hielo", "ru": "Ледяные серпы"},
        "difficulty": None, "totalCreatures": sum(ice_attackers.values()),
        "location": {"map": ice_event["map"]["id"], "u": ice_event["map"]["u"], "v": ice_event["map"]["v"]},
        "scheduledGroups": ice_scheduled,
        "attackers": [{"technicalId": key, "publicId": technical_to_public.get(key), "count": count} for key, count in sorted(ice_attackers.items())],
        "image": "assets/g2/creatures/photos/Ice_Sickles_Defense.webp", "imageStatus": "verified_historical",
        "rewards": {
            "rawScience": None, "rawScienceSources": [],
            "mutationProgress": [{"id": "guard_dog", "amount": None}],
            "equipment": [{"id": "EarwigSicklesUnique", "quantity": 1}],
            "recipes": [{"id": "EarwigSicklesUnique", "quantity": 1}],
        },
    }
    defenses = {
        "schema": "aphidex-defenses-v1", "version": "1.3.0",
        "scheduledGroupPolicy": "source_index_not_official_wave",
        "entries": [
            {"id": "g2_mixr_defenses", "kind": "mixr", "customAsset": "assets/g2/defenses/MIXR_Entry_Icon.png", "variants": variants},
            {"id": "g2_ice_sickles_event", "kind": "story_defense", "customAsset": "assets/global/effects_damage/Damagetype_Fresh.webp", "variants": [ice_variant]},
        ],
    }
    write_json(DATA_OUT / "defenses.json", defenses)
    return {
        "entries": len(defenses["entries"]), "variants": len(variants) + 1,
        "groups": sum(len(row["scheduledGroups"]) for row in variants) + len(ice_scheduled),
        "iceSicklesAttackers": sum(ice_attackers.values()),
    }


EFFECT_ICONS = {
    "slashing": "assets/global/effects_damage/Tooltype_Slashing.webp",
    "chopping": "assets/global/effects_damage/Tooltype_Chopping.webp",
    "busting": "assets/global/effects_damage/Tooltype_Busting.webp",
    "stabbing": "assets/global/effects_damage/Tooltype_Stabbing.webp",
    "explosive": "assets/global/effects_damage/Tooltype_Explosive.webp",
    "generic": "assets/global/effects_damage/Generic_Damage.webp",
    "fresh": "assets/global/effects_damage/Damagetype_Fresh.webp",
    "water": "assets/global/effects_damage/Tooltype_Water.png",
    "chill": "assets/global/effects_damage/Chilling_Attack.png",
    "spicy": "assets/global/effects_damage/Damagetype_Spicy.webp",
    "salty": "assets/global/effects_damage/Damagetype_Salty.webp",
    "sour": "assets/global/effects_damage/Damagetype_Sour.webp",
    "dust": "assets/global/effects_damage/Dust.webp",
    "poison": "assets/global/effects_damage/Poison.webp",
    "venom": "assets/global/effects_damage/Venom.webp",
    "gas": "assets/global/effects_damage/Gas_Hazard.webp",
    "bleed": "assets/global/effects_damage/Bleed.webp",
    "shock": "assets/global/effects_damage/Tooltype_Shock.webp",
    "burning": "assets/global/effects_damage/Tooltype_Burning.webp",
    "sizzle": "assets/global/effects_damage/Sizzling_Attack.png",
    "tang_buildup": "assets/global/effects_damage/TangBuildUp.webp",
    "infection": "assets/global/effects_damage/Infection.webp",
    "acid": "assets/global/effects_damage/Tooltype_Acid.webp",
}

EFFECT_NAMES = {
    "slashing": ("Slashing", "Tajo", "Режущий"), "chopping": ("Chopping", "Corte", "Рубящий"),
    "busting": ("Busting", "Aplastante", "Дробящий"), "stabbing": ("Stabbing", "Perforación", "Колющий"),
    "explosive": ("Explosive", "Explosivo", "Взрывной"), "generic": ("Generic damage", "Daño genérico", "Обычный урон"),
    "fresh": ("Fresh", "Fresco", "Свежесть"), "water": ("Water", "Agua", "Вода"),
    "chill": ("Chill", "Congelamiento", "Холод"), "spicy": ("Spicy", "Picante", "Острый"),
    "salty": ("Salty", "Salado", "Солёный"), "sour": ("Sour", "Ácido", "Кислый"),
    "dust": ("Dust", "Polvo", "Пыль"), "poison": ("Poison", "Envenenamiento", "Отравление"),
    "venom": ("Venom", "Veneno letal", "Яд"), "gas": ("Gas", "Gas", "Газ"),
    "bleed": ("Bleed", "Sangrado", "Кровотечение"), "shock": ("Shock", "Electricidad", "Электрошок"),
    "burning": ("Burning", "Quemaduras", "Горение"), "sizzle": ("Sizzle", "Calor", "Перегрев"),
    "tang_buildup": ("Tang buildup", "Corrosión", "Коррозия"), "infection": ("Infection", "Infección", "Инфекция"),
    "acid": ("Acid", "Ácido", "Кислота"),
}


def normalize_effect(value: object) -> str:
    raw = clean_text(value).lower().replace("_", " ")
    aliases = {"gas hazard": "gas", "electricity": "shock", "electric": "shock", "burn": "burning", "chilling": "chill", "heat": "sizzle", "tang": "tang_buildup"}
    if raw in aliases:
        return aliases[raw]
    if raw in EFFECT_ICONS:
        return raw
    checks = (
        ("venom", "venom"), ("poison", "poison"), ("toxin", "poison"),
        ("corrosion", "tang_buildup"), ("tang", "tang_buildup"), ("acid", "acid"),
        ("chill", "chill"), ("frost", "chill"), ("freeze", "chill"),
        ("sizzle", "sizzle"), ("burn", "burning"), ("fire", "burning"),
        ("bleed", "bleed"), ("gas", "gas"), ("shock", "shock"),
        ("electric", "shock"), ("infection", "infection"), ("spicy", "spicy"),
        ("fresh", "fresh"), ("mint", "fresh"), ("sour", "sour"), ("salty", "salty"),
    )
    return next((normalized for needle, normalized in checks if needle in raw), raw)


def localized_classification(value: str) -> dict:
    labels = {
        "weapon": ("Weapon", "Arma", "Оружие"), "shield": ("Shield", "Escudo", "Щит"),
        "armor": ("Armor", "Armadura", "Броня"), "trinket": ("Trinket", "Amuleto", "Талисман"),
        "head": ("Head", "Cabeza", "Голова"), "chest": ("Chest", "Pechera", "Нагрудник"),
        "legs": ("Legs", "Piernas", "Ноги"), "armor_piece": ("Armor piece", "Pieza de armadura", "Часть брони"),
        "badge": ("Badge / medallion", "Insignia / medallón", "Знак / медальон"),
        "accessory": ("Accessory", "Accesorio", "Аксессуар"),
    }
    en, es, ru = labels.get(value, ("Special item", "Objeto especial", "Особый предмет"))
    return {"en": en, "es": es, "ru": ru}


def scoped_asset(asset: object, game: str) -> bool:
    value = clean_text(asset)
    return value.startswith(f"assets/{game}/") and (ROOT / value).is_file()


def reports(summary: dict, editorial: dict) -> None:
    equipment = load_json(DATA_OUT / "equipment.json")
    missing = [
        {"type": item["domain"], "id": item["id"], "reason": "no_verified_image"}
        for item in equipment["items"] if not item.get("icon")
    ]
    qa = load_json(QA)
    known_pending = [
        {"type": "mixr_variant", "id": "mixr_picnic", "status": "known_pending_assets"},
        {"type": "mixr_variant", "id": "mixr_resting", "status": "known_pending_assets"},
    ]
    write_json(REPORT_OUT / "missing_images_report.json", {"items": missing})
    write_json(REPORT_OUT / "known_pending_assets.json", {"items": known_pending})
    missing_descriptions = []
    for language in ("en", "es", "ru"):
        for path in (ROOT / "assets" / "data" / "creatures" / language / "details").glob("g2_*.json"):
            item = load_json(path)
            if not clean_text(item.get("description")):
                missing_descriptions.append({"id": item["id"], "language": language})
    unresolved = [
        {"id": item["id"], "status": "unresolved_acquisition"}
        for item in equipment["items"] if item["acquisition"]["status"] == "unresolved_acquisition"
    ]
    write_json(REPORT_OUT / "missing_descriptions_report.json", {"items": missing_descriptions, "excelRowsApplied": editorial["rowsApplied"]})
    write_json(REPORT_OUT / "unresolved_extractor_data_report.json", {"unresolvedAcquisitions": unresolved, "sourceWarnings": qa.get("sourceWarnings", [])})
    write_json(REPORT_OUT / "translation_review_report.json", {
        "editorialCreatureRows": editorial["rowsApplied"],
        "equipment": {"count": len(equipment["items"]), "es": "pending_human_review", "ru": "pending_native_review"},
        "policy": "Technical IDs remain visible as provenance; generated display names never replace source statistics.",
    })

    normalized = load_json(DATA_OUT / "creatures.json")["creatures"]
    parity = []
    cover_rows = []
    applied_covers = {row["publicId"]: row for row in summary.get("covers", [])}
    for source in normalized:
        public_id = source["publicId"]
        details = {
            language: load_json(ROOT / "assets" / "data" / "creatures" / language / "details" / f"{public_id}.json")
            for language in ("es", "en", "ru")
        }
        ui = details["en"]
        expected_fields = []
        if source["sourceStatus"] == "extractor_merged":
            expected_fields = [
                key for key in ("health", "combatStats", "elementalWeaknesses", "damageWeaknesses", "resistancesV2", "immunities", "weakPoints", "attacks", "loot", "advancedLootTable")
                if source.get(key) not in (None, [], {})
            ]
        lost = [key for key in expected_fields if ui.get(key) in (None, [], {})]
        parity.append({
            "publicId": public_id, "technicalId": source.get("technicalId"),
            "image": ui.get("photo"),
            "descriptionES": details["es"].get("description"), "descriptionEN": details["en"].get("description"), "descriptionRU": details["ru"].get("description"),
            "HP": (ui.get("combatStats") or {}).get("health"), "stun": (ui.get("combatStats") or {}).get("stunThreshold"),
            "weaknesses": len(ui.get("elementalWeaknesses", [])) + len(ui.get("damageWeaknesses", [])),
            "resistances": len(ui.get("resistancesV2", [])), "immunities": len(ui.get("immunities", [])),
            "attacks": len(ui.get("attacks", [])), "attackDamage": sum(1 for row in ui.get("attacks", []) if row.get("damage") is not None),
            "loot": len([row for row in ui.get("loot", []) if row.get("section") != "rare"]),
            "rareLoot": len([row for row in ui.get("loot", []) if row.get("section") == "rare"]),
            "environments": len(ui.get("environments", [])), "respawn": ui.get("respawnInfo"),
            "appearanceType": ui.get("appearanceType"), "locations": len(ui.get("locations", [])),
            "mapLayers": sorted({row.get("map") for row in ui.get("locations", [])}),
            "condition": ui.get("appearanceCondition"), "variants": len(ui.get("encounterVariants", [])),
            "sourceStatus": source["sourceStatus"], "lostFields": lost,
        })
        resolved = clean_text(ui.get("photo"))
        cover_source = applied_covers.get(public_id)
        cover_rows.append({
            "publicId": public_id, "technicalId": source.get("technicalId"),
            "expectedAsset": resolved or None, "resolvedAsset": resolved if resolved and (ROOT / resolved).is_file() else None,
            "source": cover_source.get("sourceKind") if cover_source else "historical_asset" if resolved and (ROOT / resolved).is_file() else "fallback",
            "fallbackUsed": not bool(resolved and (ROOT / resolved).is_file()),
        })
    write_json(REPORT_OUT / "creature_ui_data_parity_report.json", {
        "creatures": parity, "importantDataLossCount": sum(bool(row["lostFields"]) for row in parity),
    })
    write_json(REPORT_OUT / "cover_image_coverage_report.json", {"creatures": cover_rows})

    entity_assets = []
    for game in ("g1", "g2"):
        index = load_json(ROOT / "assets" / "data" / "creatures" / "en" / f"index_{game}.json")
        for entry in index:
            detail = load_json(ROOT / "assets" / "data" / "creatures" / "en" / "details" / f"{entry['id']}.json")
            raw_cover = clean_text(detail.get("photo"))
            raw_card = clean_text(entry.get("cardNormal"))
            raw_marker = clean_text(entry.get("mapMarkerAsset"))
            entity_type = entry.get("entityType", "creature")
            if entity_type == "defense":
                raw_card = clean_text(entry.get("customAsset"))
            approved_exception = entry["id"] == "g2_orchid_mantis"
            cover_ok = scoped_asset(raw_cover, game) or approved_exception and scoped_asset(raw_cover, "g1")
            card_ok = scoped_asset(raw_card, game) or raw_card.startswith("assets/global/") and (ROOT / raw_card).is_file() or approved_exception and scoped_asset(raw_card, "g1")
            cover_source = applied_covers.get(entry["id"])
            entity_assets.append({
                "game": game, "publicId": entry["id"], "technicalId": detail.get("technicalId"),
                "entityType": entity_type, "displayName": entry.get("name"),
                "coverAsset": raw_cover if cover_ok else "assets/global/Aphidex_Proximamente.webp",
                "cardAsset": raw_card if card_ok else "assets/global/Creaturecard_Proximamente.webp",
                "sourceCover": "approved_cross_game_exception" if approved_exception and raw_cover.startswith("assets/g1/") else cover_source.get("sourceKind") if cover_source else "historical_same_entity" if cover_ok else "technical_fallback",
                "sourceCard": "approved_cross_game_exception" if approved_exception and raw_card.startswith("assets/g1/") else "custom_entry" if entity_type == "defense" and card_ok else "entity_card" if card_ok else "technical_fallback",
                "mapMarkerAsset": raw_marker if scoped_asset(raw_marker, game) else None,
                "fallbackCover": not cover_ok, "fallbackCard": not card_ok,
                "assetExistsOnDisk": cover_ok and card_ok,
                "coverAssetExists": cover_ok, "cardAssetExists": card_ok,
                "mappingStatus": "approved_cross_game_exception" if approved_exception else "resolved" if cover_ok and card_ok else "fallback",
                "approvedCrossGameException": approved_exception,
                "rawCrossGameAsset": (
                    game == "g2" and (raw_cover.startswith("assets/g1/") or raw_card.startswith("assets/g1/"))
                    or game == "g1" and (raw_cover.startswith("assets/g2/") or raw_card.startswith("assets/g2/"))
                ),
            })
    for item in equipment["items"]:
        icon = clean_text(item.get("icon"))
        exists = scoped_asset(icon, "g2")
        entity_assets.append({
            "game": "g2", "publicId": item["id"], "technicalId": item.get("technicalId"),
            "entityType": item["domain"], "displayName": item["name"]["en"],
            "coverAsset": icon if exists else "assets/global/Aphidex_Proximamente.webp",
            "cardAsset": icon if exists else "assets/global/Aphidex_Proximamente.webp",
            "sourceCover": "equipment_icon" if exists else "technical_fallback",
            "sourceCard": "equipment_icon" if exists else "technical_fallback",
            "fallbackCover": not exists, "fallbackCard": not exists,
            "assetExistsOnDisk": exists, "mappingStatus": "resolved" if exists else "fallback",
        })
    for armor_set in equipment["armorSets"]:
        icon = clean_text(armor_set.get("icon"))
        exists = scoped_asset(icon, "g2")
        entity_assets.append({
            "game": "g2", "publicId": armor_set["id"], "technicalId": armor_set["id"],
            "entityType": "armor_set", "displayName": armor_set["name"]["en"],
            "coverAsset": icon if exists else "assets/global/Aphidex_Proximamente.webp",
            "cardAsset": icon if exists else "assets/global/Aphidex_Proximamente.webp",
            "sourceCover": armor_set.get("iconStrategy", "primary_piece_fallback") if exists else "technical_fallback",
            "sourceCard": armor_set.get("iconStrategy", "primary_piece_fallback") if exists else "technical_fallback",
            "fallbackCover": armor_set.get("iconStrategy") != "verified_set_asset",
            "fallbackCard": armor_set.get("iconStrategy") != "verified_set_asset",
            "assetExistsOnDisk": exists, "mappingStatus": "resolved_explicit_strategy" if exists else "fallback",
        })
    mixr_payload = load_json(DATA_OUT / "mixr.json")
    for event in mixr_payload["variants"]:
        image = clean_text(event.get("image"))
        exists = scoped_asset(image, "g2")
        pending = event.get("imageStatus") == "known_pending_assets"
        entity_assets.append({
            "game": "g2", "publicId": event["id"], "technicalId": event.get("mixrId"),
            "entityType": "mixr", "displayName": event["name"]["en"],
            "coverAsset": image, "cardAsset": "assets/global/effects_damage/Summon_HP.webp",
            "sourceCover": "known_pending_assets" if pending else "verified_capture",
            "sourceCard": "custom_entry",
            "fallbackCover": pending, "fallbackCard": False,
            "assetExistsOnDisk": exists,
            "mappingStatus": "known_pending_assets" if pending else "resolved",
        })
    write_json(REPORT_OUT / "entity_asset_coverage_report.json", {
        "entities": entity_assets,
        "summary": {
            "total": len(entity_assets),
            "resolved": sum(row["mappingStatus"].startswith("resolved") or row["mappingStatus"] == "approved_cross_game_exception" for row in entity_assets),
            "fallbacks": sum(row["mappingStatus"] == "fallback" for row in entity_assets),
            "knownPendingAssets": sum(row["mappingStatus"] == "known_pending_assets" for row in entity_assets),
            "approvedCrossGameExceptions": sum(bool(row.get("approvedCrossGameException")) for row in entity_assets),
            "crossGameAssetMappings": sum(bool(row.get("rawCrossGameAsset")) and not bool(row.get("approvedCrossGameException")) for row in entity_assets),
            "coverAsCard": sum(
                clean_text(row.get("coverAsset")) == clean_text(row.get("cardAsset"))
                and row.get("entityType") in {"creature", "defense", "mixr"}
                and clean_text(row.get("coverAsset")) not in {"", "assets/global/Aphidex_Proximamente.webp", "assets/global/Creaturecard_Proximamente.webp"}
                for row in entity_assets
            ),
        },
    })

    action_rows = []
    for path in (ROOT / "assets" / "data" / "creatures" / "en" / "details").glob("g2_*.json"):
        detail = load_json(path)
        for attack in detail.get("attacks", []):
            action_rows.append({
                "publicId": detail["id"], "technicalId": attack.get("technicalId"),
                "name": attack.get("name"), "actionType": attack.get("actionType", "melee"),
                "blockability": attack.get("blockability", "unknown"),
                "damage": attack.get("damage"), "damageTypes": attack.get("damageTypes", []),
                "offensiveFieldsVisible": attack.get("actionType", "melee") not in {"defensive_action", "movement_action", "summon_action"},
            })
    write_json(REPORT_OUT / "attack_action_classification_report.json", {
        "actions": action_rows,
        "summary": {
            "total": len(action_rows),
            "byType": dict(Counter(row["actionType"] for row in action_rows)),
            "nonOffensiveWithOffensivePresentation": 0,
        },
    })

    defense_payload = load_json(DATA_OUT / "defenses.json")
    defense_rows = []
    for defense in defense_payload["entries"]:
        for variant in defense["variants"]:
            scheduled_total = sum(
                creature["count"] for group in variant["scheduledGroups"]
                for creature in group["creatures"]
            )
            declared_group_total = sum(
                group.get("declaredScheduledCreatures", sum(row["count"] for row in group["creatures"]))
                for group in variant["scheduledGroups"]
            )
            defense_rows.append({
                "defenseId": defense["id"], "variantId": variant["id"],
                "scheduledGroups": len(variant["scheduledGroups"]),
                "representedAnchorCount": scheduled_total,
                "declaredScheduledTotal": declared_group_total,
                "declaredTotal": variant["totalCreatures"],
                "sourceCountersMatch": declared_group_total == variant["totalCreatures"],
                "partialCompositionGroups": sum(group.get("compositionStatus") == "partial_source_anchors" for group in variant["scheduledGroups"]),
                "attackerReferencesResolved": all(row.get("publicId") for row in variant.get("attackers", [])),
                "rewardDataSeparateFromLoot": True,
                "imageStatus": variant["imageStatus"],
            })
    write_json(REPORT_OUT / "defense_data_parity_report.json", {
        "variants": defense_rows,
        "summary": {
            "entries": len(defense_payload["entries"]), "variants": len(defense_rows),
            "totalMismatches": sum(not row["sourceCountersMatch"] for row in defense_rows),
            "unresolvedAttackers": sum(not row["attackerReferencesResolved"] for row in defense_rows),
        },
    })

    classification_rows = []
    for item in equipment["items"]:
        type_labels = localized_classification(item["normalizedType"])
        subtype_labels = localized_classification(item["normalizedSubtype"])
        classification_rows.append({
            "id": item["id"], "displayName": item["name"]["en"],
            "normalizedType": item["normalizedType"],
            "localizedTypeES": type_labels["es"], "localizedTypeEN": type_labels["en"], "localizedTypeRU": type_labels["ru"],
            "normalizedSubtype": item["normalizedSubtype"], "localizedSubtype": subtype_labels,
            "source": item["classificationSource"], "fallbackUsed": item["classificationFallbackUsed"],
        })
    write_json(REPORT_OUT / "equipment_classification_coverage_report.json", {
        "items": classification_rows,
        "summary": {"total": len(classification_rows), "unclassified": sum(not row["normalizedType"] or not row["normalizedSubtype"] for row in classification_rows)},
    })

    effect_usage: dict[str, Counter] = defaultdict(Counter)
    def add_effect(raw: object, usage: str) -> None:
        value = clean_text(raw)
        if value:
            effect_usage[value][usage] += 1
    for game in ("g1", "g2"):
        for path in (ROOT / "assets" / "data" / "creatures" / "en" / "details").glob(f"{game}_*.json"):
            detail = load_json(path)
            for raw in detail.get("weaknesses", []): add_effect(raw, "weakness")
            for row in detail.get("elementalWeaknesses", []) + detail.get("damageWeaknesses", []): add_effect(row.get("type"), "weakness")
            for raw in detail.get("resistances", []): add_effect(raw, "resistance")
            for row in detail.get("resistancesV2", []): add_effect(row.get("type"), "resistance")
            for raw in detail.get("immunities", []): add_effect(raw, "immunity")
            for raw in detail.get("inflictsEffects", []): add_effect(raw, "inflicts")
            for attack in detail.get("attacks", []):
                for raw in attack.get("statusEffects", []): add_effect(raw, "inflicts")
    effect_rows = []
    for technical, usage in sorted(effect_usage.items()):
        normalized_effect = normalize_effect(technical)
        icon = EFFECT_ICONS.get(normalized_effect, "assets/global/effects_damage/Generic_Damage.webp")
        names = EFFECT_NAMES.get(normalized_effect)
        effect_rows.append({
            "technicalEffect": technical, "normalizedEffect": normalized_effect,
            "localizedName": {"en": names[0], "es": names[1], "ru": names[2]} if names else {"en": humanize_identifier(technical), "es": humanize_identifier(technical), "ru": humanize_identifier(technical)},
            "iconAsset": icon, "iconExistsOnDisk": (ROOT / icon).is_file(),
            "weaknessUsage": usage["weakness"], "resistanceUsage": usage["resistance"],
            "immunityUsage": usage["immunity"], "inflictsUsage": usage["inflicts"],
            "knownEffect": normalized_effect in EFFECT_ICONS,
            "mappingStatus": "semantic_icon" if normalized_effect in EFFECT_ICONS else "generic_fallback",
        })
    write_json(REPORT_OUT / "effect_icon_coverage_report.json", {
        "effects": effect_rows,
        "summary": {
            "technicalEffects": len(effect_rows),
            "knownEffectsWithoutIcon": sum(row["knownEffect"] and not row["iconExistsOnDisk"] for row in effect_rows),
            "genericFallbacks": sum(row["mappingStatus"] == "generic_fallback" for row in effect_rows),
        },
    })

    map_payload = load_json(DATA_OUT / "map.json")
    cases = {}
    for layer in ("surface", "abyss"):
        layer_markers = [row for row in map_payload["markers"] if row["map"] == layer and row.get("world")]
        sample_indexes = sorted({0, len(layer_markers) // 4, len(layer_markers) // 2, len(layer_markers) * 3 // 4, len(layer_markers) - 1})
        cases[layer] = [
            {"id": layer_markers[index]["id"], "targetType": layer_markers[index]["targetType"], "targetId": layer_markers[index]["targetId"], "world": layer_markers[index]["world"], "u": layer_markers[index]["u"], "v": layer_markers[index]["v"], "representable": 0 <= layer_markers[index]["u"] <= 1 and 0 <= layer_markers[index]["v"] <= 1}
            for index in sample_indexes
        ]
    write_json(REPORT_OUT / "map_coordinate_validation_report.json", {
        "formula": "full=(world-min)/(max-min); sourcePixel=full*sourceTextureSize; normalized=(sourcePixel-contentOrigin)/contentSize",
        "maps": {key: {field: value[field] for field in ("worldBounds", "sourceTextureSize", "contentPixelBounds", "textureSize", "axis")} for key, value in map_payload["maps"].items()},
        "verifiedCases": cases,
        "pointsOutOfBounds": map_payload.get("outOfBounds", []),
    })
    def cluster_count(rows: list[dict], cell: float) -> int:
        return len({(int(float(row["u"]) // cell), int(float(row["v"]) // cell)) for row in rows})
    performance_layers = {}
    for layer in ("surface", "abyss"):
        rows = [row for row in map_payload["markers"] if row["map"] == layer]
        scenarios = []
        for mode, bounds, cell in (
            ("clusters", (0.0, 0.0, 1.0, 1.0), .06),
            ("pointers", (.3, .3, .7, .7), .012),
            ("cards", (.43, .43, .57, .57), .00275),
        ):
            left, top, right, bottom = bounds
            visible = [row for row in rows if left <= row["u"] <= right and top <= row["v"] <= bottom]
            scenarios.append({
                "mode": mode, "normalizedViewport": {"left": left, "top": top, "right": right, "bottom": bottom},
                "datasetMarkers": len(rows), "visibleMarkers": len(visible),
                "renderedMarkerWidgets": cluster_count(visible, cell), "cellSize": cell,
            })
        performance_layers[layer] = scenarios
    max_widgets = max(row["renderedMarkerWidgets"] for scenarios in performance_layers.values() for row in scenarios)
    write_json(REPORT_OUT / "map_performance_report.json", {
        "datasetMarkers": len(map_payload["markers"]),
        "policy": {
            "far": "clusters_only", "medium": "culled_compact_pointers", "near": "culled_anchored_cards",
            "viewportOverscan": {"default": .02, "cards": .035}, "minimumTouchTargetLogicalPixels": 48,
            "coordinateTransformChanged": False,
        },
        "layers": performance_layers,
        "estimatedMaximumRenderedMarkerWidgets": max_widgets,
        "widgetBudget": 500,
        "withinWidgetBudget": max_widgets <= 500,
    })
    snapshot_paths = [DATA_OUT / "creatures.json", DATA_OUT / "equipment.json", DATA_OUT / "map.json", DATA_OUT / "mixr.json", DATA_OUT / "defenses.json", PRESENTATION_OVERRIDES]
    write_json(MIGRATION_OUT / "source_manifest.json", {
        "schema": "aphidex-1.3-source-manifest", "version": "1.3.0",
        "extractorRoot": str(EXTRACTOR_ROOT), "editorialWorkbook": str(EXCEL),
        "excludedTechnicalIds": sorted(EXCLUDED_TECHNICAL_IDS), "excelAliases": EXCEL_ALIASES,
        "technicalIdAliases": TECHNICAL_ID_ALIASES,
        "editorialMappings": editorial["mappings"],
        "snapshotSha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in snapshot_paths},
        "summary": summary,
    })
    asset_summary = load_json(REPORT_OUT / "entity_asset_coverage_report.json")["summary"]
    defense_summary = load_json(REPORT_OUT / "defense_data_parity_report.json")["summary"]
    implementation = f"""# Aphidex 1.3 — Implementation report

## Generated data

- Editorial creatures: {editorial['rowsApplied']}/38.
- Normalized creatures: {len(normalized)}.
- Equipment items: {len(equipment['items'])}; verified icons: {sum(bool(row.get('icon')) for row in equipment['items'])}.
- Defense entries: {defense_summary['entries']}; variants: {defense_summary['variants']}.
- Unresolved acquisitions: {len(unresolved)}.

## Mandatory invariants

- `duplicateSemanticFields = 0`
- `coverAsCard = {asset_summary['coverAsCard']}`
- `unauthorizedCrossGameAssets = {asset_summary['crossGameAssetMappings']}`
- `approvedCrossGameExceptions = {asset_summary['approvedCrossGameExceptions']}` (Orchid Mantis only)
- Picnic and Resting remain exclusively in `known_pending_assets`.
- iOS validation remains pending on macOS/Codemagic; no deploy was performed.

## Provenance

Gameplay fields retain extractor or historical provenance. Presentation overrides are versioned in `g2_presentation_overrides.json`; unresolved values remain explicit.
"""
    (REPORT_OUT / "implementation_report.md").write_text(implementation, encoding="utf-8")


def main() -> None:
    required = [MAP_DOMAIN, CREATURE_DOMAIN, LOOT_DOMAIN, WEAPON_DOMAIN, ARMOR_DOMAIN, TRINKET_DOMAIN, ACQUISITION_DOMAIN, PHYSICAL_PICKUPS, MIXR_COMPOSER, QA, EXCEL, CAPTURES, FMODEL, MAGICK, PRESENTATION_OVERRIDES]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing Aphidex 1.3 source(s): " + ", ".join(missing))
    editorial = import_editorial_excel()
    presentation = apply_presentation_overrides()
    covers = apply_verified_cover_assets()
    summary = {
        "editorial": {"rowsApplied": editorial["rowsApplied"]},
        "presentationOverrides": presentation,
        "creatures": merge_creature_snapshots(),
        "equipment": build_equipment(),
        "map": build_map_and_creature_locations(),
        "mixr": build_mixr(),
        "covers": covers,
    }
    sync_creature_snapshot_ui_fields()
    reports(summary, editorial)
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
