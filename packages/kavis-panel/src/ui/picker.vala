/* "Emoji and more" panel (UI layer) — sonraki-isler section 5.
 *
 * Win+. and Win+V open the same small panel near the pointer: tabs
 * for recent / starred / emoji / kaomoji / symbols / snippets /
 * clipboard, a search box on top (focused on open), a PIN toggle that
 * keeps the panel up (and on top) while clicking other windows, and a
 * close button. No GIF tab by design (no third-party API dependency).
 *
 * The panel is a POPUP window with a seat grab, so the TARGET window
 * keeps the input focus: clicking an item can paste straight into it
 * with xdotool. PIN drops the grab so other windows can be used; the
 * trade-off (logged in durum.md) is that the search box cannot take
 * keystrokes while pinned — POPUP windows have no keyboard focus of
 * their own, and grabbing would starve the app being typed into.
 */

namespace Kavis.Ui {

    public class PickerPanel : Gtk.Window {

        private const string CSS = """
        .kavis-picker {
          background-color: @kavis_surface;
          border: 1px solid @kavis_border;
          border-radius: 12px;   /* J1 */
        }
        .kavis-picker label {
          color: @kavis_text;
        }
        .kavis-picker label.dim {
          color: @kavis_text2;
        }
        .kavis-picker button {
          background-image: none;
          background-color: transparent;
          border: none;
          border-radius: 6px;
          color: @kavis_text;
          padding: 4px 8px;
          transition: background-color 120ms cubic-bezier(0.2, 0.9, 0.25, 1);
        }
        .kavis-picker button:hover {
          background-color: @kavis_overlay_hover;
        }
        .kavis-picker button:active {
          background-color: @kavis_overlay_press;
        }
        /* Tabs: teal line under the active one. */
        .kavis-picker button.picker-tab {
          border-radius: 6px 6px 0 0;
          padding: 6px 10px;
        }
        .kavis-picker button.picker-tab:checked {
          box-shadow: inset 0 -2px @kavis_teal;
          background-color: @kavis_overlay_faint;
        }
        .kavis-picker button.pin-toggle:checked {
          background-color: rgba(45, 212, 191, 0.25);
          color: @kavis_teal;
        }
        """;

        private static bool css_loaded = false;

        private ClipboardHistory history;
        private Gtk.SearchEntry search;
        private Gtk.Stack stack;
        private Gtk.ToggleButton pin_toggle;
        private HashTable<string, Gtk.ToggleButton> tab_buttons =
            new HashTable<string, Gtk.ToggleButton> (str_hash, str_equal);
        private GenericArray<Gtk.FlowBox> filter_flows =
            new GenericArray<Gtk.FlowBox> ();
        private Gtk.Box recent_box;
        private Gtk.Box starred_box;
        private Gtk.Box snippets_box;
        private Gtk.Box clipboard_box;
        private string last_page = "emoji";
        private bool grabbed = false;
        private bool switching = false;
        /* G5: dragging by the header bar (begin_move_drag does not
         * work on a POPUP window — override-redirect; moved by hand)
         * + last position kept in kavis.conf. */
        private bool dragging = false;
        private int drag_dx = 0;
        private int drag_dy = 0;
        private PanelConfig config = PanelConfig.get_default ();

