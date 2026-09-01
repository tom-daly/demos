/**
 * Sending mail from an Azure Function as one named mailbox.
 *
 * There is no password, no client secret and no connection string here. The
 * Function App has an identity of its own in the tenant, and that identity has
 * been given permission to send as exactly one mailbox - see the two PowerShell
 * scripts alongside this file.
 *
 * The mailbox address is a normal app setting (EMAIL_FROM_MAILBOX). It is the
 * only thing that changes between environments.
 */
import { DefaultAzureCredential } from '@azure/identity';

const GRAPH_BASE_URL = 'https://graph.microsoft.com/v1.0';
const GRAPH_SCOPE = 'https://graph.microsoft.com/.default';

/**
 * How long one send may take before we give up on it.
 *
 * Graph answers a send in well under a second. A request still going after this
 * is a network that has stopped answering rather than a slow send, and without a
 * limit the whole invocation waits on it.
 */
const SEND_TIMEOUT_MS = 30_000;

export interface EmailMessage {
  to: string[];
  subject: string;
  html: string;
  replyTo?: string;
}

export interface SendOutcome {
  status: 'sent' | 'skipped' | 'failed';
  /** Why, when it was skipped or failed. Written to the log, never to a person. */
  reason?: string;
  /** What Graph answered, when it answered at all. Absent if nothing came back. */
  httpStatus?: number;
}

/**
 * The token, borrowed from the Function App's own identity.
 *
 * Held across warm invocations: the credential caches the token it fetched and
 * renews it before it expires, so a busy queue costs one token rather than one
 * per message. Built on first use rather than at module load, so a deployment
 * without the setting still starts.
 */
let credential: DefaultAzureCredential | null = null;

const tokenFor = async (): Promise<string> => {
  credential ??= new DefaultAzureCredential();
  const token = await credential.getToken(GRAPH_SCOPE);
  if (!token) throw new Error('no token came back for Microsoft Graph');
  return token.token;
};

/**
 * Sends one message, and says what happened.
 *
 * **Never throws.** The caller is the one place that decides whether a failure
 * is worth trying again, and it needs the reason to do it. An exception thrown
 * from here would take that decision away.
 */
export async function sendEmail(message: EmailMessage): Promise<SendOutcome> {
  const mailbox = process.env.EMAIL_FROM_MAILBOX?.trim() ?? '';
  if (mailbox === '') {
    return { status: 'skipped', reason: 'EMAIL_FROM_MAILBOX is not set' };
  }

  try {
    const token = await tokenFor();
    const response = await fetch(
      `${GRAPH_BASE_URL}/users/${encodeURIComponent(mailbox)}/sendMail`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            subject: message.subject,
            body: { contentType: 'HTML', content: message.html },
            toRecipients: message.to.map((address) => ({ emailAddress: { address } })),
            ...(message.replyTo
              ? { replyTo: [{ emailAddress: { address: message.replyTo } }] }
              : {}),
          },
          /**
           * Not filed in Sent Items. The mailbox is the app's, not a person's,
           * and a copy of every notification ever sent piling up in it is a
           * mailbox somebody has to empty. What was sent is in the log, which is
           * where it is actually looked for.
           */
          saveToSentItems: false,
        }),
        signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
      }
    );

    if (response.ok) return { status: 'sent' };

    // Graph explains a refusal in the body, and that explanation is the whole of
    // what makes a permission problem tell itself apart from a bad address.
    const said = await response.text().catch(() => '');
    return {
      status: 'failed',
      httpStatus: response.status,
      reason: `Graph answered ${response.status}${said ? `: ${said.slice(0, 500)}` : ''}`,
    };
  } catch (err) {
    return { status: 'failed', reason: err instanceof Error ? err.message : String(err) };
  }
}
