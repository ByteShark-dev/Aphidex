import '../models/enemy.dart';

enum EffectCategory { damage, element, status }

class EffectCatalogEntry {
  final String id;
  final EffectCategory category;
  final LocalizedText name;
  final LocalizedText description;

  const EffectCatalogEntry({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
  });
}

String canonicalEffectId(String id) {
  final normalized = id.trim().toLowerCase();
  switch (normalized) {
    case 'gas_hazard':
      return 'gas';
    case 'electricity':
    case 'electric':
      return 'shock';
    case 'burn':
      return 'burning';
    case 'chilling':
      return 'chill';
    case 'heat':
      return 'sizzle';
    case 'tang':
    case 'tang buildup':
      return 'tang_buildup';
    case 'stabbing_arrows_only':
    case 'stabbing_bows_and_spears':
    case 'stabbing_arrows':
    case 'stabbing_arrrows':
    case 'projectile_piercing':
      return 'stabbing';
    default:
      return normalized;
  }
}

String normalizedTechnicalEffectId(String id) {
  final canonical = canonicalEffectId(id);
  if (effectCatalogEntries.any((entry) => entry.id == canonical)) {
    return canonical;
  }
  final value = canonical.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  if (value.contains('venom')) return 'venom';
  if (value.contains('poison') || value.contains('toxin')) return 'poison';
  if (value.contains('corrosion') || value.contains('tang')) {
    return 'tang_buildup';
  }
  if (value.contains('acid')) return 'acid';
  if (value.contains('chill') ||
      value.contains('frost') ||
      value.contains('freeze')) {
    return 'chill';
  }
  if (value.contains('sizzle')) return 'sizzle';
  if (value.contains('burn') || value.contains('fire')) return 'burning';
  if (value.contains('bleed')) return 'bleed';
  if (value.contains('gas')) return 'gas';
  if (value.contains('shock') || value.contains('electric')) return 'shock';
  if (value.contains('infection')) return 'infection';
  if (value.contains('spicy')) return 'spicy';
  if (value.contains('fresh') || value.contains('mint')) return 'fresh';
  if (value.contains('sour')) return 'sour';
  if (value.contains('salty') || value.contains('salt')) return 'salty';
  return canonical;
}

EffectCatalogEntry? effectCatalogEntryById(String id) {
  final canonicalId = canonicalEffectId(id);
  for (final entry in effectCatalogEntries) {
    if (entry.id == canonicalId) {
      return entry;
    }
  }
  return null;
}

