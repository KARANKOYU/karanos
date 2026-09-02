/* Taskbar (UI layer).
 *
 * Layout: start button with the K logo on the left, open windows in the
 * middle, workspace switcher / keyboard layout / battery / clock /
 * show-desktop on the right.
 *
 * No system tray here — XEmbed/StatusNotifier is its own task and
 * arrives with the notification infrastructure (item 37).
 */

namespace Kavis.Ui {

    public class Panel : Gtk.Window {

        /* Historical default (madde 5 öncesi tek değer). Dış araçlar
         * (CI saat denetimi) varsayılan alt/44 düzenine göre bakar;
         * gerçek kalınlık artık config.thickness'ten gelir. */
        public const int HEIGHT = 44;
        /* Window buttons shrink between these bounds before the list
         * starts scrolling (stage 2 rule: the right region is never
         * squeezed, the window list is). Icon-only since stage 3, so
         * the bounds are near-square. */
        private const int MAX_BUTTON_WIDTH = 48;
        private const int MIN_BUTTON_WIDTH = 32;
        private const int BUTTON_SPACING = 2;
        /* Below this button width the 24 px icons switch to 16 px
         * ("icons shrink first, then the list scrolls"). */
        private const int COMPACT_THRESHOLD = 40;
        private const int ICON_NORMAL = 24;
        private const int ICON_COMPACT = 16;
        /* Active-window underline: short and centered, Windows 11
         * style — not the full button width. */
        private const int UNDERLINE_WIDTH = 16;
        private const int UNDERLINE_HEIGHT = 3;

        private const string CSS = """
        /* Akrilik (madde 4): kompozitör varken panel hafif saydam —
           duvar kâğıdı alttan sezilir. Blur bilinçli olarak YOK:
           xrender'da çalışmıyor (Grup B kararı), madde 38 gerçek
           GPU'da picom blur'unu değerlendirecek; saydamlık o güne
           kadarki 'akrilik' payı. Kompozitörsüz düz renge dönülür. */
        .kavis-panel.acrylic {
          background-color: rgba(18, 28, 38, 0.85);
          border-top: 1px solid rgba(35, 58, 69, 0.9);
        }
        .kavis-panel {
          background-color: #121C26;
          border-top: 1px solid #233A45;
        }
        .kavis-panel button {
          border: none;
          /* W11 tarzı yumuşak köşeli hover kutuları. Düğmeler panel
             yüksekliğinin tamamını kaplamayı sürdürüyor (kenar boşluğu
             verilmedi): ekranın en alt pikseline tıklama çalışmaya
             devam etmeli — Fitts. */
          border-radius: 6px;
          background-image: none;
          background-color: transparent;
          color: #E6EDF3;
          padding: 0 10px;
        }
        .kavis-panel button {
          transition: background-color 180ms ease;
        }
        .kavis-panel button:hover {
          background-color: #1D2C38;
        }
        /* Etkin öğe (sanal masaüstü düğmeleri): altında turkuaz şerit. */
        .kavis-panel button.active-item {
          background-color: #1D2C38;
          box-shadow: inset 0 -3px #2DD4BF;
        }
        /* Pencere düğmeleri (Windows 11 tarzı): yalnız ikon; etkin
           pencerenin göstergesi tam genişlik şerit değil, düğmenin
           ortasında kısa ince bir çizgi (.underline çocuğu). */
        .kavis-panel button.window-item {
          padding: 0 4px;
        }
        .kavis-panel button.window-item.active-item {
          box-shadow: none;
        }
        .kavis-panel .underline {
          background-color: transparent;
          border-radius: 2px;
          transition: background-color 180ms ease;
        }
        .kavis-panel button.active-item .underline {
          background-color: #2DD4BF;
        }
        .kavis-panel button.start {
          padding: 0 12px;
        }
        .kavis-panel button.start:hover {
          background-color: #17222C;
        }
        /* Masaüstünü göster şeridi: köşede 8 px'lik W11 kalıntısı —
           yuvarlatma ve iç boşluk almaz. */
        .kavis-panel button.edge {
          border-radius: 0;
          padding: 0;
        }
        .kavis-panel label.clock {
          color: #E6EDF3;
          padding: 0 12px;
        }
        .kavis-panel label.indicator {
          color: #8B9BA8;
          padding: 0 8px;
        }
        /* Gösterge düğmeleri (Aşama 4): etiketlerin kendi iç boşluğu
           var, düğme fazladan genişletmesin. */
        .kavis-panel button.indicator-button {
          padding: 0 2px;
        }
        .kavis-start-menu {
          background-color: #17222C;
          border: 1px solid #233A45;
        }
        """;

