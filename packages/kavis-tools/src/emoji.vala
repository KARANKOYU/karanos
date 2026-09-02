/* Emoji picker (madde 7 + Grup D fix 4): search box on top (focused
 * on open, filters as you type against the generated English name
 * table — emoji_names.vala; Turkish words can be added to that table),
 * an "All" tab first, a "Recent" tab fed from
 * ~/.config/kavis/emoji-recent, then the category tabs. Click to copy
 * and paste into the previously focused window when xdotool is around
 * (same mechanism as the clipboard popup).
 */

namespace Kavis.Tools {

    public class EmojiWindow : Gtk.Window {

        private struct Category {
            public unowned string key;
            public unowned string emoji;
        }

        private const Category[] CATEGORIES = {
            { "emoji.cat_smileys",
              "😀 😃 😄 😁 😆 😅 😂 🤣 🙂 😉 😊 😍 🥰 😘 😜 🤪 🤔 🤨 😐 😑 😶 🙄 😏 😣 😥 😮 🤐 😯 😪 😫 🥱 😴 😌 😛 😝 🤤 😒 😓 😔 😕 🙃 🤑 😲 🙁 😖 😞 😟 😤 😢 😭 😦 😧 😨 😩 🤯 😬 😰 😱 🥵 🥶 😳 🤗 🤭 🥺 😇 🤠 🤡 🤥 🤫 🧐 🤓 😈 👿 💀 👻 👽 🤖 💩" },
            { "emoji.cat_people",
              "👋 🤚 ✋ 🖖 👌 🤌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ 👍 👎 ✊ 👊 🤛 🤜 👏 🙌 👐 🤲 🤝 🙏 💪 🦾 ✍️ 💅 🤳 👶 🧒 👦 👧 🧑 👱 👨 🧔 👩 🧓 👴 👵 🙍 🙎 🙅 🙆 💁 🙋 🧏 🙇 🤦 🤷 👮 💂 🥷 👷 🤴 👸 👳 👲 🧕 🤵 👰 🤰 🤱 👼 🎅 🤶" },
            { "emoji.cat_nature",
              "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🐛 🦋 🐌 🐞 🐜 🪲 🐢 🐍 🦎 🐙 🦑 🦐 🦞 🦀 🐡 🐠 🐟 🐬 🐳 🐋 🦈 🐊 🌵 🎄 🌲 🌳 🌴 🌱 🌿 ☘️ 🍀 🎋 🍂 🍁 🌾 🌺 🌻 🌹 🌷 🌸 💐 🌞 🌝 🌛 ⭐ 🌟 ⚡ 🔥 🌈 ☀️ ⛅ ☁️ 🌧️ ⛈️ ❄️ ☃️ 💧 🌊" },
            { "emoji.cat_food",
              "🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥬 🥒 🌶️ 🫑 🌽 🥕 🧄 🧅 🥔 🍠 🥐 🥯 🍞 🥖 🥨 🧀 🥚 🍳 🧈 🥞 🧇 🥓 🥩 🍗 🍖 🌭 🍔 🍟 🍕 🥪 🥙 🧆 🌮 🌯 🥗 🥘 🍝 🍜 🍲 🍛 🍣 🍱 🥟 🦪 🍤 🍙 🍚 🍘 🍥 🥠 🍢 🍡 🍧 🍨 🍦 🥧 🧁 🍰 🎂 🍮 🍭 🍬 🍫 🍿 🍩 🍪 ☕ 🍵 🥤 🧃 🍺 🍻 🥂 🍷" },
            { "emoji.cat_travel",
              "🚗 🚕 🚙 🚌 🚎 🏎️ 🚓 🚑 🚒 🚐 🛻 🚚 🚛 🚜 🛵 🏍️ 🚲 🛴 🚨 🚔 🚍 🚘 🚖 🚡 🚠 🚟 🚃 🚋 🚞 🚝 🚄 🚅 🚈 🚂 🚆 🚇 🚊 🚉 ✈️ 🛫 🛬 🛩️ 🚁 🛸 🚀 🛶 ⛵ 🚤 🛥️ 🛳️ ⛴️ 🚢 ⚓ 🗺️ 🗿 🗽 🗼 🏰 🏯 🏟️ 🎡 🎢 🎠 ⛲ ⛱️ 🏖️ 🏝️ 🏜️ 🌋 ⛰️ 🏔️ 🗻 🏕️ ⛺ 🏠 🏡 🏢 🏬 🏥 🏦 🏨 🏪 🏫 🏛️ ⛪ 🕌 🕍 🛕" },
            { "emoji.cat_objects",
              "⌚ 📱 💻 ⌨️ 🖥️ 🖨️ 🖱️ 🖲️ 🕹️ 💽 💾 💿 📀 📷 📸 📹 🎥 📽️ 🎞️ 📞 ☎️ 📟 📠 📺 📻 🎙️ 🎚️ 🎛️ 🧭 ⏱️ ⏲️ ⏰ 🕰️ ⌛ ⏳ 📡 🔋 🔌 💡 🔦 🕯️ 🧯 🛢️ 💸 💵 💴 💶 💷 💰 💳 💎 ⚖️ 🧰 🔧 🔨 ⚒️ 🛠️ ⛏️ 🔩 ⚙️ 🧱 ⛓️ 🧲 🔫 💣 🧨 🔪 🗡️ ⚔️ 🛡️ 🚬 ⚰️ ⚱️ 🏺 🔮 📿 🧿 💈 ⚗️ 🔭 🔬 🕳️ 💊 💉 🩸 🧬 🦠 🧫 🧪 🌡️ 🧹 🧺 🧻 🚽 🚰 🚿 🛁 🛀 🧼 🪒 🧽 🧴 🛎️ 🔑 🗝️ 🚪 🪑 🛋️ 🛏️ 🛌 🧸 🖼️ 🛍️ 🛒 🎁 🎈 🎏 🎀 🎊 🎉 🎎 🏮 🎐 ✉️ 📩 📨 📧 💌 📥 📤 📦 🏷️ 📪 📫 📬 📭 📮 📯 📜 📃 📄 📑 🧾 📊 📈 📉 🗒️ 🗓️ 📆 📅 🗑️ 📇 🗃️ 🗳️ 🗄️ 📋 📁 📂 🗂️ 🗞️ 📰 📓 📔 📒 📕 📗 📘 📙 📚 📖 🔖 🧷 🔗 📎 🖇️ 📐 📏 🧮 📌 📍 ✂️ 🖊️ 🖋️ ✒️ 🖌️ 🖍️ 📝 ✏️ 🔍 🔎 🔏 🔐 🔒 🔓" },
            { "emoji.cat_symbols",
              "❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ☮️ ✝️ ☪️ 🕉️ ☸️ ✡️ 🔯 🕎 ☯️ ☦️ 🛐 ⛎ ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓ 🆔 ⚛️ ☢️ ☣️ 📴 📳 🈶 🈚 🈸 🈺 🈷️ ✴️ 🆚 💮 🉐 ㊙️ ㊗️ 🈴 🈵 🈹 🈲 🅰️ 🅱️ 🆎 🆑 🅾️ 🆘 ❌ ⭕ 🛑 ⛔ 📛 🚫 💯 💢 ♨️ 🚷 🚯 🚳 🚱 🔞 📵 🚭 ❗ ❕ ❓ ❔ ‼️ ⁉️ 🔅 🔆 〽️ ⚠️ 🚸 🔱 ⚜️ 🔰 ♻️ ✅ 🈯 💹 ❇️ ✳️ ❎ 🌐 💠 Ⓜ️ 🌀 💤 🏧 🚾 ♿ 🅿️ 🈳 🈂️ 🛂 🛃 🛄 🛅 🚹 🚺 🚼 🚻 🚮 🎦 📶 🈁 🔣 ℹ️ 🔤 🔡 🔠 🆖 🆗 🆙 🆒 🆕 🆓 0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟" },
        };

