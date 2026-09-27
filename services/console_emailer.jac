"""Development email sender: instead of sending, writes each email (with its
verification / reset link) to the server log. Used until real SMTP settings
are configured — see [plugins.scale.emailer] in jac.toml and .env.example."""

import logging;
import from jac_scale.abstractions.emailer { Emailer }

glob logger = logging.getLogger("along.email");

obj ConsoleEmailer(Emailer) {
    override def send_email(
        to_addr: str, subject: str, body_text: str,
        body_html: str | None = None, from_addr: str | None = None
    ) -> bool {
        lines = [f"[email] To: {to_addr}", f"[email] Subject: {subject}"] + ["[email] " + l for l in body_text.splitlines()];
        # WARNING level so it always shows in the dev server log.
        logger.warning("\n" + "\n".join(lines));
        return True;
    }

    override def is_ready -> bool {
        return True;
    }
}
