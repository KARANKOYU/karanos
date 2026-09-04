/* Hardware test (item 50) — the checks that need no interaction.
 *
 * Every test answers one question with PASS, FAIL or SKIP and a line of
 * plain text. SKIP is not a soft FAIL: a machine with no battery has no
 * battery test to fail, and reporting that as a failure would train
 * people to ignore the report.
 *
 * Nothing here writes to the system. The one privileged read (SMART)
 * goes through a helper, because smartctl needs to open the raw device.
 *
 * Existing tools are called rather than reimplemented (the "do not
 * write your own engine" rule): alsa-utils for sound, smartctl for
 * disks, curl for the network. The RAM check is ours because there is
 * no userspace tool for it that is worth a dependency — and it is
 * deliberately a quick pattern check, not a memory test: a real one
 * needs the machine to itself and lives in GRUB (memtest86+).
 */

namespace Kavis.Settings.HwTest {

    public enum Result { PASS, FAIL, SKIP }

    public class Check : Object {
        public string id;
        public string title;
        public Result result;
        public string detail;
        public double seconds;
    }

    public string result_word (Result r) {
        switch (r) {
        case Result.PASS: return _("Passed");
        case Result.FAIL: return _("Failed");
        default:          return _("Skipped");
        }
    }

    private Check make (string id, string title, Result result,
                        string detail, double seconds = 0) {
        var c = new Check ();
        c.id = id;
        c.title = title;
        c.result = result;
        c.detail = detail;
        c.seconds = seconds;
        return c;
    }

    /* --- disks: SMART health ------------------------------------------ */

    public Check smart () {
        var timer = new Timer ();
        if (!FileUtils.test ("/usr/lib/kavis/hw-report", FileTest.IS_EXECUTABLE)) {
            return make ("smart", _("Disk health"), Result.SKIP,
                         _("The reporting helper is not installed"));
        }
        /* Wrapped in `timeout`: this is the only check that blocks on a
         * privileged call, and pkexec waits for an answer. The polkit
         * action needs no password from the active user, so it normally
         * returns at once — but if anything ever puts a dialog in front
         * of it, an unattended selftest run would sit there for ever
         * instead of reporting a skipped check. */
        string? text = Run.capture ({ "timeout", "25", "pkexec",
                                      "/usr/lib/kavis/hw-report", "smart" });
        if (text == null || text.strip () == "") {
            return make ("smart", _("Disk health"), Result.SKIP,
                _("No disk reported SMART data (common in a virtual machine)"),
                timer.elapsed ());
        }
        /* One line per disk: "sda PASSED" / "nvme0n1 FAILED". */
        int good = 0;
        string[] bad = {};
        foreach (unowned string line in text.split ("\n")) {
            string[] f = line.strip ().split (" ");
            if (f.length < 2) {
                continue;
            }
            if (f[1] == "PASSED" || f[1] == "OK") {
                good++;
            } else {
                bad += f[0];
            }
        }
        if (bad.length > 0) {
            return make ("smart", _("Disk health"), Result.FAIL,
                _("SMART reports a problem on: %s — back up now")
                    .printf (string.joinv (", ", bad)), timer.elapsed ());
        }
        if (good == 0) {
            return make ("smart", _("Disk health"), Result.SKIP,
                _("No disk reported SMART data (common in a virtual machine)"),
                timer.elapsed ());
        }
        return make ("smart", _("Disk health"), Result.PASS,
            ngettext ("%d disk reports itself healthy",
                      "%d disks report themselves healthy", good)
                .printf (good), timer.elapsed ());
    }

    /* --- memory: a quick pattern check -------------------------------- */

