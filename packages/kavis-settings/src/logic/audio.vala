/* Sound backend (madde 9 Ses bölümü). ALSA only — the ISO has no
 * PulseAudio/PipeWire daemon; amixer drives the master volume (same
 * tool the panel uses) and the default output card is chosen by
 * writing ~/.asoundrc (takes effect for newly started streams).
 */

namespace Kavis.Settings.Audio {

    public struct Card {
        public int index;
        public string name;
    }

    /* Sound cards from /proc/asound/cards:
     *  0 [PCH   ]: HDA-Intel - HDA Intel PCH  */
    public Card[] cards () {
        Card[] result = {};
        string contents;
        try {
            FileUtils.get_contents ("/proc/asound/cards", out contents);
        } catch (Error e) {
            return result;
        }
        foreach (unowned string line in contents.split ("\n")) {
            string trimmed = line.strip ();
            if (trimmed == "" || !line.contains ("]:")) {
                continue;
            }
            int index = int.parse (trimmed.split (" ")[0]);
            int dash = line.index_of (" - ");
            string name = (dash >= 0)
                ? line.substring (dash + 3).strip ()
                : trimmed;
            Card card = { index, name };
            result += card;
        }
        return result;
    }

    private string asoundrc_path () {
        return Path.build_filename (
            Environment.get_home_dir (), ".asoundrc");
    }

    /* Currently selected default card (from ~/.asoundrc; 0 default). */
    public int default_card () {
        try {
            string contents;
            FileUtils.get_contents (asoundrc_path (), out contents);
            foreach (unowned string line in contents.split ("\n")) {
                if (line.strip ().has_prefix ("defaults.pcm.card")) {
                    return int.parse (line.split (" ")[1] ?? "0");
                }
            }
        } catch (Error e) { }
        return 0;
    }

    public void set_default_card (int index) {
        try {
            FileUtils.set_contents (asoundrc_path (),
                "# Kavis Ayarlar > Ses yazdı (varsayılan çıkış aygıtı).\n"
                + "defaults.pcm.card %d\ndefaults.ctl.card %d\n"
                    .printf (index, index));
        } catch (Error e) {
            warning ("kavis-settings: .asoundrc yazilamadi: %s",
                     e.message);
        }
    }

    /* Master volume 0-100 (-M: insan kulağına doğrusal eşleme). */
    public int volume () {
        string? output = Run.capture ({ "amixer", "-M", "get",
                                        "Master" });
        if (output == null) {
            return 50;
        }
        int start = output.index_of ("[");
        int end = output.index_of ("%");
        if (start < 0 || end <= start) {
            return 50;
        }
        return int.parse (output.substring (start + 1,
                                            end - start - 1));
    }

    public void set_volume (int percent) {
        Run.fire ({ "amixer", "-M", "-q", "set", "Master",
                    "%d%%".printf (percent.clamp (0, 100)) });
    }
}
