/* kavis-selftest — process / memory / journal / coredump probes. */
namespace Kavis.Selftest {

    namespace SysMon {

        public int uss_mb (int pid) {
            string s;
            try {
                FileUtils.get_contents ("/proc/%d/smaps_rollup".printf (pid), out s);
            } catch (Error e) {
                return -1;
            }
            long kb = 0;
            foreach (string line in s.split ("\n")) {
                if (line.has_prefix ("Private_Clean:") || line.has_prefix ("Private_Dirty:")) {
                    kb += long.parse (line.replace ("Private_Clean:", "").replace ("Private_Dirty:", "").strip ().split (" ")[0]);
                }
            }
            return (int) (kb / 1024);
        }

        /* MemTotal - MemAvailable in MB (the CI's MEM-USED). */
        public int mem_used_mb () {
            string s;
            try {
                FileUtils.get_contents ("/proc/meminfo", out s);
            } catch (Error e) {
                return -1;
            }
            long total = 0, avail = 0;
            foreach (string line in s.split ("\n")) {
                if (line.has_prefix ("MemTotal:")) {
                    total = long.parse (line.substring (9).strip ().split (" ")[0]);
                } else if (line.has_prefix ("MemAvailable:")) {
                    avail = long.parse (line.substring (13).strip ().split (" ")[0]);
                }
            }
            return (int) ((total - avail) / 1024);
        }

        /* The name a process should be matched by (B2).
         *
         * /proc/PID/comm is truncated to 15 characters, so
         * "kavis-taskmanager" is stored as "kavis-taskmanag" and every
         * `process kavis-taskmanager running` expectation failed on a
         * system where it WAS running. The executable's own name has no
         * such limit, so it is the answer whenever it can be read;
         * comm stays the fallback for kernel threads and for processes
         * whose /proc/PID/exe we may not follow. */
        private string process_name (string pid) {
            string exe = "";
            try {
                exe = FileUtils.read_link ("/proc/" + pid + "/exe");
            } catch (Error e) { }
            if (exe != "") {
                return Path.get_basename (exe);
            }
            /* An interpreted program (a shell script) has the
             * interpreter as its exe, so argv[0] is closer to what the
             * scenario means. */
            string cmd;
            try {
                FileUtils.get_contents ("/proc/" + pid + "/cmdline", out cmd);
                /* cmdline is NUL separated, and every string function
                 * here stops at the first NUL — so this IS argv[0]. */
                if (cmd != "") {
                    return Path.get_basename (cmd);
                }
            } catch (Error e) { }
            string c;
            try {
                FileUtils.get_contents ("/proc/" + pid + "/comm", out c);
            } catch (Error e) {
                return "";
            }
            return c.strip ();
        }

        /* pid list by process name (exact) — pgrep -x without spawning.
         * Also accepts a comm that is the 15-character truncation of
         * the wanted name, so a process whose exe cannot be read still
         * matches. */
        public int[] pids_of (string name) {
            int[] res = {};
            string truncated = name.length > 15 ? name.substring (0, 15) : name;
            try {
                var dir = Dir.open ("/proc");
                string? pid;
                while ((pid = dir.read_name ()) != null) {
                    if (pid[0] < '0' || pid[0] > '9') {
                        continue;
                    }
                    if (process_name (pid) == name) {
                        res += int.parse (pid);
                        continue;
                    }
                    string c;
                    try {
                        FileUtils.get_contents ("/proc/" + pid + "/comm", out c);
                    } catch (Error e) {
                        continue;
                    }
                    if (c.strip () == truncated) {
                        res += int.parse (pid);
                    }
                }
            } catch (Error e) { }
            return res;
        }

        public bool running (string name) {
            return pids_of (name).length > 0;
        }

        /* processes-NNN.txt: every kavis-* plus the session pillars. */
        public string process_table () {
            var sb = new StringBuilder ();
            string[] watch = { "kavis-panel", "kavis-snap", "kavis-osd", "kavis-tools",
                               "kavis-settings", "openbox", "picom", "nemo-desktop",
                               "lxpolkit", "xcape" };
            foreach (string comm in watch) {
                foreach (int pid in pids_of (comm)) {
                    string st = "";
                    try {
                        FileUtils.get_contents ("/proc/%d/status".printf (pid), out st);
                    } catch (Error e) { }
                    int rss = 0;
                    foreach (string line in st.split ("\n")) {
                        if (line.has_prefix ("VmRSS:")) {
                            rss = int.parse (line.substring (6).strip ().split (" ")[0]) / 1024;
                        }
                    }
                    sb.append_printf ("%-16s pid %-6d rss %4d MB  uss %4d MB\n", comm, pid, rss, uss_mb (pid));
                }
            }
            return sb.str;
        }

        public int coredump_count () {
            int n = 0;
            try {
                var dir = Dir.open ("/var/lib/systemd/coredump");
                while (dir.read_name () != null) {
                    n++;
                }
            } catch (Error e) { }
            return n;
        }

        /* Journal lines since an epoch timestamp; empty when journald
         * refuses (the live user is not always in adm). */
        public string journal_since (int64 epoch) {
            string res = "";
            try {
                string se, so;
                int rc;
                Process.spawn_sync (null,
                    { "journalctl", "-b", "-q", "-o", "short", "--no-pager",
                      "--since=@%lld".printf (epoch) },
                    null, SpawnFlags.SEARCH_PATH, null, out so, out se, out rc);
                if (rc == 0) {
                    res = so;
                }
            } catch (Error e) { }
            return res;
        }

        public string run_shell (string cmd, out int rc) {
            rc = -1;
            try {
                string so, se;
                Process.spawn_sync (null, { "sh", "-c", cmd }, null,
                    SpawnFlags.SEARCH_PATH, null, out so, out se, out rc);
                if (Process.if_exited (rc)) {
                    rc = Process.exit_status (rc);
                }
                return so + se;
            } catch (Error e) {
                return e.message;
            }
        }
    }
}