    /* Writes patterns over a block of memory and reads them back. This
     * finds gross faults and nothing subtle: real memory testing needs
     * the machine to itself, which is what memtest86+ in the boot menu
     * is for. Sized at an eighth of what is free and capped, because a
     * test that pushes the machine into swap measures the disk. */
    public Check memory () {
        var timer = new Timer ();
        int64 available_kb = 0;
        string meminfo;
        try {
            FileUtils.get_contents ("/proc/meminfo", out meminfo);
        } catch (Error e) {
            return make ("memory", _("Memory"), Result.SKIP,
                         _("Cannot read /proc/meminfo"));
        }
        foreach (unowned string line in meminfo.split ("\n")) {
            if (line.has_prefix ("MemAvailable:")) {
                available_kb = int64.parse (line.substring (13).strip ()
                                                .split (" ")[0]);
            }
        }
        int64 bytes = (available_kb * 1024) / 8;
        if (bytes > 512 * 1024 * 1024) {
            bytes = 512 * 1024 * 1024;
        }
        if (bytes < 16 * 1024 * 1024) {
            return make ("memory", _("Memory"), Result.SKIP,
                _("Not enough free memory to test safely"));
        }
        int count = (int) (bytes / sizeof (uint64));
        uint64[] block;
        block = new uint64[count];
        uint64[] patterns = { 0x0000000000000000, 0xFFFFFFFFFFFFFFFF,
                              0xAAAAAAAAAAAAAAAA, 0x5555555555555555 };
        int64 errors = 0;
        foreach (uint64 pattern in patterns) {
            for (int i = 0; i < count; i++) {
                block[i] = pattern ^ (uint64) i;
            }
            for (int i = 0; i < count; i++) {
                if (block[i] != (pattern ^ (uint64) i)) {
                    errors++;
                }
            }
        }
        double mb = bytes / (1024.0 * 1024.0);
        if (errors > 0) {
            return make ("memory", _("Memory"), Result.FAIL,
                _("%lld errors in %.0f MB — run the full memory test from the boot menu")
                    .printf (errors, mb), timer.elapsed ());
        }
        return make ("memory", _("Memory"), Result.PASS,
            _("%.0f MB checked with four patterns, no errors").printf (mb),
            timer.elapsed ());
    }

    /* --- network throughput ------------------------------------------- */

    /* Downloads from the Debian mirror the machine already uses for
     * updates. No third-party speed-test service: it would be a new
     * network dependency and a new party learning this machine's
     * address, for a number the mirror can give just as well. */
    public Check network () {
        var timer = new Timer ();
        if (Environment.find_program_in_path ("curl") == null) {
            return make ("network", _("Network speed"), Result.SKIP,
                         _("curl is not installed"));
        }
        string? speed = Run.capture ({ "curl", "-s", "-o", "/dev/null",
            "--max-time", "20", "-w", "%{speed_download} %{http_code}",
            "https://deb.debian.org/debian/dists/trixie/Release" });
        if (speed == null) {
            return make ("network", _("Network speed"), Result.SKIP,
                _("No internet connection"), timer.elapsed ());
        }
        string[] f = speed.strip ().split (" ");
        if (f.length < 2 || f[1] != "200") {
            return make ("network", _("Network speed"), Result.SKIP,
                _("No internet connection"), timer.elapsed ());
        }
        double bytes_per_second = double.parse (f[0]);
        double mbit = bytes_per_second * 8 / 1000000.0;
        if (mbit < 0.5) {
            return make ("network", _("Network speed"), Result.FAIL,
                _("%.1f Mbit/s — slower than a working connection should be")
                    .printf (mbit), timer.elapsed ());
        }
        return make ("network", _("Network speed"), Result.PASS,
            _("%.1f Mbit/s from the Debian mirror").printf (mbit),
            timer.elapsed ());
    }

    /* --- camera -------------------------------------------------------- */

