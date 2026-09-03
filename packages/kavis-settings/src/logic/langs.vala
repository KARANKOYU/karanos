/* Language list for Keyboard & Language (madde 34 + Grup F dil seçici
 * kuralları — docs/referans/dil-secici.md).
 *
 * Codes and percentages come from /usr/share/kavis/i18n-stats.json
 * (built at package build time, NEVER computed at runtime). Endonyms
 * are a static table — the point of an endonym is that it does not
 * depend on the current locale.
 */

namespace Kavis.Settings.Langs {

    public struct Lang {
        public string code;
        public string endonym;
        public int percent;
    }

    private const string STATS = "/usr/share/kavis/i18n-stats.json";

    /* glibc locale for a LINGUAS code (B6). Region defaults follow the
     * language's largest/primary glibc locale; codes carrying a region
     * (pt_BR, zh_TW) pass through. */
    public string locale_of (string code) {
        if (code.contains ("_")) {
            return code + ".UTF-8";
        }
        string region;
        switch (code) {
        case "en": region = "US"; break;
        case "ja": region = "JP"; break;
        case "ko": region = "KR"; break;
        case "sv": region = "SE"; break;
        case "da": region = "DK"; break;
        case "cs": region = "CZ"; break;
        case "el": region = "GR"; break;
        case "he": region = "IL"; break;
        case "hi": region = "IN"; break;
        case "bn": region = "BD"; break;
        case "pa": region = "IN"; break;
        case "gu": region = "IN"; break;
        case "mr": region = "IN"; break;
        case "ta": region = "IN"; break;
        case "te": region = "IN"; break;
        case "kn": region = "IN"; break;
        case "ml": region = "IN"; break;
        case "ur": region = "PK"; break;
        case "ne": region = "NP"; break;
        case "si": region = "LK"; break;
        case "ar": region = "SA"; break;
        case "fa": region = "IR"; break;
        case "ku": region = "TR"; break;
        case "ckb": region = "IQ"; break;
        case "uk": region = "UA"; break;
        case "be": region = "BY"; break;
        case "sl": region = "SI"; break;
        case "sr": region = "RS"; break;
        case "bs": region = "BA"; break;
        case "sq": region = "AL"; break;
        case "et": region = "EE"; break;
        case "ca": region = "ES"; break;
        case "gl": region = "ES"; break;
        case "eu": region = "ES"; break;
        case "cy": region = "GB"; break;
        case "ga": region = "IE"; break;
        case "nb": region = "NO"; break;
        case "vi": region = "VN"; break;
        case "th": region = "TH"; break;
        case "ms": region = "MY"; break;
        case "tl": region = "PH"; break;
        case "sw": region = "KE"; break;
        case "am": region = "ET"; break;
        case "zu": region = "ZA"; break;
        case "af": region = "ZA"; break;
        case "az": region = "AZ"; break;
        case "kk": region = "KZ"; break;
        case "ky": region = "KG"; break;
        case "uz": region = "UZ"; break;
        case "tk": region = "TM"; break;
        case "tg": region = "TJ"; break;
        case "hy": region = "AM"; break;
        case "ka": region = "GE"; break;
        case "mn": region = "MN"; break;
        default:   region = code.up (); break;
        }
        return "%s_%s.UTF-8".printf (code, region);
    }

