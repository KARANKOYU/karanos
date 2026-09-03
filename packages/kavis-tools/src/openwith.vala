/* "Open with" dialog (sonraki-isler 6c) —
 * `kavis-tools open-with <file>`.
 *
 * Kavis' own picker instead of the stock GTK dialog: MIME-matched
 * apps with the first three marked recommended, the rest behind an
 * expander; an "always use this app" checkbox that writes the default
 * through GLib (same effect as `xdg-mime default`, no child process);
 * a "search the Store" button (Store lands in Grup G — until then it
 * says so). File-manager entry: a nemo action ships with the ISO;
 * nemo's OWN unknown-type dialog cannot be replaced without patching
 * nemo (noted in durum.md).
 */

namespace Kavis.Tools {

    public class OpenWithWindow : Gtk.Window {

        private File file;
        private string content_type = "application/octet-stream";
        private Gtk.ListBox list;
        private Gtk.CheckButton always_check;
        private GenericArray<AppInfo> shown =
            new GenericArray<AppInfo> ();

        public OpenWithWindow (string path) {
            file = File.new_for_path (path);
            try {
                var info = file.query_info (
                    FileAttribute.STANDARD_CONTENT_TYPE,
                    FileQueryInfoFlags.NONE);
                content_type = info.get_content_type ()
                    ?? "application/octet-stream";
            } catch (Error e) { }

            set_title (_("How should %s be opened?").printf (
                file.get_basename ()));
            set_default_size (420, 460);
            set_position (Gtk.WindowPosition.CENTER);

            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            column.set_border_width (12);
            add (column);

            var heading = new Gtk.Label (null);
            heading.set_markup ("<b>%s</b>".printf (Markup.escape_text (
                _("How should %s be opened?").printf (
                    file.get_basename ()))));
            heading.set_xalign (0);
            heading.set_line_wrap (true);
            column.pack_start (heading, false, false, 0);

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_policy (Gtk.PolicyType.NEVER,
                               Gtk.PolicyType.AUTOMATIC);
            list = new Gtk.ListBox ();
            list.set_activate_on_single_click (false);
            list.row_activated.connect (() => open_chosen ());
            scroll.add (list);
            column.pack_start (scroll, true, true, 0);

            fill_list ();

            always_check = new Gtk.CheckButton.with_label (
                _("Always open this file type with this app"));
            column.pack_start (always_check, false, false, 0);

            var buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var store_button = new Gtk.Button.with_label (
                _("Search the Store"));
            store_button.clicked.connect (open_store);
            buttons.pack_start (store_button, false, false, 0);
            var open_button = new Gtk.Button.with_label (_("Open"));
            open_button.get_style_context ()
                .add_class ("suggested-action");
            open_button.clicked.connect (open_chosen);
            buttons.pack_end (open_button, false, false, 0);
            column.pack_start (buttons, false, false, 0);
        }

        private Gtk.ListBoxRow app_row (AppInfo info, bool recommended) {
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            row.set_border_width (6);
            var icon = new Gtk.Image ();
            if (info.get_icon () != null) {
                icon.set_from_gicon (info.get_icon (),
                                     Gtk.IconSize.LARGE_TOOLBAR);
            } else {
                icon.set_from_icon_name ("application-x-executable",
                                         Gtk.IconSize.LARGE_TOOLBAR);
            }
            row.pack_start (icon, false, false, 0);
            var name = new Gtk.Label (info.get_display_name ());
            name.set_xalign (0);
            row.pack_start (name, true, true, 0);
            if (recommended) {
                var mark = new Gtk.Label (null);
                mark.set_markup ("<small>%s</small>".printf (
                    Markup.escape_text (_("Recommended"))));
                mark.get_style_context ().add_class ("dim-label");
                row.pack_end (mark, false, false, 0);
            }
            var list_row = new Gtk.ListBoxRow ();
            list_row.add (row);
            /* Reading the selection back: attach to the row instead of
             * computing an index. */
            list_row.set_data<AppInfo> ("kavis-app", info);
            return list_row;
        }

        private void fill_list () {
            var recommended =
                AppInfo.get_recommended_for_type (content_type);
            var all = AppInfo.get_all_for_type (content_type);
            if (recommended.length () == 0 && all.length () == 0) {
                all = AppInfo.get_all ();
            }

            int count = 0;
            foreach (AppInfo info in recommended) {
                if (count >= 3) {
                    break;
                }
                shown.add (info);
                list.add (app_row (info, true));
                count++;
            }

            /* The rest go under the "other applications" heading. */
            var others = new GenericArray<AppInfo> ();
            foreach (AppInfo info in all) {
                bool seen = false;
                for (int i = 0; i < shown.length; i++) {
                    if (shown[i].get_id () == info.get_id ()) {
                        seen = true;
                        break;
                    }
                }
                if (!seen && info.should_show ()) {
                    others.add (info);
                }
            }
            if (others.length > 0) {
                var expander_row = new Gtk.ListBoxRow ();
                expander_row.set_selectable (false);
                expander_row.set_activatable (false);
                var caption = new Gtk.Label (null);
                caption.set_markup ("<small>%s</small>".printf (
                    Markup.escape_text (_("Other applications"))));
                caption.set_xalign (0);
                caption.set_margin_top (8);
                expander_row.add (caption);
                list.add (expander_row);
                for (int i = 0; i < others.length; i++) {
                    shown.add (others[i]);
                    list.add (app_row (others[i], false));
                }
            }
            list.show_all ();
            /* The first real row comes preselected. */
            var first = list.get_row_at_index (0);
            if (first != null) {
                list.select_row (first);
            }
        }

        private AppInfo? selected_app () {
            unowned Gtk.ListBoxRow? row = list.get_selected_row ();
            if (row == null) {
                return null;
            }
            return row.get_data<AppInfo> ("kavis-app");
        }

        private void open_chosen () {
            var info = selected_app ();
            if (info == null) {
                return;
            }
            if (always_check.get_active ()) {
                try {
                    /* Equivalent of xdg-mime default, without a process. */
                    info.set_as_default_for_type (content_type);
                } catch (Error e) {
                    warning ("kavis-tools: could not write the default: %s",
                             e.message);
                }
            }
            var files = new List<File> ();
            files.append (file);
            try {
                info.launch (files, null);
            } catch (Error e) {
                warning ("kavis-tools: could not open: %s", e.message);
            }
            destroy ();
        }

        private void open_store () {
            if (Environment.find_program_in_path ("kavis-store")
                != null) {
                try {
                    Process.spawn_async (null, {
                        "kavis-store", "--mime", content_type
                    }, null, SpawnFlags.SEARCH_PATH, null, null);
                } catch (Error e) { }
                destroy ();
                return;
            }
            /* The Store arrives in Grup G. */
            Capture.notify_user (_("Store app coming soon"), "",
                                 "system-software-install-symbolic");
        }
    }
}