    /* Presence and openability only. A live preview needs a video
     * pipeline this package does not link, and claiming to have tested
     * the picture without showing one would be the kind of check that
     * passes on a broken camera. */
    public Check camera () {
        string[] found = {};
        try {
            var dir = Dir.open ("/dev");
            string? name;
            while ((name = dir.read_name ()) != null) {
                if (name.has_prefix ("video") && digits (name.substring (5))) {
                    found += name;
                }
            }
        } catch (Error e) { }
        if (found.length == 0) {
            return make ("camera", _("Camera"), Result.SKIP,
                         _("No camera found"));
        }
        /* Lowest node number first: video0 is the built-in camera on
         * every machine that has one. */
        string first = found[0];
        foreach (unowned string node in found) {
            if (strcmp (node, first) < 0) {
                first = node;
            }
        }
        string device = "/dev/" + first;
        int fd = Posix.open (device, Posix.O_RDONLY);
        if (fd < 0) {
            return make ("camera", _("Camera"), Result.FAIL,
                _("%s exists but cannot be opened — check permissions")
                    .printf (device));
        }
        Posix.close (fd);
        string label = camera_name (first);
        return make ("camera", _("Camera"), Result.PASS,
            (label == "") ? _("%s opens").printf (device)
                          : _("%s (%s) opens").printf (label, device));
    }

    private string camera_name (string node) {
        string contents;
        try {
            FileUtils.get_contents ("/sys/class/video4linux/" + node + "/name",
                                    out contents);
            return contents.strip ();
        } catch (Error e) {
            return "";
        }
    }

    private bool digits (string text) {
        if (text.length == 0) {
            return false;
        }
        for (int i = 0; i < text.length; i++) {
            if (text[i] < '0' || text[i] > '9') {
                return false;
            }
        }
        return true;
    }

    /* --- microphone ----------------------------------------------------- */

    /* Records three seconds and looks at the peak. Automatic on
     * purpose: "did it hear you?" is a question the machine can answer
     * better than the person, who cannot see the waveform. */
    public Check microphone () {
        var timer = new Timer ();
        if (Environment.find_program_in_path ("arecord") == null) {
            return make ("microphone", _("Microphone"), Result.SKIP,
                         _("alsa-utils is not installed"));
        }
        /* A machine with no capture hardware has nothing to test, and
         * `arecord` does not say so: it happily records three seconds
         * of digital silence from a dummy device, which then reads as
         * a muted microphone. That is how every QEMU run reported a
         * FAIL. `arecord -l` lists the capture cards and lists nothing
         * when there are none. */
        string? cards = Run.capture ({ "arecord", "-l" });
        if (cards == null || !cards.contains ("card ")) {
            return make ("microphone", _("Microphone"), Result.SKIP,
                         _("No recording device on this machine"),
                         timer.elapsed ());
        }
        string path = Path.build_filename (Environment.get_tmp_dir (),
                                           "kavis-mic-test.wav");
        FileUtils.unlink (path);
        string message;
        if (!Run.run ({ "arecord", "-q", "-d", "3", "-f", "S16_LE",
                        "-r", "16000", "-c", "1", path }, out message)) {
            return make ("microphone", _("Microphone"), Result.SKIP,
                _("No recording device: %s").printf (message.strip ()),
                timer.elapsed ());
        }
        int peak = wav_peak (path);
        FileUtils.unlink (path);
        if (peak < 0) {
            return make ("microphone", _("Microphone"), Result.SKIP,
                         _("The recording could not be read"), timer.elapsed ());
        }
        /* Exactly zero is not a quiet room — a real microphone always
         * picks up some noise floor. It means the samples never came
         * from an input at all (dummy device, muted in the driver), so
         * there is nothing to report as a failure. */
        if (peak == 0) {
            return make ("microphone", _("Microphone"), Result.SKIP,
                         _("The recording device produced no signal"),
                         timer.elapsed ());
        }
        /* 2% of full scale: below that the line is silent even for a
         * quiet room with a working microphone. */
        int percent = peak * 100 / 32767;
        if (percent < 2) {
            return make ("microphone", _("Microphone"), Result.FAIL,
                _("Silence recorded — the microphone may be muted or not connected"),
                timer.elapsed ());
        }
        return make ("microphone", _("Microphone"), Result.PASS,
            _("Sound picked up, peak %d%%").printf (percent), timer.elapsed ());
    }

