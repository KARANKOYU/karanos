/* kavis-selftest — CLI.
 *   kavis-selftest [--all] [--scenario NAME ...] [--dir ROOT] [--scenarios DIR]
 *                  [--shots] [--quiet] [--check]
 * Exit code: number of failed steps + scenario errors (at most 125).
 *
 * --check parses every scenario and runs nothing. A scenario with a
 * typo in it would otherwise only be discovered in a VM, forty minutes
 * after the mistake; this makes it a push-time check instead. */
int main (string[] args) {
    /* --check parses scenarios and touches no window, so it must not
     * need a display: requiring one made it depend on Xvfb and xauth in
     * CI, which is a lot of moving parts for reading files. Gtk.init
     * comes after the argument scan for that reason. */
    bool parse_only = false;
    foreach (unowned string arg in args) {
        if (arg == "--check") {
            parse_only = true;
        }
    }
    if (!parse_only) {
        Gtk.init (ref args);
    }
    string? scen_dir = Environment.get_variable ("KAVIS_SELFTEST_DIR")
        ?? "/usr/share/kavis/selftest";
    string? base_dir = null;
    string[] wanted = {};
    bool shots = false, quiet = false, check_only = false;
    string? record_to = null;
    string record_item = "0";
    for (int i = 1; i < args.length; i++) {
        switch (args[i]) {
        case "--all": break;
        case "--scenario": if (i + 1 < args.length) { wanted += args[++i]; } break;
        case "--dir": if (i + 1 < args.length) { base_dir = args[++i]; } break;
        case "--scenarios": if (i + 1 < args.length) { scen_dir = args[++i]; } break;
        case "--shots": shots = true; break;
        case "--quiet": quiet = true; break;
        case "--check": check_only = true; break;
        /* Record mode (item 72): watch a session and write it down as
         * a scenario. */
        case "--record": if (i + 1 < args.length) { record_to = args[++i]; } break;
        case "--item": if (i + 1 < args.length) { record_item = args[++i]; } break;
        /* Gtk.init would normally have eaten these. */
        case "--display": if (i + 1 < args.length) { i++; } break;
        default:
            stderr.printf ("usage: kavis-selftest [--all] [--scenario NAME ...] [--dir ROOT] [--scenarios DIR] [--shots] [--quiet]\n"
                           + "       kavis-selftest --record FILE.yaml [--item N]\n");
            return 2;
        }
    }
    if (record_to != null) {
        return new Kavis.Selftest.Recorder (record_to, record_item).run ();
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
        stderr.printf ("could not read the scenario directory: %s\n", e.message);
        return 2;
    }
    if (files.length == 0) {
        stderr.printf ("no scenario found (%s)\n", scen_dir);
        return 2;
    }
    /* lexical order: 01-, 03-, ... */
    for (int i = 0; i < files.length; i++) {
        for (int j = i + 1; j < files.length; j++) {
            if (strcmp (files[j], files[i]) < 0) { var t = files[i]; files[i] = files[j]; files[j] = t; }
        }
    }
    if (check_only) {
        int bad = 0;
        foreach (string f in files) {
            var sc = Kavis.Selftest.Scenario.load (f);
            if (sc.parse_error != "") {
                stderr.printf ("%s: %s\n", Path.get_basename (f),
                               sc.parse_error);
                bad++;
                continue;
            }
            if (sc.get_steps ().length == 0) {
                stderr.printf ("%s: no steps\n", Path.get_basename (f));
                bad++;
                continue;
            }
            stdout.printf ("%-28s item %-4s %2d steps  %s\n",
                           sc.name, sc.item, sc.get_steps ().length,
                           sc.title);
        }
        if (bad > 0) {
            stderr.printf ("SELFTEST-SCENARIOS-FAIL %d unusable\n", bad);
            return 1;
        }
        stdout.printf ("SELFTEST-SCENARIOS-OK %d scenarios parse\n",
                       files.length);
        return 0;
    }

    var rep = new Kavis.Selftest.Report (base_dir);
    rep.echo_stdout = !quiet;
    rep.mem_start = Kavis.Selftest.SysMon.mem_used_mb ();
    rep.line ("START dir=%s scenarios=%d".printf (rep.dir, files.length));
    var runner = new Kavis.Selftest.Runner (rep, shots);
    foreach (string f in files) {
        runner.run (Kavis.Selftest.Scenario.load (f));
    }
    rep.mem_end = Kavis.Selftest.SysMon.mem_used_mb ();
    rep.finish ();
    int fails = rep.failures ();
    rep.line (fails == 0 ? "SELFTEST-OK" : "SELFTEST-FAIL %d failures".printf (fails));
    return int.min (fails, 125);
}
