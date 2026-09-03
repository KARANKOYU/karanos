/* Start menu (UI layer).
 *
 * Layout: search box on top, category-grouped app list in the middle,
 * power button at the bottom (opens the PowerMenu popup).
 */

namespace Kavis.Ui {

    public class StartMenu : Gtk.Window {

        public const int WIDTH = 420;
        public const int HEIGHT = 560;

        private Gtk.SearchEntry search_entry;
        private Gtk.Box list_box;
        private PowerMenu power_menu;
        private GenericArray<Apps.App> app_list;
        private bool gtk_grabbed = false;

        public StartMenu () {
            Object (type: Gtk.WindowType.POPUP);
            set_size_request (WIDTH, HEIGHT);
            set_type_hint (Gdk.WindowTypeHint.POPUP_MENU);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            get_style_context ().add_class ("kavis-start-menu");

            app_list = new GenericArray<Apps.App> ();
            build ();

            /* Close on outside click. POPUP windows get no focus from
             * openbox, so "focus-out" is unreliable; pointer and
             * keyboard are grabbed directly instead. */
            button_press_event.connect (on_outside_click);
            key_press_event.connect (on_key_press);
        }

        private void build () {
            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            add (root);

            /* --- search --- */
            var search_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            search_box.set_border_width (10);
            search_entry = new Gtk.SearchEntry ();
            search_entry.set_placeholder_text (
                _("Search apps and files"));
            search_entry.search_changed.connect (on_search_changed);
            search_entry.activate.connect (launch_first_result);
            search_box.pack_start (search_entry, true, true, 0);
            root.pack_start (search_box, false, false, 0);

            /* --- app list --- */
            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            list_box.set_border_width (6);
            scrolled.add (list_box);
            root.pack_start (scrolled, true, true, 0);

            root.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                             false, false, 0);

            /* --- power ---
             * One button; clicking opens a small popup above it
             * (power_menu.vala). Four icons side by side needed tooltip
             * archaeology to tell apart — hence the popup. */
            var power_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            power_box.set_border_width (8);
            var power_button = new Gtk.Button ();
            power_button.set_relief (Gtk.ReliefStyle.NONE);
            power_button.set_tooltip_text (_("Power"));
            var power_inner = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            power_inner.pack_start (new Gtk.Image.from_icon_name (
                "system-shutdown-symbolic", Gtk.IconSize.LARGE_TOOLBAR),
                false, false, 0);
            power_inner.pack_start (new Gtk.Label (_("Power")),
                                    false, false, 0);
            power_button.add (power_inner);
            power_button.clicked.connect (open_power_menu);
            power_box.pack_start (power_button, false, false, 0);
            root.pack_start (power_box, false, false, 0);

            power_menu = new PowerMenu ();
            /* The power menu takes the seat grab for itself; when it
             * closes while the start menu is still up, the grab must
             * come back here or outside clicks stop closing the menu
             * (madde 60). GTK-level grabs stack on their own. */
            power_menu.closed.connect (() => {
                if (get_visible ()) {
                    PanelPopup.seat_grab (this);
                }
            });
        }

        /* Open the menu with its TOP-LEFT corner at (x, y) — the panel
         * computes the corner from its own position (madde 5: the menu
         * opens away from whichever edge the panel is on). */
        public void open (int x, int y) {
            /* Same exclusivity as the indicator popups: at most one
             * floating surface above the panel. */
            PanelPopup.dismiss_open ();
            app_list = Apps.all_apps ();
            search_entry.set_text ("");
            render_list (app_list, true);
            move (x, y);
            show_all ();
            search_entry.grab_focus ();

            /* Same grab pair as PanelPopup (madde 60): the GTK grab
             * redirects clicks on the rest of the app (panel) here so
             * they close the menu; the seat grab (with retry — a grab
             * right after show_all can fail as NOT_VIEWABLE) catches
             * clicks outside the app and keyboard input, since POPUP
             * windows get no WM focus. */
            Gtk.grab_add (this);
            gtk_grabbed = true;
            PanelPopup.seat_grab (this);
        }

        public void dismiss () {
            if (gtk_grabbed) {
                Gtk.grab_remove (this);
                gtk_grabbed = false;
            }
            PanelPopup.seat_ungrab ();
            hide ();
        }

        private void render_list (GenericArray<Apps.App> apps,
                                  bool grouped) {
            foreach (var child in list_box.get_children ()) {
                list_box.remove (child);
            }

            if (apps.length == 0) {
                var empty = new Gtk.Label (_("No results found"));
                empty.get_style_context ().add_class ("dim-label");
                empty.set_margin_top (24);
                list_box.pack_start (empty, false, false, 0);
                list_box.show_all ();
                return;
            }

            if (grouped) {
                foreach (unowned Apps.CategoryGroup group in
                         Apps.by_category (apps)) {
                    list_box.pack_start (header_label (group.category),
                                         false, false, 0);
                    for (int i = 0; i < group.apps.length; i++) {
                        list_box.pack_start (app_row (group.apps[i]),
                                             false, false, 0);
                    }
                }
            } else {
                for (int i = 0; i < apps.length; i++) {
                    list_box.pack_start (app_row (apps[i]), false, false, 0);
                }
            }
            list_box.show_all ();
        }

