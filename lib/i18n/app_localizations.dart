import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../controllers/locale_controller.dart';
import '../data/creature_card_state.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('es'), Locale('en'), Locale('ru')];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    final localization = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localization != null, 'AppLocalizations not found in context.');
    return localization!;
  }

  String get languageCode =>
      LocaleController.resolveSupportedLocale(locale).languageCode;

  static final RegExp _mojibakePattern = RegExp(r'[ÃÂÐÑâ€¢œž€™“”\uFFFD]');

  String _t(String key) =>
      _normalizeText(_localizedValues[languageCode]![key]!);

  String _normalizeText(String value) {
    var repaired = value.replaceAll('\u00A0', ' ');

    for (var pass = 0; pass < 3; pass++) {
      if (!_mojibakePattern.hasMatch(repaired)) {
        break;
      }

      try {
        final decoded = utf8.decode(
          latin1.encode(repaired),
          allowMalformed: true,
        );
        if (decoded == repaired) {
          break;
        }
        repaired = decoded;
      } catch (_) {
        break;
      }
    }

    return repaired;
  }

  String get appTitle => _t('appTitle');
  String get settingsTitle => _t('settingsTitle');
  String get appearanceTitle => _t('appearanceTitle');
  String get languageTitle => _t('languageTitle');
  String get systemTheme => _t('systemTheme');
  String get lightTheme => _t('lightTheme');
  String get darkTheme => _t('darkTheme');
  String get automaticLanguage => _t('automaticLanguage');
  String get useDeviceLanguage => _t('useDeviceLanguage');
  String get spanishLanguage => _t('spanishLanguage');
  String get englishLanguage => _t('englishLanguage');
  String get russianLanguage => _t('russianLanguage');
  String get creditsTitle => _t('creditsTitle');
  String get creditsSubtitle => _t('creditsSubtitle');
  String get websiteTitle => _t('websiteTitle');
  String get websiteSubtitle => _t('websiteSubtitle');
  String get wipeDataTitle => _t('wipeDataTitle');
  String get wipeDataSubtitle => _t('wipeDataSubtitle');
  String get openLinkError => _t('openLinkError');
  String get wipeConfirmTitle => _t('wipeConfirmTitle');
  String get wipeConfirmMessage => _t('wipeConfirmMessage');
  String get cancelAction => _t('cancelAction');
  String get deleteAction => _t('deleteAction');
  String get dataWiped => _t('dataWiped');
  String get chooseGameTooltip => _t('chooseGameTooltip');
  String get settingsTooltip => _t('settingsTooltip');
  String get playerProfileTooltip => _t('playerProfileTooltip');
  String get playerProfileTitle => _t('playerProfileTitle');
  String get playerProfileSubtitle => _t('playerProfileSubtitle');
  String get playerProfileNoSelection => _t('playerProfileNoSelection');
  String get playerProfileChooseAction => _t('playerProfileChooseAction');
  String get playerProfileChangeAction => _t('playerProfileChangeAction');
  String get playerProfileClearAction => _t('playerProfileClearAction');
  String get playerProfileGameSelector => _t('playerProfileGameSelector');
  String get playerProfileCharacterLabel => _t('playerProfileCharacterLabel');
  String get playerProfileCreatureCards => _t('playerProfileCreatureCards');
  String get playerProfileGoldCards => _t('playerProfileGoldCards');
  String get playerProfileKills => _t('playerProfileKills');
  String get killCountAdd => _t('killCountAdd');
  String get killCountEdit => _t('killCountEdit');
  String get killCountReset => _t('killCountReset');
  String get killCountQuantity => _t('killCountQuantity');
  String get saveAction => _t('saveAction');
  String get filterWithKills => _t('filterWithKills');
  String get filterWithoutKills => _t('filterWithoutKills');
  String get tutorialProfileTitle => _t('tutorialProfileTitle');
  String get tutorialProfileBody => _t('tutorialProfileBody');
  String get playerProfileSelectTooltip => _t('playerProfileSelectTooltip');
  String get playerProfileChangeTooltip => _t('playerProfileChangeTooltip');
  String get playerDisplayNameTitle => _t('playerDisplayNameTitle');
  String get playerDisplayNameAdd => _t('playerDisplayNameAdd');
  String get playerDisplayNameEdit => _t('playerDisplayNameEdit');
  String get playerDisplayNameSave => _t('playerDisplayNameSave');
  String get playerDisplayNameRemove => _t('playerDisplayNameRemove');
  String get playerDisplayNameCounter => _t('playerDisplayNameCounter');
  String get playerProfileShare => _t('playerProfileShare');
  String get playerProfileShareTooltip => _t('playerProfileShareTooltip');
  String get playerProfileShareUnavailable =>
      _t('playerProfileShareUnavailable');
  String get playerProfileShareText => _t('playerProfileShareText');
  String get playerProfileShareError => _t('playerProfileShareError');
  String playerProfileShareMessage({
    required String game,
    required String creatureCards,
    required String goldCards,
    String kills = '0',
    required String website,
    String? displayName,
  }) {
    final hasName = displayName != null && displayName.isNotEmpty;
    return switch (languageCode) {
      'en' =>
        '${hasName ? "$displayName's Aphidex profile" : 'My Aphidex profile'} for $game:\n'
            '$creatureCards Creature Cards\n$goldCards Gold Cards\n$kills defeated creatures\n\n'
            'Explore creatures, weaknesses, and your progress with Aphidex:\n$website',
      'ru' =>
        '${hasName ? '\u041f\u0440\u043e\u0444\u0438\u043b\u044c $displayName \u0432 Aphidex' : '\u041c\u043e\u0439 \u043f\u0440\u043e\u0444\u0438\u043b\u044c Aphidex'} \u0434\u043b\u044f $game:\n'
            '$creatureCards Creature Cards\n$goldCards \u0437\u043e\u043b\u043e\u0442\u044b\u0445 \u043a\u0430\u0440\u0442\u043e\u0447\u0435\u043a\n$kills \u0443\u043d\u0438\u0447\u0442\u043e\u0436\u0435\u043d\u0438\u0439\n\n'
            '\u0418\u0437\u0443\u0447\u0430\u0439\u0442\u0435 \u0441\u0443\u0449\u0435\u0441\u0442\u0432, \u0438\u0445 \u0441\u043b\u0430\u0431\u043e\u0441\u0442\u0438 \u0438 \u0441\u0432\u043e\u0439 \u043f\u0440\u043e\u0433\u0440\u0435\u0441\u0441 \u0441 Aphidex:\n$website',
      _ =>
        '${hasName ? 'Perfil de $displayName en Aphidex' : 'Mi perfil de Aphidex'} para $game:\n'
            '$creatureCards Tarjetas de criatura\n$goldCards tarjetas doradas\n$kills eliminaciones\n\n'
            'Consulta criaturas, debilidades y tu progreso con Aphidex:\n$website',
    };
  }

  String get playerProfileSelectorSubtitle =>
      _t('playerProfileSelectorSubtitle');
  String playerProfileSelected(String name) =>
      _t('playerProfileSelected').replaceFirst('{name}', name);
  String playerProfileSelectorTitle(String game) =>
      _t('playerProfileSelectorTitle').replaceFirst('{game}', game);

  String playerCharacterName(String id) {
    final value = switch (id) {
      'g1_burgl' => 'BURG.L',
      'g1_wendell' => 'Wendell Tully',
      'g2_masked_stranger' => switch (languageCode) {
        'es' => 'Extraña enmascarada',
        'ru' => 'Таинственная незнакомка в маске',
        _ => 'Masked Stranger',
      },
      _ =>
        id
            .split('_')
            .last
            .replaceFirstMapped(
              RegExp(r'^[a-z]'),
              (match) => match.group(0)!.toUpperCase(),
            ),
    };
    return _normalizeText(value);
  }

  String get sortDefaultOrder => _t('sortDefaultOrder');
  String get sortByName => _t('sortByName');
  String get sortByDanger => _t('sortByDanger');
  String get sortByTier => _t('sortByTier');
  String get descendingOrder => _t('descendingOrder');
  String get ascendingOrder => _t('ascendingOrder');
  String get searchEnemyHint => _t('searchEnemyHint');
  String get loadingCreaturesTitle => _t('loadingCreaturesTitle');
  String get loadingCreaturesSubtitle => _t('loadingCreaturesSubtitle');
  String get loadingCreatureDetailSubtitle =>
      _t('loadingCreatureDetailSubtitle');
  String get dataUnavailableTitle => _t('dataUnavailableTitle');
  String get dataUnavailableSubtitle => _t('dataUnavailableSubtitle');
  String get retryAction => _t('retryAction');
  String get filterAll => _t('filterAll');
  String get filtersTitle => _t('filtersTitle');
  String get clearFiltersAction => _t('clearFiltersAction');
  String get clearSearchAction => _t('clearSearchAction');
  String get favoritesFilterLabel => _t('favoritesFilterLabel');
  String get filterTiers => _t('filterTiers');
  String get filterClass => _t('filterClass');
  String get filterDanger => _t('filterDanger');
  String get filterBoss => _t('filterBoss');
  String get tierTitle => _t('tierTitle');
  String get groupNeutrals => _t('groupNeutrals');
  String get groupAggressive => _t('groupAggressive');
  String get groupPeaceful => _t('groupPeaceful');
  String get groupAnomalies => _t('groupAnomalies');
  String get groupOthers => _t('groupOthers');
  String get groupOrc {
    switch (languageCode) {
      case 'en':
        return 'O.R.C.';
      case 'ru':
        return 'O.R.C.';
      default:
        return 'O.R.C.';
    }
  }

  String get groupAngry {
    final value = switch (languageCode) {
      'en' => 'Angry',
      'ru' =>
        '\u0410\u0433\u0440\u0435\u0441\u0441\u0438\u0432\u043D\u044B\u0435',
      _ => 'Agresivos',
    };
    return _normalizeText(value);
  }

  String get groupHarmless {
    final value = switch (languageCode) {
      'en' => 'Harmless',
      'ru' => '\u0411\u0435\u0437\u043E\u0431\u0438\u0434\u043D\u044B\u0435',
      _ => 'Inofensivos',
    };
    return _normalizeText(value);
  }

  String get groupOgrr {
    switch (languageCode) {
      case 'en':
        return 'O.G.R.R.';
      case 'ru':
        return 'O.G.R.R.';
      default:
        return 'I.R.G.O.';
    }
  }

  String get groupBuggies {
    final value = switch (languageCode) {
      'en' => 'Buggies',
      'ru' => '\u0411\u0430\u0433\u0433\u0438',
      _ => 'Buggies',
    };
    return _normalizeText(value);
  }

  String get selectEditionTitle => _t('selectEditionTitle');
  String get bothGames => _t('bothGames');
  String get groundedOne => _t('groundedOne');
  String get groundedTwo => _t('groundedTwo');
  String get errorLoadingJson => _t('errorLoadingJson');
  String get goldDefault => _t('goldDefault');
  String get goldUnlocked => _t('goldUnlocked');
  String get goldFilterLabel => _t('goldFilterLabel');
  String get goldMark => _t('goldMark');
  String get elementalWeakness => _t('elementalWeakness');
  String get damageWeakness => _t('damageWeakness');
  String get resistancesTitle => _t('resistancesTitle');
  String get weakPointTitle => _t('weakPointTitle');
  String get attacksTitle => _t('attacksTitle');
  String get weaknessesTitle => _t('weaknessesTitle');
  String get upcomingTitle => _t('upcomingTitle');
  String get underConstructionLabel => _t('underConstructionLabel');
  String get upcomingItems => _t('upcomingItems');
  String get healthTitle => _t('healthTitle');
  String get notApplicableHealthLabel => _t('notApplicableHealthLabel');
  String get creatureCardTitle => _t('creatureCardTitle');
  String get creatureCardNormal => _t('creatureCardNormal');
  String get creatureCardGold => _t('creatureCardGold');
  String get creatureCardProgressTitle => _t('creatureCardProgressTitle');
  String get creatureCardObtainedLabel => _t('creatureCardObtainedLabel');
  String get creatureCardGoldLabel => _t('creatureCardGoldLabel');
  String get creatureCardViewerLockedLabel =>
      _t('creatureCardViewerLockedLabel');
  String get creatureCardProgressA11yLabel =>
      _t('creatureCardProgressA11yLabel');
  String get creatureCardProgressActionTemplate =>
      _t('creatureCardProgressActionTemplate');
  String get infusionSelectorTitle => _t('infusionSelectorTitle');
  String get infusionRecommendationsTitle => _t('infusionRecommendationsTitle');
  String get lesserMutationsTitle => _t('lesserMutationsTitle');
  String get lootTransformationsTitle => _t('lootTransformationsTitle');
  String get effectGuideAction => _t('effectGuideAction');
  String get noImageTitle => _t('noImageTitle');
  String get noImageSubtitle => _t('noImageSubtitle');
  String get emptySearchTitle => _t('emptySearchTitle');
  String get emptySearchSubtitle => _t('emptySearchSubtitle');
  String get emptyFavoritesTitle => _t('emptyFavoritesTitle');
  String get emptyFavoritesSubtitle => _t('emptyFavoritesSubtitle');
  String get emptyGoldTitle => _t('emptyGoldTitle');
  String get emptyGoldSubtitle => _t('emptyGoldSubtitle');
  String get emptyFiltersTitle => _t('emptyFiltersTitle');
  String get emptyFiltersSubtitle => _t('emptyFiltersSubtitle');
  String get masterDetailPlaceholderTitle => _t('masterDetailPlaceholderTitle');
  String get masterDetailPlaceholderSubtitle =>
      _t('masterDetailPlaceholderSubtitle');
  String get attackTell => _t('attackTell');
  String get attackAvoid => _t('attackAvoid');
  String get attackNotes => _t('attackNotes');
  String get immuneLabel => _t('immuneLabel');
  String get effectCodexTitle => _t('effectCodexTitle');
  String get effectCodexSubtitle => _t('effectCodexSubtitle');
  String get effectCodexTooltip => _t('effectCodexTooltip');
  String get effectEquipmentTitle => _t('effectEquipmentTitle');
  String get effectEquipmentComingSoon => _t('effectEquipmentComingSoon');
  String get creditsAppTagline => _t('creditsAppTagline');
  String get creditsContentTitle => _t('creditsContentTitle');
  String get creditsContentBody => _t('creditsContentBody');
  String get groundedTwoWikiButton => _t('groundedTwoWikiButton');
  String get ccLicenseButton => _t('ccLicenseButton');
  String get donorsTitle => _t('donorsTitle');
  String get noDonorsYet => _t('noDonorsYet');
  String get footerText => _t('footerText');
  String get reviewPromptTitle => _t('reviewPromptTitle');
  String get reviewPromptMessage => _t('reviewPromptMessage');
  String get reviewNeverAction => _t('reviewNeverAction');
  String get reviewLaterAction => _t('reviewLaterAction');
  String get reviewRateAction => _t('reviewRateAction');
  String get reviewConfirmTitle => _t('reviewConfirmTitle');
  String get reviewConfirmMessage => _t('reviewConfirmMessage');
  String get reviewNotYetAction => _t('reviewNotYetAction');
  String get reviewReviewedAction => _t('reviewReviewedAction');
  String get adsSettingsTitle {
    switch (languageCode) {
      case 'en':
        return 'Ads and Ad-Free';
      case 'ru':
        return '\u0420\u0435\u043A\u043B\u0430\u043C\u0430 \u0438 \u043E\u0442\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u0435';
      default:
        return 'Anuncios y modo sin anuncios';
    }
  }

  String adsEnabledSubtitle(String price) {
    switch (languageCode) {
      case 'en':
        return 'Aphidex uses discreet ads to support development. Remove them permanently for $price.';
      case 'ru':
        return '\u0412 Aphidex \u0435\u0441\u0442\u044C \u043D\u0435\u043D\u0430\u0432\u044F\u0437\u0447\u0438\u0432\u0430\u044F \u0440\u0435\u043A\u043B\u0430\u043C\u0430 \u0434\u043B\u044F \u043F\u043E\u0434\u0434\u0435\u0440\u0436\u043A\u0438 \u0440\u0430\u0437\u0440\u0430\u0431\u043E\u0442\u043A\u0438. \u041E\u0442\u043A\u043B\u044E\u0447\u0438\u0442\u0435 \u0435\u0451 \u043D\u0430\u0432\u0441\u0435\u0433\u0434\u0430 \u0437\u0430 $price.';
      default:
        return 'Aphidex cuenta con anuncios discretos para apoyar su desarrollo. Puedes quitarlos para siempre por $price.';
    }
  }

  String get adsRemovedSubtitle {
    switch (languageCode) {
      case 'en':
        return 'Ads are disabled on this account.';
      case 'ru':
        return '\u0420\u0435\u043A\u043B\u0430\u043C\u0430 \u043E\u0442\u043A\u043B\u044E\u0447\u0435\u043D\u0430 \u0434\u043B\u044F \u044D\u0442\u043E\u0439 \u0443\u0447\u0451\u0442\u043D\u043E\u0439 \u0437\u0430\u043F\u0438\u0441\u0438.';
      default:
        return 'Los anuncios est\u00E1n desactivados en esta cuenta.';
    }
  }

  String get adsStorePendingSubtitle {
    switch (languageCode) {
      case 'en':
        return 'Connecting to Google Play to load the ad-free option.';
      case 'ru':
        return '\u041F\u043E\u0434\u043A\u043B\u044E\u0447\u0430\u0435\u043C\u0441\u044F \u043A Google Play, \u0447\u0442\u043E\u0431\u044B \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044C \u043E\u0442\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u0435 \u0440\u0435\u043A\u043B\u0430\u043C\u044B.';
      default:
        return 'Conectando con Google Play para cargar la opci\u00F3n sin anuncios.';
    }
  }

  String get removeAdsAction {
    switch (languageCode) {
      case 'en':
        return 'Remove ads';
      case 'ru':
        return '\u041E\u0442\u043A\u043B\u044E\u0447\u0438\u0442\u044C \u0440\u0435\u043A\u043B\u0430\u043C\u0443';
      default:
        return 'Quitar anuncios';
    }
  }

  String removeAdsPriceAction(String price) {
    switch (languageCode) {
      case 'en':
        return 'Remove ads · $price';
      case 'ru':
        return '\u041E\u0442\u043A\u043B\u044E\u0447\u0438\u0442\u044C \u0440\u0435\u043A\u043B\u0430\u043C\u0443 · $price';
      default:
        return 'Quitar anuncios · $price';
    }
  }

  String get restorePurchasesAction {
    switch (languageCode) {
      case 'en':
        return 'Restore purchase';
      case 'ru':
        return '\u0412\u043E\u0441\u0441\u0442\u0430\u043D\u043E\u0432\u0438\u0442\u044C \u043F\u043E\u043A\u0443\u043F\u043A\u0443';
      default:
        return 'Restaurar compra';
    }
  }

  String get adsAlreadyRemovedMessage {
    switch (languageCode) {
      case 'en':
        return 'Ads are already disabled.';
      case 'ru':
        return '\u0420\u0435\u043A\u043B\u0430\u043C\u0430 \u0443\u0436\u0435 \u043E\u0442\u043A\u043B\u044E\u0447\u0435\u043D\u0430.';
      default:
        return 'Los anuncios ya est\u00E1n desactivados.';
    }
  }

  String get adsStoreUnavailableMessage {
    switch (languageCode) {
      case 'en':
        return 'Google Play is not available right now.';
      case 'ru':
        return '\u0421\u0435\u0439\u0447\u0430\u0441 Google Play \u043D\u0435\u0434\u043E\u0441\u0442\u0443\u043F\u0435\u043D.';
      default:
        return 'Google Play no est\u00E1 disponible ahora mismo.';
    }
  }

  String get adsProductUnavailableMessage {
    switch (languageCode) {
      case 'en':
        return 'The ad-free product is not configured yet.';
      case 'ru':
        return '\u041F\u043E\u043A\u0430 \u043D\u0435 \u043D\u0430\u0441\u0442\u0440\u043E\u0435\u043D \u0442\u043E\u0432\u0430\u0440 \u0434\u043B\u044F \u043E\u0442\u043A\u043B\u044E\u0447\u0435\u043D\u0438\u044F \u0440\u0435\u043A\u043B\u0430\u043C\u044B.';
      default:
        return 'El producto para quitar anuncios todav\u00EDa no est\u00E1 configurado.';
    }
  }

  String get adsPurchaseFailedMessage {
    switch (languageCode) {
      case 'en':
        return 'The purchase could not be started.';
      case 'ru':
        return '\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u043D\u0430\u0447\u0430\u0442\u044C \u043F\u043E\u043A\u0443\u043F\u043A\u0443.';
      default:
        return 'No se pudo iniciar la compra.';
    }
  }

  String get adsRestoreStartedMessage {
    switch (languageCode) {
      case 'en':
        return 'Checking previous purchases...';
      case 'ru':
        return '\u041F\u0440\u043E\u0432\u0435\u0440\u044F\u0435\u043C \u043F\u0440\u0435\u0434\u044B\u0434\u0443\u0449\u0438\u0435 \u043F\u043E\u043A\u0443\u043F\u043A\u0438...';
      default:
        return 'Comprobando compras anteriores...';
    }
  }

  String get interstitialPitchTitle {
    switch (languageCode) {
      case 'en':
        return 'Keep Aphidex ad-free';
      case 'ru':
        return 'Уберите рекламу в Aphidex';
      default:
        return 'Quita los anuncios de Aphidex';
    }
  }

  String interstitialPitchMessage(String? price) {
    switch (languageCode) {
      case 'en':
        if (price == null || price.isEmpty) {
          return 'You already reviewed several creature sheets. You can remove ads permanently to keep browsing without interruptions, or continue with the occasional interstitial.';
        }
        return 'You already reviewed several creature sheets. Remove ads permanently for $price to keep browsing without interruptions, or continue with the occasional interstitial.';
      case 'ru':
        if (price == null || price.isEmpty) {
          return 'Вы уже просмотрели несколько карточек существ. Можно отключить рекламу навсегда и продолжить без лишних прерываний, либо оставить редкие полноэкранные объявления.';
        }
        return 'Вы уже просмотрели несколько карточек существ. Отключите рекламу навсегда за $price и продолжайте без лишних прерываний, либо оставьте редкие полноэкранные объявления.';
      default:
        if (price == null || price.isEmpty) {
          return 'Ya revisaste varias fichas de insectos. Puedes quitar los anuncios para siempre y seguir navegando sin interrupciones, o continuar con un intersticial ocasional.';
        }
        return 'Ya revisaste varias fichas de insectos. Puedes quitar los anuncios para siempre por $price y seguir navegando sin interrupciones, o continuar con un intersticial ocasional.';
    }
  }

  String get interstitialPitchKeepAdsAction {
    switch (languageCode) {
      case 'en':
        return 'Keep ads';
      case 'ru':
        return 'Оставить рекламу';
      default:
        return 'Seguir con anuncios';
    }
  }

  String get adLabel {
    switch (languageCode) {
      case 'en':
        return 'Ad';
      case 'ru':
        return '\u0420\u0435\u043A\u043B\u0430\u043C\u0430';
      default:
        return 'Anuncio';
    }
  }

  String get scannerTitle {
    switch (languageCode) {
      case 'en':
        return 'Creature Scanner';
      case 'ru':
        return '\u0421\u043A\u0430\u043D\u0435\u0440 \u0441\u0443\u0449\u0435\u0441\u0442\u0432';
      default:
        return 'Esc\u00E1ner de criaturas';
    }
  }

  String get scannerTakePhotoAction {
    switch (languageCode) {
      case 'en':
        return 'Take photo';
      case 'ru':
        return '\u0421\u0434\u0435\u043B\u0430\u0442\u044C \u0444\u043E\u0442\u043E';
      default:
        return 'Tomar foto';
    }
  }

  String get scannerPickImageAction {
    switch (languageCode) {
      case 'en':
        return 'Choose image';
      case 'ru':
        return '\u0412\u044B\u0431\u0440\u0430\u0442\u044C \u0438\u0437\u043E\u0431\u0440\u0430\u0436\u0435\u043D\u0438\u0435';
      default:
        return 'Elegir imagen';
    }
  }

  String get scannerNeedsInternet {
    switch (languageCode) {
      case 'en':
        return 'This feature works on-device and does not need internet.';
      case 'ru':
        return '\u042D\u0442\u0430 \u0444\u0443\u043D\u043A\u0446\u0438\u044F \u0440\u0430\u0431\u043E\u0442\u0430\u0435\u0442 \u043D\u0430 \u0443\u0441\u0442\u0440\u043E\u0439\u0441\u0442\u0432\u0435 \u0438 \u043D\u0435 \u0442\u0440\u0435\u0431\u0443\u0435\u0442 \u0438\u043D\u0442\u0435\u0440\u043D\u0435\u0442\u0430.';
      default:
        return 'Esta funci\u00F3n trabaja en el dispositivo y no necesita internet.';
    }
  }

  String get scannerPermissionDeniedMessage {
    switch (languageCode) {
      case 'en':
        return 'Camera or photo access was denied. Enable it in system settings to use Scanner Beta.';
      case 'ru':
        return 'Доступ к камере или фото запрещен. Разрешите его в настройках системы, чтобы использовать Scanner Beta.';
      default:
        return 'No hay acceso a la c\u00E1mara o galer\u00EDa. Act\u00EDvalo en la configuraci\u00F3n del sistema para usar Scanner Beta.';
    }
  }

  String creatureCardProgressLabel(CreatureCardProgress progress) {
    return switch (progress) {
      CreatureCardProgress.unowned => _t('creatureCardProgressUnowned'),
      CreatureCardProgress.obtained => _t('creatureCardProgressObtained'),
      CreatureCardProgress.gold => _t('creatureCardProgressGold'),
    };
  }

  String creatureCardProgressSemantics(String current, String next) {
    return creatureCardProgressActionTemplate
        .replaceAll('{label}', creatureCardProgressA11yLabel)
        .replaceAll('{current}', current)
        .replaceAll('{next}', next);
  }

  String get scannerAnalyzing {
    switch (languageCode) {
      case 'en':
        return 'Analyzing creature…';
      case 'ru':
        return '\u0410\u043D\u0430\u043B\u0438\u0437\u0438\u0440\u0443\u0435\u043C \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u043E…';
      default:
        return 'Analizando criatura…';
    }
  }

  String get scannerPossibleCreaturesTitle {
    switch (languageCode) {
      case 'en':
        return 'Possible creatures';
      case 'ru':
        return '\u0412\u043E\u0437\u043C\u043E\u0436\u043D\u044B\u0435 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0430';
      default:
        return 'Posibles criaturas';
    }
  }

  String get scannerDetectedLabelsTitle {
    switch (languageCode) {
      case 'en':
        return 'Detected labels';
      case 'ru':
        return 'Обнаруженные метки';
      default:
        return 'Etiquetas detectadas';
    }
  }

  String get scannerDetectedWebTitle {
    switch (languageCode) {
      case 'en':
        return 'Detected web entities';
      case 'ru':
        return 'Обнаруженные веб-сущности';
      default:
        return 'Entidades web detectadas';
    }
  }

  String get scannerNoDetectedLabels {
    switch (languageCode) {
      case 'en':
        return 'No labels returned.';
      case 'ru':
        return 'Метки не были получены.';
      default:
        return 'No se devolvieron etiquetas.';
    }
  }

  String get openAction {
    switch (languageCode) {
      case 'en':
        return 'Open';
      case 'ru':
        return '\u041E\u0442\u043A\u0440\u044B\u0442\u044C';
      default:
        return 'Abrir';
    }
  }

  String get scannerNoMatchMessage {
    switch (languageCode) {
      case 'en':
        return 'I could not identify this creature. Try again with a clearer image.';
      case 'ru':
        return '\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u043E\u043F\u043E\u0437\u043D\u0430\u0442\u044C \u044D\u0442\u043E \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u043E. \u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439 \u0431\u043E\u043B\u0435\u0435 \u0447\u0451\u0442\u043A\u043E\u0435 \u0438\u0437\u043E\u0431\u0440\u0430\u0436\u0435\u043D\u0438\u0435.';
      default:
        return 'No pude identificar esta criatura. Intenta con una imagen m\u00E1s clara.';
    }
  }

  String get scannerSetupRequiredMessage {
    switch (languageCode) {
      case 'en':
        return 'Creature Scanner is not configured yet.';
      case 'ru':
        return '\u0421\u043A\u0430\u043D\u0435\u0440 \u0441\u0443\u0449\u0435\u0441\u0442\u0432 \u0435\u0449\u0451 \u043D\u0435 \u043D\u0430\u0441\u0442\u0440\u043E\u0435\u043D.';
      default:
        return 'Creature Scanner todav\u00EDa no est\u00E1 configurado.';
    }
  }

  String get scannerTimeoutMessage {
    switch (languageCode) {
      case 'en':
        return 'The scan took too long. Try again in a moment.';
      case 'ru':
        return '\u0421\u043A\u0430\u043D\u0438\u0440\u043E\u0432\u0430\u043D\u0438\u0435 \u0437\u0430\u043D\u044F\u043B\u043E \u0441\u043B\u0438\u0448\u043A\u043E\u043C \u043C\u043D\u043E\u0433\u043E \u0432\u0440\u0435\u043C\u0435\u043D\u0438. \u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439 \u0435\u0449\u0451 \u0440\u0430\u0437.';
      default:
        return 'El escaneo tard\u00F3 demasiado. Int\u00E9ntalo de nuevo en un momento.';
    }
  }

  String get scannerImageTooLargeMessage {
    switch (languageCode) {
      case 'en':
        return 'That image is still too large. Try a simpler capture.';
      case 'ru':
        return '\u042D\u0442\u043E \u0438\u0437\u043E\u0431\u0440\u0430\u0436\u0435\u043D\u0438\u0435 \u0432\u0441\u0451 \u0435\u0449\u0451 \u0441\u043B\u0438\u0448\u043A\u043E\u043C \u0431\u043E\u043B\u044C\u0448\u043E\u0435. \u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439 \u0431\u043E\u043B\u0435\u0435 \u043F\u0440\u043E\u0441\u0442\u043E\u0439 \u043A\u0430\u0434\u0440.';
      default:
        return 'Esa imagen sigue siendo demasiado grande. Intenta con una captura m\u00E1s simple.';
    }
  }

  String get scannerNetworkErrorMessage {
    switch (languageCode) {
      case 'en':
        return 'I could not reach the scanner service. Check your internet and try again.';
      case 'ru':
        return '\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u0441\u0432\u044F\u0437\u0430\u0442\u044C\u0441\u044F \u0441 \u0441\u0435\u0440\u0432\u0438\u0441\u043E\u043C \u0441\u043A\u0430\u043D\u0435\u0440\u0430. \u041F\u0440\u043E\u0432\u0435\u0440\u044C \u0438\u043D\u0442\u0435\u0440\u043D\u0435\u0442 \u0438 \u043F\u043E\u043F\u0440\u043E\u0431\u0443\u0439 \u0441\u043D\u043E\u0432\u0430.';
      default:
        return 'No pude conectar con el servicio del scanner. Revisa tu internet e int\u00E9ntalo de nuevo.';
    }
  }

  String get scannerServerBusyMessage {
    switch (languageCode) {
      case 'en':
        return 'The scanner service is busy. Try again in a moment.';
      case 'ru':
        return '\u0421\u0435\u0440\u0432\u0438\u0441 \u0441\u043A\u0430\u043D\u0435\u0440\u0430 \u043F\u0435\u0440\u0435\u0433\u0440\u0443\u0436\u0435\u043D. \u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439 \u0441\u043A\u043E\u0440\u043E \u0441\u043D\u043E\u0432\u0430.';
      default:
        return 'El servidor del scanner est\u00E1 ocupado. Int\u00E9ntalo de nuevo en un momento.';
    }
  }

  String get scannerAnalysisTemporaryMessage {
    switch (languageCode) {
      case 'en':
        return 'The smart analysis failed temporarily. No token was charged.';
      case 'ru':
        return '\u0423\u043C\u043D\u044B\u0439 \u0430\u043D\u0430\u043B\u0438\u0437 \u0432\u0440\u0435\u043C\u0435\u043D\u043D\u043E \u043D\u0435 \u0441\u0440\u0430\u0431\u043E\u0442\u0430\u043B. \u0422\u043E\u043A\u0435\u043D \u043D\u0435 \u0441\u043F\u0438\u0441\u0430\u043D.';
      default:
        return 'El an\u00E1lisis inteligente fall\u00F3 temporalmente. No se descont\u00F3 ning\u00FAn token.';
    }
  }

  String scannerRequestIdMessage(String requestId) {
    switch (languageCode) {
      case 'en':
        return 'Diagnostic ID: $requestId';
      case 'ru':
        return '\u0414\u0438\u0430\u0433\u043D\u043E\u0441\u0442\u0438\u0447\u0435\u0441\u043A\u0438\u0439 ID: $requestId';
      default:
        return 'ID de diagn\u00F3stico: $requestId';
    }
  }

  String get scannerRemoteTitle {
    switch (languageCode) {
      case 'en':
        return 'Smart Scanner Beta';
      case 'ru':
        return '\u0423\u043C\u043D\u044B\u0439 \u0441\u043A\u0430\u043D\u0435\u0440 beta';
      default:
        return 'Esc\u00E1ner inteligente beta';
    }
  }

  String get scannerRemoteAnalyzeAction {
    switch (languageCode) {
      case 'en':
        return 'Smart beta analysis';
      case 'ru':
        return '\u0423\u043C\u043D\u044B\u0439 \u0430\u043D\u0430\u043B\u0438\u0437 beta';
      default:
        return 'An\u00E1lisis inteligente beta';
    }
  }

  String get scannerRemotePrivacyNotice {
    switch (languageCode) {
      case 'en':
        return 'Smart analysis sends the image to a ByteShark server to identify possible creatures.';
      case 'ru':
        return '\u0423\u043C\u043D\u044B\u0439 \u0430\u043D\u0430\u043B\u0438\u0437 \u043E\u0442\u043F\u0440\u0430\u0432\u043B\u044F\u0435\u0442 \u0438\u0437\u043E\u0431\u0440\u0430\u0436\u0435\u043D\u0438\u0435 \u043D\u0430 \u0441\u0435\u0440\u0432\u0435\u0440 ByteShark \u0434\u043B\u044F \u043F\u043E\u0438\u0441\u043A\u0430 \u0432\u043E\u0437\u043C\u043E\u0436\u043D\u044B\u0445 \u0441\u0443\u0449\u0435\u0441\u0442\u0432.';
      default:
        return 'El an\u00E1lisis inteligente env\u00EDa la imagen a un servidor de ByteShark para identificar posibles criaturas.';
    }
  }

  String get scannerRemoteBetaNotice {
    switch (languageCode) {
      case 'en':
        return 'Beta: it can be wrong.';
      case 'ru':
        return 'Beta: \u043C\u043E\u0436\u0435\u0442 \u043E\u0448\u0438\u0431\u0430\u0442\u044C\u0441\u044F.';
      default:
        return 'Beta: puede equivocarse.';
    }
  }

  String get scannerApproximateResult {
    switch (languageCode) {
      case 'en':
        return 'Approximate result';
      case 'ru':
        return '\u041F\u0440\u0438\u0431\u043B\u0438\u0437\u0438\u0442\u0435\u043B\u044C\u043D\u044B\u0439 \u0440\u0435\u0437\u0443\u043B\u044C\u0442\u0430\u0442';
      default:
        return 'Resultado aproximado';
    }
  }

  String get scannerMultipleCreaturesMessage {
    switch (languageCode) {
      case 'en':
        return 'The image may contain multiple creatures. Choose the correct match.';
      case 'ru':
        return '\u041D\u0430 \u0438\u0437\u043E\u0431\u0440\u0430\u0436\u0435\u043D\u0438\u0438 \u043C\u043E\u0436\u0435\u0442 \u0431\u044B\u0442\u044C \u043D\u0435\u0441\u043A\u043E\u043B\u044C\u043A\u043E \u0441\u0443\u0449\u0435\u0441\u0442\u0432. \u0412\u044B\u0431\u0435\u0440\u0438 \u043F\u0440\u0430\u0432\u0438\u043B\u044C\u043D\u043E\u0435 \u0441\u043E\u0432\u043F\u0430\u0434\u0435\u043D\u0438\u0435.';
      default:
        return 'La imagen puede contener varias criaturas. Elige la coincidencia correcta.';
    }
  }

  String get scannerAvailableInBothGames {
    switch (languageCode) {
      case 'en':
        return 'Available in G1/G2';
      case 'ru':
        return '\u0414\u043E\u0441\u0442\u0443\u043F\u043D\u043E \u0432 G1/G2';
      default:
        return 'Disponible en G1/G2';
    }
  }

  String scannerTokensRemaining(int tokens, int dailyLimit, int usedToday) {
    switch (languageCode) {
      case 'en':
        return 'Tokens: $tokens remaining. Daily: $usedToday/$dailyLimit.';
      case 'ru':
        return '\u0422\u043E\u043A\u0435\u043D\u044B: $tokens \u043E\u0441\u0442\u0430\u043B\u043E\u0441\u044C. \u0414\u0435\u043D\u044C: $usedToday/$dailyLimit.';
      default:
        return 'Tokens: $tokens restantes. Diario: $usedToday/$dailyLimit.';
    }
  }

  String get scannerNoTokensMessage {
    switch (languageCode) {
      case 'en':
        return 'No scanner tokens remaining.';
      case 'ru':
        return '\u0422\u043E\u043A\u0435\u043D\u044B \u0441\u043A\u0430\u043D\u0435\u0440\u0430 \u0437\u0430\u043A\u043E\u043D\u0447\u0438\u043B\u0438\u0441\u044C.';
      default:
        return 'No quedan tokens del scanner.';
    }
  }

  String get scannerDailyLimitReachedMessage {
    switch (languageCode) {
      case 'en':
        return 'Daily scanner limit reached. Try again tomorrow.';
      case 'ru':
        return '\u0414\u043D\u0435\u0432\u043D\u043E\u0439 \u043B\u0438\u043C\u0438\u0442 \u0441\u043A\u0430\u043D\u0435\u0440\u0430 \u0438\u0441\u0447\u0435\u0440\u043F\u0430\u043D. \u041F\u043E\u043F\u0440\u043E\u0431\u0443\u0439 \u0437\u0430\u0432\u0442\u0440\u0430.';
      default:
        return 'L\u00EDmite diario del scanner alcanzado. Int\u00E9ntalo ma\u00F1ana.';
    }
  }

  String get scannerManualSearchAction {
    switch (languageCode) {
      case 'en':
        return 'Search manually';
      case 'ru':
        return '\u0418\u0441\u043A\u0430\u0442\u044C \u0432\u0440\u0443\u0447\u043D\u0443\u044E';
      default:
        return 'Buscar manualmente';
    }
  }

  String get scannerTryAnotherImageAction {
    switch (languageCode) {
      case 'en':
        return 'Try another image';
      case 'ru':
        return '\u0414\u0440\u0443\u0433\u043E\u0435 \u0438\u0437\u043E\u0431\u0440\u0430\u0436\u0435\u043D\u0438\u0435';
      default:
        return 'Intentar otra imagen';
    }
  }

  String get scannerRetryAction {
    switch (languageCode) {
      case 'en':
        return 'Try again';
      case 'ru':
        return '\u041F\u043E\u043F\u0440\u043E\u0431\u043E\u0432\u0430\u0442\u044C \u0441\u043D\u043E\u0432\u0430';
      default:
        return 'Intentar otra vez';
    }
  }

  String get scannerGenericErrorMessage {
    switch (languageCode) {
      case 'en':
        return 'Something went wrong while analyzing the creature.';
      case 'ru':
        return '\u041F\u0440\u0438 \u0430\u043D\u0430\u043B\u0438\u0437\u0435 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0430 \u0447\u0442\u043E-\u0442\u043E \u043F\u043E\u0448\u043B\u043E \u043D\u0435 \u0442\u0430\u043A.';
      default:
        return 'Algo sali\u00F3 mal al analizar la criatura.';
    }
  }

  String get scannerChooseGameTitle {
    switch (languageCode) {
      case 'en':
        return 'Which version should I open?';
      case 'ru':
        return '\u041A\u0430\u043A\u0443\u044E \u0432\u0435\u0440\u0441\u0438\u044E \u043E\u0442\u043A\u0440\u044B\u0442\u044C?';
      default:
        return '\u00BFQu\u00E9 versi\u00F3n debo abrir?';
    }
  }

  String get scannerComingSoonTitle {
    switch (languageCode) {
      case 'en':
        return 'Available soon';
      case 'ru':
        return 'Скоро будет доступно';
      default:
        return 'Disponible próximamente';
    }
  }

  String get scannerComingSoonMessage {
    switch (languageCode) {
      case 'en':
        return 'Creature Scanner is being refined and will return in a future update.';
      case 'ru':
        return 'Сканер существ дорабатывается и вернётся в одном из следующих обновлений.';
      default:
        return 'Creature Scanner se está ajustando y volverá en una próxima actualización.';
    }
  }

  String scannerChooseGameMessage(String name) {
    switch (languageCode) {
      case 'en':
        return '$name exists in both games. Do you want Grounded 1 or Grounded 2?';
      case 'ru':
        return '$name \u0435\u0441\u0442\u044C \u0432 \u043E\u0431\u0435\u0438\u0445 \u0438\u0433\u0440\u0430\u0445. \u041E\u0442\u043A\u0440\u044B\u0442\u044C Grounded 1 \u0438\u043B\u0438 Grounded 2?';
      default:
        return '$name existe en ambos juegos. \u00BFQuieres abrir Grounded 1 o Grounded 2?';
    }
  }

  String get tutorialSkipAction => _t('tutorialSkipAction');
  String get tutorialNextAction => _t('tutorialNextAction');
  String get tutorialBackAction => _t('tutorialBackAction');
  String get tutorialFinishAction => _t('tutorialFinishAction');
  String get tutorialRestartTitle => _t('tutorialRestartTitle');
  String get tutorialRestartSubtitle => _t('tutorialRestartSubtitle');
  String get tutorialPromptTitle => _t('tutorialPromptTitle');
  String get tutorialPromptBody => _t('tutorialPromptBody');
  String get tutorialPromptStartAction => _t('tutorialPromptStartAction');
  String get tutorialPromptSkipAction => _t('tutorialPromptSkipAction');
  String get bossPhasesTitle {
    final value = switch (languageCode) {
      'en' => 'Boss Phases',
      'ru' => '\u0424\u0430\u0437\u044B \u0431\u043E\u0441\u0441\u0430',
      _ => 'Fases del jefe',
    };
    return _normalizeText(value);
  }

  String get phaseTriggerLabel {
    final value = switch (languageCode) {
      'en' => 'Trigger',
      'ru' => '\u0422\u0440\u0438\u0433\u0433\u0435\u0440',
      _ => 'Activaci\u00F3n',
    };
    return _normalizeText(value);
  }

  String get phaseSummaryLabel {
    final value = switch (languageCode) {
      'en' => 'Summary',
      'ru' => '\u041A\u0440\u0430\u0442\u043A\u043E',
      _ => 'Resumen',
    };
    return _normalizeText(value);
  }

  String get phaseAggressionLabel {
    final value = switch (languageCode) {
      'en' => 'Aggression',
      'ru' => '\u0410\u0433\u0440\u0435\u0441\u0441\u0438\u044F',
      _ => 'Agresividad',
    };
    return _normalizeText(value);
  }

  String get phaseStartsAtLabel {
    final value = switch (languageCode) {
      'en' => 'Starts At',
      'ru' =>
        '\u041D\u0430\u0447\u0438\u043D\u0430\u0435\u0442\u0441\u044F \u043F\u0440\u0438',
      _ => 'Empieza en',
    };
    return _normalizeText(value);
  }

  String get newPatternsTitle {
    final value = switch (languageCode) {
      'en' => 'New Patterns',
      'ru' =>
        '\u041D\u043E\u0432\u044B\u0435 \u043F\u0430\u0442\u0442\u0435\u0440\u043D\u044B',
      _ => 'Nuevos patrones',
    };
    return _normalizeText(value);
  }

  String get descriptionTitle {
    switch (languageCode) {
      case 'en':
        return 'Description';
      case 'ru':
        return '\u041e\u043f\u0438\u0441\u0430\u043d\u0438\u0435';
      default:
        return 'Descripci\u00f3n';
    }
  }

  String get environmentRespawnTitle {
    switch (languageCode) {
      case 'en':
        return 'Environment / Respawn';
      case 'ru':
        return '\u0421\u0440\u0435\u0434\u0430 / \u0420\u0435\u0441\u043f\u0430\u0432\u043d';
      default:
        return 'Entorno / Reaparici\u00f3n';
    }
  }

  String get environmentsTitle {
    switch (languageCode) {
      case 'en':
        return 'Environments';
      case 'ru':
        return '\u0411\u0438\u043e\u043c\u044b';
      default:
        return 'Entornos';
    }
  }

  String get respawnTitle {
    switch (languageCode) {
      case 'en':
        return 'Respawn';
      case 'ru':
        return '\u0420\u0435\u0441\u043f\u0430\u0432\u043d';
      default:
        return 'Reaparici\u00f3n';
    }
  }

  String get statsTitle {
    switch (languageCode) {
      case 'en':
        return 'Stats';
      case 'ru':
        return '\u0425\u0430\u0440\u0430\u043a\u0442\u0435\u0440\u0438\u0441\u0442\u0438\u043a\u0438';
      default:
        return 'Estad\u00edsticas';
    }
  }

  String get stunThresholdLabel {
    switch (languageCode) {
      case 'en':
        return 'Stun Threshold';
      case 'ru':
        return '\u041f\u043e\u0440\u043e\u0433 \u043e\u0433\u043b\u0443\u0448\u0435\u043d\u0438\u044f';
      default:
        return 'Umbral de aturdimiento';
    }
  }

  String get stunCooldownLabel {
    switch (languageCode) {
      case 'en':
        return 'Stun Cooldown';
      case 'ru':
        return '\u041e\u0442\u043a\u0430\u0442 \u043e\u0433\u043b\u0443\u0448\u0435\u043d\u0438\u044f';
      default:
        return 'Recuperaci\u00f3n del aturdimiento';
    }
  }

  String get secondsShortLabel {
    switch (languageCode) {
      case 'ru':
        return '\u0441';
      default:
        return 's';
    }
  }

  String get attackDamageLabel {
    switch (languageCode) {
      case 'en':
        return 'Attack Damage';
      case 'ru':
        return '\u0423\u0440\u043e\u043d \u0430\u0442\u0430\u043a';
      default:
        return 'Da\u00f1o de ataque';
    }
  }

  String get lootTitle {
    switch (languageCode) {
      case 'ru':
        return '\u0414\u043e\u0431\u044b\u0447\u0430';
      default:
        return 'Loot';
    }
  }

  String get rewardsUnlocksTitle {
    switch (languageCode) {
      case 'en':
        return 'Rewards and unlocks';
      case 'ru':
        return '\u041d\u0430\u0433\u0440\u0430\u0434\u044b \u0438 \u0440\u0430\u0437\u0431\u043b\u043e\u043a\u0438\u0440\u043e\u0432\u043a\u0438';
      default:
        return 'Recompensas y desbloqueos';
    }
  }

  String get advancedLootTitle {
    switch (languageCode) {
      case 'en':
        return 'Advanced Loot Table';
      case 'ru':
        return '\u041f\u043e\u0434\u0440\u043e\u0431\u043d\u0430\u044f \u0442\u0430\u0431\u043b\u0438\u0446\u0430 \u0434\u043e\u0431\u044b\u0447\u0438';
      default:
        return 'Tabla avanzada de loot';
    }
  }

  String lootSectionLabel(String id) {
    switch (id) {
      case 'rare':
        switch (languageCode) {
          case 'en':
            return 'Rare Drop';
          case 'ru':
            return '\u0420\u0435\u0434\u043a\u0430\u044f \u0434\u043e\u0431\u044b\u0447\u0430';
          default:
            return 'Drop raro';
        }
      case 'ng_plus':
        switch (languageCode) {
          case 'en':
            return 'NG+ Drops';
          case 'ru':
            return '\u0414\u043e\u0431\u044b\u0447\u0430 NG+';
          default:
            return 'Drops de NG+';
        }
      case 'passive':
        switch (languageCode) {
          case 'en':
            return 'Passive Drop';
          case 'ru':
            return '\u041f\u0430\u0441\u0441\u0438\u0432\u043d\u0430\u044f \u0434\u043e\u0431\u044b\u0447\u0430';
          default:
            return 'Drop pasivo';
        }
      default:
        switch (languageCode) {
          case 'ru':
            return '\u041e\u0431\u044b\u0447\u043d\u0430\u044f \u0434\u043e\u0431\u044b\u0447\u0430';
          default:
            return 'Loot';
        }
    }
  }

  String get inflictsTraitsTitle {
    switch (languageCode) {
      case 'en':
        return 'Inflicts / Special Traits';
      case 'ru':
        return '\u041d\u0430\u043d\u043e\u0441\u0438\u0442 / \u041e\u0441\u043e\u0431\u044b\u0435 \u0441\u0432\u043e\u0439\u0441\u0442\u0432\u0430';
      default:
        return 'Inflige / Rasgos especiales';
    }
  }

  String get abilitiesTitle {
    switch (languageCode) {
      case 'en':
        return 'Abilities';
      case 'ru':
        return '\u0421\u043f\u043e\u0441\u043e\u0431\u043d\u043e\u0441\u0442\u0438';
      default:
        return 'Habilidades';
    }
  }

  String get blockableLabel {
    switch (languageCode) {
      case 'en':
        return 'Blockable';
      case 'ru':
        return '\u0411\u043b\u043e\u043a\u0438\u0440\u0443\u0435\u0442\u0441\u044f';
      default:
        return 'Bloqueable';
    }
  }

  String get breaksGuardLabel {
    switch (languageCode) {
      case 'en':
        return 'Breaks Guard';
      case 'ru':
        return '\u041b\u043e\u043c\u0430\u0435\u0442 \u0431\u043b\u043e\u043a';
      default:
        return 'Rompe guardia';
    }
  }

  String get staggersLabel {
    switch (languageCode) {
      case 'en':
        return 'Staggers';
      case 'ru':
        return '\u0428\u0430\u0442\u0430\u0435\u0442';
      default:
        return 'Hace tambalear';
    }
  }

  String boolLabel(bool? value) {
    if (value == null) {
      switch (languageCode) {
        case 'en':
          return 'N/A';
        case 'ru':
          return '\u041d/\u0434';
        default:
          return 'N/D';
      }
    }
    if (value) {
      switch (languageCode) {
        case 'en':
          return 'Yes';
        case 'ru':
          return '\u0414\u0430';
        default:
          return 'S\u00ed';
      }
    }
    switch (languageCode) {
      case 'en':
        return 'No';
      case 'ru':
        return '\u041d\u0435\u0442';
      default:
        return 'No';
    }
  }

  String get behaviorTitle {
    switch (languageCode) {
      case 'en':
        return 'Behavior';
      case 'ru':
        return '\u041f\u043e\u0432\u0435\u0434\u0435\u043d\u0438\u0435';
      default:
        return 'Comportamiento';
    }
  }

  String get interactionWithPlayerTitle {
    switch (languageCode) {
      case 'en':
        return 'Interaction With Player';
      case 'ru':
        return '\u0412\u0437\u0430\u0438\u043c\u043e\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435 \u0441 \u0438\u0433\u0440\u043e\u043a\u043e\u043c';
      default:
        return 'Interacci\u00f3n con el jugador';
    }
  }

  String get interactionWithCreaturesTitle {
    switch (languageCode) {
      case 'en':
        return 'Interaction With Creatures';
      case 'ru':
        return '\u0412\u0437\u0430\u0438\u043c\u043e\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435 \u0441 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u0430\u043c\u0438';
      default:
        return 'Interacci\u00f3n con criaturas';
    }
  }

  String get strategyTitle {
    switch (languageCode) {
      case 'en':
        return 'Strategy';
      case 'ru':
        return '\u0421\u0442\u0440\u0430\u0442\u0435\u0433\u0438\u044f';
      default:
        return 'Estrategia';
    }
  }

  String autoLanguageDescription(String languageName) =>
      _t('autoLanguageDescription').replaceFirst('{language}', languageName);

  String tutorialStepTitle(String id) => _t('tutorial_${id}_title');

  String tutorialStepBody(String id) {
    if (id == 'search') {
      switch (languageCode) {
        case 'en':
          return 'Use this bar to find any creature by name. Creature Scanner is being refined and will return in a future update.';
        case 'ru':
          return '\u0418\u0441\u043F\u043E\u043B\u044C\u0437\u0443\u0439 \u044D\u0442\u0443 \u0441\u0442\u0440\u043E\u043A\u0443, \u0447\u0442\u043E\u0431\u044B \u043D\u0430\u0439\u0442\u0438 \u043B\u044E\u0431\u043E\u0435 \u0441\u0443\u0449\u0435\u0441\u0442\u0432\u043E \u043F\u043E \u0438\u043C\u0435\u043D\u0438. Creature Scanner \u0441\u0435\u0439\u0447\u0430\u0441 \u0434\u043E\u0440\u0430\u0431\u0430\u0442\u044B\u0432\u0430\u0435\u0442\u0441\u044F \u0438 \u0432\u0435\u0440\u043D\u0451\u0442\u0441\u044F \u0432 \u043E\u0434\u043D\u043E\u043C \u0438\u0437 \u0441\u043B\u0435\u0434\u0443\u044E\u0449\u0438\u0445 \u043E\u0431\u043D\u043E\u0432\u043B\u0435\u043D\u0438\u0439.';
        default:
          return 'Usa esta barra para encontrar cualquier criatura por nombre. Creature Scanner se está ajustando y volverá en una próxima actualización.';
      }
    }
    if (id == 'settings') {
      switch (languageCode) {
        case 'en':
          return 'In settings you can change the theme, language, reset data, restart this tutorial, and disable ads if you prefer an ad-free experience. Aphidex includes ads to support development.';
        case 'ru':
          return '\u0412 \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0430\u0445 \u043C\u043E\u0436\u043D\u043E \u043F\u043E\u043C\u0435\u043D\u044F\u0442\u044C \u0442\u0435\u043C\u0443, \u044F\u0437\u044B\u043A, \u0441\u0431\u0440\u043E\u0441\u0438\u0442\u044C \u0434\u0430\u043D\u043D\u044B\u0435, \u0437\u0430\u043D\u043E\u0432\u043E \u0437\u0430\u043F\u0443\u0441\u0442\u0438\u0442\u044C \u043E\u0431\u0443\u0447\u0435\u043D\u0438\u0435 \u0438 \u043E\u0442\u043A\u043B\u044E\u0447\u0438\u0442\u044C \u0440\u0435\u043A\u043B\u0430\u043C\u0443, \u0435\u0441\u043B\u0438 \u0445\u043E\u0447\u0435\u0448\u044C \u0438\u0441\u043F\u043E\u043B\u044C\u0437\u043E\u0432\u0430\u0442\u044C Aphidex \u0431\u0435\u0437 \u043D\u0435\u0451. \u0420\u0435\u043A\u043B\u0430\u043C\u0430 \u0432 \u043F\u0440\u0438\u043B\u043E\u0436\u0435\u043D\u0438\u0438 \u043F\u043E\u043C\u043E\u0433\u0430\u0435\u0442 \u043F\u043E\u0434\u0434\u0435\u0440\u0436\u0438\u0432\u0430\u0442\u044C \u0435\u0433\u043E \u0440\u0430\u0437\u0432\u0438\u0442\u0438\u0435.';
        default:
          return 'En configuraci\u00F3n puedes cambiar tema, idioma, reiniciar datos, volver a abrir este tutorial y quitar los anuncios si prefieres usar Aphidex sin publicidad. Aphidex cuenta con anuncios para apoyar su desarrollo.';
      }
    }
    return _t('tutorial_${id}_body');
  }

  String languageNameForCode(String code) {
    switch (code) {
      case 'en':
        return englishLanguage;
      case 'ru':
        return russianLanguage;
      default:
        return spanishLanguage;
    }
  }

  String temperamentLabel(String id) {
    switch (id) {
      case 'neutral':
        return groupNeutrals;
      case 'buggy':
        return groupBuggies;
      case 'aggressive':
        return groupAggressive;
      case 'peaceful':
        return groupPeaceful;
      case 'anomaly':
        return groupAnomalies;
      default:
        return groupOthers;
    }
  }

  String weakPointPartLabel(String id) {
    switch (id) {
      case 'back':
        return _t('weakPointBack');
      case 'eyes':
        return _t('weakPointEyes');
      case 'gut':
        return _t('weakPointGut');
      case 'legs':
        return _t('weakPointLegs');
      case 'rump':
        return _t('weakPointRump');
      default:
        return id;
    }
  }

  String susceptibleDamageLabel(String id) {
    switch (id) {
      case 'any':
        return _t('damageAny');
      case 'chopping and slashing':
        return _t('damageChoppingAndSlashing');
      case 'stabbing_arrows_only':
      case 'stabbing_arrrows':
      case 'projectile_piercing':
        return _t('damageStabbingArrowsOnly');
      case 'stabbing_bows_and_spears':
        return _t('damageStabbingBowsAndSpears');
      case 'stabbing':
        return _t('damageStabbing');
      case 'slashing':
        return _t('damageSlashing');
      case 'chopping':
        return _t('damageChopping');
      case 'busting':
        return _t('damageBusting');
      default:
        return id;
    }
  }

  String attackTagLabel(String id) {
    switch (id) {
      case 'melee':
        return _t('tagMelee');
      case 'ranged':
        return _t('tagRanged');
      case 'aoe':
        return _t('tagAoe');
      case 'utility':
        return _t('tagUtility');
      default:
        return id;
    }
  }

  String effectCategoryLabel(String id) {
    switch (id) {
      case 'damage':
        return _t('effectCategoryDamage');
      case 'element':
        return _t('effectCategoryElement');
      case 'status':
        return _t('effectCategoryStatus');
      default:
        return id;
    }
  }

  String activeFiltersCountLabel(int count) {
    switch (languageCode) {
      case 'en':
        return '$count active filters';
      case 'ru':
        return '$count активных фильтров';
      default:
        return '$count filtros activos';
    }
  }

  String dangerLevelLabel(String id) {
    final value = switch (id) {
      'baja' =>
        languageCode == 'en'
            ? 'Low'
            : languageCode == 'ru'
            ? '\u041D\u0438\u0437\u043A\u0430\u044F'
            : 'Baja',
      'media' =>
        languageCode == 'en'
            ? 'Medium'
            : languageCode == 'ru'
            ? '\u0421\u0440\u0435\u0434\u043D\u044F\u044F'
            : 'Media',
      'intermedia' =>
        languageCode == 'en'
            ? 'Intermediate'
            : languageCode == 'ru'
            ? '\u041F\u0440\u043E\u043C\u0435\u0436\u0443\u0442\u043E\u0447\u043D\u0430\u044F'
            : 'Intermedia',
      'alta' =>
        languageCode == 'en'
            ? 'High'
            : languageCode == 'ru'
            ? '\u0412\u044B\u0441\u043E\u043A\u0430\u044F'
            : 'Alta',
      'muy_alta' =>
        languageCode == 'en'
            ? 'Very High'
            : languageCode == 'ru'
            ? '\u041E\u0447\u0435\u043D\u044C \u0432\u044B\u0441\u043E\u043A\u0430\u044F'
            : 'Muy alta',
      'imposible' =>
        languageCode == 'en'
            ? 'Impossible'
            : languageCode == 'ru'
            ? '\u041D\u0435\u0432\u043E\u0437\u043C\u043E\u0436\u043D\u0430\u044F'
            : 'Imposible',
      'imposible_superior' =>
        languageCode == 'en'
            ? 'Impossible Superior'
            : languageCode == 'ru'
            ? '\u041D\u0435\u0432\u043E\u0437\u043C\u043E\u0436\u043D\u0430\u044F \u0432\u044B\u0441\u0448\u0430\u044F'
            : 'Imposible Superior',
      'imposible_alt' =>
        languageCode == 'en'
            ? 'Impossible Superior'
            : languageCode == 'ru'
            ? '\u041D\u0435\u0432\u043E\u0437\u043C\u043E\u0436\u043D\u0430\u044F \u0432\u044B\u0441\u0448\u0430\u044F'
            : 'Imposible Superior',
      'imposible_alta' =>
        languageCode == 'en'
            ? 'Impossible Superior'
            : languageCode == 'ru'
            ? '\u041D\u0435\u0432\u043E\u0437\u043C\u043E\u0436\u043D\u0430\u044F \u0432\u044B\u0441\u0448\u0430\u044F'
            : 'Imposible Superior',
      'extrema' =>
        languageCode == 'en'
            ? 'Extreme'
            : languageCode == 'ru'
            ? '\u042D\u043A\u0441\u0442\u0440\u0435\u043C\u0430\u043B\u044C\u043D\u0430\u044F'
            : 'Extrema',
      'proximamente' =>
        languageCode == 'en'
            ? 'Coming Soon'
            : languageCode == 'ru'
            ? '\u0421\u043A\u043E\u0440\u043E'
            : 'Pr\u00F3ximamente',
      _ => id,
    };
    return _normalizeText(value);
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'es': {
      'appTitle': 'Aphidex',
      'settingsTitle': 'Configuración',
      'appearanceTitle': 'Apariencia',
      'languageTitle': 'Idioma',
      'systemTheme': 'Sistema',
      'lightTheme': 'Claro',
      'darkTheme': 'Oscuro',
      'automaticLanguage': 'Automático',
      'useDeviceLanguage': 'Usa el idioma del teléfono',
      'spanishLanguage': 'Español',
      'englishLanguage': 'Inglés',
      'russianLanguage': 'Ruso',
      'creditsTitle': 'Créditos',
      'creditsSubtitle': 'Licencias, donadores y avisos legales',
      'websiteTitle': 'Web de Aphidex',
      'websiteSubtitle': 'Noticias, información y novedades de Aphidex',
      'wipeDataTitle': 'Borrar datos',
      'wipeDataSubtitle': 'Reinicia favoritos, doradas y configuración',
      'openLinkError': 'No se pudo abrir el enlace.',
      'wipeConfirmTitle': 'Borrar datos',
      'wipeConfirmMessage':
          'Esto borrará:\n- Favoritos\n- Tarjetas doradas\n- Configuración (tema, filtros, idioma, etc.)\n\n¿Seguro?',
      'cancelAction': 'Cancelar',
      'deleteAction': 'Borrar',
      'dataWiped': 'Datos borrados',
      'chooseGameTooltip': 'Elegir juego',
      'settingsTooltip': 'Configuración',
      'playerProfileTooltip': 'Perfil de jugador',
      'playerProfileTitle': 'Perfil de jugador',
      'playerProfileSubtitle':
          'Elige un perfil independiente para Grounded y Grounded 2.',
      'playerProfileNoSelection': 'Aún no has elegido un perfil.',
      'playerProfileChooseAction': 'Elegir personaje',
      'playerProfileChangeAction': 'Cambiar personaje',
      'playerProfileClearAction': 'Quitar selección',
      'playerProfileGameSelector': 'Juego del perfil',
      'playerProfileCharacterLabel': 'Personaje del perfil',
      'playerProfileCreatureCards': 'Tarjetas de criatura',
      'playerProfileGoldCards': 'Tarjetas doradas',
      'playerProfileKills': 'Eliminaciones',
      'killCountAdd': 'AÃ±adir eliminaciÃ³n',
      'killCountEdit': 'Editar eliminaciones',
      'killCountReset': 'Reiniciar contador',
      'killCountQuantity': 'Cantidad',
      'saveAction': 'Guardar',
      'filterWithKills': 'Con eliminaciones',
      'filterWithoutKills': 'Sin eliminaciones',
      'tutorialProfileTitle': 'Consulta tu perfil',
      'tutorialProfileBody':
          'Consulta tus personajes, tarjetas y eliminaciones desde tu perfil.',
      'playerProfileSelectTooltip': 'Elegir personaje',
      'playerProfileChangeTooltip': 'Cambiar personaje',
      'playerDisplayNameTitle': 'Nombre del jugador',
      'playerDisplayNameAdd': 'Añadir nombre',
      'playerDisplayNameEdit': 'Editar nombre',
      'playerDisplayNameSave': 'Guardar',
      'playerDisplayNameRemove': 'Eliminar nombre',
      'playerDisplayNameCounter': '{current}/24',
      'playerProfileShare': 'Compartir perfil',
      'playerProfileShareTooltip': 'Compartir perfil',
      'playerProfileShareUnavailable': 'Elige un personaje para compartir.',
      'playerProfileShareText': 'Mi perfil de Aphidex',
      'playerProfileShareError':
          'No se pudo preparar el perfil para compartir.',
      'playerProfileSelected': 'Perfil seleccionado: {name}',
      'playerProfileSelectorTitle': 'Elige tu perfil de {game}',
      'playerProfileSelectorSubtitle':
          'Esta selección solo se aplica a este juego.',
      'sortDefaultOrder': 'Orden del juego',
      'sortByName': 'Nombre',
      'sortByDanger': 'Peligro',
      'sortByTier': 'Tier',
      'descendingOrder': 'Descendente',
      'ascendingOrder': 'Ascendente',
      'searchEnemyHint': 'Buscar enemigo...',
      'loadingCreaturesTitle': 'Cargando criaturas',
      'loadingCreaturesSubtitle':
          'Preparando el índice y los datos locales de Aphidex.',
      'loadingCreatureDetailSubtitle':
          'Cargando la ficha completa de esta entrada.',
      'dataUnavailableTitle': 'Datos no disponibles',
      'dataUnavailableSubtitle': 'Aphidex no pudo cargar esta información.',
      'retryAction': 'Reintentar',
      'filterAll': 'Todos',
      'filtersTitle': 'Filtros',
      'clearFiltersAction': 'Limpiar filtros',
      'clearSearchAction': 'Limpiar búsqueda',
      'favoritesFilterLabel': 'Favoritos',
      'filterTiers': 'Tiers',
      'filterClass': 'Clase',
      'filterDanger': 'Peligro',
      'filterBoss': 'Jefe',
      'tierTitle': 'Tier',
      'groupNeutrals': 'Neutrales',
      'groupAggressive': 'Agresivos',
      'groupPeaceful': 'Pacíficos',
      'groupAnomalies': 'Anomalías Dimensionales',
      'groupOthers': 'Otros',
      'selectEditionTitle': 'Seleccionar edición',
      'bothGames': 'Ambos',
      'groundedOne': 'Grounded',
      'groundedTwo': 'Grounded 2',
      'errorLoadingJson': 'Error cargando JSON:',
      'goldDefault': 'Dorada (predeterminada)',
      'goldUnlocked': 'Tarjeta dorada',
      'goldFilterLabel': 'Doradas',
      'goldMark': 'Marcar dorada',
      'elementalWeakness': 'Debilidad elemental',
      'damageWeakness': 'Debilidad (tipo de daño)',
      'resistancesTitle': 'Resistencias',
      'weakPointTitle': 'Punto débil',
      'attacksTitle': 'Ataques',
      'weaknessesTitle': 'Debilidades',
      'upcomingTitle': 'Próximamente:',
      'underConstructionLabel': 'En construcción',
      'upcomingItems':
          '• Loot con probabilidades\n• Spawns\n• Builds por etapa (early/mid/end/NG+)',
      'healthTitle': 'Vida',
      'notApplicableHealthLabel': 'No aplica · invulnerable',
      'creatureCardTitle': 'Tarjeta de criatura',
      'creatureCardNormal': 'Normal',
      'creatureCardGold': 'Dorada',
      'creatureCardProgressTitle': 'Progreso de tarjeta',
      'creatureCardProgressUnowned': 'Sin obtener',
      'creatureCardProgressObtained': 'Obtenida',
      'creatureCardProgressGold': 'Dorada',
      'creatureCardObtainedLabel': 'Tarjeta obtenida',
      'creatureCardGoldLabel': 'Tarjeta dorada',
      'creatureCardViewerLockedLabel': 'Sin obtener',
      'creatureCardProgressA11yLabel': 'progreso de tarjeta',
      'creatureCardProgressActionTemplate':
          '{label}: {current}. Al tocar cambiará a {next}.',
      'infusionSelectorTitle': 'Sabor o infusión',
      'infusionRecommendationsTitle': 'Recomendaciones de la infusión',
      'lesserMutationsTitle': 'Mutaciones menores',
      'lootTransformationsTitle': 'Efectos sobre el botín',
      'effectGuideAction': 'Guía de efectos',
      'noImageTitle': 'Sin imagen',
      'noImageSubtitle': 'Esta entrada todavía no tiene una imagen disponible.',
      'emptySearchTitle': 'Sin resultados',
      'emptySearchSubtitle': 'Prueba otro nombre o limpia la búsqueda actual.',
      'emptyFavoritesTitle': 'Sin favoritos',
      'emptyFavoritesSubtitle':
          'Aún no tienes entradas marcadas como favoritas.',
      'emptyGoldTitle': 'Sin tarjetas doradas',
      'emptyGoldSubtitle':
          'No hay entradas con tarjeta dorada en la selección actual.',
      'emptyFiltersTitle': 'No hay coincidencias',
      'emptyFiltersSubtitle':
          'Prueba con menos filtros o restablece la selección.',
      'masterDetailPlaceholderTitle': 'Selecciona una entrada',
      'masterDetailPlaceholderSubtitle':
          'Elige una criatura o evento para ver su ficha aquí.',
      'attackTell': 'Señal',
      'attackAvoid': 'Cómo evitar',
      'attackNotes': 'Notas',
      'effectCodexTitle': 'Enciclopedia de efectos',
      'effectCodexSubtitle':
          'Consulta qu\u00e9 hace cada tipo de da\u00f1o, elemento y estado que puede afectar a los enemigos.',
      'effectCodexTooltip': 'Enciclopedia de efectos',
      'effectCategoryDamage': 'Tipos de da\u00f1o',
      'effectCategoryElement': 'Elementos',
      'effectCategoryStatus': 'Estados',
      'effectEquipmentTitle': 'Armas y armaduras con este efecto',
      'effectEquipmentComingSoon': 'Pr\u00f3ximamente.',
      'creditsAppTagline': 'Fan-made app · Grounded 1 y Grounded 2',
      'creditsContentTitle': 'Contenido y licencias',
      'creditsContentBody':
          'Las fotografías de criaturas utilizadas en Aphidex son capturas propias tomadas directamente dentro de Grounded y Grounded 2. Aphidex no utiliza actualmente fotografías de criaturas obtenidas de wikis o de la comunidad.\n\nLa información sobre criaturas, estadísticas, debilidades, resistencias, ubicaciones y comportamiento fue recopilada y contrastada utilizando como referencia la comunidad wiki de Grounded y Grounded 2 indicada a continuación.\n\n© Sus respectivos autores y colaboradores.\nEl contenido de Grounded y Grounded 2, incluidos personajes, criaturas, nombres y elementos visibles en las capturas propias, pertenece a sus respectivos propietarios.\n\nLa información ha sido adaptada y reorganizada con fines informativos.\n\nEsta aplicación no está afiliada, patrocinada ni respaldada por Obsidian Entertainment, Xbox Game Studios ni Microsoft.',
      'groundedTwoWikiButton': 'Creature Cards (wiki.gg)',
      'ccLicenseButton': 'Licencia CC BY-SA',
      'donorsTitle': 'Donadores',
      'noDonorsYet':
          'Aún no hay donadores.\nGracias por apoyar el desarrollo de Aphidex.',
      'footerText': '©2026 ByteShark_dev\nAplicación fan-made',
      'reviewPromptTitle': '¿Te está gustando Aphidex?',
      'reviewPromptMessage':
          'Si la app te está ayudando, una calificación en Google Play ayuda mucho al proyecto.',
      'reviewNeverAction': 'No volver a mostrar',
      'reviewLaterAction': 'Después',
      'reviewRateAction': 'Calificar la app',
      'reviewConfirmTitle': '¿Pudiste dejar tu reseña?',
      'reviewConfirmMessage':
          'Si ya calificaste Aphidex, dejaremos de mostrar este aviso.',
      'reviewNotYetAction': 'Todavía no',
      'reviewReviewedAction': 'Sí, ya califiqué',
      'tutorialSkipAction': 'Saltar',
      'tutorialNextAction': 'Siguiente',
      'tutorialBackAction': 'Atr\u00E1s',
      'tutorialFinishAction': 'Finalizar',
      'tutorialRestartTitle': 'Ver tutorial',
      'tutorialRestartSubtitle':
          'Repite la gu\u00EDa inicial de Aphidex cuando quieras.',
      'tutorialPromptTitle': '\u00BFQuieres ver un tutorial introductorio?',
      'tutorialPromptBody':
          'Aphidex ahora tiene m\u00E1s funciones. Te mostramos criaturas, variantes, armas y equipo, el nuevo mapa, filtros y la enciclopedia.',
      'tutorialPromptStartAction': 'Ver tutorial',
      'tutorialPromptSkipAction': 'Omitir',
      'tutorial_search_title': 'Busca enemigos r\u00E1pido',
      'tutorial_search_body':
          'Usa esta barra para encontrar cualquier insecto o enemigo por nombre.',
      'tutorial_gamePicker_title': 'Elige el juego',
      'tutorial_gamePicker_body':
          'Aqu\u00ED cambias entre Grounded 1, Grounded 2 y Ambos juegos. En Ambos juegos no se repiten las especies compartidas.',
      'tutorial_profile_title': 'Consulta tu perfil',
      'tutorial_profile_body':
          'Consulta tus personajes, tarjetas y eliminaciones desde tu perfil.',
      'tutorial_filters_title': 'Filtra la lista',
      'tutorial_filters_body':
          'Aqu\u00ED puedes combinar filtros m\u00FAltiples al mismo tiempo: tiers, clase, peligro, favoritos y tarjetas doradas.',
      'tutorial_sort_title': 'Cambia el orden',
      'tutorial_sort_body':
          'Desde este bot\u00F3n eliges el criterio de orden y tambi\u00E9n si la lista va en ascendente o descendente.',
      'tutorial_settings_title': 'Abre ajustes',
      'tutorial_settings_body':
          'Desde configuraci\u00F3n puedes cambiar tema, idioma, borrar datos y volver a abrir este tutorial.',
      'tutorial_equipmentLibrary_title': 'Armas y equipo de Grounded 2',
      'tutorial_equipmentLibrary_body':
          'La nueva secci\u00F3n Equipo re\u00FAne armas, armaduras y amuletos con sus datos disponibles, agrupaciones y accesos relacionados.',
      'tutorial_map_title': 'Explora el mapa',
      'tutorial_map_body':
          'Aqu\u00ED puedes explorar Surface y Abyss sin cargar miles de puntos. Para ver ubicaciones, abre una criatura y toca Ver en mapa: solo aparecer\u00E1n sus marcadores.',
      'tutorial_codex_title': 'Consulta la enciclopedia',
      'tutorial_codex_body':
          'Este acceso abre la enciclopedia de efectos con explicaciones para da\u00F1os, elementos y estados.',
      'tutorial_detailSummary_title': 'Ficha del enemigo',
      'tutorial_detailSummary_body':
          'La ficha re\u00FAne foto, peligro, tier real, favorita, tarjeta dorada y secciones desplegables como entorno, loot y habilidades.',
      'tutorial_detailVariant_title': 'Cambia de variante',
      'tutorial_detailVariant_body':
          'Cuando una entrada tiene varias versiones, aqu\u00ED eliges la variante que quieres consultar. La ficha cambia sus datos y conserva tu selecci\u00F3n al navegar.',
      'tutorial_detailEffects_title': 'Debilidades y resistencias',
      'tutorial_detailEffects_body':
          'Aqu\u00ED ver\u00E1s debilidades, resistencias y el da\u00F1o o estado que puede infligir el enemigo.',
      'tutorial_detailEffect_title': 'Los iconos se pueden tocar',
      'tutorial_detailEffect_body':
          'Si tocas un efecto o tipo de da\u00F1o, Aphidex te lleva a su explicaci\u00F3n.',
      'tutorial_codexCard_title': 'Descripci\u00F3n del efecto',
      'tutorial_codexCard_body':
          'La enciclopedia resume qu\u00E9 hace cada efecto para que entiendas r\u00E1pido su funci\u00F3n.',
      'tutorial_codexEquipment_title': 'Equipo relacionado',
      'tutorial_codexEquipment_body':
          'Aqu\u00ED aparecen las armas y armaduras disponibles que aplican este efecto.',
      'autoLanguageDescription': 'Detectado automáticamente: {language}',
      'weakPointBack': 'Espalda',
      'weakPointEyes': 'Ojos',
      'weakPointGut': 'Abdomen',
      'weakPointLegs': 'Patas',
      'weakPointRump': 'Parte trasera',
      'damageAny': 'Cualquiera',
      'damageChoppingAndSlashing': 'Corte + tajo',
      'damageStabbingArrowsOnly': 'Perforación (arcos / ballestas)',
      'damageStabbingBowsAndSpears': 'Perforación (arcos / ballestas / lanzas)',
      'damageStabbing': 'Perforación',
      'damageSlashing': 'Tajo',
      'damageChopping': 'Corte',
      'damageBusting': 'Aplastante',
      'tagMelee': 'Cuerpo a cuerpo',
      'tagRanged': 'A distancia',
      'tagAoe': 'Área',
      'tagUtility': 'Utilidad',
      'immuneLabel': 'Inmune',
    },
    'en': {
      'appTitle': 'Aphidex',
      'settingsTitle': 'Settings',
      'appearanceTitle': 'Appearance',
      'languageTitle': 'Language',
      'systemTheme': 'System',
      'lightTheme': 'Light',
      'darkTheme': 'Dark',
      'automaticLanguage': 'Automatic',
      'useDeviceLanguage': 'Use the phone language',
      'spanishLanguage': 'Spanish',
      'englishLanguage': 'English',
      'russianLanguage': 'Russian',
      'creditsTitle': 'Credits',
      'creditsSubtitle': 'Licenses, donors, and legal notices',
      'websiteTitle': 'Aphidex website',
      'websiteSubtitle': 'News, information, and Aphidex updates',
      'wipeDataTitle': 'Erase data',
      'wipeDataSubtitle': 'Reset favorites, gold cards, and settings',
      'openLinkError': 'The link could not be opened.',
      'wipeConfirmTitle': 'Erase data',
      'wipeConfirmMessage':
          'This will erase:\n- Favorites\n- Gold cards\n- Settings (theme, filters, language, etc.)\n\nAre you sure?',
      'cancelAction': 'Cancel',
      'deleteAction': 'Delete',
      'dataWiped': 'Data erased',
      'chooseGameTooltip': 'Choose game',
      'settingsTooltip': 'Settings',
      'playerProfileTooltip': 'Player profile',
      'playerProfileTitle': 'Player profile',
      'playerProfileSubtitle':
          'Choose an independent profile for Grounded and Grounded 2.',
      'playerProfileNoSelection': 'You have not chosen a profile yet.',
      'playerProfileChooseAction': 'Choose character',
      'playerProfileChangeAction': 'Change character',
      'playerProfileClearAction': 'Clear selection',
      'playerProfileGameSelector': 'Profile game',
      'playerProfileCharacterLabel': 'Profile character',
      'playerProfileCreatureCards': 'Creature Cards',
      'playerProfileGoldCards': 'Gold cards',
      'playerProfileKills': 'Eliminations',
      'killCountAdd': 'Add defeat',
      'killCountEdit': 'Edit defeats',
      'killCountReset': 'Reset counter',
      'killCountQuantity': 'Quantity',
      'saveAction': 'Save',
      'filterWithKills': 'With defeats',
      'filterWithoutKills': 'Without defeats',
      'tutorialProfileTitle': 'View your profile',
      'tutorialProfileBody':
          'View your characters, cards, and defeated creatures from your profile.',
      'playerProfileSelectTooltip': 'Choose character',
      'playerProfileChangeTooltip': 'Change character',
      'playerDisplayNameTitle': 'Player name',
      'playerDisplayNameAdd': 'Add name',
      'playerDisplayNameEdit': 'Edit name',
      'playerDisplayNameSave': 'Save',
      'playerDisplayNameRemove': 'Remove name',
      'playerDisplayNameCounter': '{current}/24',
      'playerProfileShare': 'Share profile',
      'playerProfileShareTooltip': 'Share profile',
      'playerProfileShareUnavailable': 'Choose a character to share.',
      'playerProfileShareText': 'My Aphidex profile',
      'playerProfileShareError':
          'The profile could not be prepared for sharing.',
      'playerProfileSelected': 'Selected profile: {name}',
      'playerProfileSelectorTitle': 'Choose your {game} profile',
      'playerProfileSelectorSubtitle': 'This choice only applies to this game.',
      'sortDefaultOrder': 'In-game order',
      'sortByName': 'Name',
      'sortByDanger': 'Danger',
      'sortByTier': 'Tier',
      'descendingOrder': 'Descending',
      'ascendingOrder': 'Ascending',
      'searchEnemyHint': 'Search enemy...',
      'loadingCreaturesTitle': 'Loading creatures',
      'loadingCreaturesSubtitle': 'Preparing the Aphidex index and local data.',
      'loadingCreatureDetailSubtitle': 'Loading the full sheet for this entry.',
      'dataUnavailableTitle': 'Data unavailable',
      'dataUnavailableSubtitle': 'Aphidex could not load this information.',
      'retryAction': 'Retry',
      'filterAll': 'All',
      'filtersTitle': 'Filters',
      'clearFiltersAction': 'Clear filters',
      'clearSearchAction': 'Clear search',
      'favoritesFilterLabel': 'Favorites',
      'filterTiers': 'Tiers',
      'filterClass': 'Class',
      'filterDanger': 'Danger',
      'filterBoss': 'Boss',
      'tierTitle': 'Tier',
      'groupNeutrals': 'Neutrals',
      'groupAggressive': 'Aggressive / hostile',
      'groupPeaceful': 'Peaceful',
      'groupAnomalies': 'Interdimensional anomalies',
      'groupOthers': 'Others',
      'selectEditionTitle': 'Select edition',
      'bothGames': 'Both',
      'groundedOne': 'Grounded',
      'groundedTwo': 'Grounded 2',
      'errorLoadingJson': 'Error loading JSON:',
      'goldDefault': 'Gold (default)',
      'goldUnlocked': 'Gold card',
      'goldFilterLabel': 'Gold',
      'goldMark': 'Mark as gold',
      'elementalWeakness': 'Elemental weakness',
      'damageWeakness': 'Weakness (damage type)',
      'resistancesTitle': 'Resistances',
      'weakPointTitle': 'Weak point',
      'attacksTitle': 'Attacks',
      'weaknessesTitle': 'Weaknesses',
      'upcomingTitle': 'Coming soon:',
      'underConstructionLabel': 'Under construction',
      'upcomingItems':
          '• Loot with drop rates\n• Spawn locations\n• Builds by progression stage (early / mid / end / NG+)',
      'healthTitle': 'Health',
      'notApplicableHealthLabel': 'Not applicable · invulnerable',
      'creatureCardTitle': 'Creature Card',
      'creatureCardNormal': 'Normal',
      'creatureCardGold': 'Gold',
      'creatureCardProgressTitle': 'Card progress',
      'creatureCardProgressUnowned': 'Unowned',
      'creatureCardProgressObtained': 'Obtained',
      'creatureCardProgressGold': 'Gold',
      'creatureCardObtainedLabel': 'Card obtained',
      'creatureCardGoldLabel': 'Gold card',
      'creatureCardViewerLockedLabel': 'Unowned',
      'creatureCardProgressA11yLabel': 'card progress',
      'creatureCardProgressActionTemplate':
          '{label}: {current}. Tap to change to {next}.',
      'infusionSelectorTitle': 'Flavor or infusion',
      'infusionRecommendationsTitle': 'Infusion recommendations',
      'lesserMutationsTitle': 'Lesser mutations',
      'lootTransformationsTitle': 'Loot effects',
      'effectGuideAction': 'Effect guide',
      'noImageTitle': 'No image',
      'noImageSubtitle': 'This entry does not have an image available yet.',
      'emptySearchTitle': 'No results',
      'emptySearchSubtitle': 'Try another name or clear the current search.',
      'emptyFavoritesTitle': 'No favorites yet',
      'emptyFavoritesSubtitle':
          'You have not marked any entries as favorites yet.',
      'emptyGoldTitle': 'No gold cards',
      'emptyGoldSubtitle':
          'There are no gold card entries in the current selection.',
      'emptyFiltersTitle': 'No matches',
      'emptyFiltersSubtitle':
          'Try fewer filters or reset the current selection.',
      'masterDetailPlaceholderTitle': 'Select an entry',
      'masterDetailPlaceholderSubtitle':
          'Choose a creature or event to inspect it here.',
      'attackTell': 'Tell',
      'attackAvoid': 'How to avoid',
      'attackNotes': 'Notes',
      'effectCodexTitle': 'Effect Codex',
      'effectCodexSubtitle':
          'Review what each damage type, element, and status effect means for enemies.',
      'effectCodexTooltip': 'Effect Codex',
      'effectCategoryDamage': 'Damage types',
      'effectCategoryElement': 'Elements',
      'effectCategoryStatus': 'Status effects',
      'effectEquipmentTitle': 'Weapons and armor with this effect',
      'effectEquipmentComingSoon': 'Coming soon.',
      'creditsAppTagline': 'Fan-made app · Grounded 1 and Grounded 2',
      'creditsContentTitle': 'Content and licenses',
      'creditsContentBody':
          'The creature images used in Aphidex are original in-game screenshots captured directly in Grounded and Grounded 2. Aphidex does not currently use creature images obtained from community members or wikis.\n\nInformation about creatures, statistics, weaknesses, resistances, locations, and behavior was compiled and cross-checked using the Grounded and Grounded 2 community wiki listed below as a reference.\n\n© Their respective authors and contributors.\nGrounded and Grounded 2 content, including characters, creatures, names, and elements visible in the original screenshots, belongs to its respective owners.\n\nThe information has been adapted and reorganized for informational purposes.\n\nThis application is not affiliated with, sponsored by, or endorsed by Obsidian Entertainment, Xbox Game Studios, or Microsoft.',
      'groundedTwoWikiButton': 'Creature Cards (wiki.gg)',
      'ccLicenseButton': 'CC BY-SA license',
      'donorsTitle': 'Donors',
      'noDonorsYet':
          'There are no donors yet.\nThank you for supporting Aphidex development.',
      'footerText': '©2026 ByteShark_dev\nFan-made application',
      'reviewPromptTitle': 'Enjoying Aphidex?',
      'reviewPromptMessage':
          'If the app is helping you, rating it on Google Play would help the project a lot.',
      'reviewNeverAction': 'Never show again',
      'reviewLaterAction': 'Later',
      'reviewRateAction': 'Rate the app',
      'reviewConfirmTitle': 'Were you able to leave a review?',
      'reviewConfirmMessage':
          'If you already rated Aphidex, we will stop showing this reminder.',
      'reviewNotYetAction': 'Not yet',
      'reviewReviewedAction': 'Yes, I rated it',
      'tutorialSkipAction': 'Skip',
      'tutorialNextAction': 'Next',
      'tutorialBackAction': 'Back',
      'tutorialFinishAction': 'Finish',
      'tutorialRestartTitle': 'Show tutorial',
      'tutorialRestartSubtitle':
          'Replay the Aphidex quick guide whenever you want.',
      'tutorialPromptTitle': 'Would you like a quick intro tutorial?',
      'tutorialPromptBody':
          'Aphidex has grown quite a bit. We can walk you through creatures, variants, weapons and gear, the new map, filters, and the effect codex.',
      'tutorialPromptStartAction': 'Start tutorial',
      'tutorialPromptSkipAction': 'Skip',
      'tutorial_search_title': 'Search enemies fast',
      'tutorial_search_body': 'Use this bar to find any bug or enemy by name.',
      'tutorial_gamePicker_title': 'Choose the game',
      'tutorial_gamePicker_body':
          'Here you switch between Grounded 1, Grounded 2, and Both games. In Both games, shared species are grouped into one entry.',
      'tutorial_profile_title': 'View your profile',
      'tutorial_profile_body':
          'View your characters, cards, and defeated creatures from your profile.',
      'tutorial_filters_title': 'Filter the list',
      'tutorial_filters_body':
          'You can combine multiple filters here at the same time: tiers, class, danger, favorites, and gold cards.',
      'tutorial_sort_title': 'Change the order',
      'tutorial_sort_body':
          'This button now controls both the sort mode and whether the list is ascending or descending.',
      'tutorial_settings_title': 'Open settings',
      'tutorial_settings_body':
          'Settings lets you change theme, language, erase data, and launch this tutorial again.',
      'tutorial_equipmentLibrary_title': 'Grounded 2 weapons and gear',
      'tutorial_equipmentLibrary_body':
          'The new Equipment section brings together weapons, armor, and trinkets with their available data, groups, and related links.',
      'tutorial_map_title': 'Explore the map',
      'tutorial_map_body':
          'Explore Surface and Abyss here without loading thousands of points. To see locations, open a creature and tap View on map: only its markers will appear.',
      'tutorial_codex_title': 'Open the codex',
      'tutorial_codex_body':
          'This button opens the effect codex with explanations for damage, elements, and statuses.',
      'tutorial_detailSummary_title': 'Enemy sheet',
      'tutorial_detailSummary_body':
          'The sheet gathers photo, danger, real tier, favorite state, gold card state, and collapsible sections like environment, loot, and abilities.',
      'tutorial_detailVariant_title': 'Switch variants',
      'tutorial_detailVariant_body':
          'When an entry has multiple versions, choose the variant you want to inspect here. The sheet updates its data and keeps your selection while navigating.',
      'tutorial_detailEffects_title': 'Weaknesses and resistances',
      'tutorial_detailEffects_body':
          'Here you can review weaknesses, resistances, and the damage or status that the creature can inflict.',
      'tutorial_detailEffect_title': 'These icons are interactive',
      'tutorial_detailEffect_body':
          'Tap any effect or damage type and Aphidex opens its explanation.',
      'tutorial_codexCard_title': 'Effect description',
      'tutorial_codexCard_body':
          'The codex summarizes what each effect does so you can understand it quickly.',
      'tutorial_codexEquipment_title': 'Related gear',
      'tutorial_codexEquipment_body':
          'Available weapons and armor that use this effect appear here.',
      'autoLanguageDescription': 'Detected automatically: {language}',
      'weakPointBack': 'Back',
      'weakPointEyes': 'Eyes',
      'weakPointGut': 'Gut',
      'weakPointLegs': 'Legs',
      'weakPointRump': 'Rump',
      'damageAny': 'Any',
      'damageChoppingAndSlashing': 'Chopping + slashing',
      'damageStabbingArrowsOnly': 'Stabbing (bows / crossbows)',
      'damageStabbingBowsAndSpears': 'Stabbing (bows / crossbows / spears)',
      'damageStabbing': 'Stabbing',
      'damageSlashing': 'Slashing',
      'damageChopping': 'Chopping',
      'damageBusting': 'Busting',
      'tagMelee': 'Melee',
      'tagRanged': 'Ranged',
      'tagAoe': 'Area',
      'tagUtility': 'Utility',
      'immuneLabel': 'Immune',
    },
    'ru': {
      'appTitle': 'Aphidex',
      'settingsTitle': 'Настройки',
      'appearanceTitle': 'Оформление',
      'languageTitle': 'Язык',
      'systemTheme': 'Система',
      'lightTheme': 'Светлая',
      'darkTheme': 'Тёмная',
      'automaticLanguage': 'Авто',
      'useDeviceLanguage': 'Использовать язык телефона',
      'spanishLanguage': 'Испанский',
      'englishLanguage': 'Английский',
      'russianLanguage': 'Русский',
      'creditsTitle': 'Благодарности',
      'creditsSubtitle': 'Лицензии, донаты и правовая информация',
      'websiteTitle': 'Сайт Aphidex',
      'websiteSubtitle': 'Новости, информация и обновления Aphidex',
      'wipeDataTitle': 'Удалить данные',
      'wipeDataSubtitle': 'Сбросить избранное, золотые карточки и настройки',
      'openLinkError': 'Не удалось открыть ссылку.',
      'wipeConfirmTitle': 'Удалить данные',
      'wipeConfirmMessage':
          'Будут удалены:\n- Избранное\n- Золотые карточки\n- Настройки (тема, фильтры, язык и т. д.)\n\nПродолжить?',
      'cancelAction': 'Отмена',
      'deleteAction': 'Удалить',
      'dataWiped': 'Данные удалены',
      'chooseGameTooltip': 'Выбрать игру',
      'settingsTooltip': 'Настройки',
      'sortDefaultOrder': 'Порядок в игре',
      'sortByName': 'Название',
      'sortByDanger': 'Опасность',
      'sortByTier': 'Тир',
      'descendingOrder': 'По убыванию',
      'ascendingOrder': 'По возрастанию',
      'searchEnemyHint': 'Поиск врага...',
      'loadingCreaturesTitle': 'Загрузка существ',
      'loadingCreaturesSubtitle':
          'Подготавливаем индекс Aphidex и локальные данные.',
      'loadingCreatureDetailSubtitle': 'Загружаем полную карточку этой записи.',
      'dataUnavailableTitle': 'Данные недоступны',
      'dataUnavailableSubtitle': 'Aphidex не смог загрузить эту информацию.',
      'retryAction': 'Повторить',
      'filterAll': 'Все',
      'filtersTitle': 'Фильтры',
      'clearFiltersAction': 'Сбросить фильтры',
      'clearSearchAction': 'Очистить поиск',
      'favoritesFilterLabel': 'Избранное',
      'filterTiers': 'Тиры',
      'filterClass': 'Класс',
      'filterDanger': 'Опасность',
      'filterBoss': 'Босс',
      'tierTitle': 'Тир',
      'groupNeutrals': 'Нейтральные',
      'groupAggressive': 'Агрессивные / враждебные',
      'groupPeaceful': 'Мирные',
      'groupAnomalies': 'Межпространственные аномалии',
      'groupOthers': 'Прочие',
      'selectEditionTitle': 'Выбрать издание',
      'bothGames': 'Обе',
      'groundedOne': 'Grounded',
      'groundedTwo': 'Grounded 2',
      'errorLoadingJson': 'Ошибка загрузки JSON:',
      'goldDefault': 'Золотая (по умолчанию)',
      'goldUnlocked': 'Золотая карточка',
      'goldFilterLabel': 'Золотые',
      'goldMark': 'Отметить как золотую',
      'elementalWeakness': 'Стихийная слабость',
      'damageWeakness': 'Слабость к типу урона',
      'resistancesTitle': 'Сопротивления',
      'weakPointTitle': 'Слабое место',
      'attacksTitle': 'Атаки',
      'weaknessesTitle': 'Слабости',
      'upcomingTitle': 'Скоро:',
      'underConstructionLabel': 'В разработке',
      'upcomingItems':
          '• Добыча с шансами выпадения\n• Места появления\n• Сборки по этапам прогресса (early / mid / end / NG+)',
      'healthTitle': 'Здоровье',
      'notApplicableHealthLabel': 'Не применимо · неуязвимо',
      'creatureCardTitle': 'Карточка существа',
      'creatureCardNormal': 'Обычная',
      'creatureCardGold': 'Золотая',
      'creatureCardProgressTitle': 'Прогресс карточки',
      'creatureCardProgressUnowned': 'Не получена',
      'creatureCardProgressObtained': 'Получена',
      'creatureCardProgressGold': 'Золотая',
      'creatureCardObtainedLabel': 'Карточка получена',
      'creatureCardGoldLabel': 'Золотая карточка',
      'creatureCardViewerLockedLabel': 'Не получена',
      'creatureCardProgressA11yLabel': 'прогресс карточки',
      'creatureCardProgressActionTemplate':
          '{label}: {current}. По нажатию сменится на {next}.',
      'infusionSelectorTitle': 'Вкус или инфузия',
      'infusionRecommendationsTitle': 'Рекомендации по инфузии',
      'lesserMutationsTitle': 'Малые мутации',
      'lootTransformationsTitle': 'Эффекты для добычи',
      'effectGuideAction': 'Гид по эффектам',
      'noImageTitle': 'Нет изображения',
      'noImageSubtitle': 'Для этой записи пока нет доступного изображения.',
      'emptySearchTitle': 'Ничего не найдено',
      'emptySearchSubtitle':
          'Попробуйте другое имя или очистите текущий поиск.',
      'emptyFavoritesTitle': 'Пока нет избранного',
      'emptyFavoritesSubtitle':
          'Вы ещё не отметили ни одну запись как избранную.',
      'emptyGoldTitle': 'Нет золотых карточек',
      'emptyGoldSubtitle': 'В текущей выборке нет записей с золотой карточкой.',
      'emptyFiltersTitle': 'Совпадений нет',
      'emptyFiltersSubtitle':
          'Попробуйте уменьшить количество фильтров или сбросить их.',
      'masterDetailPlaceholderTitle': 'Выберите запись',
      'masterDetailPlaceholderSubtitle':
          'Выберите существо или событие, чтобы посмотреть карточку здесь.',
      'attackTell': 'Подсказка',
      'attackAvoid': 'Как избежать',
      'attackNotes': 'Заметки',
      'creditsAppTagline': 'Фанатское приложение · Grounded 1 и Grounded 2',
      'creditsContentTitle': 'Контент и лицензии',
      'creditsContentBody':
          'Изображения существ, используемые в Aphidex, являются оригинальными внутриигровыми снимками, сделанными непосредственно в Grounded и Grounded 2. В настоящее время Aphidex не использует изображения существ из вики или от сообщества.\n\nИнформация о существах, характеристиках, слабостях, сопротивлениях, местах обитания и поведении была собрана и проверена с использованием указанной ниже вики сообщества Grounded и Grounded 2 в качестве справочного источника.\n\n© Соответствующие авторы и участники.\nКонтент Grounded и Grounded 2, включая персонажей, существ, названия и элементы, видимые на собственных снимках, принадлежит соответствующим владельцам.\n\nИнформация была адаптирована и переработана в справочных целях.\n\nЭто приложение не связано, не спонсируется и не поддерживается Obsidian Entertainment, Xbox Game Studios или Microsoft.',
      'groundedTwoWikiButton': 'Creature Cards (wiki.gg)',
      'ccLicenseButton': 'Лицензия CC BY-SA',
      'donorsTitle': 'Донаторы',
      'noDonorsYet':
          'Донаторов пока нет.\nСпасибо за поддержку развития Aphidex.',
      'footerText': '©2026 ByteShark_dev\nФанатское приложение',
      'reviewPromptTitle': 'Нравится Aphidex?',
      'reviewPromptMessage':
          'Если приложение тебе помогает, оценка в Google Play сильно поддержит проект.',
      'reviewNeverAction': 'Больше не показывать',
      'reviewLaterAction': 'Позже',
      'reviewRateAction': 'Оценить приложение',
      'reviewConfirmTitle': 'Удалось оставить отзыв?',
      'reviewConfirmMessage':
          'Если ты уже оценил Aphidex, мы больше не будем показывать это напоминание.',
      'reviewNotYetAction': 'Еще нет',
      'reviewReviewedAction': 'Да, я оценил',
      'tutorialSkipAction':
          '\u041F\u0440\u043E\u043F\u0443\u0441\u0442\u0438\u0442\u044C',
      'tutorialNextAction': '\u0414\u0430\u043B\u0435\u0435',
      'tutorialBackAction': '\u041D\u0430\u0437\u0430\u0434',
      'tutorialFinishAction':
          '\u0417\u0430\u0432\u0435\u0440\u0448\u0438\u0442\u044C',
      'tutorialRestartTitle':
          '\u041F\u043E\u043A\u0430\u0437\u0430\u0442\u044C \u0442\u0443\u0442\u043E\u0440\u0438\u0430\u043B',
      'tutorialRestartSubtitle':
          '\u0417\u0430\u043D\u043E\u0432\u043E \u043E\u0442\u043A\u0440\u043E\u0439 \u043A\u0440\u0430\u0442\u043A\u043E\u0435 \u043E\u0431\u0443\u0447\u0435\u043D\u0438\u0435 Aphidex.',
      'tutorialPromptTitle':
          '\u041f\u043e\u043a\u0430\u0437\u0430\u0442\u044c \u043a\u0440\u0430\u0442\u043a\u043e\u0435 \u043e\u0431\u0443\u0447\u0435\u043d\u0438\u0435?',
      'tutorialPromptBody':
          'В Aphidex появилось много нового. Мы покажем существ, варианты, оружие и снаряжение, новую карту, фильтры и энциклопедию эффектов.',
      'tutorialPromptStartAction': '\u041d\u0430\u0447\u0430\u0442\u044c',
      'tutorialPromptSkipAction':
          '\u041f\u0440\u043e\u043f\u0443\u0441\u0442\u0438\u0442\u044c',
      'tutorial_search_title':
          '\u0411\u044B\u0441\u0442\u0440\u044B\u0439 \u043F\u043E\u0438\u0441\u043A \u0432\u0440\u0430\u0433\u043E\u0432',
      'tutorial_search_body':
          '\u042d\u0442\u0430 \u0441\u0442\u0440\u043e\u043a\u0430 \u043f\u043e\u043c\u043e\u0436\u0435\u0442 \u043d\u0430\u0439\u0442\u0438 \u043b\u044e\u0431\u043e\u0433\u043e \u0436\u0443\u043a\u0430 \u0438\u043b\u0438 \u0432\u0440\u0430\u0433\u0430 \u043f\u043e \u0438\u043c\u0435\u043d\u0438.',
      'tutorial_gamePicker_title':
          '\u0412\u044B\u0431\u043E\u0440 \u0438\u0433\u0440\u044B',
      'tutorial_gamePicker_body':
          '\u0417\u0434\u0435\u0441\u044c \u043c\u043e\u0436\u043d\u043e \u043f\u0435\u0440\u0435\u043a\u043b\u044e\u0447\u0430\u0442\u044c\u0441\u044f \u043c\u0435\u0436\u0434\u0443 Grounded 1, Grounded 2 \u0438 \u0440\u0435\u0436\u0438\u043c\u043e\u043c \u00ab\u041e\u0431\u0435 \u0438\u0433\u0440\u044b\u00bb. \u0412 \u044d\u0442\u043e\u043c \u0440\u0435\u0436\u0438\u043c\u0435 \u043e\u0431\u0449\u0438\u0435 \u0432\u0438\u0434\u044b \u043d\u0435 \u0434\u0443\u0431\u043b\u0438\u0440\u0443\u044e\u0442\u0441\u044f.',
      'tutorial_profile_title':
          '\u0412\u0430\u0448 \u043f\u0440\u043e\u0444\u0438\u043b\u044c',
      'tutorial_profile_body':
          '\u0412 \u043f\u0440\u043e\u0444\u0438\u043b\u0435 \u043c\u043e\u0436\u043d\u043e \u043f\u043e\u0441\u043c\u043e\u0442\u0440\u0435\u0442\u044c \u043f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0435\u0439, \u043a\u0430\u0440\u0442\u043e\u0447\u043a\u0438 \u0438 \u043f\u043e\u0431\u0435\u0434\u044b.',
      'tutorial_filters_title':
          '\u0424\u0438\u043B\u044C\u0442\u0440\u044B \u0441\u043F\u0438\u0441\u043A\u0430',
      'tutorial_filters_body':
          '\u0417\u0434\u0435\u0441\u044c \u043c\u043e\u0436\u043d\u043e \u043e\u0434\u043d\u043e\u0432\u0440\u0435\u043c\u0435\u043d\u043d\u043e \u043a\u043e\u043c\u0431\u0438\u043d\u0438\u0440\u043e\u0432\u0430\u0442\u044c \u0444\u0438\u043b\u044c\u0442\u0440\u044b \u043f\u043e \u0442\u0438\u0440\u0443, \u043a\u043b\u0430\u0441\u0441\u0443, \u043e\u043f\u0430\u0441\u043d\u043e\u0441\u0442\u0438, \u0438\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u043c\u0443 \u0438 \u0437\u043e\u043b\u043e\u0442\u044b\u043c \u043a\u0430\u0440\u0442\u0430\u043c.',
      'tutorial_sort_title':
          '\u041C\u0435\u043D\u044F\u0439 \u043F\u043E\u0440\u044F\u0434\u043E\u043A',
      'tutorial_sort_body':
          '\u042d\u0442\u0430 \u043a\u043d\u043e\u043f\u043a\u0430 \u0442\u0435\u043f\u0435\u0440\u044c \u043c\u0435\u043d\u044f\u0435\u0442 \u0438 \u0440\u0435\u0436\u0438\u043c \u0441\u043e\u0440\u0442\u0438\u0440\u043e\u0432\u043a\u0438, \u0438 \u043d\u0430\u043f\u0440\u0430\u0432\u043b\u0435\u043d\u0438\u0435 \u0441\u043f\u0438\u0441\u043a\u0430.',
      'tutorial_settings_title':
          '\u041E\u0442\u043A\u0440\u043E\u0439 \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438',
      'tutorial_settings_body':
          '\u0412 \u043d\u0430\u0441\u0442\u0440\u043e\u0439\u043a\u0430\u0445 \u043c\u043e\u0436\u043d\u043e \u043f\u043e\u043c\u0435\u043d\u044f\u0442\u044c \u0442\u0435\u043c\u0443, \u044f\u0437\u044b\u043a, \u0441\u0431\u0440\u043e\u0441\u0438\u0442\u044c \u0434\u0430\u043d\u043d\u044b\u0435 \u0438 \u0437\u0430\u043f\u0443\u0441\u0442\u0438\u0442\u044c \u044d\u0442\u043e \u043e\u0431\u0443\u0447\u0435\u043d\u0438\u0435 \u0441\u043d\u043e\u0432\u0430.',
      'tutorial_equipmentLibrary_title': 'Оружие и снаряжение Grounded 2',
      'tutorial_equipmentLibrary_body':
          'В новом разделе «Снаряжение» собраны оружие, броня и амулеты с доступными данными, группами и связанными переходами.',
      'tutorial_map_title': 'Исследуйте карту',
      'tutorial_map_body':
          'Исследуйте Поверхность и Бездну без загрузки тысяч точек. Чтобы увидеть места, откройте существо и нажмите «Показать на карте»: появятся только его маркеры.',
      'tutorial_codex_title':
          '\u041E\u0442\u043A\u0440\u043E\u0439 \u044D\u043D\u0446\u0438\u043A\u043B\u043E\u043F\u0435\u0434\u0438\u044E',
      'tutorial_codex_body':
          '\u042d\u0442\u0430 \u043a\u043d\u043e\u043f\u043a\u0430 \u043e\u0442\u043a\u0440\u044b\u0432\u0430\u0435\u0442 \u0441\u043f\u0440\u0430\u0432\u043a\u0443 \u043f\u043e \u0442\u0438\u043f\u0430\u043c \u0443\u0440\u043e\u043d\u0430, \u0441\u0442\u0438\u0445\u0438\u044f\u043c \u0438 \u0441\u0442\u0430\u0442\u0443\u0441\u0430\u043c.',
      'tutorial_detailSummary_title':
          '\u041A\u0430\u0440\u0442\u043E\u0447\u043A\u0430 \u0432\u0440\u0430\u0433\u0430',
      'tutorial_detailSummary_body':
          '\u0412 \u043a\u0430\u0440\u0442\u043e\u0447\u043a\u0435 \u0435\u0441\u0442\u044c \u0444\u043e\u0442\u043e, \u043e\u043f\u0430\u0441\u043d\u043e\u0441\u0442\u044c, \u0440\u0435\u0430\u043b\u044c\u043d\u044b\u0439 \u0442\u0438\u0440, \u0441\u0442\u0430\u0442\u0443\u0441 \u0438\u0437\u0431\u0440\u0430\u043d\u043d\u043e\u0433\u043e, \u0437\u043e\u043b\u043e\u0442\u043e\u0439 \u043a\u0430\u0440\u0442\u044b \u0438 \u0441\u0432\u043e\u0440\u0430\u0447\u0438\u0432\u0430\u0435\u043c\u044b\u0435 \u0440\u0430\u0437\u0434\u0435\u043b\u044b \u0441 loot, \u0441\u0440\u0435\u0434\u043e\u0439 \u0438 \u0441\u043f\u043e\u0441\u043e\u0431\u043d\u043e\u0441\u0442\u044f\u043c\u0438.',
      'tutorial_detailVariant_title': 'Переключение вариантов',
      'tutorial_detailVariant_body':
          'Если у записи есть несколько версий, здесь можно выбрать нужный вариант. Карточка обновит данные и сохранит выбор при навигации.',
      'tutorial_detailEffects_title':
          '\u0421\u043B\u0430\u0431\u043E\u0441\u0442\u0438 \u0438 \u0441\u043E\u043F\u0440\u043E\u0442\u0438\u0432\u043B\u0435\u043D\u0438\u044F',
      'tutorial_detailEffects_body':
          '\u0417\u0434\u0435\u0441\u044c \u043f\u043e\u043a\u0430\u0437\u0430\u043d\u044b \u0441\u043b\u0430\u0431\u043e\u0441\u0442\u0438, \u0441\u043e\u043f\u0440\u043e\u0442\u0438\u0432\u043b\u0435\u043d\u0438\u044f \u0438 \u0442\u0438\u043f\u044b \u0443\u0440\u043e\u043d\u0430 \u0438\u043b\u0438 \u0441\u0442\u0430\u0442\u0443\u0441\u044b, \u043a\u043e\u0442\u043e\u0440\u044b\u0435 \u043e\u043d \u043d\u0430\u043d\u043e\u0441\u0438\u0442.',
      'tutorial_detailEffect_title':
          '\u0418\u043A\u043E\u043D\u043A\u0438 \u043C\u043E\u0436\u043D\u043E \u043D\u0430\u0436\u0438\u043C\u0430\u0442\u044C',
      'tutorial_detailEffect_body':
          '\u041d\u0430\u0436\u043c\u0438 \u043d\u0430 \u043b\u044e\u0431\u043e\u0439 \u044d\u0444\u0444\u0435\u043a\u0442 \u0438\u043b\u0438 \u0442\u0438\u043f \u0443\u0440\u043e\u043d\u0430, \u0438 Aphidex \u043e\u0442\u043a\u0440\u043e\u0435\u0442 \u0435\u0433\u043e \u043e\u043f\u0438\u0441\u0430\u043d\u0438\u0435.',
      'tutorial_codexCard_title':
          '\u041E\u043F\u0438\u0441\u0430\u043D\u0438\u0435 \u044D\u0444\u0444\u0435\u043A\u0442\u0430',
      'tutorial_codexCard_body':
          '\u042d\u0442\u0430 \u043a\u0430\u0440\u0442\u043e\u0447\u043a\u0430 \u043a\u0440\u0430\u0442\u043a\u043e \u043e\u0431\u044a\u044f\u0441\u043d\u044f\u0435\u0442, \u0447\u0442\u043e \u0434\u0435\u043b\u0430\u0435\u0442 \u044d\u0444\u0444\u0435\u043a\u0442.',
      'tutorial_codexEquipment_title':
          '\u0421\u0432\u044F\u0437\u0430\u043D\u043D\u043E\u0435 \u0441\u043D\u0430\u0440\u044F\u0436\u0435\u043D\u0438\u0435',
      'tutorial_codexEquipment_body':
          'Здесь показаны доступные оружие и броня, связанные с этим эффектом.',
      'autoLanguageDescription': 'Автоматически определён язык: {language}',
      'weakPointBack': 'Спина',
      'weakPointEyes': 'Глаза',
      'weakPointGut': 'Брюшко',
      'weakPointLegs': 'Ноги',
      'weakPointRump': 'Задняя часть',
      'damageAny': 'Любой',
      'damageChoppingAndSlashing': 'Рубящий + режущий',
      'damageStabbingArrowsOnly': 'Колющий (луки / арбалеты)',
      'damageStabbingBowsAndSpears': 'Колющий (луки / арбалеты / копья)',
      'damageStabbing': 'Колющий',
      'damageSlashing': 'Режущий',
      'damageChopping': 'Рубящий',
      'damageBusting': 'Дробящий',
      'tagMelee': 'Ближний бой',
      'tagRanged': 'Дальний бой',
      'tagAoe': 'По области',
      'tagUtility': 'Поддержка',
      'effectCodexTitle': 'Энциклопедия эффектов',
      'effectCodexSubtitle':
          'Здесь собраны типы урона, элементы и статусы, которые могут влиять на врагов.',
      'effectCodexTooltip': 'Энциклопедия эффектов',
      'effectCategoryDamage': 'Типы урона',
      'effectCategoryElement': 'Элементы',
      'effectCategoryStatus': 'Статусы',
      'effectEquipmentTitle': 'Оружие и броня с этим эффектом',
      'effectEquipmentComingSoon': 'Скоро.',
      'immuneLabel': '\u0418\u043c\u043c\u0443\u043d\u0438\u0442\u0435\u0442',
      'playerProfileTooltip':
          '\u041f\u0440\u043e\u0444\u0438\u043b\u044c \u0438\u0433\u0440\u043e\u043a\u0430',
      'playerProfileTitle':
          '\u041f\u0440\u043e\u0444\u0438\u043b\u044c \u0438\u0433\u0440\u043e\u043a\u0430',
      'playerProfileSubtitle':
          '\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u043e\u0442\u0434\u0435\u043b\u044c\u043d\u044b\u0439 \u043f\u0440\u043e\u0444\u0438\u043b\u044c \u0434\u043b\u044f Grounded \u0438 Grounded 2.',
      'playerProfileNoSelection':
          '\u041f\u0440\u043e\u0444\u0438\u043b\u044c \u0435\u0449\u0451 \u043d\u0435 \u0432\u044b\u0431\u0440\u0430\u043d.',
      'playerProfileChooseAction':
          '\u0412\u044b\u0431\u0440\u0430\u0442\u044c \u043f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0430',
      'playerProfileChangeAction':
          '\u0418\u0437\u043c\u0435\u043d\u0438\u0442\u044c \u043f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0430',
      'playerProfileClearAction':
          '\u041e\u0447\u0438\u0441\u0442\u0438\u0442\u044c \u0432\u044b\u0431\u043e\u0440',
      'playerProfileGameSelector':
          '\u0418\u0433\u0440\u0430 \u043f\u0440\u043e\u0444\u0438\u043b\u044f',
      'playerProfileCharacterLabel':
          '\u041f\u0435\u0440\u0441\u043e\u043d\u0430\u0436 \u043f\u0440\u043e\u0444\u0438\u043b\u044f',
      'playerProfileCreatureCards':
          '\u041a\u0430\u0440\u0442\u043e\u0447\u043a\u0438 \u0441\u0443\u0449\u0435\u0441\u0442\u0432',
      'playerProfileGoldCards':
          '\u0417\u043e\u043b\u043e\u0442\u044b\u0435 \u043a\u0430\u0440\u0442\u044b',
      'playerProfileKills':
          '\u0423\u043d\u0438\u0447\u0442\u043e\u0436\u0435\u043d\u0438\u044f',
      'killCountAdd':
          '\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u043f\u043e\u0431\u0435\u0434\u0443',
      'killCountEdit':
          '\u0418\u0437\u043c\u0435\u043d\u0438\u0442\u044c \u043f\u043e\u0431\u0435\u0434\u044b',
      'killCountReset':
          '\u0421\u0431\u0440\u043e\u0441\u0438\u0442\u044c \u0441\u0447\u0451\u0442\u0447\u0438\u043a',
      'killCountQuantity':
          '\u041a\u043e\u043b\u0438\u0447\u0435\u0441\u0442\u0432\u043e',
      'saveAction': '\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c',
      'filterWithKills':
          '\u0421 \u043f\u043e\u0431\u0435\u0434\u0430\u043c\u0438',
      'filterWithoutKills': '\u0411\u0435\u0437 \u043f\u043e\u0431\u0435\u0434',
      'tutorialProfileTitle':
          '\u0412\u0430\u0448 \u043f\u0440\u043e\u0444\u0438\u043b\u044c',
      'tutorialProfileBody':
          '\u0412 \u043f\u0440\u043e\u0444\u0438\u043b\u0435 \u043c\u043e\u0436\u043d\u043e \u043f\u043e\u0441\u043c\u043e\u0442\u0440\u0435\u0442\u044c \u043f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0435\u0439, \u043a\u0430\u0440\u0442\u043e\u0447\u043a\u0438 \u0438 \u043f\u043e\u0431\u0435\u0434\u044b.',
      'playerProfileSelectTooltip':
          '\u0412\u044b\u0431\u0440\u0430\u0442\u044c \u043f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0430',
      'playerProfileChangeTooltip':
          '\u0418\u0437\u043c\u0435\u043d\u0438\u0442\u044c \u043f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0430',
      'playerDisplayNameTitle':
          '\u0418\u043c\u044f \u0438\u0433\u0440\u043e\u043a\u0430',
      'playerDisplayNameAdd':
          '\u0414\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u0438\u043c\u044f',
      'playerDisplayNameEdit':
          '\u0418\u0437\u043c\u0435\u043d\u0438\u0442\u044c \u0438\u043c\u044f',
      'playerDisplayNameSave':
          '\u0421\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c',
      'playerDisplayNameRemove':
          '\u0423\u0434\u0430\u043b\u0438\u0442\u044c \u0438\u043c\u044f',
      'playerDisplayNameCounter': '{current}/24',
      'playerProfileShare':
          '\u041f\u043e\u0434\u0435\u043b\u0438\u0442\u044c\u0441\u044f \u043f\u0440\u043e\u0444\u0438\u043b\u0435\u043c',
      'playerProfileShareTooltip':
          '\u041f\u043e\u0434\u0435\u043b\u0438\u0442\u044c\u0441\u044f \u043f\u0440\u043e\u0444\u0438\u043b\u0435\u043c',
      'playerProfileShareUnavailable':
          '\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u043f\u0435\u0440\u0441\u043e\u043d\u0430\u0436\u0430 \u0434\u043b\u044f \u043e\u0442\u043f\u0440\u0430\u0432\u043a\u0438.',
      'playerProfileShareText':
          '\u041c\u043e\u0439 \u043f\u0440\u043e\u0444\u0438\u043b\u044c Aphidex',
      'playerProfileShareError':
          '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043f\u043e\u0434\u0433\u043e\u0442\u043e\u0432\u0438\u0442\u044c \u043f\u0440\u043e\u0444\u0438\u043b\u044c \u0434\u043b\u044f \u043e\u0442\u043f\u0440\u0430\u0432\u043a\u0438.',
      'playerProfileSelected':
          '\u0412\u044b\u0431\u0440\u0430\u043d\u043d\u044b\u0439 \u043f\u0440\u043e\u0444\u0438\u043b\u044c: {name}',
      'playerProfileSelectorTitle':
          '\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u043f\u0440\u043e\u0444\u0438\u043b\u044c \u0434\u043b\u044f {game}',
      'playerProfileSelectorSubtitle':
          '\u042d\u0442\u043e\u0442 \u0432\u044b\u0431\u043e\u0440 \u0434\u0435\u0439\u0441\u0442\u0432\u0443\u0435\u0442 \u0442\u043e\u043b\u044c\u043a\u043e \u0434\u043b\u044f \u044d\u0442\u043e\u0439 \u0438\u0433\u0440\u044b.',
    },
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      LocaleController.supportedLanguageCodes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(LocaleController.resolveSupportedLocale(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

extension AppLocalizationX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