        private unowned Wnck.Screen screen;
        private PanelConfig config;
        private int thickness;
        /* Arka plan sınıfını taşıyan kök kutu: app_paintable pencerede
         * GTK pencerenin CSS arka planını ÇİZMEZ (PanelPopup/Overview
         * deseni) — sınıf pencereye verilince panel VM'de tamamen
         * saydam çıkıyordu ("duvar kağıdına karışıyor" hatası). */
        private Gtk.Box root_box;
        private StartMenu start_menu;
        private Gtk.ScrolledWindow window_scroll;
        private Gtk.Box window_box;
        private Gtk.Box right_box;
        private Gtk.Button start_button;
        /* Auto-hide state (madde 5). */
        private bool panel_hidden = false;
        private uint hide_timer = 0;
        /* Bildirim toast'ları (madde 37) — referans yaşasın diye alan. */
        private ToastManager toast_manager;
        /* Genel bakış (madde 55). */
        private Overview overview;
        /* Pano geçmişi + ses OSD'si (madde 7). */
        private ClipboardHistory clipboard_history;
        private ClipboardPopup clipboard_popup;
        private VolumeOsd volume_osd;
        private HashTable<ulong, Gtk.Button> window_buttons;
        private HashTable<ulong, Gtk.Image> window_images;
        private int current_button_width = 0;
        private int current_icon_size = ICON_NORMAL;
        private bool width_update_pending = false;

        public Panel () {
            Object (type: Gtk.WindowType.TOPLEVEL);
            set_title ("kavis-panel");
            set_type_hint (Gdk.WindowTypeHint.DOCK);
            set_decorated (false);
            set_resizable (false);
            set_skip_taskbar_hint (true);
            set_skip_pager_hint (true);
            set_keep_above (true);
            stick ();

            /* Akrilik (madde 4): kompozitör varken RGBA görsel + yarı
             * saydam arka plan; picom yoksa (kurtarma, çökme) düz
             * renge dönülür. picom panelden SONRA başlayabildiği için
             * composited-changed dinleniyor. */
            set_app_paintable (true);
            var gdk_screen = get_screen ();
            var rgba_visual = gdk_screen.get_rgba_visual ();
            if (rgba_visual != null) {
                set_visual (rgba_visual);
            }
            update_acrylic ();
            gdk_screen.composited_changed.connect (update_acrylic);

            load_css ();

            config = PanelConfig.load ();
            thickness = config.thickness.pixels ();
            /* Popup'lar panelin karşı yanına açılır. */
            PanelPopup.panel_position = config.position;

            /* Bildirim altyapısı (madde 37) build()'den ÖNCE: saat
             * popup'ı kurulurken sunucuya bağlanıyor. */
            Notifications.start ();
            toast_manager = new ToastManager (Notifications.server);
            /* org.kavis.Panel: openbox kısayolları buraya sesleniyor
             * (W-Tab genel bakış — madde 55, W-v pano — madde 7). */
            PanelBus.start ();

            screen = Wnck.Screen.get_default ();
            screen.force_update ();
            overview = new Overview (screen);
            clipboard_history = new ClipboardHistory ();
            clipboard_popup = new ClipboardPopup (clipboard_history);
            volume_osd = new VolumeOsd ();
            if (PanelBus.service != null) {
                PanelBus.service.overview_requested.connect (() => {
                    overview.toggle ();
                });
                PanelBus.service.clipboard_requested.connect (() => {
                    clipboard_popup.toggle ();
                });
                PanelBus.service.volume_changed.connect ((percent, muted) => {
                    volume_osd.show_level (percent, muted);
                });
            }
            start_menu = new StartMenu ();
            /* Start menu and indicator popups close one another. */
            PanelPopup.start_menu = start_menu;
            window_buttons = new HashTable<ulong, Gtk.Button> (
                direct_hash, direct_equal);
            window_images = new HashTable<ulong, Gtk.Image> (
                direct_hash, direct_equal);

            build ();
            place ();

            screen.window_opened.connect (() => refresh_windows ());
            screen.window_closed.connect (() => refresh_windows ());
            screen.active_window_changed.connect (() => on_active_changed ());
            screen.active_workspace_changed.connect (() => refresh_windows ());

            destroy.connect (Gtk.main_quit);
            /* Panel drifted after resolution changes without this. */
            Gdk.Screen.get_default ().size_changed.connect (() => place ());

            /* Sağ tık menüsü (madde 5). Düğmeler yalnız sol tıkı
             * tükettiği için sağ tık pencereye kadar kabarır. */
            button_press_event.connect ((event) => {
                if (event.button == 3) {
                    show_context_menu (event);
                    return true;
                }
                return false;
            });

            /* Otomatik gizle: kenardan girince görün, çıkınca sakla. */
            add_events (Gdk.EventMask.ENTER_NOTIFY_MASK
                        | Gdk.EventMask.LEAVE_NOTIFY_MASK);
            enter_notify_event.connect ((event) => {
                if (event.detail != Gdk.NotifyType.INFERIOR) {
                    reveal_panel ();
                }
                return false;
            });
            leave_notify_event.connect ((event) => {
                if (event.detail != Gdk.NotifyType.INFERIOR) {
                    schedule_hide ();
                }
                return false;
            });
            if (config.autohide) {
                schedule_hide ();
            }
        }

