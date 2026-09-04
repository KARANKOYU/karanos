/* Picker data (business logic — no widget code): the shared emoji /
 * kaomoji / symbol tables for the "Emoji and more" panel
 * (sonraki-isler section 5). THIS IS THE CANONICAL COPY (kavis-common)
 * — appinit scheme: build-packages.sh copies it into the kavis-panel
 * src tree. Emoji names are in the generated emoji_names.vala
 * (gen-emoji-names.py). Kaomoji/symbol lists are static, public-domain
 * strings.
 *
 * Feedback item I: the emoji set covers the eight Unicode groups the
 * users asked for — faces, people, animals, nature, food, activity,
 * travel, objects, symbols, flags — and the symbol tab gained a Greek
 * block. Categories are only ever ADDED here; the N_() markers below
 * keep every caption translatable.
 */

namespace Kavis.PickerData {

    public struct Category {
        public unowned string key;    /* EN msgid — translation in po/ */
        public unowned string items;  /* space-separated items */
    }

    public const Category[] EMOJI = {
            { N_("Smileys"),
              "😀 😃 😄 😁 😆 😅 😂 🤣 🙂 🙃 😉 😊 😇 🥰 😍 🤩 😘 😗 😚 😙 🥲 😋 😛 😜 🤪 😝 🤑 🤗 🤭 🤫 🤔 🤐 🤨 😐 😑 😶 😏 😒 🙄 😬 🤥 😌 😔 😪 🤤 😴 😷 🤒 🤕 🤢 🤮 🤧 🥵 🥶 🥴 😵 🤯 🤠 🥳 😎 🤓 🧐 😕 😟 🙁 😮 😯 😲 😳 🥺 😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 👿 💀 ☠️ 💩 🤡 👹 👺 👻 👽 👾 🤖 😺 😸 😹 😻 😼 😽 🙀 😿 😾" },
            { N_("People"),
              "👋 🤚 ✋ 🖖 👌 🤌 🤏 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ 👍 👎 ✊ 👊 🤛 🤜 👏 🙌 👐 🤲 🤝 🙏 💪 🦾 🦵 🦶 👂 🦻 👃 🧠 🫀 🫁 🦷 🦴 👀 👁️ 👅 👄 ✍️ 💅 🤳 👶 🧒 👦 👧 🧑 👱 👨 🧔 👩 🧓 👴 👵 🙍 🙎 🙅 🙆 💁 🙋 🧏 🙇 🤦 🤷 👮 🕵️ 💂 🥷 👷 🤴 👸 👳 👲 🧕 🤵 👰 🤰 🤱 👼 🎅 🤶 🦸 🦹 🧙 🧚 🧛 🧜 🧝 🧞 🧟 💆 💇 🚶 🧍 🧎 🏃 💃 🕺 👯 🧖 🧗 👫 👬 👭 💏 💑 👪 🗣️ 👤 👥 👣" },
            { N_("Animals"),
              "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐽 🐸 🐵 🙈 🙉 🙊 🐒 🐔 🐧 🐦 🐤 🐣 🐥 🦆 🦢 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🪲 🐛 🦋 🐌 🐞 🐜 🦟 🦗 🕷️ 🕸️ 🦂 🐢 🐍 🦎 🦖 🦕 🐙 🦑 🦐 🦞 🦀 🐡 🐠 🐟 🐬 🐳 🐋 🦈 🐊 🐅 🐆 🦓 🦍 🦧 🐘 🦛 🦏 🐪 🐫 🦒 🦘 🦬 🐃 🐂 🐄 🐎 🐖 🐏 🐑 🦙 🐐 🦌 🐕 🐩 🦮 🐈 🪶 🐓 🦃 🦤 🦚 🦜 🦩 🕊️ 🐇 🦝 🦨 🦡 🦫 🦦 🦥 🐁 🐀 🐿️ 🦔 🐾 🐉 🐲" },
            { N_("Nature"),
              "🌵 🎄 🌲 🌳 🌴 🪵 🌱 🌿 ☘️ 🍀 🎍 🪴 🎋 🍃 🍂 🍁 🍄 🐚 🪨 🌾 💐 🌷 🌹 🥀 🌺 🌸 🌼 🌻 🌞 🌝 🌛 🌜 🌚 🌕 🌖 🌗 🌘 🌑 🌒 🌓 🌔 🌙 🌎 🌍 🌏 🪐 💫 ⭐ 🌟 ✨ ⚡ ☄️ 💥 🔥 🌪️ 🌈 ☀️ 🌤️ ⛅ 🌥️ ☁️ 🌦️ 🌧️ ⛈️ 🌩️ 🌨️ ❄️ ☃️ ⛄ 🌬️ 💨 💧 💦 ☔ ☂️ 🌊 🌫️" },
            { N_("Food"),
              "🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥬 🥒 🌶️ 🫑 🌽 🥕 🫒 🧄 🧅 🥔 🍠 🥐 🥯 🍞 🥖 🥨 🧀 🥚 🍳 🧈 🥞 🧇 🥓 🥩 🍗 🍖 🦴 🌭 🍔 🍟 🍕 🫓 🥪 🥙 🧆 🌮 🌯 🫔 🥗 🥘 🫕 🥫 🍝 🍜 🍲 🍛 🍣 🍱 🥟 🦪 🍤 🍙 🍚 🍘 🍥 🥠 🥮 🍢 🍡 🍧 🍨 🍦 🥧 🧁 🍰 🎂 🍮 🍭 🍬 🍫 🍿 🍩 🍪 🌰 🥜 🍯 🥛 🍼 🫖 ☕ 🍵 🧃 🥤 🧋 🍶 🍺 🍻 🥂 🍷 🥃 🍸 🍹 🧉 🧊 🥢 🍽️ 🍴 🥄" },
            { N_("Activity"),
              "⚽ 🏀 🏈 ⚾ 🥎 🎾 🏐 🏉 🥏 🎱 🪀 🏓 🏸 🏒 🏑 🥍 🏏 🪃 🥅 ⛳ 🪁 🏹 🎣 🤿 🥊 🥋 🎽 🛹 🛼 🛷 ⛸️ 🥌 🎿 ⛷️ 🏂 🪂 🏋️ 🤼 🤸 ⛹️ 🤺 🤾 🏌️ 🏇 🧘 🏄 🏊 🤽 🚣 🚴 🚵 🎪 🤹 🎭 🩰 🎨 🎬 🎤 🎧 🎼 🎹 🥁 🪘 🎷 🎺 🪗 🎸 🪕 🎻 🎲 ♟️ 🎯 🎳 🎮 🕹️ 🎰 🧩 🪅 🪆 🏆 🥇 🥈 🥉 🏅 🎖️ 🏵️ 🎗️ 🎫 🎟️ 🎠 🎡 🎢" },
            { N_("Travel"),
              "🚗 🚕 🚙 🚌 🚎 🏎️ 🚓 🚑 🚒 🚐 🛻 🚚 🚛 🚜 🛵 🏍️ 🚲 🛴 🦽 🦼 🛺 🚨 🚔 🚍 🚘 🚖 🚡 🚠 🚟 🚃 🚋 🚞 🚝 🚄 🚅 🚈 🚂 🚆 🚇 🚊 🚉 ✈️ 🛫 🛬 🛩️ 💺 🚁 🛸 🚀 🛶 ⛵ 🚤 🛥️ 🛳️ ⛴️ 🚢 ⚓ 🪝 ⛽ 🚧 🚦 🚥 🗺️ 🗿 🗽 🗼 🏰 🏯 🏟️ ⛲ ⛱️ 🏖️ 🏝️ 🏜️ 🌋 ⛰️ 🏔️ 🗻 🏕️ ⛺ 🛖 🏠 🏡 🏘️ 🏚️ 🏗️ 🏭 🏢 🏬 🏣 🏤 🏥 🏦 🏨 🏪 🏫 🏩 💒 🏛️ ⛪ 🕌 🕍 🛕 🕋 ⛩️ 🌁 🌃 🏙️ 🌄 🌅 🌆 🌇 🌉 🎑 🗾" },
            { N_("Objects"),
              "⌚ 📱 💻 ⌨️ 🖥️ 🖨️ 🖱️ 🖲️ 💽 💾 💿 📀 📷 📸 📹 🎥 📽️ 🎞️ 📞 ☎️ 📟 📠 📺 📻 🎙️ 🎚️ 🎛️ 🧭 ⏱️ ⏲️ ⏰ 🕰️ ⌛ ⏳ 📡 🔋 🔌 💡 🔦 🕯️ 🧯 🛢️ 💸 💵 💴 💶 💷 💰 💳 🪙 💎 ⚖️ 🧰 🪛 🔧 🔨 ⚒️ 🛠️ ⛏️ 🪚 🔩 ⚙️ 🧱 ⛓️ 🧲 🔫 💣 🧨 🪓 🔪 🗡️ ⚔️ 🛡️ 🚬 ⚰️ ⚱️ 🏺 🔮 📿 🧿 💈 ⚗️ 🔭 🔬 🕳️ 🩹 🩺 💊 💉 🩸 🧬 🦠 🧫 🧪 🌡️ 🧹 🪣 🧺 🧻 🚽 🚰 🚿 🛁 🛀 🧼 🪒 🧽 🧴 🛎️ 🔑 🗝️ 🚪 🪑 🛋️ 🛏️ 🛌 🧸 🖼️ 🛍️ 🛒 🎁 🎈 🎏 🎀 🎊 🎉 🎎 🏮 🎐 🧧 ✉️ 📩 📨 📧 💌 📥 📤 📦 🏷️ 📪 📫 📬 📭 📮 📯 📜 📃 📄 📑 🧾 📊 📈 📉 🗒️ 🗓️ 📆 📅 🗑️ 📇 🗃️ 🗳️ 🗄️ 📋 📁 📂 🗂️ 🗞️ 📰 📓 📔 📒 📕 📗 📘 📙 📚 📖 🔖 🧷 🔗 📎 🖇️ 📐 📏 🧮 📌 📍 ✂️ 🖊️ 🖋️ ✒️ 🖌️ 🖍️ 📝 ✏️ 🔍 🔎 🔏 🔐 🔒 🔓 👓 🕶️ 🥽 🥼 🦺 👔 👕 👖 🧣 🧤 🧥 🧦 👗 👘 🥻 🩱 👙 👚 👛 👜 👝 🎒 👞 👟 🥾 🥿 👠 👡 🩰 👢 👑 👒 🎩 🎓 🧢 ⛑️ 💄 💍 💼" },
            { N_("Symbols"),
              "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ☮️ ✝️ ☪️ 🕉️ ☸️ ✡️ 🔯 🕎 ☯️ ☦️ 🛐 ⛎ ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓ 🆔 ⚛️ ☢️ ☣️ 📴 📳 🈶 🈚 🈸 🈺 🈷️ ✴️ 🆚 💮 🉐 ㊙️ ㊗️ 🈴 🈵 🈹 🈲 🅰️ 🅱️ 🆎 🆑 🅾️ 🆘 ❌ ⭕ 🛑 ⛔ 📛 🚫 💯 💢 ♨️ 🚷 🚯 🚳 🚱 🔞 📵 🚭 ❗ ❕ ❓ ❔ ‼️ ⁉️ 🔅 🔆 〽️ ⚠️ 🚸 🔱 ⚜️ 🔰 ♻️ ✅ 🈯 💹 ❇️ ✳️ ❎ 🌐 💠 Ⓜ️ 🌀 💤 🏧 🚾 ♿ 🅿️ 🈳 🈂️ 🛂 🛃 🛄 🛅 🚹 🚺 🚼 🚻 🚮 🎦 📶 🈁 🔣 ℹ️ 🔤 🔡 🔠 🆖 🆗 🆙 🆒 🆕 🆓 0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟 ▶️ ⏸️ ⏹️ ⏺️ ⏭️ ⏮️ ⏩ ⏪ 🔀 🔁 🔂 ◀️ 🔼 🔽 ⏫ ⏬ ➕ ➖ ➗ ✖️ ♾️ 💲 💱 ™️ ©️ ®️ 〰️ ➰ ➿ 🔚 🔙 🔛 🔝 🔜 ✔️ ☑️ 🔘 🔴 🟠 🟡 🟢 🔵 🟣 🟤 ⚫ ⚪ 🟥 🟧 🟨 🟩 🟦 🟪 🟫 ⬛ ⬜ ◼️ ◻️ ◾ ◽ ▪️ ▫️ 🔶 🔷 🔸 🔹 🔺 🔻 🔲 🔳 ♠️ ♣️ ♥️ ♦️ 🃏 🀄 🎴" },
            { N_("Flags"),
              "🏁 🚩 🎌 🏴 🏳️ 🏳️‍🌈 🏴‍☠️ 🇹🇷 🇦🇿 🇰🇿 🇺🇿 🇹🇲 🇰🇬 🇩🇪 🇺🇸 🇬🇧 🇫🇷 🇪🇸 🇮🇹 🇳🇱 🇧🇪 🇨🇭 🇦🇹 🇵🇹 🇬🇷 🇸🇪 🇳🇴 🇩🇰 🇫🇮 🇮🇸 🇮🇪 🇵🇱 🇨🇿 🇸🇰 🇭🇺 🇷🇴 🇧🇬 🇷🇸 🇭🇷 🇸🇮 🇧🇦 🇲🇰 🇦🇱 🇲🇪 🇽🇰 🇺🇦 🇷🇺 🇧🇾 🇲🇩 🇱🇹 🇱🇻 🇪🇪 🇬🇪 🇦🇲 🇨🇾 🇲🇹 🇱🇺 🇨🇦 🇲🇽 🇧🇷 🇦🇷 🇨🇱 🇨🇴 🇵🇪 🇻🇪 🇨🇺 🇯🇵 🇰🇷 🇨🇳 🇹🇼 🇭🇰 🇮🇳 🇵🇰 🇧🇩 🇱🇰 🇳🇵 🇹🇭 🇻🇳 🇵🇭 🇲🇾 🇸🇬 🇮🇩 🇦🇺 🇳🇿 🇿🇦 🇪🇬 🇲🇦 🇩🇿 🇹🇳 🇱🇾 🇸🇦 🇦🇪 🇶🇦 🇰🇼 🇧🇭 🇴🇲 🇾🇪 🇯🇴 🇱🇧 🇸🇾 🇮🇶 🇮🇷 🇮🇱 🇵🇸 🇳🇬 🇰🇪 🇪🇹 🇬🇭 🇹🇿 🇺🇬 🇸🇳 🇨🇮 🇨🇲 🇸🇴 🇸🇩 🇦🇫 🇲🇳 🇺🇳 🇪🇺" },
    };

