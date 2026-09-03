/* kavis-selftest — scenario files (madde 72, kararlar.md 9b).
 *
 * The format is a deliberately small YAML subset so no YAML library is
 * needed at runtime: top-level "key: value" lines, one "steps:" list
 * whose items start with "- do:" and continue with indented
 * "key: value" lines. Quotes around values are stripped, "#" starts a
 * comment, "allowed: [a, b]" is an inline list. Anything else is an
 * error — a scenario that does not parse is reported, never skipped.
 */
namespace Kavis.Selftest {

    public class Step : Object {
        public string action = "none";
        public string expect = "ok";
        public int timeout_ms = 3000;
        public string note = "";
        public bool shot = false;      /* tam kare bu adımda da saklansın */
    }

    public class Scenario : Object {
        public string name = "";
        public string title = "";
        public string madde = "";
        public string path = "";
        public string[] allowed = {};  /* bilinen pencere sınıfları */
        private Step[] _steps = {};
        public unowned Step[] get_steps () { return _steps; }
        public string parse_error = "";

        public static Scenario load (string path) {
            var sc = new Scenario ();
            sc.path = path;
            sc.name = Path.get_basename (path).replace (".yaml", "");
            string text;
            try {
                FileUtils.get_contents (path, out text);
            } catch (Error e) {
                sc.parse_error = e.message;
                return sc;
            }
            Step? cur = null;
            bool in_steps = false;
            int lineno = 0;
            foreach (string raw in text.split ("\n")) {
                lineno++;
                string line = strip_comment (raw);
                if (line.strip () == "") {
                    continue;
                }
                int indent = 0;
                while (indent < line.length && line[indent] == ' ') {
                    indent++;
                }
                string body = line.strip ();
                if (indent == 0) {
                    in_steps = false;
                    cur = null;
                    if (body == "steps:") {
                        in_steps = true;
                        continue;
                    }
                    string k, v;
                    if (!split_kv (body, out k, out v)) {
                        sc.parse_error = "satır %d: anahtar bekleniyordu: %s".printf (lineno, body);
                        return sc;
                    }
                    switch (k) {
                    case "name":  sc.name = v; break;
                    case "title": sc.title = v; break;
                    case "madde": sc.madde = v; break;
                    case "allowed": sc.allowed = parse_list (v); break;
                    default:
                        sc.parse_error = "satır %d: bilinmeyen anahtar %s".printf (lineno, k);
                        return sc;
                    }
                    continue;
                }
                if (!in_steps) {
                    sc.parse_error = "satır %d: girintili satır steps dışında".printf (lineno);
                    return sc;
                }
                if (body.has_prefix ("- ")) {
                    cur = new Step ();
                    sc._steps += cur;
                    body = body.substring (2).strip ();
                }
                if (cur == null) {
                    sc.parse_error = "satır %d: adım '- do:' ile başlamalı".printf (lineno);
                    return sc;
                }
                string key, val;
                if (!split_kv (body, out key, out val)) {
                    sc.parse_error = "satır %d: 'anahtar: değer' bekleniyordu".printf (lineno);
                    return sc;
                }
                switch (key) {
                case "do":      cur.action = val; break;
                case "expect":  cur.expect = val; break;
                case "timeout": cur.timeout_ms = int.parse (val); break;
                case "note":    cur.note = val; break;
                case "shot":    cur.shot = (val == "true" || val == "yes"); break;
                default:
                    sc.parse_error = "satır %d: adımda bilinmeyen anahtar %s".printf (lineno, key);
                    return sc;
                }
            }
            if (sc._steps.length == 0 && sc.parse_error == "") {
                sc.parse_error = "adım yok";
            }
            return sc;
        }

        /* "#" outside quotes starts a comment. */
        private static string strip_comment (string line) {
            bool in_q = false;
            var sb = new StringBuilder ();
            for (int i = 0; i < line.length; i++) {
                char c = line[i];
                if (c == '"') {
                    in_q = !in_q;
                }
                if (c == '#' && !in_q) {
                    break;
                }
                sb.append_c (c);
            }
            return sb.str;
        }

        private static bool split_kv (string body, out string key, out string val) {
            key = ""; val = "";
            int i = body.index_of (":");
            if (i <= 0) {
                return false;
            }
            key = body.substring (0, i).strip ();
            val = body.substring (i + 1).strip ();
            if (val.length >= 2 && val[0] == '"' && val[val.length - 1] == '"') {
                val = val.substring (1, val.length - 2);
            }
            return true;
        }

        private static string[] parse_list (string v) {
            string s = v.strip ();
            if (s.has_prefix ("[")) {
                s = s.substring (1);
            }
            if (s.has_suffix ("]")) {
                s = s.substring (0, s.length - 1);
            }
            string[] res = {};
            foreach (string item in s.split (",")) {
                string t = item.strip ();
                if (t != "") {
                    res += t;
                }
            }
            return res;
        }
    }
}