        public PickerPanel (ClipboardHistory history) {
            Object (type: Gtk.WindowType.POPUP);
            this.history = history;
            set_type_hint (Gdk.WindowTypeHint.POPUP_MENU);
            set_skip_taskbar_hint (true);
            set_app_paintable (true);
            var gdk_screen = get_screen ();
            var visual = gdk_screen.get_rgba_visual ();
            if (visual != null && gdk_screen.is_composited ()) {
                set_visual (visual);
            }
            if (!css_loaded) {
                css_loaded = true;
                var provider = new Gtk.CssProvider ();
                try {
                    provider.load_from_data (CSS, CSS.length);
                    Gtk.StyleContext.add_provider_for_screen (
                        Gdk.Screen.get_default (), provider,
                        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                } catch (Error e) { }
            }

            var outer = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            outer.get_style_context ().add_class ("kavis-picker");
            outer.set_border_width (10);
            add (outer);

            /* --- header bar: title + pin + close --- */
            var header_events = new Gtk.EventBox ();
            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var title = new Gtk.Label (_("Emoji and more"));
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            header.pack_start (title, true, true, 0);
            pin_toggle = new Gtk.ToggleButton ();
            pin_toggle.get_style_context ().add_class ("pin-toggle");
            pin_toggle.add (new Gtk.Image.from_icon_name (
                "view-pin-symbolic", Gtk.IconSize.BUTTON));
            pin_toggle.set_tooltip_text (_("Pin"));
            pin_toggle.toggled.connect (on_pin_toggled);
            header.pack_end (make_close_button (), false, false, 0);
            header.pack_end (pin_toggle, false, false, 0);
            header_events.add (header);
            header_events.add_events (Gdk.EventMask.BUTTON_PRESS_MASK
                | Gdk.EventMask.BUTTON_RELEASE_MASK
                | Gdk.EventMask.POINTER_MOTION_MASK);
            header_events.button_press_event.connect ((event) => {
                if (event.button == 1) {
                    int wx, wy;
                    get_position (out wx, out wy);
                    dragging = true;
                    drag_dx = (int) event.x_root - wx;
                    drag_dy = (int) event.y_root - wy;
                    return true;
                }
                return false;
            });
            header_events.motion_notify_event.connect ((event) => {
                if (dragging) {
                    move ((int) event.x_root - drag_dx,
                          (int) event.y_root - drag_dy);
                    return true;
                }
                return false;
            });
            header_events.button_release_event.connect ((event) => {
                if (dragging) {
                    dragging = false;
                    get_position (out config.picker_x,
                                  out config.picker_y);
                    config.save ();
                    return true;
                }
                return false;
            });
            outer.pack_start (header_events, false, false, 0);

            /* --- tab icons --- */
            var tabs = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            add_tab (tabs, "recent", "⏱", _("Recent"));
            add_tab (tabs, "starred", "★", _("Favorites"));
            add_tab (tabs, "emoji", "😀", _("Emoji Picker"));
            add_tab (tabs, "kaomoji", "☺", _("Kaomoji"));
            add_tab (tabs, "symbols", "Ω", _("Symbols"));
            add_tab (tabs, "snippets", "✎", _("Snippets"));
            add_tab (tabs, "clipboard", "📋", _("Clipboard history"));
            outer.pack_start (tabs, false, false, 0);

            /* --- search --- */
            search = new Gtk.SearchEntry ();
            search.set_placeholder_text (_("Search"));
            search.search_changed.connect (apply_filters);
            outer.pack_start (search, false, false, 0);

            /* --- pages --- */
            stack = new Gtk.Stack ();
            stack.set_transition_type (
                Gtk.StackTransitionType.CROSSFADE);
            stack.set_transition_duration (120);
            stack.set_size_request (380, 380);

            recent_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            stack.add_named (scrolled (recent_box), "recent");
            starred_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            stack.add_named (scrolled (starred_box), "starred");
            /* Glyph pages are built LAZILY (debug pass): creating
             * ~1000 buttons at panel start-up cost extra MBs; they are
             * built on first show and live on afterwards. */
            stack.add_named (new Gtk.Box (Gtk.Orientation.VERTICAL, 0),
                             "emoji");
            stack.add_named (new Gtk.Box (Gtk.Orientation.VERTICAL, 0),
                             "kaomoji");
            stack.add_named (new Gtk.Box (Gtk.Orientation.VERTICAL, 0),
                             "symbols");
            snippets_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            stack.add_named (scrolled (snippets_box), "snippets");
            clipboard_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            stack.add_named (scrolled (clipboard_box), "clipboard");
            outer.pack_start (stack, true, true, 0);

            history.changed.connect (() => {
                if (get_visible ()) {
                    rebuild_clipboard ();
                }
            });

            button_press_event.connect ((event) => {
                if (!pin_toggle.get_active ()
                    && PanelPopup.press_outside (this, event)) {
                    dismiss ();
                    return true;
                }
                return false;
            });
            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    dismiss ();
                    return true;
                }
                return false;
            });
        }

        private Gtk.Button make_close_button () {
            var close = new Gtk.Button.with_label ("✕");
            close.set_relief (Gtk.ReliefStyle.NONE);
            close.set_tooltip_text (_("Close"));
            close.clicked.connect (dismiss);
            return close;
        }

        private void add_tab (Gtk.Box row, string page, string glyph,
                              string tooltip) {
            var button = new Gtk.ToggleButton.with_label (glyph);
            button.set_relief (Gtk.ReliefStyle.NONE);
            button.get_style_context ().add_class ("picker-tab");
            button.set_tooltip_text (tooltip);
            button.toggled.connect (() => {
                if (switching || !button.get_active ()) {
                    if (!switching && !button.get_active ()
                        && stack.get_visible_child_name () == page) {
                        switching = true;
                        button.set_active (true);
                        switching = false;
                    }
                    return;
                }
                show_page (page);
            });
            tab_buttons.insert (page, button);
            row.pack_start (button, false, false, 0);
        }

        private Gtk.Widget scrolled (Gtk.Widget child) {
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_policy (Gtk.PolicyType.NEVER,
                               Gtk.PolicyType.AUTOMATIC);
            scroll.add (child);
            return scroll;
        }

        /* Emoji / kaomoji / symbol page: category captions +
         * FlowBoxes, one scrollable list. */
        private Gtk.Widget glyph_page (PickerData.Category[] categories) {
            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            foreach (unowned PickerData.Category category in categories) {
                var caption = new Gtk.Label (_(category.key));
                caption.get_style_context ().add_class ("dim");
                caption.set_xalign (0);
                column.pack_start (caption, false, false, 2);
                var flow = new Gtk.FlowBox ();
                flow.set_selection_mode (Gtk.SelectionMode.NONE);
                flow.set_max_children_per_line (9);
                flow.set_valign (Gtk.Align.START);
                foreach (unowned string item in
                         category.items.split (" ")) {
                    if (item.strip () != "") {
                        flow.add (glyph_button (item));
                    }
                }
                flow.set_filter_func (filter_glyph);
                filter_flows.add (flow);
                column.pack_start (flow, false, false, 0);
            }
            return scrolled (column);
        }

        private Gtk.Button glyph_button (string item) {
            var button = new Gtk.Button.with_label (item);
            button.set_relief (Gtk.ReliefStyle.NONE);
            string name = EmojiNames.name_for (item);
            if (name != "") {
                button.set_tooltip_text (name);
            }
            string copy = item;
            button.clicked.connect (() => insert_text (copy, true));
            button.button_press_event.connect ((event) => {
                if (event.button == 3) {
                    show_star_menu (copy, event);
                    return true;
                }
                return false;
            });
            return button;
        }

        private void show_star_menu (string item, Gdk.EventButton event) {
            var menu = new Gtk.Menu ();
            var star = new Gtk.MenuItem.with_label (
                PickerStore.is_starred (item)
                ? _("Remove from favorites") : _("Add to favorites"));
            star.activate.connect (() => {
                PickerStore.toggle_star (item);
                rebuild_starred ();
            });
            menu.append (star);
            /* Leak guard: the menu is destroyed on close (via Idle,
             * because activation runs AFTER deactivate). */
            menu.deactivate.connect (() => {
                Idle.add (() => {
                    menu.destroy ();
                    return Source.REMOVE;
                });
            });
            menu.show_all ();
            menu.popup_at_pointer (event);
        }

        private bool filter_glyph (Gtk.FlowBoxChild child) {
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

        private void apply_filters () {
            for (int i = 0; i < filter_flows.length; i++) {
                filter_flows[i].invalidate_filter ();
            }
            /* Optimisation (debug pass): on every keystroke rebuild
             * only the visible list page, not all FOUR — the clipboard
             * tab reads image thumbnails from disk, so rebuilding them
             * all while typing a search was wasted IO. */
            switch (stack.get_visible_child_name ()) {
            case "recent":
                rebuild_recent ();
                break;
            case "starred":
                rebuild_starred ();
                break;
            case "snippets":
                rebuild_snippets ();
                break;
            case "clipboard":
                rebuild_clipboard ();
                break;
            }
        }

        /* --- text insertion ------------------------------------------- */

        /* Put on the clipboard + paste into the focused window. The
         * panel is a POPUP, so focus stayed in the target window; the
         * panel stays open (W11 emoji behaviour). */
        private void insert_text (string item, bool remember) {
            history.set_clipboard_text (item);
            if (remember) {
                PickerStore.remember (item);
            }
            Launch.paste_keystroke ();
        }

        /* --- dynamic pages -------------------------------------------- */

        private void clear_children (Gtk.Box box) {
            foreach (var child in box.get_children ()) {
                box.remove (child);
            }
        }

        private bool matches_search (string text) {
            string needle = search.get_text ().strip ().down ();
            return needle == "" || needle in text.down ()
                || needle in EmojiNames.name_for (text).down ();
        }

        private Gtk.Widget empty_label () {
            var label = new Gtk.Label (_("None"));
            label.get_style_context ().add_class ("dim");
            label.set_margin_top (20);
            return label;
        }

        private void fill_glyph_list (Gtk.Box box, string[] items) {
            clear_children (box);
            var flow = new Gtk.FlowBox ();
            flow.set_selection_mode (Gtk.SelectionMode.NONE);
            flow.set_max_children_per_line (9);
            flow.set_valign (Gtk.Align.START);
            int count = 0;
            foreach (unowned string item in items) {
                if (matches_search (item)) {
                    flow.add (glyph_button (item));
                    count++;
                }
            }
            if (count == 0) {
                box.pack_start (empty_label (), false, false, 0);
            } else {
                box.pack_start (flow, false, false, 0);
            }
            box.show_all ();
        }

        private void rebuild_recent () {
            fill_glyph_list (recent_box, PickerStore.recent ());
        }

        private void rebuild_starred () {
            fill_glyph_list (starred_box, PickerStore.starred ());
        }

        private void rebuild_snippets () {
            clear_children (snippets_box);
            var add_button = new Gtk.Button.with_label (
                "+ " + _("Add snippet"));
            add_button.set_relief (Gtk.ReliefStyle.NONE);
            add_button.clicked.connect (() => edit_snippet (null));
            snippets_box.pack_start (add_button, false, false, 0);

            int count = 0;
            foreach (PickerStore.Snippet snippet in
                     PickerStore.snippets ()) {
                if (!matches_search (snippet.text)) {
                    continue;
                }
                count++;
                var row = new Gtk.Button ();
                row.set_relief (Gtk.ReliefStyle.NONE);
                var label = new Gtk.Label (snippet.text);
                label.set_xalign (0);
                label.set_ellipsize (Pango.EllipsizeMode.END);
                label.set_lines (2);
                row.add (label);
                PickerStore.Snippet copy = snippet;
                row.clicked.connect (() => {
                    insert_text (copy.text, false);
                });
                row.button_press_event.connect ((event) => {
                    if (event.button == 3) {
                        show_snippet_menu (copy, event);
                        return true;
                    }
                    return false;
                });
                snippets_box.pack_start (row, false, false, 0);
            }
            if (count == 0) {
                snippets_box.pack_start (empty_label (), false, false, 0);
            }
            snippets_box.show_all ();
        }

        private void show_snippet_menu (PickerStore.Snippet snippet,
                                        Gdk.EventButton event) {
            var menu = new Gtk.Menu ();
            var edit = new Gtk.MenuItem.with_label (_("Edit"));
            PickerStore.Snippet copy = snippet;
            edit.activate.connect (() => edit_snippet (copy.id));
            menu.append (edit);
            var remove = new Gtk.MenuItem.with_label (_("Delete"));
            remove.activate.connect (() => {
                PickerStore.delete_snippet (copy.id);
                rebuild_snippets ();
            });
            menu.append (remove);
            /* Leak guard: the menu is destroyed on close (via Idle,
             * because activation runs AFTER deactivate). */
            menu.deactivate.connect (() => {
                Idle.add (() => {
                    menu.destroy ();
                    return Source.REMOVE;
                });
            });
            menu.show_all ();
            menu.popup_at_pointer (event);
        }

        /* Add/edit: a small dialog with multi-line text. The dialog
         * is a real window — it must take focus to be typed into; the
         * picker meanwhile stays open as if pinned. */
        private void edit_snippet (string? id) {
            string initial = "";
            if (id != null) {
                foreach (PickerStore.Snippet snippet in
                         PickerStore.snippets ()) {
                    if (snippet.id == id) {
                        initial = snippet.text;
                    }
                }
            }
            var dialog = new Gtk.Dialog ();
            dialog.set_title (_("Snippets"));
            dialog.set_default_size (360, 160);
            dialog.set_keep_above (true);
            dialog.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
            dialog.add_button (_("Save"), Gtk.ResponseType.OK);
            var view = new Gtk.TextView ();
            view.get_buffer ().set_text (initial);
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.add (view);
            scroll.set_border_width (8);
            dialog.get_content_area ().pack_start (scroll, true, true, 0);
            dialog.show_all ();

            bool was_pinned = pin_toggle.get_active ();
            if (!was_pinned) {
                release_grab ();   /* so the dialog can be typed into */
            }
            string? snippet_id = id;
            dialog.response.connect ((response) => {
                if (response == Gtk.ResponseType.OK) {
                    Gtk.TextIter start, end;
                    view.get_buffer ().get_bounds (out start, out end);
                    string text = view.get_buffer ().get_text (
                        start, end, false).strip ();
                    if (text != "") {
                        if (snippet_id == null) {
                            PickerStore.add_snippet (text);
                        } else {
                            PickerStore.update_snippet (snippet_id, text);
                        }
                    }
                }
                dialog.destroy ();
                rebuild_snippets ();
                if (!was_pinned && get_visible ()) {
                    take_grab ();
                }
            });
        }

        private void rebuild_clipboard () {
            clear_children (clipboard_box);
            var top = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var clear_button = new Gtk.Button.with_label (
                _("Clear all"));
            clear_button.set_relief (Gtk.ReliefStyle.NONE);
            clear_button.clicked.connect (() => history.clear ());
            top.pack_end (clear_button, false, false, 0);
            clipboard_box.pack_start (top, false, false, 0);

            int count = 0;
            for (int i = 0; i < history.items.length; i++) {
                var entry = history.items[i];
                if (!entry.is_image && !matches_search (entry.text)) {
                    continue;
                }
                count++;
                var line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
                var row = new Gtk.Button ();
                row.set_relief (Gtk.ReliefStyle.NONE);
                if (entry.is_image) {
                    try {
                        row.add (new Gtk.Image.from_pixbuf (
                            new Gdk.Pixbuf.from_file_at_scale (
                                entry.path, 220, 72, true)));
                    } catch (Error e) {
                        continue;
                    }
                } else {
                    var label = new Gtk.Label (entry.text);
                    label.set_xalign (0);
                    label.set_ellipsize (Pango.EllipsizeMode.END);
                    row.add (label);
                }
                var target = entry;
                row.clicked.connect (() => {
                    history.activate_entry (target);
                    if (!pin_toggle.get_active ()) {
                        dismiss ();
                    }
                    /* Small allowance for the close + focus return. */
                    Timeout.add (200, () => {
                        Launch.paste_keystroke ();
                        return Source.REMOVE;
                    });
                });
                line.pack_start (row, true, true, 0);

                var pin_button = new Gtk.ToggleButton ();
                pin_button.set_relief (Gtk.ReliefStyle.NONE);
                pin_button.add (new Gtk.Image.from_icon_name (
                    "view-pin-symbolic", Gtk.IconSize.BUTTON));
                pin_button.set_tooltip_text (_("Pin"));
                pin_button.set_active (entry.pinned);
                pin_button.toggled.connect (() => {
                    if (pin_button.get_active () != target.pinned) {
                        history.toggle_pin (target);
                    }
                });
                line.pack_end (pin_button, false, false, 0);

                var delete_button = new Gtk.Button.from_icon_name (
                    "user-trash-symbolic", Gtk.IconSize.BUTTON);
                delete_button.set_relief (Gtk.ReliefStyle.NONE);
                delete_button.set_tooltip_text (_("Delete"));
                delete_button.clicked.connect (() => {
                    history.delete_entry (target);
                });
                line.pack_end (delete_button, false, false, 0);

                clipboard_box.pack_start (line, false, false, 0);
            }
            if (count == 0) {
                clipboard_box.pack_start (
                    empty_label (), false, false, 0);
            }
            clipboard_box.show_all ();
        }

        /* --- open / close --------------------------------------------- */

        private bool[] glyph_built = { false, false, false };

        private void ensure_glyph_page (string page) {
            int index;
            unowned PickerData.Category[] dataset;
            switch (page) {
            case "emoji":
                index = 0;
                dataset = PickerData.EMOJI;
                break;
            case "kaomoji":
                index = 1;
                dataset = PickerData.KAOMOJI;
                break;
            case "symbols":
                index = 2;
                dataset = PickerData.SYMBOLS;
                break;
            default:
                return;
            }
            if (glyph_built[index]) {
                return;
            }
            glyph_built[index] = true;
            var holder = stack.get_child_by_name (page) as Gtk.Box;
            holder.pack_start (glyph_page (dataset), true, true, 0);
            holder.show_all ();
        }

        private void show_page (string page) {
            ensure_glyph_page (page);
            last_page = page;
            stack.set_visible_child_name (page);
            switching = true;
            tab_buttons.foreach ((name, button) => {
                button.set_active (name == page);
            });
            switching = false;
        }

        /* page: tab name; "last" = last used (emoji the first time). */
        public void open (string page) {
            if (get_visible ()) {
                dismiss ();
                return;
            }
            string target = (page == "last") ? last_page : page;

            search.set_text ("");
            rebuild_recent ();
            rebuild_starred ();
            rebuild_snippets ();
            rebuild_clipboard ();

            show_all ();
            /* set_visible_child does NOT work on an unshown child —
             * pick the page AFTER show_all (caught on Xvfb). */
            show_page (target);
            /* Near the pointer, clamped into the workarea. */
            var display = Gdk.Display.get_default ();
            int px, py;
            display.get_default_seat ().get_pointer ()
                .get_position (null, out px, out py);
            var monitor = display.get_monitor_at_point (px, py);
            Gdk.Rectangle area = monitor.get_workarea ();
            Gtk.Requisition natural;
            get_preferred_size (null, out natural);
            int x = px - natural.width / 2;
            int y = py - natural.height - 12;
            x = x.clamp (area.x + 8,
                         area.x + area.width - natural.width - 8);
            y = y.clamp (area.y + 8,
                         area.y + area.height - natural.height - 8);
            move (x, y);

            if (!pin_toggle.get_active ()) {
                take_grab ();
            }
            search.grab_focus ();
        }

        private void take_grab () {
            Gtk.grab_add (this);
            grabbed = true;
            PanelPopup.seat_grab (this);
        }

        private void release_grab () {
            if (grabbed) {
                Gtk.grab_remove (this);
                grabbed = false;
            }
            PanelPopup.seat_ungrab ();
        }

        private void on_pin_toggled () {
            if (!get_visible ()) {
                return;
            }
            if (pin_toggle.get_active ()) {
                /* Pin: the grab is released — other windows can be
                 * used, the panel stays on top, clicking outside does
                 * not close it. */
                release_grab ();
                set_keep_above (true);
            } else {
                take_grab ();
            }
        }

        public void dismiss () {
            release_grab ();
            hide ();
        }
    }
}
