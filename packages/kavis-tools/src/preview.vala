/* Quick preview (madde 36) — the org.nemo.Preview D-Bus service.
 *
 * Nemo's Space key calls ShowFile(uri, xid, close_if_already_visible)
 * on org.nemo.Preview (src/nemo-previewer.c upstream); the reference
 * implementation (nemo-preview) is not in trixie and drags in clutter.
 * Owning the bus name here means Nemo needs no patch: a D-Bus service
 * file autostarts `kavis-tools preview` on the first Space press.
 *
 * Supported: images (incl. animated gif), video/audio (GStreamer
 * playbin + gtksink), PDF (poppler's pdftoppm, page by page), text
 * and code, archive listings (7z/unrar/tar). Anything else gets an
 * info card. The daemon exits ~30 s after the last window closes so
 * it costs no RAM while idle.
 */

namespace Kavis.Tools {

    [DBus (name = "org.nemo.Preview")]
    public class PreviewService : Object {

        private unowned PreviewApp app;

        internal PreviewService (PreviewApp app) {
            this.app = app;
        }

        public void show_file (string uri, int xid,
                               bool close_if_already_visible)
                               throws Error {
            app.show_uri (uri, close_if_already_visible);
        }

        public void close () throws Error {
            app.close_window ();
        }
    }

    public class PreviewApp : Object {

        private PreviewWindow? window = null;
        private uint quit_timer = 0;

        public void show_uri (string uri, bool close_if_already_visible) {
            if (window != null && close_if_already_visible
                && window.uri == uri) {
                window.destroy ();
                return;
            }
            if (quit_timer != 0) {
                Source.remove (quit_timer);
                quit_timer = 0;
            }
            if (window != null) {
                window.destroy ();
            }
            window = new PreviewWindow (uri);
            window.destroy.connect (() => {
                window = null;
                schedule_quit ();
            });
            window.show_all ();
            window.present ();
        }

        public void close_window () {
            if (window != null) {
                window.destroy ();
            }
        }

        /* Keep the process warm briefly (Space-Space-Space browsing),
         * then exit — D-Bus activation restarts it in well under a
         * second and idle RAM stays zero. */
        private void schedule_quit () {
            if (quit_timer != 0) {
                Source.remove (quit_timer);
            }
            quit_timer = Timeout.add_seconds (30, () => {
                quit_timer = 0;
                if (window == null) {
                    Gtk.main_quit ();
                }
                return false;
            });
        }
    }

    public class PreviewWindow : Gtk.Window {

        public string uri { get; private set; }

        private Gst.Element? playbin = null;
        private uint tick_timer = 0;
        private bool seeking = false;

        /* PDF state */
        private string? pdf_path = null;
        private int pdf_page = 1;
        private int pdf_pages = 1;
        private Gtk.Image? pdf_image = null;
        private Gtk.Label? pdf_label = null;

        public PreviewWindow (string uri) {
            this.uri = uri;
            var file = File.new_for_uri (uri);
            string name = file.get_basename () ?? uri;
            title = name;
            window_position = Gtk.WindowPosition.CENTER;
            set_default_size (700, 500);

            string ctype = "application/octet-stream";
            try {
                var info = file.query_info (
                    FileAttribute.STANDARD_CONTENT_TYPE, 0);
                ctype = info.get_content_type ();
            } catch (Error e) { }

            Gtk.Widget content;
            string? path = file.get_path ();
            if (path == null) {
                /* Remote (smb/sftp) file without a local path: gvfs-fuse
                 * usually provides one; if not, show the info card. */
                content = build_fallback (file, ctype);
            } else if (ctype.has_prefix ("image/")) {
                content = build_image (path, ctype);
            } else if (ctype.has_prefix ("video/")
                       || ctype.has_prefix ("audio/")) {
                content = build_media (ctype.has_prefix ("audio/"));
            } else if (ctype == "application/pdf") {
                content = build_pdf (path);
            } else if (is_text_type (ctype)) {
                content = build_text (path);
            } else if (archive_command (path, ctype) != null) {
                content = build_archive (path, ctype);
            } else {
                content = build_fallback (file, ctype);
            }
            add (content);

            key_press_event.connect ((ev) => {
                switch (ev.keyval) {
                case Gdk.Key.Escape:
                case Gdk.Key.space:
                    destroy ();
                    return true;
                case Gdk.Key.Left:
                case Gdk.Key.Page_Up:
                    return pdf_flip (-1);
                case Gdk.Key.Right:
                case Gdk.Key.Page_Down:
                    return pdf_flip (1);
                }
                return false;
            });
            destroy.connect (() => {
                if (tick_timer != 0) {
                    Source.remove (tick_timer);
                    tick_timer = 0;
                }
                if (playbin != null) {
                    playbin.set_state (Gst.State.NULL);
                    playbin = null;
                }
            });
        }