        private Gtk.Label header_label (string category) {
            string name = Apps.category_display (category);
            var label = new Gtk.Label (null);
            label.set_xalign (0);
            label.set_markup ("<b>%s</b>".printf (Markup.escape_text (name)));
            label.get_style_context ().add_class ("category");
            label.set_margin_top (10);
            label.set_margin_start (6);
            label.set_margin_bottom (2);
            return label;
        }

        private Gtk.Button app_row (Apps.App app) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            Gtk.Image icon;
            var gicon = app.app_info.get_icon ();
            if (gicon != null) {
                icon = new Gtk.Image.from_gicon (gicon,
                    Gtk.IconSize.LARGE_TOOLBAR);
            } else {
                icon = new Gtk.Image.from_icon_name (
                    "application-x-executable", Gtk.IconSize.LARGE_TOOLBAR);
            }
            box.pack_start (icon, false, false, 0);
            var label = new Gtk.Label (app.name);
            label.set_xalign (0);
            label.set_ellipsize (Pango.EllipsizeMode.END);
            label.get_style_context ().add_class ("app-name");
            box.pack_start (label, true, true, 0);
            button.add (box);
            button.clicked.connect (() => on_app_chosen (app));
            /* Sağ tık (sonraki-isler 2): sabitle / masaüstüne kısayol. */
            button.button_press_event.connect ((event) => {
                if (event.button == 3) {
                    show_app_menu (app, event);
                    return true;
                }
                return false;
            });
            return button;
        }

        private void show_app_menu (Apps.App app, Gdk.EventButton event) {
            string? id = app.app_info.get_id ();
            if (id == null) {
                return;
            }
            var menu = new Gtk.Menu ();
            bool pinned = Pinned.contains (id);
            var pin_item = new Gtk.MenuItem.with_label (
                pinned ? _("Unpin from taskbar") : _("Pin to taskbar"));
            string id_copy = id;
            pin_item.activate.connect (() => {
                if (pinned) {
                    Pinned.remove (id_copy);
                } else {
                    Pinned.add (id_copy);
                }
                taskbar_changed ();
            });
            menu.append (pin_item);

            var shortcut_item = new Gtk.MenuItem.with_label (
                _("Add desktop shortcut"));
            shortcut_item.activate.connect (() => {
                copy_to_desktop (id_copy);
            });
            menu.append (shortcut_item);

            /* Sızıntı önlemi: kapanınca menü yok edilir (aktivasyon

             * deactivate'ten SONRA koştuğu için Idle ile). */

            menu.deactivate.connect (() => {

                Idle.add (() => {

                    menu.destroy ();

                    return Source.REMOVE;

                });

            });

            menu.show_all ();

            menu.popup_at_pointer (event);
        }

        /* Sabitleme değişince görev çubuğu yeniden kurulmalı; menü
         * paneli tanımaz, sinyalle duyurur. */
        public signal void taskbar_changed ();

        /* Masaüstüne kısayol: .desktop dosyasını kullanıcının masaüstü
         * dizinine kopyala (çalıştırılabilir işaret nemo-desktop'ın
         * güven denetimi için). */
        private void copy_to_desktop (string id) {
            var info = new DesktopAppInfo (id);
            if (info == null || info.get_filename () == null) {
                return;
            }
            unowned string? desktop_dir =
                Environment.get_user_special_dir (
                    UserDirectory.DESKTOP);
            if (desktop_dir == null) {
                return;
            }
            string target = Path.build_filename (
                desktop_dir, Path.get_basename (info.get_filename ()));
            try {
                File.new_for_path (info.get_filename ()).copy (
                    File.new_for_path (target),
                    FileCopyFlags.OVERWRITE);
                FileUtils.chmod (target, 0755);
            } catch (Error e) {
                warning ("kavis-panel: kisayol kopyalanamadi: %s",
                         e.message);
            }
        }

        private void on_search_changed () {
            string query = search_entry.get_text ();
            var results = Apps.search (app_list, query);
            render_list (results, query.strip ().length == 0);
        }

        private void launch_first_result () {
            var results = Apps.search (app_list, search_entry.get_text ());
            if (results.length > 0) {
                on_app_chosen (results[0]);
            }
        }

        private void on_app_chosen (Apps.App app) {
            dismiss ();
            try {
                app.launch ();
            } catch (Error e) {
                warning ("kavis-panel: %s baslatilamadi: %s",
                         app.name, e.message);
            }
        }

        private void open_power_menu (Gtk.Button button) {
            /* Open the popup above the power button. The start menu
             * stays open: closing the popup drops the user back on the
             * list. */
            var window = button.get_window ();
            if (window == null) {
                return;
            }
            int root_x, root_y;
            window.get_origin (out root_x, out root_y);
            Gtk.Allocation alloc;
            button.get_allocation (out alloc);
            /* Our grab must go first so the popup can take its own. */
            var display = Gdk.Display.get_default ();
            if (display != null) {
                display.get_default_seat ().ungrab ();
            }
            power_menu.open (root_x + alloc.x, root_y + alloc.y);
        }

        private bool on_outside_click (Gdk.EventButton event) {
            /* Root-coordinate test (madde 60): bubbled events carry
             * child-window-relative x/y, which made inside clicks look
             * outside — see PanelPopup.press_outside. */
            if (PanelPopup.press_outside (this, event)) {
                dismiss ();
                return true;
            }
            return false;
        }

        private bool on_key_press (Gdk.EventKey event) {
            if (event.keyval == Gdk.Key.Escape) {
                dismiss ();
                return true;
            }
            return false;
        }
    }
}
