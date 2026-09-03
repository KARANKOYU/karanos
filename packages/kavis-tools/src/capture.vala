/* Screen capture (madde 29, reworked in Grup D fix 5) —
 * `kavis-tools capture [--quick]`.
 *
 * --quick (Ctrl+PrtScr): captures WITHOUT asking, mode from
 * ~/.config/kavis/capture.conf ([capture] mode=window|monitor|all).
 *
 * PrtScr: Windows Snipping Tool flow, all in our own code (no
 * flameshot, no slop, no scrot):
 *   1. The instant the key is hit the whole root window is grabbed
 *      into a FROZEN pixbuf — open menus, tooltips, popups stay in
 *      the frame.
 *   2. A fullscreen overlay shows that frame under a 60% darkening
 *      layer, crosshair cursor, and a small top-center toolbar:
 *      Image|Video toggle, selection mode (rectangle / freeform /
 *      window / full screen), close. Esc cancels.
 *   3. The selected area shows undarkened with a teal border and a
 *      size readout. Window mode highlights the window under the
 *      pointer (Wnck geometry), click selects it.
 *   4. Image: CROP FROM THE FROZEN FRAME, copy to clipboard, save
 *      under pictures/screenshots, notify (preview image + click
 *      reveals the file — the panel's image-path / x-kavis-path
 *      hints). Video: recording starts on the selected geometry
 *      (ffmpeg x11grab, optional system audio and/or microphone via
 *      pulse), a floating bar shows red dot + elapsed + stop;
 *      pressing PrtScr again also stops (pidfile + SIGUSR1).
 */

namespace Kavis.Tools {

    namespace Capture {

        public string config_value (string key, string fallback) {
            var file = new KeyFile ();
            try {
                file.load_from_file (Path.build_filename (
                    Environment.get_user_config_dir (), "kavis",
                    "capture.conf"), KeyFileFlags.NONE);
                return file.get_string ("capture", key);
            } catch (Error e) {
                return fallback;
            }
        }

        public string save_dir (string kind) {
            string configured = config_value ("save_dir", "");
            if (configured != "") {
                return configured;
            }
            unowned string home = Environment.get_home_dir ();
            if (kind == "video") {
                /* Madde 5: videolar videos/recordings altına. */
                string videos = Path.build_filename (home, "videos");
                if (FileUtils.test (videos, FileTest.IS_DIR)) {
                    return Path.build_filename (videos, "recordings");
                }
                return home;
            }
            string pictures = Path.build_filename (home, "pictures");
            if (FileUtils.test (pictures, FileTest.IS_DIR)) {
                return Path.build_filename (pictures, "screenshots");
            }
            return home;
        }

        public string timestamp_path (string kind, string extension) {
            string dir = save_dir (kind);
            DirUtils.create_with_parents (dir, 0755);
            var now = new DateTime.now_local ();
            return Path.build_filename (dir,
                now.format ("%Y-%m-%d_%H-%M-%S") + extension);
        }

        /* gdbus zaten ISO'da; libnotify bağımlılığı yok. `attach`
         * dolu gelirse panel bildirim merkezinde küçük önizleme
         * gösterir ve tıklayınca dosyayı dosya yöneticisinde açar. */
        public void notify_user (string summary, string body,
                                 string icon, string attach = "") {
            string hints = "{}";
            if (attach != "") {
                hints = "{'image-path': <'%s'>, 'x-kavis-path': <'%s'>}"
                    .printf (attach, attach);
            }
            try {
                Process.spawn_async (null, {
                    "gdbus", "call", "--session",
                    "--dest", "org.freedesktop.Notifications",
                    "--object-path", "/org/freedesktop/Notifications",
                    "--method", "org.freedesktop.Notifications.Notify",
                    "Kavis", "0", icon, summary, body, "[]", hints, "6000"
                }, null, SpawnFlags.SEARCH_PATH
                   | SpawnFlags.STDOUT_TO_DEV_NULL, null, null);
            } catch (Error e) {
                warning ("kavis-tools: bildirim verilemedi: %s", e.message);
            }
        }

        /* D4: dosya bildirimi — tıklanabilir toast için hedef yol +
         * "Show in folder" düğmesi. Düğme tıkı ActionInvoked ile bu
         * sürece döner (pano ömrü boyunca zaten yaşıyoruz). */
        private DBusConnection? notify_bus;
        private uint32 notify_id;
        private string? notify_target;

        public void reveal_in_folder (string path) {
            try {
                if (Environment.find_program_in_path ("nemo") != null) {
                    Process.spawn_async (null, { "nemo", path }, null,
                        SpawnFlags.SEARCH_PATH, null, null);
                } else {
                    Process.spawn_async (null, { "xdg-open",
                        Path.get_dirname (path) }, null,
                        SpawnFlags.SEARCH_PATH, null, null);
                }
            } catch (Error e) { }
        }

        public void notify_file (string summary, string path,
                                 string icon) {
            try {
                notify_bus = Bus.get_sync (BusType.SESSION);
                var hints = new VariantBuilder (
                    new VariantType ("a{sv}"));
                hints.add ("{sv}", "image-path",
                           new Variant.string (path));
                hints.add ("{sv}", "x-kavis-path",
                           new Variant.string (path));
                var actions = new VariantBuilder (
                    new VariantType ("as"));
                actions.add ("s", "show-folder");
                actions.add ("s", _("Show in folder"));
                var reply = notify_bus.call_sync (
                    "org.freedesktop.Notifications",
                    "/org/freedesktop/Notifications",
                    "org.freedesktop.Notifications", "Notify",
                    new Variant ("(susssasa{sv}i)", "Kavis",
                                 (uint32) 0, icon, summary, path,
                                 actions, hints, 6000),
                    new VariantType ("(u)"),
                    DBusCallFlags.NONE, -1, null);
                reply.get ("(u)", out notify_id);
                notify_target = path;
                notify_bus.signal_subscribe (null,
                    "org.freedesktop.Notifications", "ActionInvoked",
                    "/org/freedesktop/Notifications", null,
                    DBusSignalFlags.NONE,
                    (connection, sender, opath, iface, name, args) => {
                        uint32 id;
                        string key;
                        args.get ("(us)", out id, out key);
                        if (id == notify_id && key == "show-folder"
                            && notify_target != null) {
                            reveal_in_folder (notify_target);
                        }
                    });
            } catch (Error e) {
                /* bildirim servisi yoksa sessiz; dosya zaten kayıtlı */
                notify_user (summary, path, icon, path);
            }
        }

