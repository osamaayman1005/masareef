"""Customizes the android/ folder that `flutter create` generates in CI.

The android/ folder is not committed: it is regenerated on every build so
it always matches the installed Flutter version. This script adds what the
app needs on top: the SMS reader, the SMS permission, the name and the icon.
It also refuses to build if the application id ever changes, because a new
id installs as a different app and the old data would be left behind.
"""

from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android" / "app"
EXPECTED_APP_ID = "app.masareef"


def fail(message: str) -> None:
    print(f"overlay: {message}", file=sys.stderr)
    sys.exit(1)


def check_application_id() -> None:
    gradle = next(
        (p for p in (ANDROID / "build.gradle.kts", ANDROID / "build.gradle") if p.exists()),
        None,
    )
    if gradle is None:
        fail("no app build.gradle found")
    match = re.search(r'applicationId\s*=?\s*"([^"]+)"', gradle.read_text())
    if match is None or match.group(1) != EXPECTED_APP_ID:
        found = match.group(1) if match else "none"
        fail(f"applicationId is {found}, expected {EXPECTED_APP_ID}. Updates would lose data.")


def install_main_activity() -> None:
    generated = list((ANDROID / "src" / "main").rglob("MainActivity.*"))
    if len(generated) != 1:
        fail(f"expected one generated MainActivity, found {len(generated)}")
    original = generated[0]
    package = re.search(r"^package\s+([\w.]+)", original.read_text(), re.M)
    if package is None:
        fail("could not read the MainActivity package")
    template = (ROOT / "ci" / "android" / "MainActivity.kt").read_text()
    original.unlink()
    original.with_suffix(".kt").write_text(template.replace("PACKAGE_NAME", package.group(1)))


def patch_manifest() -> None:
    manifest = ANDROID / "src" / "main" / "AndroidManifest.xml"
    text = manifest.read_text()
    permission = '<uses-permission android:name="android.permission.READ_SMS" />'
    if permission not in text:
        text = text.replace("<application", f"{permission}\n    <application", 1)
    text = re.sub(r'android:label="[^"]*"', 'android:label="Masareef"', text, count=1)
    manifest.write_text(text)


def install_icon() -> None:
    source = ROOT / "ci" / "android" / "res"
    target = ANDROID / "src" / "main" / "res"
    for file in source.rglob("*"):
        if file.is_file():
            destination = target / file.relative_to(source)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(file, destination)


if __name__ == "__main__":
    check_application_id()
    install_main_activity()
    patch_manifest()
    install_icon()
    print("overlay: android project customized")