    /* Peak absolute sample of a 16-bit mono WAV; -1 when unreadable. */
    private int wav_peak (string path) {
        uint8[] data;
        try {
            FileUtils.get_data (path, out data);
        } catch (Error e) {
            return -1;
        }
        if (data.length < 64) {
            return -1;
        }
        int peak = 0;
        /* 44 bytes of canonical WAV header before the samples. */
        for (int i = 44; i + 1 < data.length; i += 2) {
            int sample = (int) (short) (data[i] | (data[i + 1] << 8));
            int magnitude = (sample < 0) ? -sample : sample;
            if (magnitude > peak) {
                peak = magnitude;
            }
        }
        return peak;
    }

    /* The automatic checks by name, for `kavis-settings --hw-test`.
     * Only these: the interactive ones need a person, and a test hook
     * that pretended to run them would report a person's answer that
     * nobody gave. */
    public Check? run_by_id (string id) {
        switch (id) {
        case "memory":     return memory ();
        case "camera":     return camera ();
        case "network":    return network ();
        case "smart":      return smart ();
        case "microphone": return microphone ();
        }
        return null;
    }

    /* --- the report ----------------------------------------------------- */

    /* One HTML file per run, next to the selftest reports and in the
     * same shape, so both open the same way. Kept rather than
     * overwritten: item 50 wants runs to be comparable over time. */
    public string write_report (Check[] checks) {
        string dir = Path.build_filename (Environment.get_user_data_dir (),
                                          "kavis", "hardware-test");
        DirUtils.create_with_parents (dir, 0755);
        string stamp = new DateTime.now_local ().format ("%Y%m%d-%H%M%S");
        string path = Path.build_filename (dir, stamp + ".html");
        var sb = new StringBuilder ();
        int failures = 0;
        foreach (Check c in checks) {
            if (c.result == Result.FAIL) {
                failures++;
            }
        }
        sb.append ("<!doctype html><meta charset=\"utf-8\">");
        sb.append_printf ("<title>%s</title>", _("Hardware test"));
        sb.append ("<style>body{font:14px system-ui,sans-serif;background:#0D141B;color:#E6EDF3;margin:24px}"
                   + "table{border-collapse:collapse;margin-top:12px}"
                   + "td,th{border:1px solid #233A45;padding:6px 10px;text-align:left}"
                   + ".PASS{color:#22C55E}.FAIL{color:#EF4444}.SKIP{color:#8B9BA8}</style>");
        sb.append_printf ("<h1>%s</h1>", _("Hardware test"));
        sb.append_printf ("<p>%s</p>",
            Markup.escape_text (new DateTime.now_local ()
                                    .format ("%Y-%m-%d %H:%M")));
        sb.append_printf ("<p>%s</p>", failures == 0
            ? Markup.escape_text (_("Everything passed."))
            : Markup.escape_text (ngettext ("%d check failed.",
                                            "%d checks failed.", failures)
                                      .printf (failures)));
        sb.append_printf ("<table><tr><th>%s</th><th>%s</th><th>%s</th></tr>",
            Markup.escape_text (_("Check")),
            Markup.escape_text (_("Result")),
            Markup.escape_text (_("Detail")));
        foreach (Check c in checks) {
            sb.append_printf ("<tr><td>%s</td><td class=\"%s\">%s</td><td>%s</td></tr>",
                Markup.escape_text (c.title),
                (c.result == Result.PASS) ? "PASS"
                    : ((c.result == Result.FAIL) ? "FAIL" : "SKIP"),
                Markup.escape_text (result_word (c.result)),
                Markup.escape_text (c.detail));
        }
        sb.append ("</table>");
        try {
            FileUtils.set_contents (path, sb.str);
        } catch (Error e) {
            warning ("kavis-settings: hardware report: %s", e.message);
            return "";
        }
        return path;
    }
}
