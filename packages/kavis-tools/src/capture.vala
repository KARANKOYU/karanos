/* Screen capture (madde 29) — `kavis-tools capture [--quick]`.
 *
 * --quick (Ctrl+PrtScr): captures WITHOUT asking. What gets captured
 * comes from ~/.config/kavis/capture.conf ([capture] mode=window|
 * monitor|all — the Settings app edits it, Grup F). The grab itself is
 * native Gdk (root window pixbuf): no external tool, no flash, works
 * the instant the key is hit. Saved to the configured folder
 * (default: pictures/screenshots under $HOME) with a timestamp name,
 * copied to the clipboard (the process lingers briefly — X clipboards
 * die with their owner), announced via the notification service.
 *
 * Without --quick (PrtScr): a small two-tab chooser.
 *   [Görsel] → flameshot gui — the freeze/darken/select/edit flow is
 *   exactly flameshot's core competence (madde 29F: flameshot temel).
 *   [Video]  → region via slop, recording via ffmpeg x11grab; a tiny
 *   always-on-top pill shows a counter and a stop button. Pause is
 *   deliberately v1-dışı (SIGSTOP freezes ffmpeg but corrupts
 *   timestamps); the strings exist for when it lands properly.
 */

namespace Kavis.Tools {

    namespace Capture {

        private string config_value (string key, string fallback) {
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

        private string save_dir (string kind) {
            string configured = config_value ("save_dir", "");
            if (configured != "") {
                return configured;
            }
            /* Varsayılan: resimler/screenshots — madde 29C. */
            unowned string home = Environment.get_home_dir ();
            string pictures = Path.build_filename (home, "pictures");
            if (kind == "video") {
                string videos = Path.build_filename (home, "videos");
                if (FileUtils.test (videos, FileTest.IS_DIR)) {
                    return videos;
                }
                return home;
            }
            if (FileUtils.test (pictures, FileTest.IS_DIR)) {
                return Path.build_filename (pictures, "screenshots");
            }
            return home;
        }

        private string timestamp_path (string kind, string extension) {
            string dir = save_dir (kind);
            DirUtils.create_with_parents (dir, 0755);
            var now = new DateTime.now_local ();
            return Path.build_filename (dir,
                now.format ("%Y-%m-%d_%H-%M-%S") + extension);
        }

        private void notify_user (string summary, string body,
                                  string icon) {
            /* gdbus zaten ISO'da (madde 55 köprüsü); libnotify
             * bağımlılığına gerek yok. */
            try {
                Process.spawn_async (null, {
                    "gdbus", "call", "--session",
                    "--dest", "org.freedesktop.Notifications",
                    "--object-path", "/org/freedesktop/Notifications",
                    "--method", "org.freedesktop.Notifications.Notify",
                    "Kavis", "0", icon, summary, body, "[]", "{}", "6000"
                }, null, SpawnFlags.SEARCH_PATH
                   | SpawnFlags.STDOUT_TO_DEV_NULL, null, null);
            } catch (Error e) {
                warning ("kavis-tools: bildirim verilemedi: %s", e.message);
            }
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

            var clipboard = Gtk.Clipboard.get_default (display);
            clipboard.set_image (pixbuf);
            notify_user (Strings.get ("screenshot.saved"), path,
                         "camera-photo-symbolic");

            /* X panosu sahibiyle ölür: görüntü yapıştırılabilir kalsın
             * diye süreç kısa süre yaşar, sonra sessizce çıkar. */
            Timeout.add_seconds (60, () => {
                Gtk.main_quit ();
                return Source.REMOVE;
            });
            Gtk.main ();
            return 0;
        }

        /* --- araç menüsü (PrtScr) -------------------------------------- */

        public Gtk.Window chooser () {
            var window = new CaptureChooser ();
            return window;
        }
    }

    public class CaptureChooser : Gtk.Window {