        /* ---- images ---------------------------------------------- */

        private Gtk.Widget build_image (string path, string ctype) {
            /* Gdk.Screen.get_width/height is deprecated since 3.22; use
             * the primary monitor's geometry (correct on multi-monitor too). */
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor () ?? display.get_monitor (0);
            var geo = monitor.get_geometry ();
            var screen_h = geo.height;
            var screen_w = geo.width;
            int max_w = (int) (screen_w * 0.8);
            int max_h = (int) (screen_h * 0.8);
            try {
                if (ctype == "image/gif") {
                    var anim = new Gdk.PixbufAnimation.from_file (path);
                    var img = new Gtk.Image.from_animation (anim);
                    set_default_size (
                        int.min (anim.get_width (), max_w),
                        int.min (anim.get_height (), max_h));
                    return wrap_scrolled (img);
                }
                var pix = new Gdk.Pixbuf.from_file_at_scale (
                    path, max_w, max_h, true);
                set_default_size (pix.get_width (), pix.get_height ());
                return new Gtk.Image.from_pixbuf (pix);
            } catch (Error e) {
                return error_label ();
            }
        }

        /* ---- video / audio --------------------------------------- */

        private static bool gst_ready = false;

        private Gtk.Widget build_media (bool audio_only) {
            if (!gst_ready) {
                unowned string[]? no_args = null;
                Gst.init (ref no_args);
                gst_ready = true;
            }
            playbin = Gst.ElementFactory.make ("playbin", "playbin");
            var sink = Gst.ElementFactory.make ("gtksink", "sink");
            if (playbin == null || (sink == null && !audio_only)) {
                playbin = null;
                return error_label ();
            }

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box.margin = 8;
            if (!audio_only) {
                Gtk.Widget video_widget;
                sink.get ("widget", out video_widget);
                playbin.set ("video-sink", sink);
                video_widget.expand = true;
                box.pack_start (video_widget, true, true, 0);
            } else {
                var icon = new Gtk.Image.from_icon_name (
                    "audio-x-generic", Gtk.IconSize.DIALOG);
                icon.pixel_size = 128;
                icon.expand = true;
                box.pack_start (icon, true, true, 0);
                set_default_size (420, 240);
            }

            var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            var play = new Gtk.Button.from_icon_name (
                "media-playback-pause-symbolic", Gtk.IconSize.BUTTON);
            var scale = new Gtk.Scale.with_range (
                Gtk.Orientation.HORIZONTAL, 0, 1, 0.001);
            scale.draw_value = false;
            scale.hexpand = true;
            var time_label = new Gtk.Label ("");
            controls.pack_start (play, false, false, 0);
            controls.pack_start (scale, true, true, 0);
            controls.pack_start (time_label, false, false, 0);
            box.pack_start (controls, false, false, 0);

            playbin.set ("uri", uri);
            playbin.set_state (Gst.State.PLAYING);

            play.clicked.connect (() => {
                Gst.State state;
                Gst.State pending;
                playbin.get_state (out state, out pending, 0);
                bool playing = (state == Gst.State.PLAYING);
                playbin.set_state (playing
                    ? Gst.State.PAUSED : Gst.State.PLAYING);
                ((Gtk.Image) play.image).icon_name = playing
                    ? "media-playback-start-symbolic"
                    : "media-playback-pause-symbolic";
            });
            scale.button_press_event.connect (() => {
                seeking = true;
                return false;
            });
            scale.button_release_event.connect (() => {
                int64 duration = 0;
                if (playbin.query_duration (Gst.Format.TIME,
                                            out duration)) {
                    playbin.seek_simple (Gst.Format.TIME,
                        Gst.SeekFlags.FLUSH | Gst.SeekFlags.KEY_UNIT,
                        (int64) (scale.get_value () * duration));
                }
                seeking = false;
                return false;
            });
            tick_timer = Timeout.add (500, () => {
                if (playbin == null) {
                    return false;
                }
                int64 pos = 0;
                int64 duration = 0;
                if (!seeking
                    && playbin.query_position (Gst.Format.TIME, out pos)
                    && playbin.query_duration (Gst.Format.TIME,
                                               out duration)
                    && duration > 0) {
                    scale.set_value ((double) pos / duration);
                    time_label.label = "%s / %s".printf (
                        format_time (pos), format_time (duration));
                }
                return true;
            });
            return box;
        }