        private void update_acrylic () {
            if (root_box == null) {
                return;
            }
            unowned Gtk.StyleContext context = root_box.get_style_context ();
            if (get_screen ().is_composited ()) {
                context.add_class ("acrylic");
            } else {
                context.remove_class ("acrylic");
            }
        }

        private void load_css () {
            var provider = new Gtk.CssProvider ();
            try {
                provider.load_from_data (CSS, CSS.length);
                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (), provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning ("kavis-panel: CSS yuklenemedi: %s", e.message);
            }
        }

        private void build () {
            /* Dikey konumda (sol/sağ, madde 5) tüm eksen döner: küme
             * üstte toplanır, göstergeler alta iner, pencere listesi
             * dikey kayar. */
            var axis = config.vertical
                ? Gtk.Orientation.VERTICAL : Gtk.Orientation.HORIZONTAL;
            var box = new Gtk.Box (axis, 0);
            root_box = box;
            box.get_style_context ().add_class ("kavis-panel");
            update_acrylic ();
            add (box);

            /* --- start button --- */
            start_button = new Gtk.Button ();
            start_button.get_style_context ().add_class ("start");
            start_button.set_relief (Gtk.ReliefStyle.NONE);
            /* Logo follows the active theme (item 1): dark logo on the
             * dark theme, light on light. The choice lives in Brand —
             * one place. Left-aligned (the Windows 10 default) the
             * logo carries a "Başlat" label; centered (Windows 11
             * option) it is icon-only with the label in the tooltip. */
            bool centered =
                config.alignment == PanelConfig.Alignment.CENTER;
            if (centered || config.vertical) {
                start_button.add (Brand.logo_image (24));
                start_button.set_tooltip_text (Strings.get ("panel.start"));
            } else {
                var start_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                start_row.pack_start (Brand.logo_image (24),
                                      false, false, 0);
                start_row.pack_start (
                    new Gtk.Label (Strings.get ("panel.start")),
                    false, false, 0);
                start_button.add (start_row);
            }
            start_button.clicked.connect (on_start_clicked);

            /* --- window list --- */
            /* Inside a ScrolledWindow so its minimum width collapses:
             * however many windows are open, the panel window never
             * demands more than the screen and the right region keeps
             * its natural size. Buttons first shrink toward
             * MIN_BUTTON_WIDTH; past that the list scrolls (overlay
             * scrollbar + mouse wheel). propagate_natural_width: the
             * scroll area ASKS for its content's width (so the cluster
             * can sit centered) but still collapses under pressure. */
            window_box = new Gtk.Box (axis, BUTTON_SPACING);
            window_scroll = new Gtk.ScrolledWindow (null, null);
            if (config.vertical) {
                window_scroll.set_policy (Gtk.PolicyType.NEVER,
                                          Gtk.PolicyType.AUTOMATIC);
                window_scroll.set_propagate_natural_height (true);
            } else {
                window_scroll.set_policy (Gtk.PolicyType.AUTOMATIC,
                                          Gtk.PolicyType.NEVER);
                window_scroll.set_propagate_natural_width (true);
            }
            window_scroll.add (window_box);
            window_scroll.size_allocate.connect (() => {
                queue_button_width_update ();
            });

            /* --- cluster placement (madde 4 + hizalama seçeneği) --- */
            /* Sol hizalı (varsayılan, W10): Başlat + pencere listesi
             * soldan başlar. Ortalı (W11 seçeneği): iki genişleyen
             * boşluk kümeyi ortalar. Her iki düzende de pencere listesi
             * doğal genişliğini aşınca kaydırma devreye girer — sağ
             * bölge asla ezilmez (Aşama 2 kuralı geçerli). */
            var cluster = new Gtk.Box (axis, 4);
            cluster.pack_start (start_button, false, false, 0);
            cluster.pack_start (window_scroll, false, false, 0);

            if (centered) {
                var left_spacer = new Gtk.Box (axis, 0);
                var right_spacer = new Gtk.Box (axis, 0);
                box.pack_start (left_spacer, true, true, 0);
                box.pack_start (cluster, false, false, 0);
                box.pack_start (right_spacer, true, true, 0);
            } else {
                box.pack_start (cluster, false, false, 0);
            }

            /* --- right edge --- */
            /* Packed with expand=false: it always gets exactly its
             * natural width, no matter how crowded the window list is. */
            right_box = new Gtk.Box (axis, 0);
            /* Kavis araç çubuğu (madde 3): göstergelerin solunda,
             * yalnız kendi araçlarımız — üçüncü parti tepsi ayrı iş. */
            right_box.pack_start (new UsbIndicator (), false, false, 0);
            right_box.pack_start (new WifiIndicator (), false, false, 0);
            right_box.pack_start (new WorkspaceIndicator (screen, axis),
                                  false, false, 0);
            right_box.pack_start (new KeyboardIndicator (), false, false, 0);
            right_box.pack_start (new VolumeIndicator (), false, false, 0);
            right_box.pack_start (new BatteryIndicator (), false, false, 0);
            right_box.pack_start (new Clock (), false, false, 0);

            var show_desktop = new Gtk.Button ();
            show_desktop.get_style_context ().add_class ("edge");
            show_desktop.set_relief (Gtk.ReliefStyle.NONE);
            show_desktop.set_tooltip_text (Strings.get ("panel.show_desktop"));
            if (config.vertical) {
                show_desktop.set_size_request (-1, 8);
            } else {
                show_desktop.set_size_request (8, -1);
            }
            show_desktop.clicked.connect (() => {
                screen.toggle_showing_desktop (!screen.get_showing_desktop ());
            });
            right_box.pack_start (show_desktop, false, false, 0);

            box.pack_end (right_box, false, false, 0);
            /* Sağ bölge genişleyince (gösterge eklenince) pencere
             * düğmelerinin payı da değişir. */
            right_box.size_allocate.connect (() => {
                queue_button_width_update ();
            });
        }