        private const int RECENT_LIMIT = 30;

        private Gtk.SearchEntry search;
        private Gtk.Notebook notebook;
        private Gtk.FlowBox recent_flow;
        private Gtk.FlowBox[] flows = {};
        private string[] recent = {};

        public EmojiWindow () {
            set_title (Strings.get ("emoji.title"));
            set_default_size (440, 420);

            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            column.set_border_width (8);
            add (column);

            search = new Gtk.SearchEntry ();
            search.set_placeholder_text (Strings.get ("common.search"));
            search.search_changed.connect (on_search_changed);
            column.pack_start (search, false, false, 0);

            notebook = new Gtk.Notebook ();
            notebook.set_scrollable (true);
            column.pack_start (notebook, true, true, 0);

            /* "Tümü" tek kaydırılabilir liste olarak en başta. */
            var all = new StringBuilder ();
            foreach (unowned Category category in CATEGORIES) {
                if (all.len > 0) {
                    all.append_c (' ');
                }
                all.append (category.emoji);
            }
            Gtk.FlowBox all_flow;
            notebook.append_page (flow_page (all.str, out all_flow),
                new Gtk.Label (Strings.get ("emoji.cat_all")));

            load_recent ();
            notebook.append_page (
                flow_page (string.joinv (" ", recent), out recent_flow),
                new Gtk.Label (Strings.get ("emoji.cat_recent")));

            foreach (unowned Category category in CATEGORIES) {
                Gtk.FlowBox flow;
                var page = flow_page (category.emoji, out flow);
                notebook.append_page (page,
                    new Gtk.Label (Strings.get (category.key)));
            }

            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    destroy ();
                    return true;
                }
                return false;
            });

            /* Açılışta odak aramada. */
            search.grab_focus ();
        }

        private Gtk.Widget flow_page (string glyphs,
                                      out Gtk.FlowBox flow_out) {
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_policy (Gtk.PolicyType.NEVER,
                               Gtk.PolicyType.AUTOMATIC);
            var flow = new Gtk.FlowBox ();
            flow.set_selection_mode (Gtk.SelectionMode.NONE);
            flow.set_max_children_per_line (9);
            flow.set_border_width (8);
            /* Az sonuçlu filtrede çocuklar dikeyde gerilmesin. */
            flow.set_valign (Gtk.Align.START);
            foreach (unowned string glyph in glyphs.split (" ")) {
                if (glyph.strip () != "") {
                    flow.add (emoji_button (glyph));
                }
            }
            flow.set_filter_func (filter_child);
            flows += flow;
            scroll.add (flow);
            flow_out = flow;
            return scroll;
        }

        private Gtk.Button emoji_button (string glyph) {
            var button = new Gtk.Button.with_label (glyph);
            button.set_relief (Gtk.ReliefStyle.NONE);
            button.set_tooltip_text (EmojiNames.name_for (glyph));
            string copy = glyph;
            button.clicked.connect (() => pick (copy));
            return button;
        }

        /* Yazdıkça filtre: üretilen İngilizce ad (tabloya eklenmiş
         * TR sözcükler dahil) alt dizi olarak aranır. */
        private bool filter_child (Gtk.FlowBoxChild child) {
            string text = search.get_text ().strip ().down ();
            if (text == "") {
                return true;
            }
            var button = child.get_child () as Gtk.Button;
            if (button == null) {
                return true;
            }
            unowned string glyph = button.get_label ();
            return glyph == text
                || text in EmojiNames.name_for (glyph).down ();
        }

        private void on_search_changed () {
            if (search.get_text ().strip () != "") {
                /* Arama tek listede anlamlı — Tümü sekmesine geç. */
                notebook.set_current_page (0);
            }
            foreach (unowned Gtk.FlowBox flow in flows) {
                flow.invalidate_filter ();
            }
        }

        /* --- son kullanılanlar (~/.config/kavis/emoji-recent) -------- */

        private string recent_path () {
            return Path.build_filename (
                Environment.get_user_config_dir (), "kavis",
                "emoji-recent");
        }

        private void load_recent () {
            recent = {};
            string contents;
            try {
                FileUtils.get_contents (recent_path (), out contents);
            } catch (Error e) {
                return;
            }
            foreach (unowned string line in contents.split ("\n")) {
                if (line.strip () != "") {
                    recent += line.strip ();
                }
            }
        }

        private void remember (string glyph) {
            string[] updated = { glyph };
            foreach (unowned string old in recent) {
                if (old != glyph && updated.length < RECENT_LIMIT) {
                    updated += old;
                }
            }
            recent = updated;
            string path = recent_path ();
            DirUtils.create_with_parents (Path.get_dirname (path), 0755);
            try {
                FileUtils.set_contents (path,
                    string.joinv ("\n", recent) + "\n");
            } catch (Error e) {
                warning ("kavis-tools: emoji-recent yazilamadi: %s",
                         e.message);
            }
            /* Sekme açıkken de tazelensin. */
            foreach (var child in recent_flow.get_children ()) {
                recent_flow.remove (child);
            }
            foreach (unowned string entry in recent) {
                recent_flow.add (emoji_button (entry));
            }
            recent_flow.show_all ();
        }

        private void pick (string glyph) {
            var clipboard = Gtk.Clipboard.get_default (
                Gdk.Display.get_default ());
            clipboard.set_text (glyph, -1);
            remember (glyph);
            /* Odaklı pencereye bas (xdotool varsa) ve açık kal — üst
             * üste seçim W11 davranışı. */
            if (Environment.find_program_in_path ("xdotool") != null) {
                try {
                    Process.spawn_async (null,
                        { "xdotool", "key", "--clearmodifiers", "ctrl+v" },
                        null, SpawnFlags.SEARCH_PATH, null, null);
                } catch (Error e) {
                    /* pano zaten dolu */
                }
            }
        }
    }
}
