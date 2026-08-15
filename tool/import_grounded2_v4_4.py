"""Import Grounded 2 v4.4 data and assets into Aphidex.

The crosswalk owns stable IDs, the extractor owns combat data, and the
localization dumps own EN/es-MX player-facing names and descriptions.
Grounded 1 files are never read or written by this tool.
"""
from __future__ import annotations

import csv
import html
import json
import re
import shutil
from copy import deepcopy
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXTRACTOR = Path(r"F:\Ordenar\aphidex_g2_extractor_v4_4\aphidex_grounded2_v4_4.json")
BESTIARY = Path(r"F:\Ordenar\aphidex_g2_extractor_v4_4\grounded2_bestiary_v4_4.json")
CROSSWALK = Path(r"F:\Ordenar\aphidex_crosswalk_v4_4_inspect_20260813\stable_id_crosswalk_v4_4.json")
INVENTORY = Path(r"F:\Ordenar\creature_inventory_v4_4.csv")
LOCALIZATION = {
    "en": Path(r"F:\Software_Instaladores\Grounded 2\Grounded 2\Content\Augusta\Binaries\WinGDK\ue4ss\Mods\AphidexLocalizationDumper\Output\localization_en.tsv"),
    "es": Path(r"F:\Software_Instaladores\Grounded 2\Grounded 2\Content\Augusta\Binaries\WinGDK\ue4ss\Mods\AphidexLocalizationDumper\Output\localization_es-MX.tsv"),
}
TIER_SOURCE = Path(r"C:\Users\tibur\Downloads\Nuevos tiers")
CAPTURES = Path(r"F:\XboxCaptureCopies")
CARD_EXPORTS = Path(r"F:\Software_Instaladores\F-model\Output\Exports\Augusta\Content\Blueprints\Items\Icons\CreatureCards")
REPORTS = ROOT / "migration" / "grounded2_v4_4"

TIER_FILES = (
    "G2_tier_0.png", "G2_tier_1.png", "G2_tier_2.png",
    "G2_tier_3.png", "CreatureTier4.png", "G2_tier_boss.png",
    "G2_tier_boss_V.png",
)

# Automatic Russian names for rows that do not have an existing curated RU row.
RU_NAMES = {
    "g2_ancient_pond_jockey": "Древний рой прудовых наездников",
    "g2_chop_r": "CHOP.R", "g2_cku": "C.K.U.",
    "g2_diving_bell_spider": "Паук-серебрянка",
    "g2_green_shield_bug": "Зелёный щитник",
    "g2_koi_calico": "Калико", "g2_koi_dagon": "Дагон",
    "g2_koi_oriole": "Иволга", "g2_koi_sunny": "Санни",
    "g2_ogrr_green_shield_bug": "Зелёный щитник O.G.R.R.",
    "g2_ogrr_striped_bark_scorpion": "Полосатый древесный скорпион O.G.R.R.",
    "g2_ogrr_tiger_mosquito": "Тигровый комар O.G.R.R.",
    "g2_ogrr_toe_biter": "Водяной клоп O.G.R.R.",
    "g2_ogrr_toe_biter_leviathan": "Водяной клоп-левиафан O.G.R.R.",
    "g2_orc_green_shield_bug": "Зелёный щитник O.R.C.",
    "g2_orc_striped_bark_scorpion": "Полосатый древесный скорпион O.R.C.",
    "g2_orc_striped_bark_scorpion_jr": "Молодой полосатый древесный скорпион O.R.C.",
    "g2_orc_striped_bark_scorpling": "Детёныш полосатого древесного скорпиона O.R.C.",
    "g2_orc_tiger_mosquito": "Тигровый комар O.R.C.",
    "g2_orc_toe_biter": "Водяной клоп O.R.C.",
    "g2_orc_toe_biter_leviathan": "Водяной клоп-левиафан O.R.C.",
    "g2_orc_toe_biter_nymph": "Нимфа водяного клопа O.R.C.",
    "g2_papa_toe_biter": "Папа-водяной клоп",
    "g2_pond_jockey": "Рой прудовых наездников", "g2_sauc_r": "SAUC.R",
    "g2_spiny_water_flea": "Колючая водяная блоха",
    "g2_striped_bark_scorpion": "Полосатый древесный скорпион",
    "g2_striped_bark_scorpion_jr": "Молодой полосатый древесный скорпион",
    "g2_striped_bark_scorpling": "Детёныш полосатого древесного скорпиона",
    "g2_tadpole": "Головастик", "g2_tick": "Клещ",
    "g2_tiger_mosquito": "Тигровый комар", "g2_toe_biter": "Водяной клоп",
    "g2_toe_biter_leviathan": "Водяной клоп-левиафан",
    "g2_toe_biter_nymph": "Нимфа водяного клопа",
    "g2_water_boatman": "Водяной гребляк", "g2_water_flea": "Водяная блоха",
    "g2_buggy_toe_biter": "Багги: нимфа водяного клопа",
}

