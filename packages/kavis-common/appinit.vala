/* Common startup for every kavis-* GTK application (madde 61).
 *
 * KANONİK KOPYA BURASI. tools/build-packages.sh (prepare_sources) bu
 * dosyayı derleme sırasında her GTK paketinin src/ ağacına kopyalar;
 * kopyalar .gitignore'dadır. YALNIZ bu dosyayı düzenle — assets/logo
 * kopyalarıyla aynı "depoda tek yerde dur" düzeni.
 *
 * Neden var: GTK'ya dokunan her kavis uygulaması aynı başlangıç
 * ayarlarına muhtaç; ilk uygulamada (panel) bulunan tuzaklar burada
 * birikir ki sonrakiler (Ayarlar, Mağaza, araçlar) baştan korunsun.
 */

namespace Kavis.AppInit {

    /* Call BEFORE Gtk.init. Safe to call more than once. */
    public void init () {
        /* Locale + gettext (Grup D task c): every kavis binary reads
         * its UI texts from the "kavis" domain (msgids are English —
         * the product default language; tr.po carries Turkish). The
         * .mo files ship in kavis-panel. */
        /* Kullanıcının seçtiği dil (B6): Ayarlar ~/.config/kavis/locale
         * yazar; oturum ortamı eski kalsa bile her Kavis süreci bunu
         * okur — panel yeniden başlayınca hemen yeni dilde açılır. */
        apply_user_locale ();
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain ("kavis", "/usr/share/locale");
        Intl.bind_textdomain_codeset ("kavis", "UTF-8");
        Intl.textdomain ("kavis");

        /* Kavis GTK apps never use GL themselves (drawing is cairo,
         * compositing is picom's job), but GTK3's X11 backend probes
         * GLX on the first realized window — and without a GPU
         * (VirtualBox, QEMU) Mesa answers with llvmpipe, pinning
         * ~50 MB of libLLVM into RSS. Measured on the panel: 85 MB
         * with GL probing, 34 MB without. Off by default, overridable
         * from the environment (override=false), so an app that one
         * day does need GtkGLArea can opt back in with GDK_GL=always. */
        Environment.set_variable ("GDK_GL", "disable", false);
    }

    private void apply_user_locale () {
        string path = Path.build_filename (
            Environment.get_user_config_dir (), "kavis", "locale");
        string contents;
        try {
            FileUtils.get_contents (path, out contents);
        } catch (Error e) {
            return;
        }
        foreach (unowned string line in contents.split ("\n")) {
            int eq = line.index_of_char ('=');
            if (eq < 1) {
                continue;
            }
            string key = line.substring (0, eq).strip ();
            string value = line.substring (eq + 1).strip ();
            if ((key == "LANG" || key == "LANGUAGE") && value != "") {
                Environment.set_variable (key, value, true);
            }
        }
    }
}