        private static string format_time (int64 nanos) {
            int64 total = nanos / Gst.SECOND;
            if (total >= 3600) {
                return "%d:%02d:%02d".printf ((int) (total / 3600),
                    (int) (total % 3600 / 60), (int) (total % 60));
            }
            return "%d:%02d".printf ((int) (total / 60),
                                     (int) (total % 60));
        }

        /* ---- PDF -------------------------------------------------- */

        private Gtk.Widget build_pdf (string path) {
            pdf_path = path;
            pdf_pages = pdf_page_count (path);
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            pdf_image = new Gtk.Image ();
            box.pack_start (wrap_scrolled (pdf_image), true, true, 0);
            var bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            bar.halign = Gtk.Align.CENTER;
            bar.margin = 6;
            var prev = new Gtk.Button.from_icon_name (
                "go-previous-symbolic", Gtk.IconSize.BUTTON);
            var next = new Gtk.Button.from_icon_name (
                "go-next-symbolic", Gtk.IconSize.BUTTON);
            pdf_label = new Gtk.Label ("");
            bar.pack_start (prev, false, false, 0);
            bar.pack_start (pdf_label, false, false, 0);
            bar.pack_start (next, false, false, 0);
            box.pack_start (bar, false, false, 0);
            prev.clicked.connect (() => pdf_flip (-1));
            next.clicked.connect (() => pdf_flip (1));
            set_default_size (640, 780);
            render_pdf_page ();
            return box;
        }

        private static int pdf_page_count (string path) {
            try {
                string output;
                Process.spawn_sync (null,
                    { "pdfinfo", path }, null,
                    SpawnFlags.SEARCH_PATH, null, out output);
                foreach (unowned string line in output.split ("\n")) {
                    if (line.has_prefix ("Pages:")) {
                        return int.max (1,
                            int.parse (line.substring (6).strip ()));
                    }
                }
            } catch (Error e) { }
            return 1;
        }

        private bool pdf_flip (int direction) {
            if (pdf_path == null) {
                return false;
            }
            int target = pdf_page + direction;
            if (target < 1 || target > pdf_pages) {
                return true;
            }
            pdf_page = target;
            render_pdf_page ();
            return true;
        }

        private void render_pdf_page () {
            pdf_label.label = "%d / %d".printf (pdf_page, pdf_pages);
            try {
                string dir = DirUtils.make_tmp ("kavis-preview-XXXXXX");
                string prefix = Path.build_filename (dir, "page");
                Process.spawn_sync (null, {
                    "pdftoppm", "-png", "-r", "110", "-singlefile",
                    "-f", pdf_page.to_string (),
                    "-l", pdf_page.to_string (),
                    pdf_path, prefix
                }, null, SpawnFlags.SEARCH_PATH, null);
                string png = prefix + ".png";
                pdf_image.set_from_file (png);
                FileUtils.remove (png);
                DirUtils.remove (dir);
            } catch (Error e) {
                pdf_image.set_from_icon_name (
                    "application-pdf", Gtk.IconSize.DIALOG);
            }
        }

