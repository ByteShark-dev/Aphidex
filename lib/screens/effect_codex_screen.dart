import 'package:flutter/material.dart';

import '../controllers/tutorial_controller.dart';
import '../data/effect_catalog.dart';
import '../data/ui_mapper.dart';
import '../i18n/app_localizations.dart';

Future<void> openEffectCodex(BuildContext context, {String? initialEffectId}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EffectCodexScreen(initialEffectId: initialEffectId),
    ),
  );
}

Future<void> showEffectInfoSheet(
  BuildContext context, {
  required String effectId,
}) async {
  final entry = effectCatalogEntryById(effectId);
  if (entry == null) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _EffectInfoSheet(entry: entry),
  );
}

class EffectCodexScreen extends StatefulWidget {
  final String? initialEffectId;
  final bool autoScrollToInitialEffect;

  const EffectCodexScreen({
    super.key,
    this.initialEffectId,
    this.autoScrollToInitialEffect = true,
  });

  @override
  State<EffectCodexScreen> createState() => _EffectCodexScreenState();
}

class _EffectCodexScreenState extends State<EffectCodexScreen> {
  late final String? _highlightedId;
  late final Map<String, GlobalKey> _entryKeys;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.initialEffectId == null
        ? null
        : effectCatalogEntryById(widget.initialEffectId!)?.id;
    _entryKeys = {
      for (final entry in effectCatalogEntries) entry.id: GlobalKey(),
    };

    if (_highlightedId != null && widget.autoScrollToInitialEffect) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToHighlighted(),
      );
    }
  }

  Future<void> _scrollToHighlighted() async {
    final targetId = _highlightedId;
    if (targetId == null) {
      return;
    }

    final targetContext = _entryKeys[targetId]?.currentContext;
    if (targetContext == null) {
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.effectCodexTitle)),
      body: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.effectCodexSubtitle,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 18),
              _EffectSection(
                title: l10n.effectCategoryLabel('damage'),
                entries: effectCatalogEntries
                    .where((entry) => entry.category == EffectCategory.damage)
                    .toList(),
                highlightedId: _highlightedId,
                entryKeys: _entryKeys,
              ),
              const SizedBox(height: 18),
              _EffectSection(
                title: l10n.effectCategoryLabel('element'),
                entries: effectCatalogEntries
                    .where((entry) => entry.category == EffectCategory.element)
                    .toList(),
                highlightedId: _highlightedId,
                entryKeys: _entryKeys,
              ),
              const SizedBox(height: 18),
              _EffectSection(
                title: l10n.effectCategoryLabel('status'),
                entries: effectCatalogEntries
                    .where((entry) => entry.category == EffectCategory.status)
                    .toList(),
                highlightedId: _highlightedId,
                entryKeys: _entryKeys,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EffectSection extends StatelessWidget {
  final String title;
  final List<EffectCatalogEntry> entries;
  final String? highlightedId;
  final Map<String, GlobalKey> entryKeys;

  const _EffectSection({
    required this.title,
    required this.entries,
    required this.highlightedId,
    required this.entryKeys,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              key: entryKeys[entry.id],
              child: _EffectCard(
                tutorialCardKey: TutorialController.instance.keyFor(
                  tutorialAnchorEffectCard(entry.id),
                  scope: TutorialTargetScope.codex,
                ),
                tutorialEquipmentKey: TutorialController.instance.keyFor(
                  tutorialAnchorEffectEquipment(entry.id),
                  scope: TutorialTargetScope.codex,
                ),
                entry: entry,
                isHighlighted: highlightedId == entry.id,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EffectCard extends StatelessWidget {
  final EffectCatalogEntry entry;
  final bool isHighlighted;
  final GlobalKey tutorialCardKey;
  final GlobalKey tutorialEquipmentKey;

  const _EffectCard({
    required this.entry,
    required this.isHighlighted,
    required this.tutorialCardKey,
    required this.tutorialEquipmentKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = l10n.languageCode;
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isHighlighted ? colorScheme.primary : Colors.black12;

    return Container(
      key: tutorialCardKey,
      child: AnimatedContainer(
        key: ValueKey('effect-card-${entry.id}'),
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isHighlighted ? 2 : 1),
          color: isHighlighted
              ? colorScheme.primary.withValues(alpha: 0.08)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  UiMapper.effectIcon(entry.id),
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name.resolve(languageCode),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.effectCategoryLabel(entry.category.name),
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(entry.description.resolve(languageCode)),
            const SizedBox(height: 14),
            Container(
              key: tutorialEquipmentKey,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.effectEquipmentTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.effectEquipmentComingSoon),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectInfoSheet extends StatelessWidget {
  final EffectCatalogEntry entry;

  const _EffectInfoSheet({required this.entry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageCode = l10n.languageCode;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Image.asset(
                    UiMapper.effectIcon(entry.id),
                    width: 28,
                    height: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name.resolve(languageCode),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.effectCategoryLabel(entry.category.name),
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(entry.description.resolve(languageCode)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final parentContext = navigator.context;
                navigator.pop();
                await openEffectCodex(parentContext, initialEffectId: entry.id);
              },
              icon: const Icon(Icons.menu_book_rounded),
              label: Text(l10n.effectCodexTitle),
            ),
          ),
        ],
      ),
    );
  }
}