    /* code → endonym for every po/LINGUAS entry. */
    private unowned string endonym_of (string code) {
        switch (code) {
        case "tr":    return "Türkçe";
        case "en_GB": return "English (UK)";
        case "de":    return "Deutsch";
        case "fr":    return "Français";
        case "es":    return "Español";
        case "es_MX": return "Español (México)";
        case "it":    return "Italiano";
        case "pt_PT": return "Português";
        case "pt_BR": return "Português (Brasil)";
        case "nl":    return "Nederlands";
        case "pl":    return "Polski";
        case "cs":    return "Čeština";
        case "sk":    return "Slovenčina";
        case "sl":    return "Slovenščina";
        case "hr":    return "Hrvatski";
        case "bs":    return "Bosanski";
        case "sr":    return "Српски";
        case "mk":    return "Македонски";
        case "sq":    return "Shqip";
        case "bg":    return "Български";
        case "ro":    return "Română";
        case "hu":    return "Magyar";
        case "el":    return "Ελληνικά";
        case "ru":    return "Русский";
        case "uk":    return "Українська";
        case "be":    return "Беларуская";
        case "lt":    return "Lietuvių";
        case "lv":    return "Latviešu";
        case "et":    return "Eesti";
        case "fi":    return "Suomi";
        case "sv":    return "Svenska";
        case "da":    return "Dansk";
        case "nb":    return "Norsk bokmål";
        case "is":    return "Íslenska";
        case "ga":    return "Gaeilge";
        case "cy":    return "Cymraeg";
        case "ca":    return "Català";
        case "gl":    return "Galego";
        case "eu":    return "Euskara";
        case "ar":    return "العربية";
        case "he":    return "עברית";
        case "fa":    return "فارسی";
        case "ku":    return "Kurdî";
        case "ckb":   return "کوردیی ناوەندی";
        case "az":    return "Azərbaycanca";
        case "kk":    return "Қазақша";
        case "ky":    return "Кыргызча";
        case "uz":    return "Oʻzbekcha";
        case "tk":    return "Türkmençe";
        case "tg":    return "Тоҷикӣ";
        case "hy":    return "Հայերեն";
        case "ka":    return "ქართული";
        case "hi":    return "हिन्दी";
        case "ur":    return "اردو";
        case "bn":    return "বাংলা";
        case "pa":    return "ਪੰਜਾਬੀ";
        case "gu":    return "ગુજરાતી";
        case "mr":    return "मराठी";
        case "ta":    return "தமிழ்";
        case "te":    return "తెలుగు";
        case "kn":    return "ಕನ್ನಡ";
        case "ml":    return "മലയാളം";
        case "si":    return "සිංහල";
        case "ne":    return "नेपाली";
        case "zh_CN": return "简体中文";
        case "zh_TW": return "繁體中文";
        case "ja":    return "日本語";
        case "ko":    return "한국어";
        case "th":    return "ไทย";
        case "vi":    return "Tiếng Việt";
        case "id":    return "Bahasa Indonesia";
        case "ms":    return "Bahasa Melayu";
        case "tl":    return "Filipino";
        case "mn":    return "Монгол";
        case "sw":    return "Kiswahili";
        case "am":    return "አማርኛ";
        case "zu":    return "isiZulu";
        case "af":    return "Afrikaans";
        default:      return code;
        }
    }

    /* Selector order (dil-secici.md): 100% first, then percent desc,
     * 0% alphabetical at the end. English (the msgid source) is put on
     * top as a synthetic 100% entry. */
    public Lang[] list () {
        Lang[] result = {};
        Lang english = { "en", "English", 100 };
        result += english;

        string json;
        try {
            FileUtils.get_contents (STATS, out json);
        } catch (Error e) {
            return result;
        }
        /* Satır biçimi sabit (tools/i18n-stats.sh üretir):
         *   "tr": {"translated": 161, "total": 161, "percent": 100},
         * json-glib bağımlılığı yerine satır deseni yeter. */
        Lang[] parsed = {};
        try {
            var re = new Regex (
                "\"([A-Za-z_]+)\": \\{[^}]*\"percent\": ([0-9]+)\\}");
            MatchInfo info;
            re.match (json, 0, out info);
            while (info.matches ()) {
                Lang lang = {
                    info.fetch (1),
                    endonym_of (info.fetch (1)),
                    int.parse (info.fetch (2))
                };
                parsed += lang;
                info.next ();
            }
        } catch (RegexError e) { }

        /* Sıralama: yüzde azalan; eşitse alfabetik (0%'ler doğal
         * olarak sona, alfabetik düşer). 78 öğe için basit araya
         * ekleme yeter — kütüphane sıralaması struct dizisiyle
         * Vala'da sancılı. */
        for (int i = 1; i < parsed.length; i++) {
            Lang key = parsed[i];
            int j = i - 1;
            while (j >= 0
                   && (parsed[j].percent < key.percent
                       || (parsed[j].percent == key.percent
                           && strcmp (parsed[j].code, key.code) > 0))) {
                parsed[j + 1] = parsed[j];
                j--;
            }
            parsed[j + 1] = key;
        }
        foreach (unowned Lang lang in parsed) {
            result += lang;
        }
        return result;
    }
}