        /* ---- text / code ----------------------------------------- */

        private static bool is_text_type (string ctype) {
            if (ContentType.is_a (ctype, "text/plain")) {
                return true;
            }
            switch (ctype) {
            case "application/json":
            case "application/xml":
            case "application/x-shellscript":
            case "application/javascript":
            case "application/x-yaml":
            case "application/x-desktop":
                return true;
            }
            return false;
        }

        private Gtk.Widget build_text (string path) {
            bool truncated;
            string text = read_head (path, 262144, out truncated);
            return build_text_view (text, truncated);
        }

        private static string read_head (string path, size_t limit,
                                         out bool truncated) {
            truncated = false;
            var stream = FileStream.open (path, "r");
            if (stream == null) {
                return "";
            }
            var buffer = new uint8[limit + 1];
            size_t got = stream.read (buffer[0 : limit]);
            truncated = (stream.read (buffer[limit : limit + 1]) > 0);
            buffer[got] = 0;
            string raw = (string) buffer;
            if (!raw.validate ((ssize_t) got)) {
                /* Not UTF-8 (latin-1 logs and friends): show what
                 * converts, replacing the rest. */
                try {
                    raw = GLib.convert_with_fallback (
                        raw, (ssize_t) got, "UTF-8", "ISO-8859-1", "?");
                } catch (ConvertError e) {
                    raw = "";
                }
            }
            return raw;
        }

        private Gtk.Widget build_text_view (string text, bool truncated) {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            var view = new Gtk.TextView ();
            view.editable = false;
            view.cursor_visible = false;
            view.monospace = true;
            view.left_margin = 8;
            view.right_margin = 8;
            view.top_margin = 8;
            view.buffer.text = text;
            box.pack_start (wrap_scrolled (view), true, true, 0);
            if (truncated) {
                var note = new Gtk.Label (
                    _("Showing the first part of a large file"));
                note.get_style_context ().add_class ("dim-label");
                note.margin = 4;
                box.pack_start (note, false, false, 0);
            }
            return box;
        }

        /* ---- archives -------------------------------------------- */

        private static string[]? archive_command (string path,
                                                  string ctype) {
            /* tar variants go to tar itself (compressors are ISO
             * packages: gzip/xz/bzip2/zstd), rar to unrar, the rest
             * (zip, 7z, iso, cab...) to 7z. */
            switch (ctype) {
            case "application/x-tar":
            case "application/x-compressed-tar":
            case "application/x-bzip-compressed-tar":
            case "application/x-xz-compressed-tar":
            case "application/x-zstd-compressed-tar":
                return { "tar", "-tvf", path };
            case "application/vnd.rar":
            case "application/x-rar":
                return { "unrar", "l", "-idq", path };
            case "application/zip":
            case "application/x-7z-compressed":
            case "application/x-cd-image":
            case "application/vnd.ms-cab-compressed":
            case "application/gzip":
            case "application/x-xz":
            case "application/x-bzip2":
            case "application/zstd":
                return { "7z", "l", "-ba", path };
            }
            return null;
        }

        private Gtk.Widget build_archive (string path, string ctype) {
            string[] argv = archive_command (path, ctype);
            try {
                string output;
                int status;
                Process.spawn_sync (null, argv, null,
                    SpawnFlags.SEARCH_PATH
                    | SpawnFlags.STDERR_TO_DEV_NULL,
                    null, out output, null, out status);
                if (status != 0 || output.strip () == "") {
                    return error_label ();
                }
                /* Cap huge archives; the point is a peek, not an
                 * inventory. */
                var lines = output.split ("\n");
                bool truncated = lines.length > 2000;
                if (truncated) {
                    output = string.joinv ("\n", lines[0 : 2000]);
                }
                return build_text_view (output, truncated);
            } catch (Error e) {
                return error_label ();
            }
        }

