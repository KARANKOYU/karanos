/* Right-edge indicators of the taskbar (UI layer).
 *
 * Since stage 4 each indicator is a flat button that toggles a small
 * popup above the panel (calendar, battery + power plan, keyboard
 * layout, volume). System access lives in the logic namespaces
 * (Battery, Keyboard, Volume); these files only draw.
 *
 * No system tray (XEmbed / StatusNotifier) here — that is its own task
 * and comes later with the notification infrastructure (item 37).
 */

namespace Kavis.Ui {

    /* Clock and date; clicking opens the monthly calendar. Seconds are
     * not shown, so a redraw per minute is enough: we poll every 30 s —
     * missing the exact minute boundary by at most half a second, and
     * self-correcting after suspend. */
    public class Clock : Gtk.Button {

        private Gtk.Label text_label;
        private NotificationCenterPopup popup;
        private bool vertical;

        public Clock (bool vertical = false) {
            this.vertical = vertical;
            set_relief (Gtk.ReliefStyle.NONE);
            get_style_context ().add_class ("indicator-button");
            text_label = new Gtk.Label ("");
            text_label.get_style_context ().add_class ("clock");
            text_label.set_justify (Gtk.Justification.CENTER);
            add (text_label);

            popup = new NotificationCenterPopup ();
            clicked.connect (() => popup.toggle_at (this));

            refresh ();
            Timeout.add_seconds (30, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private void refresh () {
            var now = new DateTime.now_local ();
            /* Dikey panelde (test8 A1) yıl sığmıyor: kısa tarih. */
            text_label.set_markup ("<small>%s\n%s</small>".printf (
                now.format ("%H:%M"),
                now.format (vertical ? "%d.%m" : "%d.%m.%Y")));
        }
    }

    /* Active keyboard layout (TR/EN); clicking opens the switcher. */
    public class KeyboardIndicator : Gtk.Button {

        private Gtk.Label text_label;
        private KeyboardPopup popup;

        public KeyboardIndicator () {
            set_relief (Gtk.ReliefStyle.NONE);
            get_style_context ().add_class ("indicator-button");
            text_label = new Gtk.Label ("");
            text_label.get_style_context ().add_class ("indicator");
            add (text_label);

            popup = new KeyboardPopup ();
            popup.changed.connect (() => refresh ());
            clicked.connect (() => popup.toggle_at (this));

            refresh ();
            Timeout.add_seconds (2, () => {
                refresh ();
                return Source.CONTINUE;
            });
        }

        private void refresh () {
            text_label.set_text (Keyboard.current_layout ().up ());
        }
    }

    /* Status cluster (sonraki-isler 1): Wi-Fi + volume + battery are
     * ONE button, hovered together W11-style; clicking opens the
     * shared quick settings, they are not clickable individually.
     * Right click merges the old per-tool quick actions (mute +
     * output devices, Wi-Fi disconnect / network settings, power
     * plans) so nothing from the madde 3 contract is lost. Hidden
     * entirely when none of the three exists. */
    public class StatusCluster : Gtk.Button {

        private Gtk.Image? wifi_icon = null;
        private Gtk.Image? volume_icon = null;
        private Gtk.Label? battery_label = null;
        private bool has_wifi;
        private bool has_volume;
        private bool has_battery;

        public StatusCluster (bool vertical = false) {
            set_relief (Gtk.ReliefStyle.NONE);
            get_style_context ().add_class ("indicator-button");

            has_wifi = Quick.wifi_available ();
            has_volume = Volume.available ();
            has_battery = Battery.present ();
            if (!has_wifi && !has_volume && !has_battery) {
                set_no_show_all (true);
                hide ();
                return;
            }

            /* Dikey panelde öğeler alt alta (test8 A1). */
            var row = new Gtk.Box (vertical
                ? Gtk.Orientation.VERTICAL
                : Gtk.Orientation.HORIZONTAL, 8);
            if (vertical) {
                row.set_margin_top (6);
                row.set_margin_bottom (6);
            } else {
                row.set_margin_start (6);
                row.set_margin_end (6);
            }
            if (has_wifi) {
                wifi_icon = new Gtk.Image.from_icon_name (
                    "network-wireless-symbolic", Gtk.IconSize.BUTTON);
                row.pack_start (wifi_icon, false, false, 0);
            }
            if (has_volume) {
                volume_icon = new Gtk.Image.from_icon_name (
                    "audio-volume-high-symbolic", Gtk.IconSize.BUTTON);
                row.pack_start (volume_icon, false, false, 0);
            }
            if (has_battery) {
                battery_label = new Gtk.Label ("");
                row.pack_start (battery_label, false, false, 0);
            }
            add (row);
            set_tooltip_text (_("Network, sound, battery"));

            clicked.connect (() => {
                QuickSettingsPopup.get_default ().toggle_at (this);
            });
            button_press_event.connect ((event) => {
                if (event.button == 3) {
                    show_menu (event);
                    return true;
                }
                return false;
            });

            refresh_fast ();
            refresh_slow ();
            Timeout.add_seconds (10, () => {
                refresh_fast ();
                return Source.CONTINUE;
            });
            Timeout.add_seconds (30, () => {
                refresh_slow ();
                return Source.CONTINUE;
            });
        }

        /* Ses ikonu (10 sn). Araç ipucu grubu anlatır (test8 B5) —
         * SSID değil: küme tek düğme, adı da bütünü söylemeli. */
        private void refresh_fast () {
            if (volume_icon != null) {
                var state = Volume.read ();
                volume_icon.set_from_icon_name (
                    Volume.icon_name (state.percent, state.muted),
                    Gtk.IconSize.BUTTON);
            }
        }

        /* Pil yüzdesi (30 sn). */
        private void refresh_slow () {
            if (battery_label == null) {
                return;
            }
            int percent = Battery.percent ();
            if (percent < 0) {
                battery_label.set_text ("");
                return;
            }
            unowned string mark = Battery.charging () ? "⚡" : "";
            /* Yüzde biçimi dile göre değişir (TR: %93, EN: 93%) —
             * biçim dizgesinin kendisi çevrilir. */
            battery_label.set_text (mark + _("%d%%").printf (percent));
        }

        private void show_menu (Gdk.EventButton event) {
            var menu = new Gtk.Menu ();
            if (has_volume) {
                var mute = new Gtk.MenuItem.with_label (_("Mute"));
                mute.activate.connect (() => {
                    Volume.toggle_mute ();
                    Timeout.add (150, () => {
                        refresh_fast ();
                        return Source.REMOVE;
                    });
                });
                menu.append (mute);
                if (Quick.sound_output_available ()) {
                    unowned SList<Gtk.RadioMenuItem>? group = null;
                    foreach (unowned Quick.SoundOutput sink in
                             Quick.sound_outputs ()) {
                        var item = new Gtk.RadioMenuItem.with_label (
                            group, sink.description);
                        group = item.get_group ();
                        item.set_active (sink.active);
                        string name = sink.name;
                        bool was_active = sink.active;
                        item.activate.connect (() => {
                            if (item.get_active () && !was_active) {
                                Quick.sound_set_output (name);
                            }
                        });
                        menu.append (item);
                    }
                }
            }
            if (has_wifi) {
                if (menu.get_children ().length () > 0) {
                    menu.append (new Gtk.SeparatorMenuItem ());
                }
                var disconnect = new Gtk.MenuItem.with_label (
                    _("Disconnect"));
                disconnect.set_sensitive (Quick.wifi_ssid () != "");
                disconnect.activate.connect (() => {
                    Quick.wifi_disconnect ();
                });
                menu.append (disconnect);
                var settings = new Gtk.MenuItem.with_label (
                    _("Network settings"));
                settings.activate.connect (() => {
                    Launch.settings ("network");
                });
                menu.append (settings);
            }
            if (has_battery) {
                if (menu.get_children ().length () > 0) {
                    menu.append (new Gtk.SeparatorMenuItem ());
                }
                append_plan_menus (menu);
            }
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

        private void append_plan_menus (Gtk.Menu menu) {
            bool[] sources = { true, false };
            string[] source_keys = {
                N_("When plugged in"), N_("On battery")
            };
            for (int s = 0; s < sources.length; s++) {
                var source_item = new Gtk.MenuItem.with_label (
                    _(source_keys[s]));
                var submenu = new Gtk.Menu ();
                unowned SList<Gtk.RadioMenuItem>? group = null;
                bool plugged = sources[s];
                PowerPlan.Plan[] plans = { PowerPlan.Plan.PERFORMANCE,
                                           PowerPlan.Plan.NORMAL,
                                           PowerPlan.Plan.SAVER };
                var current = PowerPlan.get_plan (plugged);
                foreach (var plan in plans) {
                    var item = new Gtk.RadioMenuItem.with_label (
                        group, plan_label (plan));
                    group = item.get_group ();
                    item.set_active (current == plan);
                    var chosen = plan;   /* closure copy */
                    item.activate.connect (() => {
                        if (item.get_active ()) {
                            PowerPlan.set_plan (plugged, chosen);
                        }
                    });
                    submenu.append (item);
                }
                source_item.set_submenu (submenu);
                menu.append (source_item);
            }
        }

        /* Anahtar birleştirme gettext'e çevrilemez (msgid sabit metin
         * olmalı) — plan adı açık eşlemeyle. */
        private static unowned string plan_label (PowerPlan.Plan plan) {
            switch (plan) {
            case PowerPlan.Plan.PERFORMANCE:
                return _("High performance");
            case PowerPlan.Plan.SAVER:
                return _("Power saver");
            default:
                return _("Balanced");
            }
        }
    }

    /* Virtual-desktop switcher: one small button per workspace, the
     * active one carries a teal underline (CSS class "active-item"). */
    public class WorkspaceIndicator : Gtk.Box {
        private unowned Wnck.Screen screen;
        private Gtk.Button[] buttons = {};
        private int[] numbers = {};

        public WorkspaceIndicator (Wnck.Screen screen,
                                   Gtk.Orientation axis
                                   = Gtk.Orientation.HORIZONTAL) {
            Object (orientation: axis, spacing: 2);
            this.screen = screen;
            rebuild ();
            screen.workspace_created.connect (() => rebuild ());
            screen.workspace_destroyed.connect (() => rebuild ());
            screen.active_workspace_changed.connect (() => mark_active ());
        }

        private void rebuild () {
            foreach (var child in get_children ()) {
                remove (child);
            }
            buttons = {};
            numbers = {};
            foreach (unowned Wnck.Workspace workspace in
                     screen.get_workspaces ()) {
                var button = new Gtk.Button.with_label (
                    "%d".printf (workspace.get_number () + 1));
                button.set_relief (Gtk.ReliefStyle.NONE);
                button.set_tooltip_text (workspace.get_name () ?? "");
                unowned Wnck.Workspace target = workspace;
                button.clicked.connect (() => {
                    target.activate (Gtk.get_current_event_time ());
                });
                buttons += button;
                numbers += workspace.get_number ();
                pack_start (button, false, false, 0);
            }
            show_all ();
            mark_active ();
        }

        private void mark_active () {
            unowned Wnck.Workspace? active = screen.get_active_workspace ();
            int active_number = (active != null) ? active.get_number () : -1;
            for (int i = 0; i < buttons.length; i++) {
                unowned Gtk.StyleContext context =
                    buttons[i].get_style_context ();
                if (numbers[i] == active_number) {
                    context.add_class ("active-item");
                } else {
                    context.remove_class ("active-item");
                }
            }
        }
    }
}