    /* xgettext markers (N_ cannot live in a const initializer). public:
     * exists only so xgettext reads it; if private, valac would complain
     * "never used". */
    public void emoji_markers () {
        N_("Smileys"); N_("People"); N_("Animals"); N_("Nature");
        N_("Food"); N_("Activity"); N_("Travel"); N_("Objects");
        N_("Symbols"); N_("Flags");
    }

    /* Kaomoji carry SPACES of their own — "( ͡° ͜ʖ ͡°)" split on a space
     * used to fall apart into four dead buttons — so this table is
     * separated by "|" and read through split_items() below. "|" is
     * reserved: no item may contain it. */
    public const Category[] KAOMOJI = {
        { N_("Happy"),
          "(^_^)|(≧▽≦)|(^o^)/|(o^▽^o)|(⌒▽⌒)☆|٩(◕‿◕)۶|(´｡• ᵕ •｡`)|(＠＾◡＾)|ヽ(・∀・)ﾉ|(￣▽￣)b|(•‿•)|(＾ω＾)|ヽ(>∀<☆)ノ|(¬‿¬)|(๑>ᴗ<๑)" },
        { N_("Sad"),
          "(T_T)|(;_;)|(μ_μ)|(o´_`o)|(╥﹏╥)|(ಥ_ಥ)|(っ˘̩╭╮˘̩)っ|(个_个)|(._.)|(ᵕ_ᵕ)|(っ- ‸ - ς)|(｡•́︿•̀｡)" },
        { N_("Angry"),
          "(>_<)|(¬_¬)|(-_-)|(눈_눈)|(╬Ò﹏Ó)|(¬▂¬)|(╯°□°)╯︵ ┻━┻|ヽ(`Д´)ﾉ|(ノಠ益ಠ)ノ|(҂⌣̀_⌣́)" },
        { N_("Surprised"),
          "(o_O)|(⊙_⊙)|(O_O;)|Σ(°△°)|(ﾟｏﾟ)|w(°ｏ°)w|(⊙▂⊙)|Σ(￣□￣;)|(・_・;)" },
        { N_("Love"),
          "(♡°▽°♡)|(´∀｀)♡|♡(◡‿◡)|(｡♥‿♥｡)|(❤ω❤)|(づ￣ ³￣)づ|(´ε｀ )♡|♡(˃͈ դ ˂͈ᐟ)" },
        { N_("Other"),
          "( ͡° ͜ʖ ͡°)|(•_•)|(⌐■_■)|( ˘▽˘)っ♨|( ･ω･)ﾉ|(ง •̀_•́)ง|¯\\_(ツ)_/¯|(づ｡◕‿‿◕｡)づ|ᕕ( ᐛ )ᕗ|ლ(ಠ益ಠ)ლ|(シ_ _)シ" },
    };