PHOTO_MAP = {
    "g2_ancient_pond_jockey": "G2_Jinete_Antiguo.png",
    "g2_chop_r": "G2_choper.png", "g2_cku": "G2_CKU.png",
    "g2_diving_bell_spider": "G2_ A_Campana.png",
    "g2_koi_calico": "G2_koi_calico.png", "g2_koi_dagon": "G2_koi_Dagon.png",
    "g2_koi_oriole": "G2_koi_monarca.png", "g2_koi_sunny": "G2_koi_soleada.png",
    "g2_orc_green_shield_bug": "G2_Chinche_V_ORC.png",
    "g2_orc_tiger_mosquito": "G2_Mosco_tigre_orc.png",
    "g2_orc_toe_biter_leviathan": "G2_Chinche_M_Leviatan_ORC.png",
    "g2_orc_toe_biter_nymph": "G2_Chinche_M_ninfa_orc.png",
    "g2_pond_jockey": "G2_Jinete_A.png", "g2_sauc_r": "G2_Saucr.png",
    "g2_spiny_water_flea": "G2_Pulga_A_Espinoza.png",
    "g2_striped_bark_scorpion": "G2_Escorpion_R_Adulto.png",
    "g2_striped_bark_scorpion_jr": "G2_Escorpion_R_Juvenil.png",
    "g2_striped_bark_scorpling": "G2_Escorpion_R_ninfa.png",
    "g2_tadpole": "G2_Renacuajo.png", "g2_tick": "G2_garrapatas.png",
    "g2_tiger_mosquito": "G2_Mosco_tigre.png", "g2_water_boatman": "G2_Barquero.png",
    "g2_water_flea": "G2_Pulga_A.png", "g2_buggy_toe_biter": "G2_Chinche_M_buggie.png",
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def clean_text(value: str | None) -> str:
    if not value:
        return ""
    return html.unescape(re.sub(r"<[^>]+>", "", value)).strip()


def localization_rows(path: Path) -> dict[tuple[str, str], str]:
    result = {}
    with path.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            if row.get("source") == "bestiaryItem":
                result[(row["entity"], row["field"])] = clean_text(row.get("text"))
    return result


def damage_id(raw: str) -> str:
    aliases = {"general": "generic", "chopping": "chopping", "stabbing": "stabbing",
               "slashing": "slashing", "busting": "busting", "fresh": "fresh",
               "spicy": "spicy", "sour": "sour", "salty": "salty", "water": "water",
               "explosive": "explosive", "gas": "gas", "venom": "venom", "poison": "poison"}
    key = re.sub(r"[^a-z]", "", raw.lower())
    return aliases.get(key, re.sub(r"(?<!^)(?=[A-Z])", "_", raw).lower())


def bonuses(rows: list[dict]) -> list[dict]:
    output = []
    for row in rows or []:
        for kind in row.get("damageTypes", []):
            output.append({"type": damage_id(kind), "bonusPct": int(round(abs(float(row.get("percent", 0)))) )})
    return output


def attacks(rows: list[dict]) -> list[dict]:
    output = []
    for row in rows or []:
        name = row.get("id") or row.get("ability") or "Unknown attack"
        tags = []
        damage = row.get("damage") or {}
        if damage.get("type"):
            tags.append(damage_id(damage["type"]))
        if row.get("ranged"):
            tags.append("ranged")
        notes = []
        if row.get("resolved") is False:
            notes.append("Damage row unresolved in extractor v4.4; no value was inferred.")
        elif damage.get("amount") is not None:
            notes.append(f"Extracted base damage: {damage['amount']:g}.")
        output.append({"name": {"en": name, "es": name, "ru": name}, "tags": tags,
                       "notes": {"en": " ".join(notes), "es": " ".join(notes), "ru": " ".join(notes)}})
    return output


def weak_points(parts: list[str]) -> list[dict]:
    return [{"part": re.sub(r"(?<!^)(?=[A-Z])", "_", part).lower(),
             "susceptibleDamage": "any", "susceptibleDamageTypes": ["any"]}
            for part in (parts or [])]


def merge_encounter_variants(crosswalk_rows: list[dict], extracted_rows: list[dict]) -> list[dict]:
    """Merge duplicate Named C.R.O. rows by their technical character row."""
    merged = {}
    for row in [*(extracted_rows or []), *(crosswalk_rows or [])]:
        key = row.get("technicalCharacterRow") or row.get("characterRow") or row.get("id")
        if not key:
            continue
        current = merged.setdefault(key, {})
        current.update(row)
        current.setdefault("id", key)
        current.setdefault("characterRow", key)
    return list(merged.values())


def copy_card(raw: dict, kind: str) -> str:
    card = raw.get("cards", {}).get(kind, {})
    source = Path(card.get("localImage", ""))
    if not source.is_file():
        return ""
    if kind == "normal":
        destination = ROOT / "assets" / "g2" / "creatures" / "cards" / f"Creaturecard_{source.name}"
    else:
        destination = ROOT / "assets" / "g2" / "creatures" / "cards_golden" / f"Creaturecardgold_{source.name}"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    return destination.relative_to(ROOT).as_posix()


def copy_special_gold_card(stable_id: str) -> str:
    filename = {"g2_crow": "T_UI_TierX_Crow_G.png", "g2_garter_snake": "T_UI_Boss_Snake_G.png"}.get(stable_id)
    if not filename:
        return ""
    source = CARD_EXPORTS / "Gold" / filename
    if not source.is_file():
        raise FileNotFoundError(source)
    short_name = "Crow" if stable_id == "g2_crow" else "Garter_Snake"
    destination = ROOT / "assets" / "g2" / "creatures" / "cards_golden" / f"Creaturecardgold_{short_name}.png"
    shutil.copy2(source, destination)
    return destination.relative_to(ROOT).as_posix()


def main() -> None:
    required = [EXTRACTOR, BESTIARY, CROSSWALK, INVENTORY, *LOCALIZATION.values(), TIER_SOURCE, CAPTURES]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise FileNotFoundError("Missing required input(s): " + ", ".join(missing))

    master_path = ROOT / "assets" / "data" / "enemies_g2.json"
    current = load_json(master_path)
    current_by_id = {entry["id"]: entry for entry in current}
    extractor = {entry["id"]: entry for entry in load_json(EXTRACTOR)["creatures"]}
    bestiary = {entry["id"]: entry for entry in load_json(BESTIARY)["creatures"]}
    crosswalk = load_json(CROSSWALK)
    inventory = {row["bestiaryId"]: row for row in csv.DictReader(INVENTORY.open(encoding="utf-8-sig"))}
    localized = {lang: localization_rows(path) for lang, path in LOCALIZATION.items()}
    named = {}
    for variant in crosswalk["namedEncounterVariantMap"]:
        named.setdefault(variant["parentAphidexId"], []).append(variant)

    final = []
    unresolved = []
    auto_ru = []
    mapped_photos = []
    missing_photos = []
    for order, link in enumerate(crosswalk["entries"], start=201):
        stable_id = link["aphidexId"]
        technical_id = link["technicalId"]
        bestiary_id = link["bestiaryId"]
        game = extractor.get(technical_id, {})
        raw = bestiary.get(technical_id, bestiary.get(bestiary_id, {}))
        inv = inventory.get(bestiary_id, {})
        old = deepcopy(current_by_id.get(stable_id, {}))
        is_new = link["mappingStatus"] == "NEW"
        ru_name = old.get("name", {}).get("ru") or RU_NAMES.get(stable_id) or link["gameNameEn"]
        if is_new:
            auto_ru.append(stable_id)
        description_en = localized["en"].get((bestiary_id, "description"), "")
        description_es = localized["es"].get((bestiary_id, "description"), "")
        if is_new:
            old = {
                "id": stable_id, "speciesKey": link["speciesKeyProposal"], "collectionGroup": link.get("variantType") or "other",
                "game": "g2", "danger": "unknown", "order": order, "defaultGold": False,
                "photo": "assets/global/Proximamente.png", "temperament": "other", "loot": [], "abilities": [],
                "behavior": {"en": "Behavior is sourced from the v4.4 combat data.", "es": "El comportamiento se basa en los datos de combate v4.4.", "ru": "Поведение основано на боевых данных версии 4.4."},
                "interactionWithPlayer": {"en": "See the verified combat values below.", "es": "Consulta abajo los valores de combate verificados.", "ru": "Проверенные боевые значения приведены ниже."},
                "interactionWithCreatures": {"en": "No additional interaction was verified.", "es": "No se verificó una interacción adicional.", "ru": "Дополнительные взаимодействия не подтверждены."},
                "strategy": {"en": "Use the listed weaknesses and resistances.", "es": "Usa las fortalezas y debilidades indicadas.", "ru": "Используйте указанные слабости и сопротивления."},
            }
        tier_raw = inv.get("gameTierRaw") or game.get("tier") or old.get("tier", 1)
        raw_tier = int(float(tier_raw)) if tier_raw not in (None, "") else 1
        card_tier_raw = inv.get("cardTierVisual")
        card_tier = int(float(card_tier_raw)) if card_tier_raw not in (None, "") else raw_tier
        yellow = bestiary_id in {"KoiA", "KoiB", "KoiC", "KoiD", "CrowDummy", "SnakeDummy"}
        source_boss = bool(game.get("boss")) or bool(raw.get("bossAnalysis", {}).get("isBoss"))
        is_boss = yellow or source_boss or bool(old.get("isBoss"))
        health = game.get("stats", {}).get("health")
        if yellow:
            health = None
        normal_card = copy_card(raw, "normal")
        gold_card = copy_card(raw, "gold") or copy_special_gold_card(stable_id)
        old.update({
            "id": stable_id, "speciesKey": link["speciesKeyProposal"], "groupId": link.get("groupId"),
            "name": {"en": link["gameNameEn"], "es": link["gameNameEsMX"], "ru": ru_name},
            "tier": 5 if is_boss else max(1, raw_tier), "cardTier": card_tier,
            "technicalId": technical_id, "bestiaryId": bestiary_id,
            "isBoss": is_boss, "bossCardStyle": "yellow" if yellow else ("red" if is_boss else None),
            "isKillable": not yellow, "healthDisplay": "hidden" if yellow else "normal",
            "cardNormal": normal_card, "cardGold": gold_card,
            "weaknesses": [damage_id(x) for row in game.get("weaknesses", []) for x in row.get("damageTypes", [])],
            "resistances": [damage_id(x) for row in game.get("resistances", []) for x in row.get("damageTypes", [])],
            "elementalWeaknesses": bonuses([r for r in game.get("weaknesses", []) if any(damage_id(x) in {"fresh", "spicy", "sour", "salty"} for x in r.get("damageTypes", []))]),
            "damageWeaknesses": bonuses([r for r in game.get("weaknesses", []) if any(damage_id(x) not in {"fresh", "spicy", "sour", "salty"} for x in r.get("damageTypes", []))]),
            "resistancesV2": bonuses(game.get("resistances", [])), "weakPoints": weak_points(game.get("weakpoints", [])),
            "attacks": attacks(game.get("attacks", [])),
            "encounterVariants": merge_encounter_variants(named.get(stable_id, []), game.get("encounterVariants", [])),
            "contextVariants": game.get("contextVariants", []), "specialCombatModifiers": game.get("specialCombatModifiers", []),
            "mechanicSignals": game.get("mechanicSignals", []), "dataRevision": "grounded2-v4.4",
        })
        if health is None:
            old["health"] = None
        else:
            hp = int(round(float(health)))
            old["health"] = {"value": hp, "rating": 1 if hp < 400 else 2 if hp < 700 else 3 if hp < 1100 else 4 if hp < 2000 else 5}
            old.setdefault("combatStats", {})["health"] = hp
        if description_en:
            old.setdefault("description", {})["en"] = description_en
        if description_es:
            old.setdefault("description", {})["es"] = description_es
        if is_new:
            old.setdefault("description", {})["ru"] = f"Автоматически переведённая запись бестиария Grounded 2 для существа «{ru_name}». Боевые данные соответствуют версии 4.4."
            old["localizationStatus"] = "ru_automatic_pending_review"
        for attack in game.get("attacks", []):
            if attack.get("resolved") is False:
                unresolved.append({"id": stable_id, "technicalId": technical_id, "attack": attack})
        photo_name = PHOTO_MAP.get(stable_id)
        if photo_name and (CAPTURES / photo_name).is_file():
            destination = ROOT / "assets" / "g2" / "creatures" / "photos" / f"v4_4_{stable_id}.png"
            shutil.copy2(CAPTURES / photo_name, destination)
            old["photo"] = destination.relative_to(ROOT).as_posix()
            mapped_photos.append(stable_id)
        elif is_new:
            missing_photos.append(stable_id)
        final.append(old)

    # Preserve the eight explicitly current-only records, including visible Orchid Mantis.
    for row in crosswalk["currentOnlyEntries"]:
        entry = current_by_id.get(row["aphidexId"])
        if entry:
            final.append(deepcopy(entry))

    # Verified amphibious Buggie; no unverified numerical stats are inferred.
    toe = next(entry for entry in final if entry["id"] == "g2_toe_biter_nymph")
    buggy = deepcopy(toe)
    buggy.update({
        "id": "g2_buggy_toe_biter", "speciesKey": "buggy_toe_biter", "collectionGroup": "buggy",
        "name": {"en": "Toe-biter Nymph Buggy", "es": "Bichito: ninfa de mordedor de dedos", "ru": RU_NAMES["g2_buggy_toe_biter"]},
        "favoriteKey": "g2_buggy_toe_biter", "tier": 1, "cardTier": toe.get("cardTier", 3),
        "isBoss": False, "bossCardStyle": None, "isKillable": False, "health": None, "healthDisplay": "hidden",
        "attacks": [], "combatStats": None, "dataVerification": "buggy_stats_unverified",
        "description": {
            "en": "An amphibious Toe-biter Nymph Buggy that can travel on land and through water. Specific combat stats were not present in the supplied v4.4 dumps.",
            "es": "Una Buggie anfibia de ninfa de mordedor de dedos que puede desplazarse por tierra y agua. Los dumps v4.4 entregados no incluyen stats de combate específicos.",
            "ru": "Амфибийный багги из нимфы водяного клопа, способный двигаться по суше и воде. В предоставленных данных v4.4 нет отдельных боевых характеристик.",
        },
        "localizationStatus": "ru_automatic_pending_review",
    })
    photo_name = PHOTO_MAP["g2_buggy_toe_biter"]
    if (CAPTURES / photo_name).is_file():
        destination = ROOT / "assets" / "g2" / "creatures" / "photos" / "v4_4_g2_buggy_toe_biter.png"
        shutil.copy2(CAPTURES / photo_name, destination)
        buggy["photo"] = destination.relative_to(ROOT).as_posix()
        mapped_photos.append("g2_buggy_toe_biter")
    final.append(buggy)
    auto_ru.append("g2_buggy_toe_biter")

    if len({entry["id"] for entry in final}) != len(final):
        raise ValueError("Duplicate final IDs")
    if len(crosswalk["entries"]) != 123 or len(final) != 132:
        raise ValueError(f"Unexpected roster: include={len(crosswalk['entries'])}, final={len(final)}")

    for filename in TIER_FILES:
        destination = ROOT / "assets" / "g2" / "tier_icons" / filename
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(TIER_SOURCE / filename, destination)
    write_json(master_path, final)
    REPORTS.mkdir(parents=True, exist_ok=True)
    write_json(REPORTS / "unresolved_attacks.json", unresolved)
    write_json(REPORTS / "asset_manifest.json", {
        "cards": {entry["id"]: {"normal": entry.get("cardNormal", ""), "gold": entry.get("cardGold", "")} for entry in final},
        "misplacedGoldCards": ["Creaturecard_Garter_Snake.png", "Creaturecard_Crow.png"],
        "photosMapped": mapped_photos, "photosMissing": missing_photos,
    })
    with (REPORTS / "russian_translation_review.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["id", "name_ru", "status"])
        for stable_id in auto_ru:
            entry = next(item for item in final if item["id"] == stable_id)
            writer.writerow([stable_id, entry["name"]["ru"], "automatic_pending_human_review"])
    write_json(REPORTS / "validation_report.json", {
        "include": 123, "preservedSpecial": 8, "toeBiterBuggy": 1, "final": len(final),
        "newCrosswalkIds": sum(row["mappingStatus"] == "NEW" for row in crosswalk["entries"]),
        "preservedCrosswalkIds": sum(row["mappingStatus"] == "PRESERVE" for row in crosswalk["entries"]),
        "namedVariants": sum(len(entry.get("encounterVariants", [])) for entry in final),
        "contextVariants": sum(len(entry.get("contextVariants", [])) for entry in final),
        "unresolvedAttacks": len(unresolved), "automaticRussianRows": len(auto_ru),
        "g1FilesTouched": False,
    })
    print(json.dumps(load_json(REPORTS / "validation_report.json"), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
