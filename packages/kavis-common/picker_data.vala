/* Picker data (business logic — no widget code): the shared emoji /
 * kaomoji / symbol tables for the "Emoji and more" panel
 * (sonraki-isler section 5). THIS IS THE CANONICAL COPY (kavis-common)
 * — appinit scheme: build-packages.sh copies it into the kavis-panel
 * src tree. Emoji names are in the generated emoji_names.vala
 * (gen-emoji-names.py). Kaomoji/symbol lists are static, public-domain
 * strings.
 */

namespace Kavis.PickerData {

    public struct Category {
        public unowned string key;    /* EN msgid — translation in po/ */
        public unowned string items;  /* space-separated items */
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

    /* xgettext markers (N_ cannot live in a const initializer). public:
     * exists only so xgettext reads it; if private, valac would complain
     * "never used". */
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
