class Recipe {
  final String id, name, description, equipment, symbol;
  final int cost, price, seconds, level;
  const Recipe(
    this.id,
    this.name,
    this.description,
    this.equipment,
    this.symbol,
    this.cost,
    this.price,
    this.seconds,
    this.level,
  );
  List<RecipeStep> get steps => switch (id) {
    'latte' => const [
      RecipeStep('coffee', 'Espresso', 4),
      RecipeStep('milk', 'Susu', 4),
    ],
    'mocha' => const [
      RecipeStep('coffee', 'Espresso', 3),
      RecipeStep('chocolate', 'Cokelat', 3),
      RecipeStep('milk', 'Susu', 4),
    ],
    'matcha' => const [
      RecipeStep('tea', 'Matcha', 5),
      RecipeStep('milk', 'Susu', 5),
    ],
    'affogato' => const [
      RecipeStep('coffee', 'Espresso', 5),
      RecipeStep('freezer', 'Es krim', 7),
    ],
    _ => [RecipeStep(equipment, name, seconds)],
  };
  Set<String> get tools => steps.map((s) => s.tool).toSet();
}

class RecipeStep {
  final String tool, ingredient;
  final int seconds;
  const RecipeStep(this.tool, this.ingredient, this.seconds);
}

const recipes = [
  Recipe(
    'espresso',
    'Espresso',
    'Kopi pekat, awal cerita yang baik.',
    'coffee',
    '☕',
    0,
    24,
    5,
    1,
  ),
  Recipe(
    'tea',
    'Teh melati',
    'Ringan dan harum untuk sore yang tenang.',
    'tea',
    '🍵',
    60,
    32,
    6,
    1,
  ),
  Recipe(
    'latte',
    'Caffè latte',
    'Espresso dengan susu lembut.',
    'milk',
    '☕',
    110,
    46,
    8,
    2,
  ),
  Recipe(
    'croissant',
    'Croissant',
    'Pastry hangat berlapis mentega.',
    'oven',
    '🥐',
    150,
    58,
    9,
    2,
  ),
  Recipe(
    'mocha',
    'Mocha',
    'Kopi, cokelat, dan sedikit waktu luang.',
    'milk',
    '🍫',
    180,
    68,
    10,
    3,
  ),
  Recipe(
    'matcha',
    'Matcha latte',
    'Teh hijau dengan susu lembut.',
    'tea',
    '🍵',
    220,
    76,
    10,
    3,
  ),
  Recipe(
    'cake',
    'Cheesecake',
    'Sepotong kecil untuk dirayakan.',
    'oven',
    '🍰',
    300,
    98,
    12,
    4,
  ),
  Recipe(
    'affogato',
    'Affogato',
    'Es krim yang bertemu espresso.',
    'freezer',
    '🍨',
    380,
    115,
    12,
    5,
  ),
];

class Equipment {
  final String id, name, description;
  final int cost, level;
  const Equipment(this.id, this.name, this.description, this.cost, this.level);
}

const equipment = [
  Equipment(
    'coffee',
    'Mesin espresso',
    'Mesin pertamamu. Sudah siap digunakan.',
    0,
    1,
  ),
  Equipment('tea', 'Penyeduh teh', 'Membuka menu teh dan matcha.', 100, 1),
  Equipment('milk', 'Milk steamer', 'Untuk latte dan mocha.', 180, 2),
  Equipment('chocolate', 'Dispenser cokelat', 'Cokelat untuk mocha.', 120, 3),
  Equipment(
    'oven',
    'Oven kecil',
    'Pastry dan kue, hangat setiap hari.',
    220,
    2,
  ),
  Equipment('freezer', 'Freezer', 'Ruang untuk menu penutup dingin.', 450, 5),
];

class Furniture {
  final String id, name, symbol;
  final int cost, charm;
  const Furniture(this.id, this.name, this.symbol, this.cost, this.charm);
}

const furniture = [
  Furniture('table', 'Meja kayu', '🪑', 90, 2),
  Furniture('chair', 'Kursi', '🪑', 35, 1),
  Furniture('counter', 'Meja kerja', '▰', 70, 1),
  Furniture('plant', 'Tanaman', '🌿', 45, 3),
  Furniture('lamp', 'Lampu lantai', '💡', 70, 4),
  Furniture('shelf', 'Rak buku', '📚', 120, 6),
];

class Chapter {
  final String name, title, line, choice, response;
  final int requiredServed, reward;
  const Chapter(
    this.name,
    this.title,
    this.line,
    this.choice,
    this.response,
    this.requiredServed,
    this.reward,
  );
}

const chapters = [
  Chapter(
    'Nara',
    'Tetangga baru',
    'Aku baru pindah ke seberang. Boleh aku duduk dan menggambar di sini?',
    'Tentu. Meja dekat jendela masih kosong.',
    'Terima kasih! Aku akan membuat sketsa kafe ini untukmu.',
    1,
    50,
  ),
  Chapter(
    'Dimas',
    'Secangkir sebelum buka',
    'Toko bukuku sepi belakangan ini. Mungkin orang belum tahu tempatnya.',
    'Bagaimana kalau kita buat pojok baca di sini?',
    'Aku akan membawa beberapa buku besok. Kita mulai dari situ.',
    8,
    100,
  ),
  Chapter(
    'Sari',
    'Resep hari Minggu',
    'Ibu selalu membuat kue saat hujan. Aroma kopi di sini mengingatkanku padanya.',
    'Ceritakan resepnya. Kita coba bersama.',
    'Dengan senang hati. Rahasianya justru sabar menunggu oven.',
    20,
    180,
  ),
  Chapter(
    'Nara',
    'Pameran kecil',
    'Sketsa pengunjung sudah terkumpul. Kita pajang di dinding kafe?',
    'Ayo. Undang semua yang pernah kamu gambar.',
    'Sabtu sore, ya. Aku akan menyiapkan undangannya.',
    40,
    260,
  ),
];

Recipe recipeById(String id) => recipes.firstWhere((r) => r.id == id);