        /* The monitor the panel lives on (madde 5): the configured
         * model if it is still connected, else primary — a vanished
         * monitor must never leave the user panel-less. */
        private Gdk.Monitor pick_monitor () {
            var display = Gdk.Display.get_default ();
            if (config.monitor != "primary") {
                for (int i = 0; i < display.get_n_monitors (); i++) {
                    var candidate = display.get_monitor (i);
                    if (candidate != null
                        && candidate.get_model () == config.monitor) {
                        return candidate;
                    }
                }
            }
            var primary = display.get_primary_monitor ();
            return (primary != null) ? primary : display.get_monitor (0);
        }

        private void place () {
            Gdk.Rectangle area = pick_monitor ().get_geometry ();
            int w, h, x, y;
            switch (config.position) {
            case PanelConfig.Position.TOP:
                w = area.width;  h = thickness;
                x = area.x;      y = area.y;
                break;
            case PanelConfig.Position.LEFT:
                w = thickness;   h = area.height;
                x = area.x;      y = area.y;
                break;
            case PanelConfig.Position.RIGHT:
                w = thickness;   h = area.height;
                x = area.x + area.width - thickness;
                y = area.y;
                break;
            default:   /* BOTTOM */
                w = area.width;  h = thickness;
                x = area.x;      y = area.y + area.height - thickness;
                break;
            }
            set_size_request (w, h);
            resize (w, h);
            move (x, y);
            panel_hidden = false;
            Idle.add (() => {
                set_strut (area);
                return Source.REMOVE;
            });
        }

        /* Reserve the panel strip at the bottom of the screen so
         * maximized windows stop above it (_NET_WM_STRUT_PARTIAL).
         *
         * The Python panel needed python3-xlib for this because
         * PyGObject hides Gdk.property_change; in Vala we talk to
         * libX11 directly — one XChangeProperty call, no extra
         * dependency. */
        private void set_strut (Gdk.Rectangle area) {
            var window = get_window ();
            if (window == null) {
                return;
            }
            var x11_window = window as Gdk.X11.Window;
            if (x11_window == null) {
                return;
            }
            unowned X.Display xdisplay =
                ((Gdk.X11.Display) get_display ()).get_xdisplay ();

            /* Combined screen extents (Gdk.Screen.get_width/height are
             * deprecated): struts are measured from the edges of the
             * WHOLE virtual screen, not of one monitor. */
            int screen_width = 0;
            int screen_height = 0;
            var display = Gdk.Display.get_default ();
            for (int i = 0; i < display.get_n_monitors (); i++) {
                Gdk.Rectangle mg = display.get_monitor (i).get_geometry ();
                screen_width = int.max (screen_width, mg.x + mg.width);
                screen_height = int.max (screen_height, mg.y + mg.height);
            }

            /* left, right, top, bottom, left_start, left_end,
             * right_start, right_end, top_start, top_end,
             * bottom_start, bottom_end */
            long[] strut_values = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

            /* Otomatik gizlide şerit ayrılmaz: pencereler tüm ekranı
             * kullanır, panel üstlerine kayarak gelir. */
            if (!config.autohide) {
                switch (config.position) {
                case PanelConfig.Position.TOP:
                    strut_values[2] = area.y + thickness;
                    strut_values[8] = area.x;
                    strut_values[9] = area.x + area.width - 1;
                    break;
                case PanelConfig.Position.LEFT:
                    strut_values[0] = area.x + thickness;
                    strut_values[4] = area.y;
                    strut_values[5] = area.y + area.height - 1;
                    break;
                case PanelConfig.Position.RIGHT:
                    strut_values[1] = screen_width
                        - (area.x + area.width) + thickness;
                    strut_values[6] = area.y;
                    strut_values[7] = area.y + area.height - 1;
                    break;
                default:   /* BOTTOM — şerit birleşik ekranın en altına
                            * kadar uzar (alttaki monitör boşluğunu da
                            * kapatır). */
                    strut_values[3] = screen_height
                        - (area.y + area.height) + thickness;
                    strut_values[10] = area.x;
                    strut_values[11] = area.x + area.width - 1;
                    break;
                }
            }

            X.Atom strut_partial = xdisplay.intern_atom (
                "_NET_WM_STRUT_PARTIAL", false);
            X.Atom strut = xdisplay.intern_atom ("_NET_WM_STRUT", false);
            X.Atom cardinal = xdisplay.intern_atom ("CARDINAL", false);
            X.Window xid = x11_window.get_xid ();

            xdisplay.change_property (xid, strut_partial, cardinal, 32,
                                      X.PropMode.Replace, (uchar[]) strut_values, 12);
            xdisplay.change_property (xid, strut, cardinal, 32,
                                      X.PropMode.Replace, (uchar[]) strut_values, 4);
            xdisplay.flush ();
        }