        /* Pano X sahibiyle ölür: görüntüyü koyup bir süre yaşa. */
        public void hold_clipboard_then_quit () {
            Timeout.add_seconds (60, () => {
                Gtk.main_quit ();
                return Source.REMOVE;
            });
        }

        private string recording_pid_path () {
            return Path.build_filename (
                Environment.get_user_runtime_dir (),
                "kavis-capture.pid");
        }

        /* --- hızlı yakalama (Ctrl+PrtScr) ------------------------------ */

        public int quick () {
            var root = Gdk.get_default_root_window ();
            var display = Gdk.Display.get_default ();
            int x = 0, y = 0, w = root.get_width (), h = root.get_height ();

            string mode = config_value ("mode", "all");
            if (mode == "monitor") {
                int px, py;
                var seat = display.get_default_seat ();
                seat.get_pointer ().get_position (null, out px, out py);
                Gdk.Rectangle geo =
                    display.get_monitor_at_point (px, py).get_geometry ();
                x = geo.x; y = geo.y; w = geo.width; h = geo.height;
            } else if (mode == "window") {
                var screen = Wnck.Screen.get_default ();
                screen.force_update ();
                unowned Wnck.Window? active = screen.get_active_window ();
                if (active != null) {
                    active.get_geometry (out x, out y, out w, out h);
                }
            }

            var pixbuf = Gdk.pixbuf_get_from_window (root, x, y, w, h);
            if (pixbuf == null) {
                warning ("kavis-tools: ekran okunamadi");
                return 1;
            }
            string path = timestamp_path ("image", ".png");
            try {
                pixbuf.save (path, "png");
            } catch (Error e) {
                warning ("kavis-tools: kaydedilemedi: %s", e.message);
                return 1;
            }

            Gtk.Clipboard.get_default (display).set_image (pixbuf);
            notify_file (_("Screenshot saved"), path,
                         "camera-photo-symbolic");
            hold_clipboard_then_quit ();
            Gtk.main ();
            return 0;
        }

        /* --- PrtScr: dondurulmuş kare seçicisi ------------------------- */

        /* Kayıt sürerken PrtScr kaydı durdurur: çalışan sürece SIGUSR1
         * gönderilir (RecorderBar yakalayıp düzgün kapatır). */
        public int snip (bool color_mode = false) {
            string pid_file = recording_pid_path ();
            string contents;
            try {
                FileUtils.get_contents (pid_file, out contents);
                int pid = int.parse (contents.strip ());
                if (pid > 0 && Posix.kill ((Posix.pid_t) pid, 0) == 0) {
                    Posix.kill ((Posix.pid_t) pid, Posix.Signal.USR1);
                    return 0;
                }
                FileUtils.unlink (pid_file);   /* bayat dosya */
            } catch (Error e) {
                /* kayıt yok — seçiciye devam */
            }

            /* Kareyi HER ŞEYDEN ÖNCE dondur (madde 5 kuralı: basılan
             * andaki ekran, açık menüler dahil). */
            var root = Gdk.get_default_root_window ();
            var frozen = Gdk.pixbuf_get_from_window (
                root, 0, 0, root.get_width (), root.get_height ());
            if (frozen == null) {
                warning ("kavis-tools: ekran okunamadi");
                return 1;
            }
            var window = new SnipWindow (frozen, color_mode);
            window.show_all ();
            Gtk.main ();
            return 0;
        }
    }

    /* Fullscreen frozen-frame selector. */
    public class SnipWindow : Gtk.Window {

        private enum Mode { RECT, ELLIPSE, FREEFORM, WINDOW, FULL, COLOR }

        /* Marka turkuazı (görsel kimlik tablosu). */
        private const double TEAL_R = 0.176;
        private const double TEAL_G = 0.831;
        private const double TEAL_B = 0.749;

        private Gdk.Pixbuf frozen;
        private Gtk.DrawingArea canvas;
        private Mode mode = Mode.RECT;
        private bool video_mode = false;
        private Gtk.CheckButton audio_check;
        private Gtk.CheckButton mic_check;
        private Gtk.ToggleButton image_toggle;
        private Gtk.ToggleButton video_toggle;
        private Gtk.ToggleButton[] mode_buttons = {};

        private bool selecting = false;
        private bool has_area = false;
        private int start_x = 0;
        private int start_y = 0;
        private int sel_x = 0;
        private int sel_y = 0;
        private int sel_w = 0;
        private int sel_h = 0;
        private double[] path_x = {};
        private double[] path_y = {};
        private bool switching_toggle = false;
        /* Renk modu (5c): işaretçi konumu + bildirim eylem aboneliği. */
        private int pointer_x = 0;
        private int pointer_y = 0;
        private DBusConnection? bus = null;
        private Gtk.Box? window_list_holder = null;
        private Gtk.Box window_list_box;
        private uint32 color_notif_id = 0;
        private string rgb_text = "";
        private string hsl_text = "";

