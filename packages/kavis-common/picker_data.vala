/* Picker data (business logic — no widget code): the shared emoji /
 * kaomoji / symbol tables for the "Emoji and more" panel
 * (sonraki-isler bölüm 5). KANONİK KOPYA BURASI (kavis-common) —
 * appinit düzeni: build-packages.sh kavis-panel src ağacına kopyalar.
 * Emoji adları üretilen emoji_names.vala'da (gen-emoji-adlari.py).
 * Kaomoji/sembol listeleri statik ve halk malı dizgiler.
 */

namespace Kavis.PickerData {

    public struct Category {
        public unowned string key;    /* EN msgid — çeviri po/ */
        public unowned string items;  /* boşlukla ayrılmış öğeler */
    }

    public const Category[] EMOJI = {
            { N_("Smileys"),
              "😀 😃 😄 😁 😆 😅 😂 🤣 🙂 😉 😊 😍 🥰 😘 😜 🤪 🤔 🤨 😐 😑 😶 🙄 😏 😣 😥 😮 🤐 😯 😪 😫 🥱 😴 😌 😛 😝 🤤 😒 😓 😔 😕 🙃 🤑 😲 🙁 😖 😞 😟 😤 😢 😭 😦 😧 😨 😩 🤯 😬 😰 😱 🥵 🥶 😳 🤗 🤭 🥺 😇 🤠 🤡 🤥 🤫 🧐 🤓 😈 👿 💀 👻 👽 🤖 💩" },
            { N_("People"),
              "👋 🤚 ✋ 🖖 👌 🤌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ 👍 👎 ✊ 👊 🤛 🤜 👏 🙌 👐 🤲 🤝 🙏 💪 🦾 ✍️ 💅 🤳 👶 🧒 👦 👧 🧑 👱 👨 🧔 👩 🧓 👴 👵 🙍 🙎 🙅 🙆 💁 🙋 🧏 🙇 🤦 🤷 👮 💂 🥷 👷 🤴 👸 👳 👲 🧕 🤵 👰 🤰 🤱 👼 🎅 🤶" },
            { N_("Nature"),
              "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🐛 🦋 🐌 🐞 🐜 🪲 🐢 🐍 🦎 🐙 🦑 🦐 🦞 🦀 🐡 🐠 🐟 🐬 🐳 🐋 🦈 🐊 🌵 🎄 🌲 🌳 🌴 🌱 🌿 ☘️ 🍀 🎋 🍂 🍁 🌾 🌺 🌻 🌹 🌷 🌸 💐 🌞 🌝 🌛 ⭐ 🌟 ⚡ 🔥 🌈 ☀️ ⛅ ☁️ 🌧️ ⛈️ ❄️ ☃️ 💧 🌊" },
            { N_("Food"),
              "🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥬 🥒 🌶️ 🫑 🌽 🥕 🧄 🧅 🥔 🍠 🥐 🥯 🍞 🥖 🥨 🧀 🥚 🍳 🧈 🥞 🧇 🥓 🥩 🍗 🍖 🌭 🍔 🍟 🍕 🥪 🥙 🧆 🌮 🌯 🥗 🥘 🍝 🍜 🍲 🍛 🍣 🍱 🥟 🦪 🍤 🍙 🍚 🍘 🍥 🥠 🍢 🍡 🍧 🍨 🍦 🥧 🧁 🍰 🎂 🍮 🍭 🍬 🍫 🍿 🍩 🍪 ☕ 🍵 🥤 🧃 🍺 🍻 🥂 🍷" },
            { N_("Travel"),
              "🚗 🚕 🚙 🚌 🚎 🏎️ 🚓 🚑 🚒 🚐 🛻 🚚 🚛 🚜 🛵 🏍️ 🚲 🛴 🚨 🚔 🚍 🚘 🚖 🚡 🚠 🚟 🚃 🚋 🚞 🚝 🚄 🚅 🚈 🚂 🚆 🚇 🚊 🚉 ✈️ 🛫 🛬 🛩️ 🚁 🛸 🚀 🛶 ⛵ 🚤 🛥️ 🛳️ ⛴️ 🚢 ⚓ 🗺️ 🗿 🗽 🗼 🏰 🏯 🏟️ 🎡 🎢 🎠 ⛲ ⛱️ 🏖️ 🏝️ 🏜️ 🌋 ⛰️ 🏔️ 🗻 🏕️ ⛺ 🏠 🏡 🏢 🏬 🏥 🏦 🏨 🏪 🏫 🏛️ ⛪ 🕌 🕍 🛕" },
            { N_("Objects"),
              "⌚ 📱 💻 ⌨️ 🖥️ 🖨️ 🖱️ 🖲️ 🕹️ 💽 💾 💿 📀 📷 📸 📹 🎥 📽️ 🎞️ 📞 ☎️ 📟 📠 📺 📻 🎙️ 🎚️ 🎛️ 🧭 ⏱️ ⏲️ ⏰ 🕰️ ⌛ ⏳ 📡 🔋 🔌 💡 🔦 🕯️ 🧯 🛢️ 💸 💵 💴 💶 💷 💰 💳 💎 ⚖️ 🧰 🔧 🔨 ⚒️ 🛠️ ⛏️ 🔩 ⚙️ 🧱 ⛓️ 🧲 🔫 💣 🧨 🔪 🗡️ ⚔️ 🛡️ 🚬 ⚰️ ⚱️ 🏺 🔮 📿 🧿 💈 ⚗️ 🔭 🔬 🕳️ 💊 💉 🩸 🧬 🦠 🧫 🧪 🌡️ 🧹 🧺 🧻 🚽 🚰 🚿 🛁 🛀 🧼 🪒 🧽 🧴 🛎️ 🔑 🗝️ 🚪 🪑 🛋️ 🛏️ 🛌 🧸 🖼️ 🛍️ 🛒 🎁 🎈 🎏 🎀 🎊 🎉 🎎 🏮 🎐 ✉️ 📩 📨 📧 💌 📥 📤 📦 🏷️ 📪 📫 📬 📭 📮 📯 📜 📃 📄 📑 🧾 📊 📈 📉 🗒️ 🗓️ 📆 📅 🗑️ 📇 🗃️ 🗳️ 🗄️ 📋 📁 📂 🗂️ 🗞️ 📰 📓 📔 📒 📕 📗 📘 📙 📚 📖 🔖 🧷 🔗 📎 🖇️ 📐 📏 🧮 📌 📍 ✂️ 🖊️ 🖋️ ✒️ 🖌️ 🖍️ 📝 ✏️ 🔍 🔎 🔏 🔐 🔒 🔓" },
            { N_("Symbols"),
              "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ☮️ ✝️ ☪️ 🕉️ ☸️ ✡️ 🔯 🕎 ☯️ ☦️ 🛐 ⛎ ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓ 🆔 ⚛️ ☢️ ☣️ 📴 📳 🈶 🈚 🈸 🈺 🈷️ ✴️ 🆚 💮 🉐 ㊙️ ㊗️ 🈴 🈵 🈹 🈲 🅰️ 🅱️ 🆎 🆑 🅾️ 🆘 ❌ ⭕ 🛑 ⛔ 📛 🚫 💯 💢 ♨️ 🚷 🚯 🚳 🚱 🔞 📵 🚭 ❗ ❕ ❓ ❔ ‼️ ⁉️ 🔅 🔆 〽️ ⚠️ 🚸 🔱 ⚜️ 🔰 ♻️ ✅ 🈯 💹 ❇️ ✳️ ❎ 🌐 💠 Ⓜ️ 🌀 💤 🏧 🚾 ♿ 🅿️ 🈳 🈂️ 🛂 🛃 🛄 🛅 🚹 🚺 🚼 🚻 🚮 🎦 📶 🈁 🔣 ℹ️ 🔤 🔡 🔠 🆖 🆗 🆙 🆒 🆕 🆓 0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟" },
    };