        private void on_start_clicked (Gtk.Button button) {
            if (start_menu.get_visible ()) {
                start_menu.dismiss ();
                return;
            }
            var window = button.get_window ();
            if (window == null) {
                return;
            }
            int root_x, root_y;
            window.get_origin (out root_x, out root_y);
            Gtk.Allocation alloc;
            button.get_allocation (out alloc);
            int bx = root_x + alloc.x;
            int by = root_y + alloc.y;

            /* Menünün SOL-ÜST köşesi panel konumuna göre (madde 5):
             * open() mutlak köşe bekler. */
            int x, y;
            switch (config.position) {
            case PanelConfig.Position.TOP:
                x = bx;
                y = by + alloc.height;
                break;
            case PanelConfig.Position.LEFT:
                x = bx + alloc.width;
                y = by;
                break;
            case PanelConfig.Position.RIGHT:
                x = bx - StartMenu.WIDTH;
                y = by;
                break;
            default:   /* BOTTOM */
                x = bx;
                y = by - StartMenu.HEIGHT;
                break;
            }
            /* Monitör içine kıstır. */
            Gdk.Rectangle area = pick_monitor ().get_geometry ();
            x = int.max (area.x, int.min (x, area.x + area.width
                                          - StartMenu.WIDTH));
            y = int.max (area.y, int.min (y, area.y + area.height
                                          - StartMenu.HEIGHT));
            start_menu.open (x, y);
        }

        public void refresh_windows () {
            foreach (var child in window_box.get_children ()) {
                window_box.remove (child);
            }
            window_buttons.remove_all ();
            window_images.remove_all ();

            unowned Wnck.Workspace? active_workspace =
                screen.get_active_workspace ();
            unowned Wnck.Window? active_window = screen.get_active_window ();

            foreach (unowned Wnck.Window window in screen.get_windows ()) {
                if (window.is_skip_tasklist ()) {
                    continue;
                }
                /* Only windows of the current virtual desktop. */
                if (active_workspace != null
                    && !window.is_on_workspace (active_workspace)) {
                    continue;
                }
                var button = window_button (window, window == active_window);
                window_buttons.insert (window.get_xid (), button);
                window_box.pack_start (button, false, false, 0);
            }
            window_box.show_all ();
            current_button_width = 0;   /* count changed — recompute */
            queue_button_width_update ();
        }

        /* Coalesce width updates into one idle pass: size_allocate fires
         * in bursts, and setting size requests from inside an allocate
         * cycle triggers GTK re-layout warnings. */
        private void queue_button_width_update () {
            if (width_update_pending) {
                return;
            }
            width_update_pending = true;
            Idle.add (() => {
                width_update_pending = false;
                update_button_widths ();
                return Source.REMOVE;
            });
        }

