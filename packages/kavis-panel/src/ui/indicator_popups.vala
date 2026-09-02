/* The four indicator popups (UI layer) — stage 4.
 *
 * Shared open/close behavior lives in PanelPopup. UI texts are
 * gettext msgids (English source, po/tr.po); system access goes
 * through the logic namespaces (Battery, Keyboard, Volume, PowerPlan)
 * so no widget file touches /sys or spawns a process directly.
 */

namespace Kavis.Ui {

    /* Clock popup (Grup D fix — Windows 11 layout): notification
     * center on top (grouped by app, per-group clear, previews,
     * click-to-open), collapsible calendar below. Quick settings
     * moved to their own popup (QuickSettingsPopup). */
    public class NotificationCenterPopup : PanelPopup {

        private Gtk.Calendar calendar;
        private Gtk.Box notif_list;
        private Gtk.ScrolledWindow notif_scroll;
        private Gtk.Button clear_all_button;
        private Gtk.Label date_label;
        private Gtk.Label collapse_arrow;
        private PanelConfig config;

        public NotificationCenterPopup () {
            edge_aligned = true;
            config = PanelConfig.get_default ();
            content.set_size_request (380, -1);

            /* --- bildirim merkezi başlığı --- */
            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var title = new Gtk.Label (_("Notifications"));
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            header.pack_start (title, true, true, 0);
            var gear = new Gtk.Button.from_icon_name (
                "emblem-system-symbolic", Gtk.IconSize.BUTTON);
            gear.set_relief (Gtk.ReliefStyle.NONE);
            gear.set_tooltip_text (_("Settings"));
            gear.clicked.connect (() => {
                dismiss ();
                Launch.settings ("notifications");
            });
            header.pack_end (gear, false, false, 0);
            clear_all_button = new Gtk.Button.with_label (
                _("Clear all"));
            clear_all_button.set_relief (Gtk.ReliefStyle.NONE);
            clear_all_button.clicked.connect (() => {
                if (Notifications.server != null) {
                    Notifications.server.clear_all ();
                }
            });
            header.pack_end (clear_all_button, false, false, 0);
            content.pack_start (header, false, false, 0);

            content.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 4);

            notif_scroll = new Gtk.ScrolledWindow (null, null);
            notif_scroll.set_policy (Gtk.PolicyType.NEVER,
                                     Gtk.PolicyType.AUTOMATIC);
            notif_list = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            notif_scroll.add (notif_list);
            content.pack_start (notif_scroll, true, true, 0);

            if (Notifications.server != null) {
                Notifications.server.history_changed.connect (() => {
                    if (get_visible ()) {
                        rebuild_notifications ();
                        refit ();
                    }
                });
            }

            content.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 4);

            /* --- takvim bölümü: başlık satırı + daraltma --- */
            var cal_header = new Gtk.Button ();
            cal_header.set_relief (Gtk.ReliefStyle.NONE);
            var cal_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            date_label = new Gtk.Label ("");
            date_label.set_xalign (0);
            cal_row.pack_start (date_label, true, true, 0);
            collapse_arrow = new Gtk.Label ("⌄");
            collapse_arrow.get_style_context ().add_class ("dim");
            cal_row.pack_end (collapse_arrow, false, false, 0);
            cal_header.add (cal_row);
            cal_header.clicked.connect (() => {
                set_calendar_collapsed (!config.calendar_collapsed, true);
                rebuild_notifications ();   /* liste yüksekliği değişir */
                if (get_visible ()) {
                    refit ();
                }
            });
            content.pack_start (cal_header, false, false, 0);

