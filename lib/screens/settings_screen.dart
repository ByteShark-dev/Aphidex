import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';
import '../controllers/locale_controller.dart';
import '../controllers/monetization_controller.dart';
import '../controllers/review_prompt_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/tutorial_controller.dart';
import '../i18n/app_localizations.dart';
import '../i18n/data_management_strings.dart';
import 'credits_screen.dart';
import 'data_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse(AphidexLinks.publicWebsite);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.openLinkError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final locale = LocaleController.instance;
    final monetization = MonetizationController.instance;
    final l10n = context.l10n;
    final dataStrings = DataManagementStrings.forLanguage(l10n.languageCode);
    final systemLanguage = l10n.languageNameForCode(
      LocaleController.resolveSupportedLocale(
        View.of(context).platformDispatcher.locale,
      ).languageCode,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appearanceTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<ThemePref>(
                      valueListenable: theme.theme,
                      builder: (context, pref, _) {
                        return SegmentedButton<ThemePref>(
                          segments: [
                            ButtonSegment(
                              value: ThemePref.system,
                              label: Text(l10n.systemTheme),
                              icon: const Icon(Icons.phone_android),
                            ),
                            ButtonSegment(
                              value: ThemePref.light,
                              label: Text(l10n.lightTheme),
                              icon: const Icon(Icons.light_mode),
                            ),
                            ButtonSegment(
                              value: ThemePref.dark,
                              label: Text(l10n.darkTheme),
                              icon: const Icon(Icons.dark_mode),
                            ),
                          ],
                          selected: {pref},
                          onSelectionChanged: (set) =>
                              theme.setTheme(set.first),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.languageTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<LanguagePref>(
                      valueListenable: locale.preference,
                      builder: (context, pref, _) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<LanguagePref>(
                              initialValue: pref,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.language),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: LanguagePref.system,
                                  child: Text(l10n.automaticLanguage),
                                ),
                                DropdownMenuItem(
                                  value: LanguagePref.es,
                                  child: Text(l10n.spanishLanguage),
                                ),
                                DropdownMenuItem(
                                  value: LanguagePref.en,
                                  child: Text(l10n.englishLanguage),
                                ),
                                DropdownMenuItem(
                                  value: LanguagePref.ru,
                                  child: Text(l10n.russianLanguage),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  locale.setLanguage(value);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pref == LanguagePref.system
                                  ? l10n.autoLanguageDescription(systemLanguage)
                                  : l10n.useDeviceLanguage,
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (monetization.isSupportedPlatform) ...[
              ListenableBuilder(
                listenable: Listenable.merge([
                  monetization.adsRemoved,
                  monetization.storeAvailable,
                  monetization.removeAdsProduct,
                  monetization.isBusy,
                ]),
                builder: (context, _) {
                  final adsRemoved = monetization.adsRemoved.value;
                  final product = monetization.removeAdsProduct.value;
                  final busy = monetization.isBusy.value;
                  final displayPrice = product == null
                      ? null
                      : MonetizationController.displayStorePrice(product);
                  final subtitle = adsRemoved
                      ? l10n.adsRemovedSubtitle
                      : (product != null
                            ? l10n.adsEnabledSubtitle(displayPrice!)
                            : l10n.adsStorePendingSubtitle);

                  Future<void> handleBuy() async {
                    final result = await monetization.buyRemoveAds();
                    if (!context.mounted) {
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    switch (result) {
                      case MonetizationActionResult.alreadyOwned:
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.adsAlreadyRemovedMessage),
                          ),
                        );
                        break;
                      case MonetizationActionResult.storeUnavailable:
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.adsStoreUnavailableMessage),
                          ),
                        );
                        break;
                      case MonetizationActionResult.productUnavailable:
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.adsProductUnavailableMessage),
                          ),
                        );
                        break;
                      case MonetizationActionResult.failed:
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.adsPurchaseFailedMessage),
                          ),
                        );
                        break;
                      case MonetizationActionResult.launchedPurchaseFlow:
                      case MonetizationActionResult.startedRestore:
                      case MonetizationActionResult.unsupportedPlatform:
                        break;
                    }
                  }

                  Future<void> handleRestore() async {
                    final result = await monetization.restoreRemoveAds();
                    if (!context.mounted) {
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    switch (result) {
                      case MonetizationActionResult.startedRestore:
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.adsRestoreStartedMessage),
                          ),
                        );
                        break;
                      case MonetizationActionResult.storeUnavailable:
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(l10n.adsStoreUnavailableMessage),
                          ),
                        );
                        break;
                      case MonetizationActionResult.unsupportedPlatform:
                      case MonetizationActionResult.alreadyOwned:
                      case MonetizationActionResult.productUnavailable:
                      case MonetizationActionResult.failed:
                      case MonetizationActionResult.launchedPurchaseFlow:
                        break;
                    }
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.hide_source_outlined),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.adsSettingsTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(subtitle),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: busy || adsRemoved
                                    ? null
                                    : () => handleBuy(),
                                icon: const Icon(Icons.block),
                                label: Text(
                                  product == null
                                      ? l10n.removeAdsAction
                                      : l10n.removeAdsPriceAction(
                                          displayPrice!,
                                        ),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: busy ? null : () => handleRestore(),
                                icon: const Icon(Icons.refresh),
                                label: Text(l10n.restorePurchasesAction),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            Card(
              child: ListTile(
                key: const ValueKey('restart-tutorial-tile'),
                leading: const Icon(Icons.school_outlined),
                title: Text(l10n.tutorialRestartTitle),
                subtitle: Text(l10n.tutorialRestartSubtitle),
                trailing: const Icon(Icons.play_arrow),
                onTap: () => TutorialController.instance.startFromSettings(),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(l10n.creditsTitle),
                subtitle: Text(l10n.creditsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreditsScreen()),
                  );
                  if (context.mounted) {
                    await ReviewPromptController.instance.registerScreenClose(
                      context,
                    );
                  }
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.websiteTitle),
                subtitle: Text(l10n.websiteSubtitle),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => _openWebsite(context),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: Text(dataStrings['title']),
                subtitle: Text(l10n.wipeDataSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DataManagementScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
