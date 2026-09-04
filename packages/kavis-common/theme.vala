/* Palette for every Kavis GTK component (B2, v0.4-test1 feedback).
 *
 * THIS IS THE CANONICAL COPY — build-packages.sh copies it into the
 * GTK packages' src trees; the copies are in .gitignore.
 *
 * Why: the panel, popups, OSD, dialogs and Settings all carried the
 * dark hex codes inline, so "Light" only switched GTK apps. Now every
 * component CSS refers to @kavis_* names and THIS file is the single
 * place that defines them — one provider per process, replaced in
 * place when kavis.conf [appearance] theme changes (GTK re-resolves
 * named colors on provider change, so the switch is live, no restart).
 * The GTK theme for third-party apps still goes through xsettingsd
 * (Kavis / Kavis-Light) — same source, two consumers.
 *
 * Color tables mirror docs/tasarim-dili.md (dark + light palette).
 */

namespace Kavis.Theme {

    private const string DARK = """
        @define-color kavis_ground  #0D141B;
        @define-color kavis_panel   #121C26;
        @define-color kavis_surface #17222C;
        @define-color kavis_card    #1C2833;
        @define-color kavis_hover   #1D2C38;
        @define-color kavis_border  #233A45;
        @define-color kavis_text    #E6EDF3;
        @define-color kavis_text2   #8B9BA8;
        @define-color kavis_text3   #4A5A66;
        @define-color kavis_teal    #2DD4BF;
        @define-color kavis_blue    #4F92F7;
        @define-color kavis_on_teal #0D141B;
        @define-color kavis_overlay_faint rgba(255, 255, 255, 0.05);
        @define-color kavis_overlay_hover rgba(255, 255, 255, 0.09);
        @define-color kavis_overlay_press rgba(255, 255, 255, 0.14);
        @define-color kavis_card_border   rgba(255, 255, 255, 0.08);
        /* A4: 1px light line along the TOP edge of every surface, so a
           panel reads as catching light from above instead of being a
           flat rectangle. Drawn as an inset box-shadow, never a border
           (a border would change the widget's size). */
        @define-color kavis_top_edge      rgba(255, 255, 255, 0.06);
        @define-color kavis_panel_acrylic   rgba(18, 28, 38, 0.85);
        @define-color kavis_surface_acrylic rgba(23, 34, 44, 0.92);
        @define-color kavis_border_acrylic  rgba(35, 58, 69, 0.9);
        @define-color kavis_backdrop        rgba(13, 20, 27, 0.92);
        @define-color kavis_underline_idle  rgba(139, 155, 168, 0.75);
        @define-color kavis_menu_category   #8FA1B3;
        @define-color kavis_menu_hover      rgba(255, 255, 255, 0.10);
        @define-color kavis_overlay_flash   rgba(255, 255, 255, 0.18);
    """;

    private const string LIGHT = """
        @define-color kavis_ground  #F3F5F7;
        @define-color kavis_panel   #E9EDF1;
        @define-color kavis_surface #FFFFFF;
        @define-color kavis_card    #FFFFFF;
        @define-color kavis_hover   #EEF1F4;
        @define-color kavis_border  #D5DBE1;
        @define-color kavis_text    #1A2430;
        @define-color kavis_text2   #5C6B78;
        @define-color kavis_text3   #A0ACB8;
        @define-color kavis_teal    #2DD4BF;
        @define-color kavis_blue    #4F92F7;
        @define-color kavis_on_teal #0D141B;
        @define-color kavis_overlay_faint rgba(0, 0, 0, 0.03);
        @define-color kavis_overlay_hover rgba(0, 0, 0, 0.06);
        @define-color kavis_overlay_press rgba(0, 0, 0, 0.10);
        @define-color kavis_card_border   rgba(0, 0, 0, 0.10);
        /* A4: on a white surface a white highlight has nothing to add;
           the light theme uses the same line as a hairline separator. */
        @define-color kavis_top_edge      rgba(0, 0, 0, 0.05);
        @define-color kavis_panel_acrylic   rgba(233, 237, 241, 0.85);
        @define-color kavis_surface_acrylic rgba(255, 255, 255, 0.92);
        @define-color kavis_border_acrylic  rgba(213, 219, 225, 0.9);
        @define-color kavis_backdrop        rgba(243, 245, 247, 0.92);
        @define-color kavis_underline_idle  rgba(92, 107, 120, 0.75);
        @define-color kavis_menu_category   #5C6B78;
        @define-color kavis_menu_hover      rgba(0, 0, 0, 0.06);
        @define-color kavis_overlay_flash   rgba(0, 0, 0, 0.14);
    """;

    private Gtk.CssProvider? provider = null;
    private FileMonitor? monitor = null;
    private bool light_now = false;

    /* Emitted after the palette provider was swapped; widgets that
     * hold theme-dependent assets (the start-button logo) redraw. */
    public class Signals : Object {
        public signal void changed (bool light);
    }
    private Signals? signals = null;

    public unowned Signals events () {
        if (signals == null) {
            signals = new Signals ();
        }
        return signals;
    }

    /* kavis.conf [appearance] theme == "light". Anything else (dark,
     * legacy "system", missing) is dark — the product default. */
    public bool is_light () {
        try {
            return Config.load ()
                .get_string ("appearance", "theme") == "light";
        } catch (Error e) {
            return false;
        }
    }

    /* Install the palette provider on the default screen and follow
     * kavis.conf. Call once after Gtk.init, before any component CSS
     * is loaded (the names must resolve when widgets first style). */
    public void install () {
        if (provider != null) {
            return;
        }
        provider = new Gtk.CssProvider ();
        light_now = is_light ();
        load (light_now);
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        monitor = Config.watch (() => {
            bool light = is_light ();
            if (light != light_now) {
                light_now = light;
                load (light);
                events ().changed (light);
            }
        });
    }

    private void load (bool light) {
        try {
            provider.load_from_data (light ? LIGHT : DARK, -1);
        } catch (Error e) {
            warning ("kavis: could not load palette: %s", e.message);
        }
    }
}