            calendar = new Gtk.Calendar ();
            calendar.show_heading = true;    /* "Eylül 2026" + ▲▼ */
            calendar.show_day_names = true;
            content.pack_start (calendar, false, false, 0);
        }

        /* Daraltılınca yalnız başlık satırı kalır; durum kavis.conf'ta
         * hatırlanır ([clock] calendar_collapsed). */
        private void set_calendar_collapsed (bool collapsed, bool save) {
            calendar.set_no_show_all (collapsed);
            calendar.set_visible (!collapsed);
            collapse_arrow.set_text (collapsed ? "‹" : "⌄");
            if (save) {
                config.calendar_collapsed = collapsed;
                config.save ();
            }
        }

        private void rebuild_notifications () {
            foreach (var child in notif_list.get_children ()) {
                notif_list.remove (child);
            }
            unowned NotificationServer? server = Notifications.server;
            if (server == null || server.history.length == 0) {
                /* Bildirim yokken liste küçülür, takvim tam boy kalır. */
                notif_scroll.set_size_request (-1, 64);
                var empty = new Gtk.Label (
                    _("No new notifications"));
                empty.get_style_context ().add_class ("dim");
                empty.set_margin_top (20);
                notif_list.pack_start (empty, false, false, 0);
                clear_all_button.set_sensitive (false);
                notif_list.show_all ();
                return;
            }
            notif_scroll.set_size_request (-1,
                config.calendar_collapsed ? 320 : 220);
            clear_all_button.set_sensitive (true);

            /* Uygulama bazlı grupla: geçmiş zaten yeni→eski sıralı;
             * ilk görüldüğü sıraya göre grup başlıkları. */
            var seen = new GenericArray<string> ();
            for (int i = 0; i < server.history.length; i++) {
                unowned string app = server.history[i].app_name;
                bool found = false;
                for (int j = 0; j < seen.length; j++) {
                    if (seen[j] == app) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    seen.add (app);
                }
            }
            for (int g = 0; g < seen.length; g++) {
                unowned string app = seen[g];
                var group_header = new Gtk.Box (
                    Gtk.Orientation.HORIZONTAL, 8);
                var app_label = new Gtk.Label (null);
                app_label.set_markup ("<small><b>%s</b></small>".printf (
                    Markup.escape_text (app)));
                app_label.get_style_context ().add_class ("dim");
                app_label.set_xalign (0);
                group_header.pack_start (app_label, true, true, 0);
                var clear_button = new Gtk.Button.from_icon_name (
                    "window-close-symbolic", Gtk.IconSize.BUTTON);
                clear_button.set_relief (Gtk.ReliefStyle.NONE);
                clear_button.set_tooltip_text (
                    _("Clear"));
                string app_copy = app;
                clear_button.clicked.connect (() => {
                    Notifications.server.clear_app (app_copy);
                });
                group_header.pack_end (clear_button, false, false, 0);
                notif_list.pack_start (group_header, false, false, 0);

                for (int i = 0; i < server.history.length; i++) {
                    unowned NotificationEntry entry = server.history[i];
                    if (entry.app_name != app) {
                        continue;
                    }
                    notif_list.pack_start (notification_row (entry),
                                           false, false, 0);
                }
            }
            notif_list.show_all ();
        }

        /* One notification: a time line whose chevron collapses the
         * card (W11 behavior), then summary / body / optional image
         * preview. Clicking the card opens what it points at (e.g. a
         * screenshot reveals itself in the file manager). */
        private Gtk.Widget notification_row (NotificationEntry entry) {
            var row = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            var toggle = new Gtk.Button ();
            toggle.set_relief (Gtk.ReliefStyle.NONE);
            var line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            var when = new Gtk.Label (entry.timestamp.format ("%H:%M"));
            when.get_style_context ().add_class ("dim");
            when.set_xalign (0);
            line.pack_start (when, true, true, 0);
            var arrow = new Gtk.Label ("⌄");
            arrow.get_style_context ().add_class ("dim");
            line.pack_end (arrow, false, false, 0);
            toggle.add (line);
            row.pack_start (toggle, false, false, 0);

            var details = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            var summary = new Gtk.Label (null);
            summary.set_markup ("<b>%s</b>".printf (
                Markup.escape_text (entry.summary)));
            summary.set_xalign (0);
            summary.set_ellipsize (Pango.EllipsizeMode.END);
            details.pack_start (summary, false, false, 0);
            if (entry.body != "") {
                var body = new Gtk.Label (entry.body);
                body.get_style_context ().add_class ("dim");
                body.set_xalign (0);
                body.set_ellipsize (Pango.EllipsizeMode.END);
                details.pack_start (body, false, false, 0);
            }
            if (entry.image_path != ""
                && FileUtils.test (entry.image_path, FileTest.IS_REGULAR)) {
                try {
                    var preview = new Gtk.Image.from_pixbuf (
                        new Gdk.Pixbuf.from_file_at_scale (
                            entry.image_path, 320, 110, true));
                    preview.set_halign (Gtk.Align.START);
                    details.pack_start (preview, false, false, 2);
                } catch (Error e) { }
            }

            /* Hedefi olan bildirim tıklanabilir bir karta sarılır. */
            Gtk.Widget detail_holder;
            if (entry.target_path != "") {
                var card = new Gtk.Button ();
                card.set_relief (Gtk.ReliefStyle.NONE);
                card.add (details);
                string target = entry.target_path;
                card.clicked.connect (() => {
                    dismiss ();
                    Launch.reveal (target);
                });
                row.pack_start (card, false, false, 0);
                detail_holder = card;
            } else {
                details.set_margin_start (8);
                row.pack_start (details, false, false, 0);
                detail_holder = details;
            }

            /* Chevron daraltması: ayrıntı kutusu gizlenir, saat satırı
             * kalır. Durum geçicidir (yeniden kurulunca açık gelir). */
            toggle.clicked.connect (() => {
                bool visible = detail_holder.get_visible ();
                detail_holder.set_no_show_all (visible);
                detail_holder.set_visible (!visible);
                arrow.set_text (visible ? "‹" : "⌄");
            });
            return row;
        }

        protected override void refresh_content () {
            /* Başlık: "Çarşamba, 2 Eylül" — gün/ay adları yereldan. */
            var now = new DateTime.now_local ();
            date_label.set_markup ("<b>%s, %d %s</b>".printf (
                Markup.escape_text (now.format ("%A")),
                now.get_day_of_month (),
                Markup.escape_text (now.format ("%B"))));

            /* Jump back to the current month with today selected —
             * whatever month was browsed last time. */
            calendar.select_month (now.get_month () - 1, now.get_year ());
            calendar.select_day (now.get_day_of_month ());
            set_calendar_collapsed (config.calendar_collapsed, false);

            rebuild_notifications ();
        }
    }

    /* Keyboard-layout popup: TR / EN choice, the active one marked. */
    public class KeyboardPopup : PanelPopup {

        public signal void changed ();

        private Gtk.Image tr_mark;
        private Gtk.Image en_mark;

        public KeyboardPopup () {
            /* Grup D 2c: başlık ve satırlar kenara yapışıktı — 8-10px
             * iç boşluk, başlıkla liste arasına ince ayrım çizgisi. */
            var title = new Gtk.Label (_("Keyboard layout"));
            title.get_style_context ().add_class ("dim");
            title.set_xalign (0);
            title.set_margin_start (8);
            title.set_margin_end (8);
            title.set_margin_top (4);
            content.pack_start (title, false, false, 0);

            content.pack_start (
                new Gtk.Separator (Gtk.Orientation.HORIZONTAL),
                false, false, 4);

            content.pack_start (
                layout_row (N_("Turkish Q"), "tr", out tr_mark),
                false, false, 0);
            content.pack_start (
                layout_row (N_("English (US)"), "us", out en_mark),
                false, false, 0);
        }

        private Gtk.Button layout_row (string label_key, string layout,
                                       out Gtk.Image mark) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            row.set_margin_start (2);
            row.set_margin_end (2);
            var label = new Gtk.Label (_(label_key));
            label.set_xalign (0);
            label.set_width_chars (16);
            row.pack_start (label, true, true, 0);
            var check = new Gtk.Image.from_icon_name (
                "object-select-symbolic", Gtk.IconSize.BUTTON);
            row.pack_end (check, false, false, 0);
            button.add (row);
            button.clicked.connect (() => {
                Keyboard.set_layout (layout);
                dismiss ();
                /* setxkbmap runs asynchronously; poke listeners after
                 * it has had time to apply. */
                Timeout.add (400, () => {
                    changed ();
                    return Source.REMOVE;
                });
            });
            mark = check;
            return button;
        }

        protected override void refresh_content () {
            bool turkish = Keyboard.current_layout ().down ()
                .has_prefix ("tr");
            /* show_all on open would reveal both marks; pin them. */
            tr_mark.set_no_show_all (!turkish);
            en_mark.set_no_show_all (turkish);
            tr_mark.set_visible (turkish);
            en_mark.set_visible (!turkish);
        }
    }

}