    /* xgettext markers (N_ const başlatıcıda duramaz). public: yalnız
     * xgettext okusun diye vardır; private olsaydı valac "never used"
     * derdi. */
    public void emoji_markers () {
        N_("Smileys"); N_("People"); N_("Nature"); N_("Food");
        N_("Travel"); N_("Objects"); N_("Symbols");
    }

    public const Category[] KAOMOJI = {
        { N_("Happy"),
          "(^_^) (≧▽≦) (^o^)/ (o^▽^o) (⌒▽⌒)☆ ٩(◕‿◕)۶ (´｡• ᵕ •｡`) (＠＾◡＾) ヽ(・∀・)ﾉ (￣▽￣)b" },
        { N_("Sad"),
          "(T_T) (;_;) (μ_μ) (o´_`o) (╥﹏╥) (ಥ_ಥ) (っ˘̩╭╮˘̩)っ (个_个)" },
        { N_("Angry"),
          "(>_<) (¬_¬) (-_-) (눈_눈) (╬Ò﹏Ó) (¬▂¬)" },
        { N_("Surprised"),
          "(o_O) (⊙_⊙) (O_O;) Σ(°△°) (ﾟｏﾟ) w(°ｏ°)w" },
        { N_("Love"),
          "(♡°▽°♡) (´∀｀)♡ ♡(◡‿◡) (｡♥‿♥｡) (❤ω❤)" },
        { N_("Other"),
          "( ͡° ͜ʖ ͡°) (•_•) (⌐■_■) ( ˘▽˘)っ♨ ( ･ω･)ﾉ (ง •̀_•́)ง" },
    };

    public void kaomoji_markers () {
        N_("Happy"); N_("Sad"); N_("Angry"); N_("Surprised");
        N_("Love"); N_("Other");
    }

    public const Category[] SYMBOLS = {
        { N_("Currency"),
          "₺ € $ £ ¥ ¢ ₹ ₽ ₩ ฿ ¤" },
        { N_("Arrows"),
          "← → ↑ ↓ ↔ ↕ ⇐ ⇒ ⇔ ↩ ↪ ⤴ ⤵ ➜ ➤" },
        { N_("Punctuation"),
          "— – … « » „ “ ” ‘ ’ ¡ ¿ § ¶ † ‡ • · ° ′ ″ ‽" },
        { N_("Math"),
          "± × ÷ ≈ ≠ ≡ ≤ ≥ ∞ √ ∑ ∏ ∫ ∂ ∆ π µ Ω ‰ ½ ⅓ ¼ ¾ ⅛" },
        { N_("Accented letters"),
          "é è ê ë á à â ä ã å í ì î ï ó ò ô ö õ ú ù û ü ñ ç ß æ ø ı İ ğ ş" },
        { N_("Super/subscript"),
          "⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ⁺ ⁻ ⁿ ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ₊ ₋" },
    };

    public void symbol_markers () {
        N_("Currency"); N_("Arrows"); N_("Punctuation"); N_("Math");
        N_("Accented letters"); N_("Super/subscript");
    }
}
