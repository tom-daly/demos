"""Azure Functions entry points. Three of them.

  POST /api/webhook   SharePoint (via Graph) says "something changed" -> queue a scan   (anonymous; clientState checked)
  queue  documents    scan: walk the delta and queue each new file · file: process one   (the worker)
  timer  housekeeping every 15 min: keep exactly one live subscription, queue a catch-up scan,
                      delete expired table rows
"""
from __future__ import annotations

import json
import logging

import azure.functions as func

from pipeline import graph, process, state, storage
from pipeline.config import settings

log = logging.getLogger("pipeline")
app = func.FunctionApp()

# The Azure SDKs log every HTTP request at Information. That buries our own lines, so keep them to warnings.
for noisy in ("azure", "azure.core.pipeline.policies.http_logging_policy", "azure.identity", "urllib3", "httpx", "httpcore", "openai"):
    logging.getLogger(noisy).setLevel(logging.WARNING)


@app.route(route="webhook", methods=["POST"], auth_level=func.AuthLevel.ANONYMOUS)
def webhook(req: func.HttpRequest) -> func.HttpResponse:
    # Step 1 of a subscription: Graph calls with ?validationToken= and wants it echoed back within 10 s.
    token = req.params.get("validationToken")
    if token:
        return func.HttpResponse(token, status_code=200, mimetype="text/plain")

    # Step 2, forever after: a small JSON saying "something changed". Verify it is ours, then queue a scan.
    # No work happens here; answering fast is what keeps the subscription alive.
    try:
        body = req.get_json()
    except ValueError:
        return func.HttpResponse("bad json", status_code=400)
    ours = [n for n in body.get("value", []) if n.get("clientState") == settings().webhook_client_state]
    if not ours:
        log.warning("webhook: %s notification(s) with wrong clientState ignored", len(body.get("value", [])))
        return func.HttpResponse(status_code=202)
    storage.enqueue({"kind": "scan", "reason": "notification", "subscriptions": [n.get("subscriptionId") for n in ours]})
    return func.HttpResponse(status_code=202)


@app.queue_trigger(arg_name="msg", queue_name="%STORAGE_QUEUE_NAME%", connection="AzureWebJobsStorage")
def worker(msg: func.QueueMessage) -> None:
    body = json.loads((msg.get_body() or b"{}").decode("utf-8"))
    kind = body.get("kind")
    log.info("worker: %s %s (delivery %s, message %s)", kind, body.get("name") or body.get("reason", ""), msg.dequeue_count, msg.id)
    if kind == "scan":
        process.scan(reason=body.get("reason", ""))
    elif kind == "file":
        process.process_file(body, delivery=msg.dequeue_count or 0)
    else:
        log.error("worker: unknown message kind %r", kind)


@app.timer_trigger(arg_name="timer", schedule="0 */15 * * * *", run_on_startup=True)
def housekeeping(timer: func.TimerRequest) -> None:
    # Every 15 minutes: cheap (one Graph GET, one delta walk), and on Flex Consumption "run on startup"
    # does not fire by itself after a deploy, so a short schedule is what actually gets things going.
    # 1. Exactly one live subscription, renewed before it lapses. Notifications expire quietly otherwise.
    sub = graph.ensure_subscription()
    log.info("housekeeping: subscription %s until %s", sub.get("SubscriptionId"), sub.get("ExpiresAt"))
    # 2. The logging list exists from the first run on, so an empty list is visible proof the app is alive.
    log.info("housekeeping: logging list %s", graph.log_list_id())
    # 3. A catch-up scan, so a missed notification costs at most fifteen minutes.
    storage.enqueue({"kind": "scan", "reason": "timer"})
    # 4. Table rows have no TTL of their own; this is it.
    log.info("housekeeping: sweep %s", state.sweep())