    public void kaomoji_markers () {
        N_("Happy"); N_("Sad"); N_("Angry"); N_("Surprised");
        N_("Love"); N_("Other");
    }

    public const Category[] SYMBOLS = {
        { N_("Math"),
          "± × ÷ ≈ ≠ ≡ ≢ ≤ ≥ ≪ ≫ ∞ √ ∛ ∑ ∏ ∫ ∮ ∂ ∆ ∇ ∈ ∉ ∋ ⊂ ⊃ ⊆ ⊇ ∪ ∩ ∅ ∀ ∃ ∄ ∴ ∵ ∝ ∠ ∡ ⊥ ∥ ⌀ ⊕ ⊗ ¬ ∧ ∨ ⇒ ⇔ ℝ ℕ ℤ ℚ ℂ π µ ‰ ‱ ½ ⅓ ⅔ ¼ ¾ ⅕ ⅛ ⅜ ⅝ ⅞" },
        { N_("Arrows"),
          "← → ↑ ↓ ↔ ↕ ↖ ↗ ↘ ↙ ⇐ ⇒ ⇑ ⇓ ⇔ ⇕ ↩ ↪ ↰ ↱ ↲ ↳ ↺ ↻ ⤴ ⤵ ➜ ➤ ➔ ➞ ⇢ ⇠ ⇡ ⇣ ⌫ ⌦ ⏎ ⇧ ⇪ ⌘ ⌥ ⎋ ⇥ ⌃ ▲ ▼ ◀ ▶" },
        { N_("Currency"),
          "₺ € $ £ ¥ ¢ ₹ ₽ ₩ ฿ ¤ ₪ ₫ ₴ ₦ ₱ ₲ ₡ ₸ ₮ ₾ ₼ ₭ ₨ ﷼" },
        { N_("Greek"),
          "α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ ς τ υ φ χ ψ ω Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π Ρ Σ Τ Υ Φ Χ Ψ Ω ϑ ϕ ϖ ϱ" },
        { N_("Super/subscript"),
          "⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ⁺ ⁻ ⁼ ⁽ ⁾ ⁿ ⁱ ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ₊ ₋ ₌ ₍ ₎ ₐ ₑ ₒ ₓ ₕ ₖ ₗ ₘ ₙ ₚ ₛ ₜ" },
        { N_("Accented letters"),
          "é è ê ë á à â ä ã å í ì î ï ó ò ô ö õ ú ù û ü ñ ç ß æ ø ı İ ğ ş Ç Ğ Ş Ö Ü É Á À Â Ä Ã Å Í Î Ï Ó Ô Õ Ú Û Ñ Æ Ø ý ÿ œ Œ đ ł ř š ž č ę ą ń" },
        { N_("Punctuation"),
          "— – … « » „ “ ” ‘ ’ ‚ ‹ › ¡ ¿ § ¶ † ‡ • · ° ′ ″ ‽ ※ ‾ ⁂ ¦ ‖ № ℮ ☞ ☜ ✓ ✔ ✗ ✘ ★ ☆ ♪ ♫ ♬ ♭ ♮ ♯ ☑ ☐ ☒" },
    };

    /* Split one category's item string. The emoji and symbol tables are
     * space separated (no item contains a space); the kaomoji table is
     * "|" separated because kaomoji do. */
    public string[] split_items (string items) {
        string[] result = {};
        foreach (unowned string item in
                 items.split (("|" in items) ? "|" : " ")) {
            if (item.strip () != "") {
                result += item;
            }
        }
        return result;
    }

    public void symbol_markers () {
        N_("Math"); N_("Arrows"); N_("Currency"); N_("Greek");
        N_("Super/subscript"); N_("Accented letters");
        N_("Punctuation");
    }
}