        public SnipWindow (Gdk.Pixbuf frozen, bool color_mode = false) {
            Object (type: Gtk.WindowType.POPUP);
            this.frozen = frozen;
            if (color_mode) {
                mode = Mode.COLOR;
            }
            set_default_size (frozen.get_width (), frozen.get_height ());
            move (0, 0);

            var overlay = new Gtk.Overlay ();
            add (overlay);

            canvas = new Gtk.DrawingArea ();
            canvas.add_events (Gdk.EventMask.BUTTON_PRESS_MASK
                               | Gdk.EventMask.BUTTON_RELEASE_MASK
                               | Gdk.EventMask.POINTER_MOTION_MASK);
            canvas.draw.connect (on_draw);
            canvas.button_press_event.connect (on_press);
            canvas.motion_notify_event.connect (on_motion);
            canvas.button_release_event.connect (on_release);
            overlay.add (canvas);

            /* D1: araç çubuğu üstünde imleç OK olsun (canvas artı
             * kalır) — kendi GdkWindow'u olan EventBox sarmalı. */
            var bar_holder = new Gtk.EventBox ();
            bar_holder.add (build_toolbar ());
            bar_holder.set_halign (Gtk.Align.CENTER);
            bar_holder.set_valign (Gtk.Align.START);
            bar_holder.realize.connect (() => {
                bar_holder.get_window ().set_cursor (
                    new Gdk.Cursor.for_display (
                        Gdk.Display.get_default (),
                        Gdk.CursorType.LEFT_PTR));
            });
            overlay.add_overlay (bar_holder);

            /* D3: Pencere modu — imleçle vurgu yerine AÇIK PENCERE
             * LİSTESİ (ikon + başlık); seçilen yakalanır. */
            var list_holder = new Gtk.EventBox ();
            window_list_holder = new Gtk.Box (
                Gtk.Orientation.VERTICAL, 0);
            window_list_holder.get_style_context ()
                .add_class ("kavis-snip-bar");
            window_list_holder.set_border_width (10);
            window_list_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            var list_scroll = new Gtk.ScrolledWindow (null, null);
            list_scroll.set_policy (Gtk.PolicyType.NEVER,
                                    Gtk.PolicyType.AUTOMATIC);
            list_scroll.set_size_request (380, 300);
            list_scroll.add (window_list_box);
            window_list_holder.pack_start (list_scroll, true, true, 0);
            list_holder.add (window_list_holder);
            list_holder.set_halign (Gtk.Align.CENTER);
            list_holder.set_valign (Gtk.Align.CENTER);
            list_holder.realize.connect (() => {
                list_holder.get_window ().set_cursor (
                    new Gdk.Cursor.for_display (
                        Gdk.Display.get_default (),
                        Gdk.CursorType.LEFT_PTR));
            });
            list_holder.set_no_show_all (true);
            overlay.add_overlay (list_holder);
            window_list_holder.set_data<Gtk.EventBox> (
                "holder", list_holder);

            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    cancel ();
                    return true;
                }
                return false;
            });

            realize.connect (() => {
                get_window ().set_cursor (new Gdk.Cursor.for_display (
                    Gdk.Display.get_default (),
                    Gdk.CursorType.CROSSHAIR));
            });
            /* POPUP pencere klavye/fareyi ancak grab ile alır; map
             * asenkron olduğundan kısa aralıkla yeniden dene. */
            map_event.connect (() => {
                try_grab ();
                return false;
            });
        }

        private void try_grab () {
            var seat = Gdk.Display.get_default ().get_default_seat ();
            /* owner_events=true: olaylar kendi alt pencerelerimize
             * (canvas) normal aksın — false olsaydı hepsi üst
             * pencereye yönlenir, çizim alanı hiç basış görmezdi
             * (Xvfb'de yaşandı). */
            if (seat.grab (get_window (), Gdk.SeatCapabilities.ALL,
                           true, null, null, null)
                == Gdk.GrabStatus.SUCCESS) {
                return;
            }
            uint tries = 0;
            Timeout.add (50, () => {
                tries++;
                if (!get_visible ()) {
                    return Source.REMOVE;
                }
                return seat.grab (get_window (),
                                  Gdk.SeatCapabilities.ALL,
                                  true, null, null, null)
                    != Gdk.GrabStatus.SUCCESS && tries < 10;
            });
        }

        private void cancel () {
            Gdk.Display.get_default ().get_default_seat ().ungrab ();
            destroy ();
            Gtk.main_quit ();
        }

        /* --- üst araç çubuğu ------------------------------------------ */

        private Gtk.Widget build_toolbar () {
            var bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            bar.get_style_context ().add_class ("kavis-snip-bar");
            bar.set_margin_top (12);
            bar.set_border_width (6);

            var css = new Gtk.CssProvider ();
            try {
                css.load_from_data ("""
                    .kavis-snip-bar {
                      background-color: @kavis_surface;
                      border: 1px solid @kavis_border;
                      border-radius: 12px;   /* J1 */
                    }
                    .kavis-snip-bar button {
                      background-image: none;
                      background-color: transparent;
                      border: none;
                      border-radius: 8px;
                      color: @kavis_text;
                      padding: 4px 10px;
                    }
                    .kavis-snip-bar button:hover {
                      background-color: @kavis_hover;
                    }
                    .kavis-snip-bar button:checked {
                      background-color: @kavis_teal;
                      color: @kavis_on_teal;
                    }
                    .kavis-snip-bar button:checked label {
                      color: @kavis_on_teal;
                    }
                    .kavis-snip-bar label {
                      color: @kavis_text;
                    }
                    """, -1);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), css,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) { }

            image_toggle = new Gtk.ToggleButton.with_label (
                "📷 " + _("Image"));
            video_toggle = new Gtk.ToggleButton.with_label (
                "🔴 " + _("Video"));
            image_toggle.set_active (true);
            image_toggle.toggled.connect (() => {
                set_video_mode (false);
            });
            video_toggle.toggled.connect (() => {
                set_video_mode (true);
            });
            bar.pack_start (image_toggle, false, false, 0);
            bar.pack_start (video_toggle, false, false, 0);

            bar.pack_start (new Gtk.Separator (
                Gtk.Orientation.VERTICAL), false, false, 2);

            string[] mode_keys = {
                N_("Rectangle"), N_("Ellipse"), N_("Freeform"),
                N_("Window"), N_("Full screen"), N_("Color")
            };
            Mode[] modes = { Mode.RECT, Mode.ELLIPSE, Mode.FREEFORM,
                             Mode.WINDOW, Mode.FULL, Mode.COLOR };
            for (int i = 0; i < modes.length; i++) {
                var button = new Gtk.ToggleButton.with_label (
                    _(mode_keys[i]));
                button.set_active (modes[i] == mode);
                Mode chosen = modes[i];
                button.toggled.connect (() => {
                    on_mode_toggled (button, chosen);
                });
                mode_buttons += button;
                bar.pack_start (button, false, false, 0);
            }

            /* Ses seçenekleri yalnız video kipinde görünür. */
            audio_check = new Gtk.CheckButton.with_label (
                _("Record audio too"));
            audio_check.set_no_show_all (true);
            mic_check = new Gtk.CheckButton.with_label (
                _("Microphone"));
            mic_check.set_no_show_all (true);
            bar.pack_start (audio_check, false, false, 0);
            bar.pack_start (mic_check, false, false, 0);

            bar.pack_start (new Gtk.Separator (
                Gtk.Orientation.VERTICAL), false, false, 2);
            var close = new Gtk.Button.with_label ("✕");
            close.set_relief (Gtk.ReliefStyle.NONE);
            close.set_tooltip_text (_("Close"));
            close.clicked.connect (cancel);
            bar.pack_start (close, false, false, 0);

            return bar;
        }

        private void set_video_mode (bool video) {
            if (switching_toggle) {
                return;
            }
            switching_toggle = true;
            video_mode = video;
            image_toggle.set_active (!video);
            video_toggle.set_active (video);
            audio_check.set_visible (video);
            mic_check.set_visible (video);
            switching_toggle = false;
        }

        private void on_mode_toggled (Gtk.ToggleButton source,
                                      Mode chosen) {
            if (switching_toggle || !source.get_active ()) {
                /* Sönen düğme; ya da tümü sönmesin diye geri yak. */
                if (!switching_toggle && !source.get_active ()
                    && mode == chosen) {
                    switching_toggle = true;
                    source.set_active (true);
                    switching_toggle = false;
                }
                return;
            }
            switching_toggle = true;
            mode = chosen;
            foreach (unowned Gtk.ToggleButton button in mode_buttons) {
                if (button != source) {
                    button.set_active (false);
                }
            }
            switching_toggle = false;
            has_area = false;
            selecting = false;
            update_window_list ();
            canvas.queue_draw ();
        }

        /* D3: pencere listesi yalnız Pencere modunda görünür. */
        private void update_window_list () {
            var holder = window_list_holder.get_data<Gtk.EventBox> (
                "holder");
            if (mode != Mode.WINDOW) {
                holder.set_visible (false);
                holder.set_no_show_all (true);
                return;
            }
            foreach (var child in window_list_box.get_children ()) {
                window_list_box.remove (child);
            }
            var screen = Wnck.Screen.get_default ();
            screen.force_update ();
            foreach (unowned Wnck.Window candidate in
                     screen.get_windows ()) {
                if (candidate.is_skip_tasklist ()
                    || candidate.get_window_type ()
                       == Wnck.WindowType.DESKTOP
                    || candidate.get_window_type ()
                       == Wnck.WindowType.DOCK) {
                    continue;
                }
                var row = new Gtk.Button ();
                row.set_relief (Gtk.ReliefStyle.NONE);
                var line = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
                var icon = candidate.get_icon ();
                if (icon != null) {
                    line.pack_start (new Gtk.Image.from_pixbuf (
                        icon.scale_simple (24, 24,
                            Gdk.InterpType.BILINEAR)),
                        false, false, 0);
                }
                var title = new Gtk.Label (candidate.get_name () ?? "");
                title.set_xalign (0);
                title.set_ellipsize (Pango.EllipsizeMode.END);
                title.set_max_width_chars (36);
                line.pack_start (title, true, true, 0);
                row.add (line);
                unowned Wnck.Window target = candidate;
                row.clicked.connect (() => {
                    capture_window (target);
                });
                window_list_box.pack_start (row, false, false, 0);
            }
            holder.set_no_show_all (false);
            holder.show_all ();
        }

        /* Seçilen pencereyi yakala. Kompozitör varken pencerenin KENDİ
         * çizim yüzeyi okunur (COMPOSITE yönlendirmesi örtülü kısmı da
         * içerir — picom canlı sistemde hep açık); kompozitörsüz yedek:
         * öne getirip kök pencereden kırp. Görev çubuğu kareye girmez —
         * kaynak pencerenin kendisi. */
        private void capture_window (Wnck.Window target) {
            Gdk.Display.get_default ().get_default_seat ().ungrab ();
            hide ();

            if (video_mode) {
                /* Video: pencere öne, kaydı geometrisinde başlat. */
                bool with_audio = audio_check.get_active ();
                bool with_mic = mic_check.get_active ();
                target.activate (Gtk.get_current_event_time ());
                int wx, wy, ww, wh;
                target.get_geometry (out wx, out wy, out ww, out wh);
                destroy ();
                Timeout.add (400, () => {
                    launch_ffmpeg (wx, wy, ww / 2 * 2, wh / 2 * 2,
                                   with_audio, with_mic);
                    return Source.REMOVE;
                });
                return;
            }

            Timeout.add (250, () => {
                grab_window_image (target);
                return Source.REMOVE;
            });
        }

        private void grab_window_image (Wnck.Window target) {
            var display = Gdk.Display.get_default ();
            Gdk.Pixbuf? result = null;
            if (get_screen ().is_composited ()) {
                var foreign = new Gdk.X11.Window.foreign_for_display (
                    display as Gdk.X11.Display, target.get_xid ());
                if (foreign != null) {
                    result = Gdk.pixbuf_get_from_window (foreign, 0, 0,
                        foreign.get_width (), foreign.get_height ());
                }
            }
            if (result == null) {
                /* Yedek: öne getir, kökten kırp. */
                target.activate (Gtk.get_current_event_time ());
                int wx, wy, ww, wh;
                target.get_geometry (out wx, out wy, out ww, out wh);
                var root = Gdk.get_default_root_window ();
                result = Gdk.pixbuf_get_from_window (root, wx, wy,
                                                     ww, wh);
            }
            if (result == null) {
                warning ("kavis-tools: pencere okunamadi");
                cancel ();
                return;
            }
            string path = Capture.timestamp_path ("image", ".png");
            try {
                result.save (path, "png");
            } catch (Error e) {
                warning ("kavis-tools: kaydedilemedi: %s", e.message);
                cancel ();
                return;
            }
            Gtk.Clipboard.get_default (
                Gdk.Display.get_default ()).set_image (result);
            Capture.notify_file (_("Screenshot saved"), path,
                                 "camera-photo-symbolic");
            Capture.hold_clipboard_then_quit ();
        }

        /* --- çizim ---------------------------------------------------- */

        private bool on_draw (Cairo.Context cr) {
            Gdk.cairo_set_source_pixbuf (cr, frozen, 0, 0);
            cr.paint ();
            if (mode == Mode.COLOR) {
                /* Renk modunda karartma YOK — renkler bozulmasın;
                 * imlecin yanında 9×9 büyüteç + hex kutusu. */
                draw_magnifier (cr);
                return false;
            }
            cr.set_source_rgba (0, 0, 0, 0.6);
            cr.paint ();

            if (!has_area) {
                return false;
            }

            /* Seçim karartmasız: donmuş kare seçim yoluna kırpılıp
             * yeniden çizilir. */
            cr.save ();
            selection_path (cr);
            cr.clip ();
            Gdk.cairo_set_source_pixbuf (cr, frozen, 0, 0);
            cr.paint ();
            cr.restore ();

            selection_path (cr);
            cr.set_source_rgb (TEAL_R, TEAL_G, TEAL_B);
            cr.set_line_width (2);
            cr.stroke ();

            /* Köşede boyut. */
            if (sel_w > 0 && sel_h > 0) {
                string text = "%d×%d".printf (sel_w, sel_h);
                cr.select_font_face ("sans", Cairo.FontSlant.NORMAL,
                                     Cairo.FontWeight.BOLD);
                cr.set_font_size (13);
                Cairo.TextExtents extents;
                cr.text_extents (text, out extents);
                double tx = sel_x;
                double ty = sel_y + sel_h + extents.height + 8;
                if (ty > frozen.get_height () - 4) {
                    ty = sel_y - 8;
                }
                cr.set_source_rgba (0.09, 0.13, 0.17, 0.9);
                cr.rectangle (tx - 4, ty - extents.height - 4,
                              extents.width + 12, extents.height + 8);
                cr.fill ();
                cr.set_source_rgb (TEAL_R, TEAL_G, TEAL_B);
                cr.move_to (tx + 2, ty - 2);
                cr.show_text (text);
            }
            return false;
        }

        private void selection_path (Cairo.Context cr) {
            if (mode == Mode.ELLIPSE) {
                /* D2: eliptik seçim — dışı şeffaf kalır. */
                if (sel_w < 2 || sel_h < 2) {
                    return;
                }
                cr.save ();
                cr.translate (sel_x + sel_w / 2.0, sel_y + sel_h / 2.0);
                cr.scale (sel_w / 2.0, sel_h / 2.0);
                cr.arc (0, 0, 1, 0, 2 * Math.PI);
                cr.restore ();
                return;
            }
            if (mode == Mode.FREEFORM && path_x.length > 2) {
                cr.move_to (path_x[0], path_y[0]);
                for (int i = 1; i < path_x.length; i++) {
                    cr.line_to (path_x[i], path_y[i]);
                }
                cr.close_path ();
            } else {
                cr.rectangle (sel_x, sel_y, sel_w, sel_h);
            }
        }

        /* --- fare ----------------------------------------------------- */

        private bool on_press (Gdk.EventButton event) {
            if (event.button != 1) {
                return false;
            }
            switch (mode) {
            case Mode.COLOR:
                pick_color ((int) event.x, (int) event.y);
                break;
            case Mode.FULL:
                sel_x = 0; sel_y = 0;
                sel_w = frozen.get_width ();
                sel_h = frozen.get_height ();
                has_area = true;
                finish_selection ();
                break;
            case Mode.WINDOW:
                /* D3: seçim listeden yapılır, tuvalde tık işlemez. */
                break;
            case Mode.FREEFORM:
                selecting = true;
                path_x = { event.x };
                path_y = { event.y };
                has_area = false;
                break;
            default:   /* RECT ve ELLIPSE: köşeden sürükle */
                selecting = true;
                start_x = (int) event.x;
                start_y = (int) event.y;
                sel_w = 0; sel_h = 0;
                has_area = false;
                break;
            }
            return true;
        }

        private bool on_motion (Gdk.EventMotion event) {
            if (mode == Mode.COLOR) {
                pointer_x = (int) event.x;
                pointer_y = (int) event.y;
                canvas.queue_draw ();
                return true;
            }
            if (mode == Mode.WINDOW) {
                return true;   /* D3: vurgu yok, liste var */
            }
            if (!selecting) {
                return false;
            }
            if (mode == Mode.FREEFORM) {
                path_x += event.x;
                path_y += event.y;
                update_path_bounds ();
            } else {
                sel_x = int.min (start_x, (int) event.x);
                sel_y = int.min (start_y, (int) event.y);
                sel_w = (start_x - (int) event.x).abs ();
                sel_h = (start_y - (int) event.y).abs ();
            }
            has_area = true;
            canvas.queue_draw ();
            return true;
        }

        private bool on_release (Gdk.EventButton event) {
            if (!selecting || event.button != 1) {
                return false;
            }
            selecting = false;
            if (has_area && sel_w > 4 && sel_h > 4) {
                finish_selection ();
            } else {
                has_area = false;
                canvas.queue_draw ();
            }
            return true;
        }

        private void update_path_bounds () {
            double min_x = path_x[0], max_x = path_x[0];
            double min_y = path_y[0], max_y = path_y[0];
            for (int i = 1; i < path_x.length; i++) {
                min_x = double.min (min_x, path_x[i]);
                max_x = double.max (max_x, path_x[i]);
                min_y = double.min (min_y, path_y[i]);
                max_y = double.max (max_y, path_y[i]);
            }
            sel_x = (int) min_x;
            sel_y = (int) min_y;
            sel_w = (int) (max_x - min_x);
            sel_h = (int) (max_y - min_y);
        }

        /* --- renk seçici (5c) ----------------------------------------- */

        private void pixel_at (int x, int y, out uchar r, out uchar g,
                               out uchar b) {
            x = x.clamp (0, frozen.get_width () - 1);
            y = y.clamp (0, frozen.get_height () - 1);
            unowned uint8[] pixels = frozen.get_pixels ();
            int offset = y * frozen.get_rowstride ()
                + x * frozen.get_n_channels ();
            r = pixels[offset];
            g = pixels[offset + 1];
            b = pixels[offset + 2];
        }

        /* 9×9 piksel büyüteç + altında renk kutusu ve hex. Dondurulmuş
         * kareden okur — hareketli içerik sorun değil. */
        private void draw_magnifier (Cairo.Context cr) {
            const int CELL = 11;
            const int HALF = 4;
            int size = CELL * (2 * HALF + 1);
            int ax = pointer_x + 20;
            int ay = pointer_y + 20;
            if (ax + size + 8 > frozen.get_width ()) {
                ax = pointer_x - size - 20;
            }
            if (ay + size + 44 > frozen.get_height ()) {
                ay = pointer_y - size - 64;
            }

            for (int dy = -HALF; dy <= HALF; dy++) {
                for (int dx = -HALF; dx <= HALF; dx++) {
                    uchar r, g, b;
                    pixel_at (pointer_x + dx, pointer_y + dy,
                              out r, out g, out b);
                    cr.set_source_rgb (r / 255.0, g / 255.0, b / 255.0);
                    cr.rectangle (ax + (dx + HALF) * CELL,
                                  ay + (dy + HALF) * CELL, CELL, CELL);
                    cr.fill ();
                }
            }
            /* Çerçeve + ortadaki hücre. */
            cr.set_source_rgb (0.09, 0.13, 0.17);
            cr.set_line_width (2);
            cr.rectangle (ax, ay, size, size);
            cr.stroke ();
            cr.set_source_rgb (0.176, 0.831, 0.749);
            cr.rectangle (ax + HALF * CELL, ay + HALF * CELL, CELL, CELL);
            cr.stroke ();

            /* Renk kutusu + hex. */
            uchar cr_, cg, cb;
            pixel_at (pointer_x, pointer_y, out cr_, out cg, out cb);
            string hex = "#%02X%02X%02X".printf (cr_, cg, cb);
            cr.set_source_rgba (0.09, 0.13, 0.17, 0.92);
            cr.rectangle (ax, ay + size + 6, size, 30);
            cr.fill ();
            cr.set_source_rgb (cr_ / 255.0, cg / 255.0, cb / 255.0);
            cr.rectangle (ax + 6, ay + size + 12, 18, 18);
            cr.fill ();
            cr.select_font_face ("monospace", Cairo.FontSlant.NORMAL,
                                 Cairo.FontWeight.BOLD);
            cr.set_font_size (13);
            cr.set_source_rgb (0.902, 0.929, 0.953);
            cr.move_to (ax + 32, ay + size + 26);
            cr.show_text (hex);
        }

        /* h 0-360, s/l 0-100. */
        private static void rgb_to_hsl (uchar r8, uchar g8, uchar b8,
                                        out int h, out int s, out int l) {
            double r = r8 / 255.0, g = g8 / 255.0, b = b8 / 255.0;
            double max = double.max (r, double.max (g, b));
            double min = double.min (r, double.min (g, b));
            double lum = (max + min) / 2;
            double hue = 0, sat = 0;
            if (max != min) {
                double d = max - min;
                sat = (lum > 0.5) ? d / (2 - max - min) : d / (max + min);
                if (max == r) {
                    hue = (g - b) / d + ((g < b) ? 6 : 0);
                } else if (max == g) {
                    hue = (b - r) / d + 2;
                } else {
                    hue = (r - g) / d + 4;
                }
                hue /= 6;
            }
            h = (int) Math.round (hue * 360);
            s = (int) Math.round (sat * 100);
            l = (int) Math.round (lum * 100);
        }

        private void pick_color (int x, int y) {
            uchar r, g, b;
            pixel_at (x, y, out r, out g, out b);
            string hex = "#%02X%02X%02X".printf (r, g, b);
            rgb_text = "rgb(%d, %d, %d)".printf (r, g, b);
            int hh, ss, ll;
            rgb_to_hsl (r, g, b, out hh, out ss, out ll);
            hsl_text = "hsl(%d, %d%%, %d%%)".printf (hh, ss, ll);

            Gdk.Display.get_default ().get_default_seat ().ungrab ();
            hide ();

            var clipboard = Gtk.Clipboard.get_default (
                Gdk.Display.get_default ());
            clipboard.set_text (hex, -1);

            /* Renk kutusu görseli (bildirim önizlemesi). */
            string swatch = Path.build_filename (
                Environment.get_user_cache_dir (), "kavis",
                "renk-kutusu.png");
            DirUtils.create_with_parents (
                Path.get_dirname (swatch), 0700);
            var pixel = new Gdk.Pixbuf (Gdk.Colorspace.RGB, false, 8,
                                        48, 48);
            pixel.fill (((uint32) r << 24) | ((uint32) g << 16)
                        | ((uint32) b << 8) | 0xFF);
            try {
                pixel.save (swatch, "png");
            } catch (Error e) {
                swatch = "";
            }

            /* Eylem düğmeli bildirim: rgb/hsl kopyala. Düğme tıkları
             * ActionInvoked ile bu sürece döner (60 sn yaşıyoruz —
             * pano zaten bunu istiyor). */
            send_color_notification (hex, swatch);
            Capture.hold_clipboard_then_quit ();
        }

        private void send_color_notification (string hex, string swatch) {
            try {
                bus = Bus.get_sync (BusType.SESSION);
                var hints = new VariantBuilder (
                    new VariantType ("a{sv}"));
                if (swatch != "") {
                    hints.add ("{sv}", "image-path",
                               new Variant.string (swatch));
                }
                var actions = new VariantBuilder (
                    new VariantType ("as"));
                actions.add ("s", "copy-rgb");
                actions.add ("s", _("Copy RGB"));
                actions.add ("s", "copy-hsl");
                actions.add ("s", _("Copy HSL"));
                var reply = bus.call_sync (
                    "org.freedesktop.Notifications",
                    "/org/freedesktop/Notifications",
                    "org.freedesktop.Notifications", "Notify",
                    new Variant ("(susssasa{sv}i)", "Kavis",
                                 (uint32) 0, "color-select-symbolic",
                                 hex,
                                 "%s · %s".printf (rgb_text, hsl_text),
                                 actions, hints, 8000),
                    new VariantType ("(u)"),
                    DBusCallFlags.NONE, -1, null);
                reply.get ("(u)", out color_notif_id);

                bus.signal_subscribe (null,
                    "org.freedesktop.Notifications", "ActionInvoked",
                    "/org/freedesktop/Notifications", null,
                    DBusSignalFlags.NONE,
                    (connection, sender, path, iface, name, args) => {
                        uint32 id;
                        string key;
                        args.get ("(us)", out id, out key);
                        if (id != color_notif_id) {
                            return;
                        }
                        var clip = Gtk.Clipboard.get_default (
                            Gdk.Display.get_default ());
                        if (key == "copy-rgb") {
                            clip.set_text (rgb_text, -1);
                        } else if (key == "copy-hsl") {
                            clip.set_text (hsl_text, -1);
                        }
                    });
            } catch (Error e) {
                warning ("kavis-tools: renk bildirimi verilemedi: %s",
                         e.message);
            }
        }

        /* --- sonuç ---------------------------------------------------- */

        private void finish_selection () {
            sel_x = int.max (0, sel_x);
            sel_y = int.max (0, sel_y);
            sel_w = int.min (sel_w, frozen.get_width () - sel_x);
            sel_h = int.min (sel_h, frozen.get_height () - sel_y);
            if (sel_w <= 0 || sel_h <= 0) {
                return;
            }
            Gdk.Display.get_default ().get_default_seat ().ungrab ();
            if (video_mode) {
                start_recording ();
            } else {
                save_image ();
            }
        }

        private void save_image () {
            Gdk.Pixbuf result;
            if (mode == Mode.ELLIPSE
                || (mode == Mode.FREEFORM && path_x.length > 2)) {
                /* Yol dışı şeffaf: kırpılmış yüzeye yola kıstırılmış
                 * çizim (W11 serbest kesim davranışı). */
                var surface = new Cairo.ImageSurface (
                    Cairo.Format.ARGB32, sel_w, sel_h);
                var cr = new Cairo.Context (surface);
                cr.translate (-sel_x, -sel_y);
                selection_path (cr);
                cr.clip ();
                Gdk.cairo_set_source_pixbuf (cr, frozen, 0, 0);
                cr.paint ();
                result = Gdk.pixbuf_get_from_surface (
                    surface, 0, 0, sel_w, sel_h);
            } else {
                result = new Gdk.Pixbuf.subpixbuf (
                    frozen, sel_x, sel_y, sel_w, sel_h).copy ();
            }

            string path = Capture.timestamp_path ("image", ".png");
            try {
                result.save (path, "png");
            } catch (Error e) {
                warning ("kavis-tools: kaydedilemedi: %s", e.message);
                cancel ();
                return;
            }
            Gtk.Clipboard.get_default (
                Gdk.Display.get_default ()).set_image (result);
            Capture.notify_file (_("Screenshot saved"), path,
                                 "camera-photo-symbolic");
            hide ();
            Capture.hold_clipboard_then_quit ();
        }

        private void start_recording () {
            int x = sel_x, y = sel_y;
            int w = sel_w / 2 * 2;   /* x11grab çift boyut ister */
            int h = sel_h / 2 * 2;
            bool with_audio = audio_check.get_active ();
            bool with_mic = mic_check.get_active ();
            destroy ();

            /* Overlay yok olsun, gerçek ekran görünsün. */
            Timeout.add (250, () => {
                launch_ffmpeg (x, y, w, h, with_audio, with_mic);
                return Source.REMOVE;
            });
        }

        private static void launch_ffmpeg (int x, int y, int w, int h,
                                           bool with_audio,
                                           bool with_mic) {
            string path = Capture.timestamp_path ("video", ".mp4");
            string[] argv = {
                "ffmpeg", "-loglevel", "quiet",
                "-f", "x11grab", "-framerate",
                Capture.config_value ("framerate", "30"),
                "-video_size", "%dx%d".printf (w, h),
                "-i", "%s+%d,%d".printf (
                    Environment.get_variable ("DISPLAY") ?? ":0", x, y)
            };

            /* Sistem sesi = varsayılan çıkışın monitörü; mikrofon =
             * varsayılan kaynak. İkisi birden seçilirse amix. */
            int audio_inputs = 0;
            if (with_audio) {
                string sink = "";
                try {
                    string output;
                    Process.spawn_sync (null,
                        { "pactl", "get-default-sink" }, null,
                        SpawnFlags.SEARCH_PATH
                        | SpawnFlags.STDERR_TO_DEV_NULL,
                        null, out output, null, null);
                    sink = output.strip ();
                } catch (Error e) { }
                if (sink != "") {
                    argv += "-f"; argv += "pulse";
                    argv += "-i"; argv += sink + ".monitor";
                    audio_inputs++;
                }
            }
            if (with_mic) {
                argv += "-f"; argv += "pulse";
                argv += "-i"; argv += "default";
                audio_inputs++;
            }
            if (audio_inputs == 2) {
                argv += "-filter_complex";
                argv += "[1:a][2:a]amix=inputs=2[a]";
                argv += "-map"; argv += "0:v";
                argv += "-map"; argv += "[a]";
            }

            argv += "-c:v"; argv += "libx264";
            argv += "-preset"; argv += "ultrafast";
            argv += "-pix_fmt"; argv += "yuv420p";
            argv += path;

            Pid ffmpeg_pid;
            try {
                Process.spawn_async (null, argv, null,
                    SpawnFlags.SEARCH_PATH
                    | SpawnFlags.DO_NOT_REAP_CHILD, null, out ffmpeg_pid);
            } catch (Error e) {
                warning ("kavis-tools: ffmpeg baslatilamadi: %s", e.message);
                Gtk.main_quit ();
                return;
            }
            var recorder = new RecorderBar (ffmpeg_pid, path);
            recorder.show_all ();
        }
    }

    /* Küçük, hep üstte kayıt çubuğu: kırmızı nokta + sayaç + durdur.
     * PrtScr da durdurur: pid dosyası + SIGUSR1 (Capture.snip). */
    private class RecorderBar : Gtk.Window {

        private Pid ffmpeg_pid;
        private new string path;
        private Gtk.Label counter;
        private int seconds = 0;
        private uint tick = 0;
        private string pid_file;

        public RecorderBar (Pid ffmpeg_pid, string path) {
            Object (type: Gtk.WindowType.TOPLEVEL);
            this.ffmpeg_pid = ffmpeg_pid;
            this.path = path;
            set_title (_("Recording"));
            set_resizable (false);
            set_keep_above (true);
            stick ();
            set_tooltip_text (_("You can also press PrtSc to stop"));

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            row.set_border_width (10);
            add (row);
            counter = new Gtk.Label (null);
            set_counter_text ();
            row.pack_start (counter, false, false, 0);
            var stop = new Gtk.Button.with_label (
                _("Stop"));
            stop.clicked.connect (finish);
            row.pack_start (stop, false, false, 0);

            /* Sağ üst köşe: kayıt alanının dışında kalmak kullanıcıya
             * kalıyor; W11 de böyle. */
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor ();
            if (monitor != null) {
                Gdk.Rectangle area = monitor.get_workarea ();
                move (area.x + area.width - 220, area.y + 16);
            }

            pid_file = Path.build_filename (
                Environment.get_user_runtime_dir (), "kavis-capture.pid");
            try {
                FileUtils.set_contents (pid_file,
                    "%d\n".printf ((int) Posix.getpid ()));
            } catch (Error e) { }
            Unix.signal_add (Posix.Signal.USR1, () => {
                finish ();
                return Source.REMOVE;
            });

            tick = Timeout.add_seconds (1, () => {
                seconds++;
                set_counter_text ();
                return Source.CONTINUE;
            });

            ChildWatch.add (ffmpeg_pid, (pid, wait_status) => {
                Process.close_pid (pid);
                FileUtils.unlink (pid_file);
                /* D4: bildirimdeki "Show in folder" düğmesi bu süreçte
                 * işleniyor — hemen ölme, kısa bir pay bırak. */
                Capture.hold_clipboard_then_quit ();
            });
        }

        private void set_counter_text () {
            counter.set_markup (
                "<span foreground='#EF4444'>●</span> %d:%02d".printf (
                    seconds / 60, seconds % 60));
        }

        private void finish () {
            if (tick != 0) {
                Source.remove (tick);
                tick = 0;
            }
            /* SIGINT: ffmpeg dosyayı düzgün kapatır (moov atomu). */
            Posix.kill ((Posix.pid_t) ffmpeg_pid, Posix.Signal.INT);
            hide ();
            Capture.notify_file (_("Screen recording saved"),
                                 path, "camera-video-symbolic");
            /* ChildWatch ffmpeg bitince kısa bekleyişe geçirir. */
        }
    }
}