        /* Fit the window buttons to the space the list CAN take:
         * equal widths, clamped to [MIN_BUTTON_WIDTH, MAX_BUTTON_WIDTH].
         * Below the minimum the ScrolledWindow takes over and scrolls.
         *
         * Ortalanmış küme (madde 4) sonrası kullanılabilir alan
         * kaydırıcının tahsisinden OKUNAMAZ: propagate_natural_width
         * yüzünden tahsis içerik genişliğine eşittir ve hesap kendi
         * kendini beslerdi (32'de başlayan düğme 32'de kalırdı).
         * Alan panel geometrisinden türetilir: panel − sağ bölge −
         * Başlat − küme boşlukları. */
        private void update_button_widths () {
            uint count = window_buttons.size ();
            if (count == 0) {
                return;
            }
            /* Dikey panelde aynı hesap yükseklik ekseninde döner. */
            int panel_extent = config.vertical
                ? get_allocated_height () : get_allocated_width ();
            int right_extent = config.vertical
                ? right_box.get_allocated_height ()
                : right_box.get_allocated_width ();
            int start_extent = config.vertical
                ? start_button.get_allocated_height ()
                : start_button.get_allocated_width ();
            int list_space = panel_extent - right_extent - start_extent
                - 16;   /* küme iç boşluğu + nefes payı */
            int available = list_space - (int) (count - 1) * BUTTON_SPACING;
            if (available <= 1) {
                return;
            }
            int width = available / (int) count;
            width = int.min (MAX_BUTTON_WIDTH,
                             int.max (MIN_BUTTON_WIDTH, width));
            if (width == current_button_width) {
                return;
            }
            current_button_width = width;
            window_buttons.foreach ((xid, button) => {
                if (config.vertical) {
                    button.set_size_request (-1, width);
                } else {
                    button.set_size_request (width, -1);
                }
            });

            int icon_size = (width >= COMPACT_THRESHOLD)
                ? ICON_NORMAL : ICON_COMPACT;
            if (icon_size != current_icon_size) {
                current_icon_size = icon_size;
                refresh_icons ();
            }
        }

        private Gtk.Button window_button (Wnck.Window window, bool active) {
            var button = new Gtk.Button ();
            button.set_relief (Gtk.ReliefStyle.NONE);
            button.get_style_context ().add_class ("window-item");
            if (active) {
                button.get_style_context ().add_class ("active-item");
            }

            /* Icon centered, thin underline pinned to the bottom. The
             * underline is always in the layout (transparent when
             * inactive) so activation never shifts the icon. */
            var column = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            var image = new Gtk.Image.from_pixbuf (
                window_icon (window, current_icon_size));
            image.set_valign (Gtk.Align.CENTER);
            column.pack_start (image, true, true, 0);

            var underline = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            underline.get_style_context ().add_class ("underline");
            underline.set_size_request (UNDERLINE_WIDTH, UNDERLINE_HEIGHT);
            underline.set_halign (Gtk.Align.CENTER);
            column.pack_end (underline, false, false, 0);

            button.add (column);

            /* Icon-only buttons: the full window title lives in the
             * tooltip and follows later title changes. */
            button.set_tooltip_text (window.get_name () ?? "");
            hook_name_changed (window);
            window_images.insert (window.get_xid (), image);

            unowned Wnck.Window target = window;
            button.clicked.connect (() => activate_window (target));
            if (current_button_width > 0) {
                if (config.vertical) {
                    button.set_size_request (-1, current_button_width);
                } else {
                    button.set_size_request (current_button_width, -1);
                }
            }
            return button;
        }

        /* The window's own icon scaled to `size`; a generic themed icon
         * when the window has none (libwnck would fall back to a bare
         * X pictogram). */
        private static Gdk.Pixbuf? window_icon (Wnck.Window window,
                                                int size) {
            Gdk.Pixbuf? icon = null;
            if (window.get_icon_is_fallback ()) {
                try {
                    icon = Gtk.IconTheme.get_default ().load_icon (
                        "application-x-executable", size, 0);
                } catch (Error e) {
                    icon = null;
                }
            }
            if (icon == null) {
                icon = window.get_icon ();
            }
            if (icon == null) {
                return null;
            }
            if (icon.get_width () != size || icon.get_height () != size) {
                icon = icon.scale_simple (size, size,
                                          Gdk.InterpType.BILINEAR);
            }
            return icon;
        }

        /* Keep tooltips in sync with title changes without rebuilding
         * the whole list. Connected once per window (flagged on the
         * object); the handler dies with the window. */
        private void hook_name_changed (Wnck.Window window) {
            if (window.get_data<bool> ("kavis-name-hooked")) {
                return;
            }
            window.set_data<bool> ("kavis-name-hooked", true);
            unowned Wnck.Window target = window;
            window.name_changed.connect (() => {
                var button = window_buttons.lookup (target.get_xid ());
                if (button != null) {
                    button.set_tooltip_text (target.get_name () ?? "");
                }
            });
        }

        /* Re-render every taskbar icon at the current size (called when
         * crossing the compact threshold). */
        private void refresh_icons () {
            foreach (unowned Wnck.Window window in screen.get_windows ()) {
                var image = window_images.lookup (window.get_xid ());
                if (image != null) {
                    image.set_from_pixbuf (
                        window_icon (window, current_icon_size));
                }
            }
        }