        /* ---- fallback / error ------------------------------------ */

        private Gtk.Widget build_fallback (File file, string ctype) {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            box.valign = Gtk.Align.CENTER;
            box.margin = 24;
            var icon = new Gtk.Image.from_gicon (
                ContentType.get_icon (ctype), Gtk.IconSize.DIALOG);
            icon.pixel_size = 96;
            box.pack_start (icon, false, false, 0);
            var name = new Gtk.Label (file.get_basename () ?? uri);
            name.get_style_context ().add_class ("title");
            name.ellipsize = Pango.EllipsizeMode.MIDDLE;
            box.pack_start (name, false, false, 0);
            string details = ContentType.get_description (ctype);
            try {
                var info = file.query_info (
                    FileAttribute.STANDARD_SIZE + ","
                    + FileAttribute.TIME_MODIFIED, 0);
                details += " — " + format_size (info.get_size ());
                var mtime = info.get_modification_date_time ();
                if (mtime != null) {
                    details += " — " + mtime.to_local ().format ("%x %H:%M");
                }
            } catch (Error e) { }
            var meta = new Gtk.Label (details);
            meta.get_style_context ().add_class ("dim-label");
            box.pack_start (meta, false, false, 0);
            set_default_size (460, 280);
            return box;
        }

        private Gtk.Widget error_label () {
            var label = new Gtk.Label (_("Could not preview this file"));
            label.get_style_context ().add_class ("dim-label");
            set_default_size (420, 200);
            return label;
        }

        private static Gtk.Widget wrap_scrolled (Gtk.Widget child) {
            var scrolled = new Gtk.ScrolledWindow (null, null);
            scrolled.add (child);
            return scrolled;
        }
    }

    namespace Preview {

        /* Entry point for `kavis-tools preview [file]`. Owns the
         * org.nemo.Preview name; if another instance already owns it,
         * forwards the file there and exits. */
        public int run (string? path) {
            var app = new PreviewApp ();
            string? uri = null;
            if (path != null) {
                uri = File.new_for_commandline_arg (path).get_uri ();
            }
            /* No session bus (a bare X session, a broken user bus):
             * single-instance handling is impossible, so show the file
             * here instead of exiting without a window. Checked before
             * own_name because its name-lost callback cannot receive a
             * null connection (debug pass 3 Sep). */
            DBusConnection? bus = null;
            try {
                bus = Bus.get_sync (BusType.SESSION);
            } catch (Error e) {
                warning ("kavis-tools: preview without a session bus: %s",
                         e.message);
            }
            if (bus == null) {
                if (uri != null) {
                    app.show_uri (uri, false);
                }
                Gtk.main ();
                return 0;
            }
            Bus.own_name (BusType.SESSION, "org.nemo.Preview",
                BusNameOwnerFlags.NONE,
                (conn) => {
                    try {
                        conn.register_object (
                            "/org/nemo/Preview",
                            new PreviewService (app));
                    } catch (IOError e) {
                        warning ("kavis-tools: preview registration: %s",
                                 e.message);
                    }
                },
                () => {
                    if (uri != null) {
                        app.show_uri (uri, false);
                    }
                },
                (conn, name) => {
                    /* Name taken: an instance is already running —
                     * forward the file to it and exit. */
                    if (uri != null) {
                        try {
                            conn.call_sync ("org.nemo.Preview",
                                "/org/nemo/Preview", "org.nemo.Preview",
                                "ShowFile",
                                new Variant ("(sib)", uri, 0, false),
                                null, DBusCallFlags.NONE, -1);
                        } catch (Error e) {
                            warning ("kavis-tools: preview forwarding: %s",
                                     e.message);
                        }
                    }
                    Gtk.main_quit ();
                });
            Gtk.main ();
            return 0;
        }
    }
}
