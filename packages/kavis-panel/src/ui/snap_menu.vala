/* Snap layout menu (UI layer) — sonraki-isler bölüm 4.
 *
 * Win+Z opens a small centered popup showing layout schemas (halves,
 * two-thirds, quarters, thirds); hovering lights a cell, clicking
 * moves the window that was ACTIVE when the menu opened into that
 * cell. Placement uses Wnck set_geometry directly with the same
 * fractions kavis-snap uses — calling into the drag daemon would need
 * new IPC for no gain (lightest-solution rule; decision logged).
 *
 * Trigger 2 from the spec (600 ms hover over the maximize button)
 * is NOT possible: openbox exposes no titlebar hover events to other
 * processes. Win+Z is the trigger. (Noted in durum.md.)
 */

namespace Kavis.Ui {

    public class SnapMenu : Gtk.Window {

        private struct Cell {
            public double fx;
            public double fy;
            public double fw;
            public double fh;
        }

        private const string CSS = """
        .kavis-snap-menu {
          background-color: @kavis_surface;
          border: 1px solid @kavis_border;
          border-radius: 12px;   /* J1 */
        }
        .kavis-snap-menu button.snap-cell {
          background-image: none;
          background-color: @kavis_hover;
          border: 1px solid @kavis_border;
          border-radius: 4px;
          padding: 0;
          transition: background-color 140ms ease;
        }
        .kavis-snap-menu button.snap-cell:hover {
          background-color: rgba(45, 212, 191, 0.45);
          border-color: @kavis_teal;
        }
        """;

        private static bool css_loaded = false;
        private unowned Wnck.Window? target = null;
        private bool grabbed = false;

        public SnapMenu () {
            Object (type: Gtk.WindowType.POPUP);
            set_type_hint (Gdk.WindowTypeHint.POPUP_MENU);
            set_skip_taskbar_hint (true);
            set_app_paintable (true);
            var screen = get_screen ();
            var visual = screen.get_rgba_visual ();
            if (visual != null && screen.is_composited ()) {
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

            var grid = new Gtk.Grid ();
            grid.get_style_context ().add_class ("kavis-snap-menu");
            grid.set_row_spacing (10);
            grid.set_column_spacing (10);
            grid.set_border_width (14);
            add (grid);

            /* 2 sütun: yarımlar, üçte iki; çeyrekler, üçler. */
            Cell[] halves = {
                { 0, 0, 0.5, 1 }, { 0.5, 0, 0.5, 1 }
            };
            Cell[] two_thirds = {
                { 0, 0, 2.0 / 3, 1 }, { 2.0 / 3, 0, 1.0 / 3, 1 }
            };
            Cell[] quarters = {
                { 0, 0, 0.5, 0.5 }, { 0.5, 0, 0.5, 0.5 },
                { 0, 0.5, 0.5, 0.5 }, { 0.5, 0.5, 0.5, 0.5 }
            };
            Cell[] thirds = {
                { 0, 0, 1.0 / 3, 1 }, { 1.0 / 3, 0, 1.0 / 3, 1 },
                { 2.0 / 3, 0, 1.0 / 3, 1 }
            };
            grid.attach (schema (halves), 0, 0, 1, 1);
            grid.attach (schema (two_thirds), 1, 0, 1, 1);
            grid.attach (schema (quarters), 0, 1, 1, 1);
            grid.attach (schema (thirds), 1, 1, 1, 1);

            button_press_event.connect ((event) => {
                if (PanelPopup.press_outside (this, event)) {
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

        /* One layout schema: a fixed 108×68 board holding one button
         * per cell at the cell's fraction of the board. */
        private Gtk.Widget schema (Cell[] cells) {
            const int BOARD_W = 108;
            const int BOARD_H = 68;
            const int GAP = 3;
            var board = new Gtk.Fixed ();
            board.set_size_request (BOARD_W, BOARD_H);
            foreach (Cell cell in cells) {
                var button = new Gtk.Button ();
                button.set_relief (Gtk.ReliefStyle.NONE);
                button.get_style_context ().add_class ("snap-cell");
                int w = (int) (cell.fw * BOARD_W) - GAP;
                int h = (int) (cell.fh * BOARD_H) - GAP;
                button.set_size_request (int.max (10, w),
                                         int.max (10, h));
                Cell chosen = cell;
                button.clicked.connect (() => place (chosen));
                board.put (button,
                           (int) (cell.fx * BOARD_W),
                           (int) (cell.fy * BOARD_H));
            }
            return board;
        }

        private void place (Cell cell) {
            unowned Wnck.Window? window = target;
            target = null;
            dismiss ();
            if (window == null) {
                return;
            }
            /* Menü açıkken pencere kapanmış olabilir — unowned işaretçi
             * sarkmasın (debug turu bulgusu). */
            bool alive = false;
            foreach (unowned Wnck.Window candidate in
                     Wnck.Screen.get_default ().get_windows ()) {
                if (candidate == window) {
                    alive = true;
                    break;
                }
            }
            if (!alive) {
                return;
            }
            int wx, wy, ww, wh;
            window.get_geometry (out wx, out wy, out ww, out wh);
            var display = Gdk.Display.get_default ();
            var monitor = display.get_monitor_at_point (
                wx + ww / 2, wy + wh / 2);
            /* Workarea: panel şeridi düşülmüş alan. */
            Gdk.Rectangle area = monitor.get_workarea ();
            int x = area.x + (int) (cell.fx * area.width);
            int y = area.y + (int) (cell.fy * area.height);
            int w = (int) (cell.fw * area.width);
            int h = (int) (cell.fh * area.height);
            window.unmaximize ();
            window.set_geometry (Wnck.WindowGravity.NORTHWEST,
                Wnck.WindowMoveResizeMask.X | Wnck.WindowMoveResizeMask.Y
                | Wnck.WindowMoveResizeMask.WIDTH
                | Wnck.WindowMoveResizeMask.HEIGHT,
                x, y, w, h);
            window.activate (Gtk.get_current_event_time ());
        }

        /* Menü açılırken ETKİN pencere hedeftir; popup WM odağı
         * almaz, pencere etkin kalır. */
        public void open () {
            if (get_visible ()) {
                dismiss ();
                return;
            }
            var screen = Wnck.Screen.get_default ();
            screen.force_update ();
            target = screen.get_active_window ();
            if (target == null) {
                return;
            }

            show_all ();
            Gtk.Requisition natural;
            get_preferred_size (null, out natural);
            var display = Gdk.Display.get_default ();
            var monitor = display.get_primary_monitor ()
                ?? display.get_monitor (0);
            Gdk.Rectangle area = monitor.get_workarea ();
            move (area.x + (area.width - natural.width) / 2,
                  area.y + (area.height - natural.height) / 2);

            Gtk.grab_add (this);
            grabbed = true;
            PanelPopup.seat_grab (this);
        }

        public void dismiss () {
            if (grabbed) {
                Gtk.grab_remove (this);
                grabbed = false;
            }
            PanelPopup.seat_ungrab ();
            hide ();
        }
    }
}