        private void activate_window (Wnck.Window window) {
            uint32 timestamp = Gtk.get_current_event_time ();
            /* Clicking the active window again minimizes it — Windows
             * behavior. */
            if (window == screen.get_active_window ()
                && !window.is_minimized ()) {
                window.minimize ();
            } else {
                window.unminimize (timestamp);
                window.activate (timestamp);
            }
        }

        /* --- sağ tık menüsü (madde 5) --------------------------------- */

        private void show_context_menu (Gdk.EventButton event) {
            var menu = new Gtk.Menu ();

            /* Konum */
            var position_item = new Gtk.MenuItem.with_label (
                Strings.get ("panel.menu_position"));
            var position_menu = new Gtk.Menu ();
            unowned SList<Gtk.RadioMenuItem>? position_group = null;
            PanelConfig.Position[] positions = {
                PanelConfig.Position.BOTTOM, PanelConfig.Position.TOP,
                PanelConfig.Position.LEFT, PanelConfig.Position.RIGHT
            };
            string[] position_keys = {
                "panel.position_bottom", "panel.position_top",
                "panel.position_left", "panel.position_right"
            };
            for (int i = 0; i < positions.length; i++) {
                var item = new Gtk.RadioMenuItem.with_label (
                    position_group, Strings.get (position_keys[i]));
                position_group = item.get_group ();
                item.set_active (config.position == positions[i]);
                PanelConfig.Position value = positions[i];
                item.activate.connect (() => {
                    if (item.get_active () && config.position != value) {
                        config.position = value;
                        restart_self ();
                    }
                });
                position_menu.append (item);
            }
            position_item.set_submenu (position_menu);
            menu.append (position_item);

            /* Boyut */
            var size_item = new Gtk.MenuItem.with_label (
                Strings.get ("panel.menu_size"));
            var size_menu = new Gtk.Menu ();
            unowned SList<Gtk.RadioMenuItem>? size_group = null;
            PanelConfig.Thickness[] sizes = {
                PanelConfig.Thickness.THIN, PanelConfig.Thickness.MEDIUM,
                PanelConfig.Thickness.THICK
            };
            string[] size_keys = {
                "panel.size_thin", "panel.size_medium", "panel.size_thick"
            };
            for (int i = 0; i < sizes.length; i++) {
                var item = new Gtk.RadioMenuItem.with_label (
                    size_group, Strings.get (size_keys[i]));
                size_group = item.get_group ();
                item.set_active (config.thickness == sizes[i]);
                PanelConfig.Thickness value = sizes[i];
                item.activate.connect (() => {
                    if (item.get_active () && config.thickness != value) {
                        config.thickness = value;
                        restart_self ();
                    }
                });
                size_menu.append (item);
            }
            size_item.set_submenu (size_menu);
            menu.append (size_item);

            /* Hizalama (Grup D düzeltmesi): sol varsayılan, ortalı
             * seçenek. Yerleşimi build() kurduğu için değişim de
             * konum/boyut gibi restart_self() ister. */
            var align_item = new Gtk.MenuItem.with_label (
                Strings.get ("panel.menu_align"));
            var align_menu = new Gtk.Menu ();
            unowned SList<Gtk.RadioMenuItem>? align_group = null;
            PanelConfig.Alignment[] alignments = {
                PanelConfig.Alignment.LEFT, PanelConfig.Alignment.CENTER
            };
            string[] align_keys = {
                "panel.align_left", "panel.align_center"
            };
            for (int i = 0; i < alignments.length; i++) {
                var item = new Gtk.RadioMenuItem.with_label (
                    align_group, Strings.get (align_keys[i]));
                align_group = item.get_group ();
                item.set_active (config.alignment == alignments[i]);
                PanelConfig.Alignment value = alignments[i];
                item.activate.connect (() => {
                    if (item.get_active () && config.alignment != value) {
                        config.alignment = value;
                        restart_self ();
                    }
                });
                align_menu.append (item);
            }
            align_item.set_submenu (align_menu);
            menu.append (align_item);

            /* Ekran — yalnız birden fazla monitör varsa. */
            var display = Gdk.Display.get_default ();
            if (display.get_n_monitors () > 1) {
                var monitor_item = new Gtk.MenuItem.with_label (
                    Strings.get ("panel.menu_monitor"));
                var monitor_menu = new Gtk.Menu ();
                unowned SList<Gtk.RadioMenuItem>? monitor_group = null;

                var primary_item = new Gtk.RadioMenuItem.with_label (
                    monitor_group, Strings.get ("panel.monitor_primary"));
                monitor_group = primary_item.get_group ();
                primary_item.set_active (config.monitor == "primary");
                primary_item.activate.connect (() => {
                    if (primary_item.get_active ()
                        && config.monitor != "primary") {
                        config.monitor = "primary";
                        config.save ();
                        place ();
                    }
                });
                monitor_menu.append (primary_item);

                for (int i = 0; i < display.get_n_monitors (); i++) {
                    var candidate = display.get_monitor (i);
                    if (candidate == null) {
                        continue;
                    }
                    string model = candidate.get_model () ?? "%d".printf (i);
                    var item = new Gtk.RadioMenuItem.with_label (
                        monitor_group, model);
                    monitor_group = item.get_group ();
                    item.set_active (config.monitor == model);
                    item.activate.connect (() => {
                        if (item.get_active () && config.monitor != model) {
                            config.monitor = model;
                            config.save ();
                            place ();
                        }
                    });
                    monitor_menu.append (item);
                }
                monitor_item.set_submenu (monitor_menu);
                menu.append (monitor_item);
            }

            /* Otomatik gizle */
            var autohide_item = new Gtk.CheckMenuItem.with_label (
                Strings.get ("panel.menu_autohide"));
            autohide_item.set_active (config.autohide);
            autohide_item.toggled.connect (() => {
                config.autohide = autohide_item.get_active ();
                config.save ();
                place ();   /* şeridi geri ver / kaldır */
                if (config.autohide) {
                    schedule_hide ();
                }
            });
            menu.append (autohide_item);

            menu.append (new Gtk.SeparatorMenuItem ());

            /* Kısayollar. Hedef uygulama henüz kurulu değilse öğe soluk
             * kalır — kavis-settings Grup F'de, kavis-tools madde 7'de
             * geliyor. */
            menu.append (launcher_item ("panel.display_settings",
                "kavis-settings", { "kavis-settings", "display" }));
            menu.append (launcher_item ("panel.task_manager",
                "kavis-tools", { "kavis-tools", "tasks" }));

            menu.show_all ();
            menu.popup_at_pointer (event);
        }

