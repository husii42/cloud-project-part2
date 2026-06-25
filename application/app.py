"""
Cloud & DevOps Engineering – Part II
Aalen University

Flask web application that:
  - Web Page 1 ("/"):       lists all blobs in the Storage Account's container,
                             with a download link for each, and a link to Page 2.
  - Web Page 2 ("/upload"): an upload form for files / images.

Authentication to Azure Storage uses DefaultAzureCredential, which means:
  - Locally:        falls back to `az login` (Azure CLI credential) or
                     environment variables, whichever is available.
  - On App Service: automatically uses the Web App's System-Assigned
                     Managed Identity – no connection string, no access key,
                     no secret anywhere in this code or in App Settings.

This is the secret-less pattern that Part I's Key Vault module was a
stepping stone towards: the Storage Account connection string still gets
written to Key Vault (for completeness / manual debugging), but the running
application never reads it.
"""

import logging
import os
from datetime import datetime, timedelta, timezone

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from flask import Flask, flash, redirect, render_template, request, url_for
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.secret_key = os.environ.get("FLASK_SECRET_KEY", os.urandom(24))

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ── Configuration (from App Settings / environment variables) ──────────────
STORAGE_ACCOUNT_NAME = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME")
CONTAINER_NAME = os.environ.get("AZURE_STORAGE_CONTAINER_NAME", "images")
KEY_VAULT_URI = os.environ.get("KEY_VAULT_URI")  # not used at runtime today, kept for future secrets

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp", "txt", "pdf"}
MAX_CONTENT_LENGTH = 25 * 1024 * 1024  # 25 MB upload limit
app.config["MAX_CONTENT_LENGTH"] = MAX_CONTENT_LENGTH

# ── Azure clients (created once, reused across requests) ───────────────────
_credential = DefaultAzureCredential()
_blob_service_client = None


def get_blob_service_client() -> BlobServiceClient:
    """Lazily create the BlobServiceClient. Lazy so the app can still start
    and report a clear error on the page if AZURE_STORAGE_ACCOUNT_NAME is
    missing, instead of crashing at import time."""
    global _blob_service_client
    if _blob_service_client is None:
        if not STORAGE_ACCOUNT_NAME:
            raise RuntimeError(
                "AZURE_STORAGE_ACCOUNT_NAME is not set. Check the App Service "
                "Application Settings (set by Terraform via modules/appservice)."
            )
        account_url = f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
        _blob_service_client = BlobServiceClient(account_url=account_url, credential=_credential)
    return _blob_service_client


def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


# ── Web Page 1: list all blobs with download links ──────────────────────────
@app.route("/")
def index():
    blobs = []
    error = None
    try:
        container_client = get_blob_service_client().get_container_client(CONTAINER_NAME)
        for blob in container_client.list_blobs():
            blobs.append(
                {
                    "name": blob.name,
                    "size_kb": round((blob.size or 0) / 1024, 1),
                    "last_modified": blob.last_modified.strftime("%Y-%m-%d %H:%M") if blob.last_modified else "-",
                    "url": f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net/{CONTAINER_NAME}/{blob.name}",
                }
            )
        blobs.sort(key=lambda b: b["last_modified"], reverse=True)
    except RuntimeError as exc:
        error = str(exc)
    except Exception as exc:  # noqa: BLE001 - show a friendly message instead of a 500 page
        logger.exception("Failed to list blobs")
        error = f"Could not reach Azure Storage: {exc}"

    return render_template("index.html", blobs=blobs, error=error, container_name=CONTAINER_NAME)


# ── Web Page 2: upload form ─────────────────────────────────────────────────
@app.route("/upload", methods=["GET", "POST"])
def upload():
    if request.method == "POST":
        file = request.files.get("file")

        if file is None or file.filename == "":
            flash("Please choose a file before uploading.", "error")
            return redirect(url_for("upload"))

        if not allowed_file(file.filename):
            flash(
                f"File type not allowed. Allowed types: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
                "error",
            )
            return redirect(url_for("upload"))

        filename = secure_filename(file.filename)
        # Prefix with a timestamp so concurrent/duplicate uploads don't overwrite each other.
        blob_name = f"{datetime.now(timezone.utc):%Y%m%d-%H%M%S}-{filename}"

        try:
            container_client = get_blob_service_client().get_container_client(CONTAINER_NAME)
            container_client.upload_blob(name=blob_name, data=file.stream, overwrite=False)
            flash(f"Uploaded '{filename}' successfully.", "success")
            return redirect(url_for("index"))
        except RuntimeError as exc:
            flash(str(exc), "error")
        except Exception as exc:  # noqa: BLE001
            logger.exception("Failed to upload blob")
            flash(f"Upload failed: {exc}", "error")

        return redirect(url_for("upload"))

    return render_template("upload.html")


# ── Health check – used by the deployment pipeline to confirm the app is live ──
@app.route("/healthz")
def healthz():
    return {"status": "ok"}, 200


if __name__ == "__main__":
    # Local development entrypoint. In Azure App Service, gunicorn (see
    # modules/appservice's app_command_line) serves the app instead of this.
    app.run(host="0.0.0.0", port=8000, debug=True)
