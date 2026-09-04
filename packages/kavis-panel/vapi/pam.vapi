/* Minimal binding for Linux-PAM (the lock screen, item 70).
 *
 * A lock screen has to ask PAM whether a password is right — that is
 * what every locker does, and it is the only way the answer respects
 * the system's own rules (account expiry, faillock, a fingerprint
 * module, a smartcard). Checking /etc/shadow by hand would ignore all
 * of it and need to run as root besides.
 *
 * Debian ships no vapi for libpam, and this is the whole surface we
 * need: start a transaction, authenticate, end it. The conversation
 * callback is the fiddly part — PAM hands it an array of message
 * pointers and expects an allocated array of responses back, which it
 * then frees itself, so the response strings must come from the C
 * allocator and not from Vala's string ownership.
 *
 * Link with -lpam (packages/kavis-panel/debian/rules).
 */

[CCode (cheader_filename = "security/pam_appl.h")]
namespace Pam {

	[CCode (cname = "PAM_SUCCESS")]
	public const int SUCCESS;
	[CCode (cname = "PAM_PROMPT_ECHO_OFF")]
	public const int PROMPT_ECHO_OFF;
	[CCode (cname = "PAM_PROMPT_ECHO_ON")]
	public const int PROMPT_ECHO_ON;
	[CCode (cname = "PAM_ERROR_MSG")]
	public const int ERROR_MSG;
	[CCode (cname = "PAM_TEXT_INFO")]
	public const int TEXT_INFO;
	[CCode (cname = "PAM_DISALLOW_NULL_AUTHTOK")]
	public const int DISALLOW_NULL_AUTHTOK;

	[CCode (cname = "struct pam_message", has_type_id = false)]
	public struct Message {
		public int msg_style;
		public unowned string msg;
	}

	[CCode (cname = "struct pam_response", has_type_id = false)]
	public struct Response {
		public char* resp;
		public int resp_retcode;
	}

	/* No cname: C has no name for this function type (pam_conv
	 * declares it inline), so valac emits its own typedef. */
	[CCode (has_target = false)]
	public delegate int ConvFunc (int num_msg,
	                              [CCode (array_length = false)] Message** msg,
	                              out Response* resp, void* appdata);

	[CCode (cname = "struct pam_conv", has_type_id = false)]
	public struct Conv {
		public ConvFunc conv;
		public void* appdata_ptr;
	}

	[CCode (cname = "pam_handle_t", free_function = "", has_type_id = false)]
	[Compact]
	public class Handle {
	}

	[CCode (cname = "pam_start")]
	public int start (string service, string? user, ref Conv conv,
	                  out unowned Handle handle);

	[CCode (cname = "pam_authenticate")]
	public int authenticate (Handle handle, int flags);

	[CCode (cname = "pam_end")]
	public int end (Handle handle, int status);

	[CCode (cname = "pam_strerror")]
	public unowned string strerror (Handle handle, int errnum);
}