        private Gtk.MenuItem launcher_item (string key, string program,
                                            string[] argv) {
            var item = new Gtk.MenuItem.with_label (Strings.get (key));
            if (Environment.find_program_in_path (program) == null) {
                item.set_sensitive (false);
                return item;
            }
            string[] command = argv;
            item.activate.connect (() => {
                try {
                    Process.spawn_async (null, command, null,
                        SpawnFlags.SEARCH_PATH, null, null);
                } catch (Error e) {
                    warning ("kavis-panel: %s baslatilamadi: %s",
                             program, e.message);
                }
            });
            return item;
        }

        /* Konum/boyut değişince panel kendini yeniden başlatır: her
         * widget'ı canlı döndürmek yerine en hafif ve en sağlam yol —
         * panel durumsuz, açılışı anlık. exec süreç görüntüsünü yerinde
         * değiştirir; X bağlantısı CLOEXEC olduğundan eski pencereler
         * sunucudan düşer. */
        private void restart_self () {
            config.save ();
            string[] argv = { "kavis-panel" };
            Posix.execv ("/proc/self/exe", argv);
            /* exec döndüyse başarısızdır — panelsiz kalma. */
            warning ("kavis-panel: yeniden baslatilamadi, ayar sonraki acilista gecerli");
        }

        /* --- otomatik gizle (madde 5) --------------------------------- */

        private void reveal_panel () {
            if (hide_timer != 0) {
                Source.remove (hide_timer);
                hide_timer = 0;
            }
            if (panel_hidden) {
                place ();
            }
        }

        private void schedule_hide () {
            if (!config.autohide) {
                return;
            }
            if (hide_timer != 0) {
                Source.remove (hide_timer);
            }
            hide_timer = Timeout.add (600, () => {
                hide_timer = 0;
                /* Açık popup/menü varken saklanmak onları köksüz
                 * bırakır. */
                if (PanelPopup.any_open () || start_menu.get_visible ()) {
                    schedule_hide ();
                    return Source.REMOVE;
                }
                slide_away ();
                return Source.REMOVE;
            });
        }

        /* 2 px'lik algılama şeridi kalacak şekilde kenara kayar. */
        private void slide_away () {
            if (panel_hidden || !config.autohide) {
                return;
            }
            Gdk.Rectangle area = pick_monitor ().get_geometry ();
            switch (config.position) {
            case PanelConfig.Position.TOP:
                move (area.x, area.y - thickness + 2);
                break;
            case PanelConfig.Position.LEFT:
                move (area.x - thickness + 2, area.y);
                break;
            case PanelConfig.Position.RIGHT:
                move (area.x + area.width - 2, area.y);
                break;
            default:
                move (area.x, area.y + area.height - 2);
                break;
            }
            panel_hidden = true;
        }

        private void on_active_changed () {
            unowned Wnck.Window? active = screen.get_active_window ();
            ulong active_xid = (active != null) ? active.get_xid () : 0;
            window_buttons.foreach ((xid, button) => {
                unowned Gtk.StyleContext context = button.get_style_context ();
                if (xid == active_xid) {
                    context.add_class ("active-item");
                } else {
                    context.remove_class ("active-item");
                }
            });
        }
    }
}