        public CaptureChooser () {
            Object (type: Gtk.WindowType.TOPLEVEL);
            set_title ("Kavis");
            set_resizable (false);
            set_keep_above (true);
            set_position (Gtk.WindowPosition.CENTER);

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            row.set_border_width (14);
            add (row);

            var image_button = new Gtk.Button.with_label (
                "📷 " + Strings.get ("capture.image"));
            image_button.clicked.connect (() => {
                hide ();
                /* flameshot kendi donmuş/karartılmış seçicisini ve
                 * düzenleyicisini açar (madde 29B görüntü akışı). */
                try {
                    Process.spawn_async (null,
                        { "flameshot", "gui",
                          "--path", Capture.save_dir ("image") },
                        null, SpawnFlags.SEARCH_PATH, null, null);
                } catch (Error e) {
                    warning ("kavis-tools: flameshot baslatilamadi: %s",
                             e.message);
                }
                Timeout.add (300, () => {
                    destroy ();
                    return Source.REMOVE;
                });
            });
            row.pack_start (image_button, true, true, 0);

            var video_button = new Gtk.Button.with_label (
                "🔴 " + Strings.get ("capture.video"));
            video_button.clicked.connect (() => {
                hide ();
                Timeout.add (250, () => {
                    start_recording ();
                    return Source.REMOVE;
                });
            });
            row.pack_start (video_button, true, true, 0);

            key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    destroy ();
                    return true;
                }
                return false;
            });
        }

        private void start_recording () {
            /* slop: sürükleyerek bölge seç (tam ekran için tıkla). */
            string region_output;
            int status;
            try {
                Process.spawn_sync (null,
                    { "slop", "-f", "%w %h %x %y", "-b", "2",
                      "-c", "0.18,0.83,0.75,0.8" },
                    null, SpawnFlags.SEARCH_PATH, null,
                    out region_output, null, out status);
            } catch (Error e) {
                warning ("kavis-tools: slop calistirilamadi: %s", e.message);
                destroy ();
                return;
            }
            if (status != 0) {
                destroy ();   /* seçim iptal */
                return;
            }
            string[] parts = region_output.strip ().split (" ");
            if (parts.length != 4) {
                destroy ();
                return;
            }
            /* x11grab çift boyut ister. */
            int w = int.parse (parts[0]) / 2 * 2;
            int h = int.parse (parts[1]) / 2 * 2;
            string path = Capture.timestamp_path ("video", ".mp4");

            Pid ffmpeg_pid;
            try {
                Process.spawn_async (null, {
                    "ffmpeg", "-loglevel", "quiet",
                    "-f", "x11grab", "-framerate",
                    Capture.config_value ("framerate", "30"),
                    "-video_size", "%dx%d".printf (w, h),
                    "-i", "%s+%s,%s".printf (
                        Environment.get_variable ("DISPLAY") ?? ":0",
                        parts[2], parts[3]),
                    "-c:v", "libx264", "-preset", "ultrafast",
                    "-pix_fmt", "yuv420p", path
                }, null, SpawnFlags.SEARCH_PATH
                   | SpawnFlags.DO_NOT_REAP_CHILD, null, out ffmpeg_pid);
            } catch (Error e) {
                warning ("kavis-tools: ffmpeg baslatilamadi: %s", e.message);
                destroy ();
                return;
            }

            var recorder = new RecorderBar (ffmpeg_pid, path);
            recorder.show_all ();
            destroy ();
        }
    }

    /* Küçük, hep üstte kayıt çubuğu: sayaç + durdur. */
    private class RecorderBar : Gtk.Window {

        private Pid ffmpeg_pid;
        private string path;
        private Gtk.Label counter;
        private int seconds = 0;
        private uint tick = 0;

        public RecorderBar (Pid ffmpeg_pid, string path) {
            Object (type: Gtk.WindowType.TOPLEVEL);
            this.ffmpeg_pid = ffmpeg_pid;
            this.path = path;
            set_title (Strings.get ("capture.recording"));
            set_resizable (false);
            set_keep_above (true);
            stick ();

            var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            row.set_border_width (10);
            add (row);
            counter = new Gtk.Label ("● 0:00");
            row.pack_start (counter, false, false, 0);
            var stop = new Gtk.Button.with_label (
                Strings.get ("capture.stop"));
            stop.clicked.connect (finish);
            row.pack_start (stop, false, false, 0);

            /* Sağ üst köşe: kayda girmesin diye kayıt alanının dışında
             * olmak kullanıcıya kalıyor; W11 de böyle. */
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor ();
            if (monitor != null) {
                Gdk.Rectangle area = monitor.get_workarea ();
                move (area.x + area.width - 220, area.y + 16);
            }

            tick = Timeout.add_seconds (1, () => {
                seconds++;
                counter.set_text ("● %d:%02d".printf (
                    seconds / 60, seconds % 60));
                return Source.CONTINUE;
            });

            ChildWatch.add (ffmpeg_pid, (pid, wait_status) => {
                Process.close_pid (pid);
                Gtk.main_quit ();
            });
        }

        private void finish () {
            if (tick != 0) {
                Source.remove (tick);
                tick = 0;
            }
            /* SIGINT: ffmpeg dosyayı düzgün kapatır (moov atomu). */
            Posix.kill ((Posix.pid_t) ffmpeg_pid, Posix.Signal.INT);
            hide ();
            Capture.notify_user (Strings.get ("capture.saved_video"),
                                 path, "camera-video-symbolic");
            /* ChildWatch ffmpeg bitince ana döngüyü kapatır. */
        }
    }
}