const effectCatalogEntries = <EffectCatalogEntry>[
  EffectCatalogEntry(
    id: 'slashing',
    category: EffectCategory.damage,
    name: LocalizedText(es: 'Tajo', en: 'Slashing', ru: 'Режущий'),
    description: LocalizedText(
      es: 'Daño de hojas o filos que cortan de lado.',
      en: 'Damage from blades or edges that cut across the target.',
      ru: 'Урон от лезвий или кромок, которые режут цель сбоку.',
    ),
  ),
  EffectCatalogEntry(
    id: 'chopping',
    category: EffectCategory.damage,
    name: LocalizedText(es: 'Corte', en: 'Chopping', ru: 'Рубящий'),
    description: LocalizedText(
      es: 'Daño pesado de hachas o golpes que parten material duro.',
      en: 'Heavy axe-like damage that chops through tougher material.',
      ru: 'Тяжёлый урон топорного типа, который рубит прочный материал.',
    ),
  ),
  EffectCatalogEntry(
    id: 'busting',
    category: EffectCategory.damage,
    name: LocalizedText(es: 'Aplastante', en: 'Busting', ru: 'Дробящий'),
    description: LocalizedText(
      es: 'Daño contundente que rompe, aturde o aplasta.',
      en: 'Blunt impact damage that breaks, staggers, or crushes.',
      ru: 'Тупой ударный урон, который ломает, шатает или дробит.',
    ),
  ),
  EffectCatalogEntry(
    id: 'stabbing',
    category: EffectCategory.damage,
    name: LocalizedText(es: 'Perforación', en: 'Stabbing', ru: 'Колющий'),
    description: LocalizedText(
      es: 'Daño de puntas y estocadas que perforan un punto concreto.',
      en: 'Piercing damage from points and thrusts that hit a narrow spot.',
      ru: 'Колющий урон от острых наконечников и выпадов в узкую точку.',
    ),
  ),
  EffectCatalogEntry(
    id: 'generic',
    category: EffectCategory.damage,
    name: LocalizedText(
      es: 'Daño genérico',
      en: 'Generic damage',
      ru: 'Обычный урон',
    ),
    description: LocalizedText(
      es: 'Daño neutral sin afinidad especial de arma o elemento.',
      en: 'Neutral damage with no special weapon or element affinity.',
      ru: 'Нейтральный урон без особой связи с оружием или стихией.',
    ),
  ),
  EffectCatalogEntry(
    id: 'explosive',
    category: EffectCategory.damage,
    name: LocalizedText(es: 'Explosivo', en: 'Explosive', ru: 'Взрывной'),
    description: LocalizedText(
      es: 'Daño de explosión o impacto en área.',
      en: 'Explosion or blast damage that hits an area.',
      ru: 'Урон от взрыва или ударной волны по области.',
    ),
  ),
  EffectCatalogEntry(
    id: 'water',
    category: EffectCategory.damage,
    name: LocalizedText(es: 'Agua', en: 'Water', ru: 'Вода'),
    description: LocalizedText(
      es: 'Daño o afinidad de agua que castiga objetivos vulnerables a la humedad o presión.',
      en: 'Water-aligned damage or affinity that punishes targets vulnerable to moisture or pressure.',
      ru: 'Водный тип урона или стихия, эффективная против целей, уязвимых к влаге или давлению.',
    ),
  ),
  EffectCatalogEntry(
    id: 'fresh',
    category: EffectCategory.element,
    name: LocalizedText(es: 'Fresco', en: 'Fresh', ru: 'Свежесть'),
    description: LocalizedText(
      es: 'Elemento fresco; suele contrarrestar calor, podredumbre o fuego.',
      en: 'Fresh element; often counters heat, rot, or fire-based threats.',
      ru: 'Стихия свежести; часто противостоит жару, гнили или огню.',
    ),
  ),
  EffectCatalogEntry(
    id: 'chill',
    category: EffectCategory.status,
    name: LocalizedText(
      es: 'Congelamiento',
      en: 'Chill buildup',
      ru: '\u041d\u0430\u043a\u043e\u043f\u043b\u0435\u043d\u0438\u0435 \u0445\u043e\u043b\u043e\u0434\u0430',
    ),
    description: LocalizedText(
      es: 'Acumulación de frío que ralentiza y castiga a criaturas vulnerables a este estado.',
      en: 'Cold buildup that slows targets down and punishes creatures vulnerable to freezing effects.',
      ru: '\u041d\u0430\u043a\u043e\u043f\u043b\u0435\u043d\u0438\u0435 \u0445\u043e\u043b\u043e\u0434\u0430, \u043a\u043e\u0442\u043e\u0440\u043e\u0435 \u0437\u0430\u043c\u0435\u0434\u043b\u044f\u0435\u0442 \u0446\u0435\u043b\u044c \u0438 \u043e\u0441\u043e\u0431\u0435\u043d\u043d\u043e \u043e\u043f\u0430\u0441\u043d\u043e \u0434\u043b\u044f \u0441\u0443\u0449\u0435\u0441\u0442\u0432, \u0443\u044f\u0437\u0432\u0438\u043c\u044b\u0445 \u043a \u0437\u0430\u043c\u043e\u0440\u043e\u0437\u043a\u0435.',
    ),
  ),
  EffectCatalogEntry(
    id: 'spicy',
    category: EffectCategory.element,
    name: LocalizedText(es: 'Picante', en: 'Spicy', ru: 'Острый'),
    description: LocalizedText(
      es: 'Elemento de calor intenso con daño tipo llama o quemadura.',
      en: 'Heat-heavy element with flame-like or burning damage.',
      ru: 'Стихия сильного жара с уроном, похожим на пламя или ожог.',
    ),
  ),
  EffectCatalogEntry(
    id: 'salty',
    category: EffectCategory.element,
    name: LocalizedText(es: 'Salado', en: 'Salty', ru: 'Солёный'),
    description: LocalizedText(
      es: 'Elemento salado; destaca contra criaturas y materiales concretos.',
      en: 'Salty element that is especially effective against specific targets.',
      ru: 'Солёная стихия, особенно эффективная против некоторых целей.',
    ),
  ),
  EffectCatalogEntry(
    id: 'sour',
    category: EffectCategory.element,
    name: LocalizedText(es: 'Ácido', en: 'Sour', ru: 'Кислый'),
    description: LocalizedText(
      es: 'Elemento ácido o eléctrico que descarga energía inestable.',
      en: 'Acidic or electric element that releases unstable energy.',
      ru: 'Кислотная или электрическая стихия с нестабильным зарядом.',
    ),
  ),
  EffectCatalogEntry(
    id: 'acid',
    category: EffectCategory.status,
    name: LocalizedText(es: 'Ácido', en: 'Acid', ru: 'Кислота'),
    description: LocalizedText(
      es: 'Efecto corrosivo que desgasta al objetivo.',
      en: 'A corrosive effect that wears the target down.',
      ru: 'Коррозионный эффект, постепенно ослабляющий цель.',
    ),
  ),
  EffectCatalogEntry(
    id: 'venom',
    category: EffectCategory.status,
    name: LocalizedText(es: 'Veneno letal', en: 'Venom', ru: 'Яд'),
    description: LocalizedText(
      es: 'Toxina potente de colmillos o aguijones que drena vida rápidamente.',
      en: 'A potent toxin from fangs or stingers that drains health quickly.',
      ru: 'Мощный токсин от клыков или жал, быстро снижающий здоровье.',
    ),
  ),
  EffectCatalogEntry(
    id: 'poison',
    category: EffectCategory.status,
    name: LocalizedText(es: 'Envenenamiento', en: 'Poison', ru: 'Отравление'),
    description: LocalizedText(
      es: 'Estado dañino que causa daño continuo durante un tiempo.',
      en: 'A harmful status that deals damage over time.',
      ru: 'Негативный эффект, который наносит урон с течением времени.',
    ),
  ),
  EffectCatalogEntry(
    id: 'gas',
    category: EffectCategory.status,
    name: LocalizedText(es: 'Gas', en: 'Gas', ru: 'Газ'),
    description: LocalizedText(
      es: 'Nube tóxica que daña mientras permaneces dentro.',
      en: 'A toxic cloud that damages anything staying inside it.',
      ru: 'Токсичное облако, которое наносит урон, пока цель остаётся внутри.',
    ),
  ),
  EffectCatalogEntry(
    id: 'bleed',
    category: EffectCategory.status,
    name: LocalizedText(es: 'Sangrado', en: 'Bleed', ru: 'Кровотечение'),
    description: LocalizedText(
      es: 'Herida abierta que provoca pérdida gradual de vida.',
      en: 'An open wound effect that causes gradual health loss.',
      ru: 'Эффект открытой раны, вызывающий постепенную потерю здоровья.',
    ),
  ),
  EffectCatalogEntry(
    id: 'dust',
    category: EffectCategory.status,
    name: LocalizedText(es: 'Polvo', en: 'Dust', ru: 'Пыль'),
    description: LocalizedText(
      es: 'Nube de polvo o partículas que afecta y daña al objetivo.',
      en: 'A cloud of dust or particles that hinders and harms the target.',
      ru: 'Облако пыли или частиц, которое мешает и вредит цели.',
    ),
  ),
  EffectCatalogEntry(
    id: 'shock',
    category: EffectCategory.status,
    name: LocalizedText(es: 'Electricidad', en: 'Shock', ru: 'Электрошок'),
    description: LocalizedText(
      es: 'Descarga eléctrica que daña y puede entumecer o aturdir.',
      en: 'An electric discharge that damages and can numb or stun.',
      ru: 'Электрический разряд, который наносит урон и может оглушить.',
    ),
  ),
  EffectCatalogEntry(
    id: 'burning',
    category: EffectCategory.status,
    name: LocalizedText(es: 'Quemaduras', en: 'Burning', ru: 'Горение'),
    description: LocalizedText(
      es: 'Estado de fuego o calor que sigue dañando por un tiempo.',
      en: 'A fire or heat status that keeps dealing damage for a while.',
      ru: 'Эффект огня или жара, который продолжает наносить урон некоторое время.',
    ),
  ),
  EffectCatalogEntry(
    id: 'sizzle',
    category: EffectCategory.status,
    name: LocalizedText(
      es: 'Calor',
      en: 'Sizzle',
      ru: '\u041f\u0435\u0440\u0435\u0433\u0440\u0435\u0432',
    ),
    description: LocalizedText(
      es: 'Acumulaci\u00f3n de calor abrasador que da\u00f1a con el tiempo y presiona constantemente al objetivo.',
      en: 'Scorching heat buildup that deals sustained damage over time and keeps pressure on the target.',
      ru: '\u041d\u0430\u043a\u043e\u043f\u043b\u0435\u043d\u0438\u0435 \u043f\u0430\u043b\u044f\u0449\u0435\u0433\u043e \u0436\u0430\u0440\u0430, \u043a\u043e\u0442\u043e\u0440\u043e\u0435 \u043f\u043e\u0441\u0442\u0435\u043f\u0435\u043d\u043d\u043e \u043d\u0430\u043d\u043e\u0441\u0438\u0442 \u0443\u0440\u043e\u043d \u0438 \u043f\u043e\u0441\u0442\u043e\u044f\u043d\u043d\u043e \u0434\u0430\u0432\u0438\u0442 \u043d\u0430 \u0446\u0435\u043b\u044c.',
    ),
  ),
  EffectCatalogEntry(
    id: 'tang_buildup',
    category: EffectCategory.status,
    name: LocalizedText(
      es: 'Corrosión',
      en: 'Tang buildup',
      ru: 'Накопление Tang',
    ),
    description: LocalizedText(
      es: 'Acumulación especial que algunas criaturas pueden resistir o ignorar por completo.',
      en: 'A special buildup effect that some creatures can resist or ignore completely.',
      ru: 'Особый эффект накопления, которому некоторые существа могут сопротивляться или полностью его игнорировать.',
    ),
  ),
  EffectCatalogEntry(
    id: 'infection',
    category: EffectCategory.status,
    name: LocalizedText(es: 'Infección', en: 'Infection', ru: 'Инфекция'),
    description: LocalizedText(
      es: 'Estado infeccioso ligado a esporas, hongos o corrupción.',
      en: 'An infection status tied to spores, fungus, or corruption.',
      ru: 'Инфекционный эффект, связанный со спорами, грибком или порчей.',
    ),
  ),
];
