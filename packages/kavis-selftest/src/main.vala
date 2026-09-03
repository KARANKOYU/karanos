/* kavis-selftest — CLI.
 *   kavis-selftest [--all] [--scenario AD ...] [--dir KÖK] [--scenarios DİZİN]
 *                  [--shots] [--quiet]
 * Çıkış kodu: başarısız adım + senaryo hatası sayısı (en çok 125). */
int main (string[] args) {
    Gtk.init (ref args);
    string? scen_dir = Environment.get_variable ("KAVIS_SELFTEST_DIR")
        ?? "/usr/share/kavis/selftest";
    string? base_dir = null;
    string[] wanted = {};
    bool shots = false, quiet = false;
    for (int i = 1; i < args.length; i++) {
        switch (args[i]) {
        case "--all": break;
        case "--scenario": if (i + 1 < args.length) { wanted += args[++i]; } break;
        case "--dir": if (i + 1 < args.length) { base_dir = args[++i]; } break;
        case "--scenarios": if (i + 1 < args.length) { scen_dir = args[++i]; } break;
        case "--shots": shots = true; break;
        case "--quiet": quiet = true; break;
        default:
            stderr.printf ("kullanım: kavis-selftest [--all] [--scenario AD ...] [--dir KÖK] [--scenarios DİZİN] [--shots] [--quiet]\n");
            return 2;
        }
    }
    string[] files = {};
    try {
        var d = Dir.open (scen_dir);
        string? n;
        while ((n = d.read_name ()) != null) {
            if (!n.has_suffix (".yaml")) { continue; }
            string stem = n.substring (0, n.length - 5);
            if (wanted.length > 0) {
                bool hit = false;
                foreach (string wn in wanted) { if (stem == wn || stem.has_suffix ("-" + wn) || n == wn) { hit = true; } }
                if (!hit) { continue; }
            }
            files += Path.build_filename (scen_dir, n);
        }
    } catch (Error e) {
        stderr.printf ("senaryo dizini okunamadı: %s\n", e.message);
        return 2;
    }
    if (files.length == 0) {
        stderr.printf ("senaryo bulunamadı (%s)\n", scen_dir);
        return 2;
    }
    /* sözlük sırası: 01-, 03-, ... */
    for (int i = 0; i < files.length; i++) {
        for (int j = i + 1; j < files.length; j++) {
            if (strcmp (files[j], files[i]) < 0) { var t = files[i]; files[i] = files[j]; files[j] = t; }
        }
    }
    var rep = new Kavis.Selftest.Report (base_dir);
    rep.echo_stdout = !quiet;
    rep.mem_start = Kavis.Selftest.SysMon.mem_used_mb ();
    rep.line ("START dizin=%s senaryo=%d".printf (rep.dir, files.length));
    var runner = new Kavis.Selftest.Runner (rep, shots);
    foreach (string f in files) {
        runner.run (Kavis.Selftest.Scenario.load (f));
    }
    rep.mem_end = Kavis.Selftest.SysMon.mem_used_mb ();
    rep.finish ();
    int fails = rep.failures ();
    rep.line (fails == 0 ? "SELFTEST-OK" : "SELFTEST-FAIL %d hata".printf (fails));
    return int.min (fails, 125);
}
