#!/usr/bin/env python3
"""android/app/build.gradle(.kts) dosyasini idempotent sekilde yamalar.

  desugar  -> flutter_local_notifications icin core library desugaring
  signing  -> android/key.properties ile release imzalama (secret varsa)
"""
import os
import re
import sys

DESUGAR_LIB = "com.android.tools:desugar_jdk_libs:2.1.4"


def find_gradle():
    for name in ("build.gradle.kts", "build.gradle"):
        path = os.path.join("android", "app", name)
        if os.path.exists(path):
            return path, name.endswith(".kts")
    sys.exit("android/app/build.gradle(.kts) bulunamadi")


def desugar(text, kts):
    if "coreLibraryDesugaring" in text or "CoreLibraryDesugaring" in text:
        return text
    flag = ("isCoreLibraryDesugaringEnabled = true" if kts
            else "coreLibraryDesugaringEnabled true")
    if "compileOptions {" in text:
        text = re.sub(r"(compileOptions\s*\{)", r"\1\n        " + flag, text, count=1)
    else:
        text = re.sub(r"(\nandroid\s*\{)", r"\1\n    compileOptions {\n        " + flag + "\n    }", text, count=1)
    dep = (f'    coreLibraryDesugaring("{DESUGAR_LIB}")' if kts
           else f"    coreLibraryDesugaring '{DESUGAR_LIB}'")
    block = "\ndependencies {\n" + dep + "\n}\n"
    if re.search(r"^dependencies\s*\{", text, re.M):
        text = re.sub(r"(^dependencies\s*\{)", r"\1\n" + dep, text, count=1, flags=re.M)
    else:
        text = text.rstrip("\n") + "\n" + block
    return text


def signing(text, kts):
    if 'getByName("release")' in text or "signingConfigs.release" in text:
        return text
    if kts:
        cfg = '''
    signingConfigs {
        create("release") {
            val ksProps = java.util.Properties()
            ksProps.load(java.io.FileInputStream(rootProject.file("key.properties")))
            keyAlias = ksProps["keyAlias"] as String
            keyPassword = ksProps["keyPassword"] as String
            storeFile = file(ksProps["storeFile"] as String)
            storePassword = ksProps["storePassword"] as String
        }
    }
'''
        text = re.sub(r"(^android\s*\{)", r"\1" + cfg, text, count=1, flags=re.M)
        text = text.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
    else:
        cfg = '''
    signingConfigs {
        release {
            def ksProps = new Properties()
            ksProps.load(new FileInputStream(rootProject.file("key.properties")))
            keyAlias ksProps['keyAlias']
            keyPassword ksProps['keyPassword']
            storeFile file(ksProps['storeFile'])
            storePassword ksProps['storePassword']
        }
    }
'''
        text = re.sub(r"(^android\s*\{)", r"\1" + cfg, text, count=1, flags=re.M)
        text = text.replace("signingConfigs.debug", "signingConfigs.release")
    return text


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("desugar", "signing"):
        sys.exit(__doc__)
    path, kts = find_gradle()
    original = open(path, encoding="utf-8").read()
    patched = (desugar if sys.argv[1] == "desugar" else signing)(original, kts)
    if patched != original:
        open(path, "w", encoding="utf-8").write(patched)
        print(f"{sys.argv[1]}: {path} yamalandi")
    else:
        print(f"{sys.argv[1]}: {path} zaten hazir")


if __name__ == "__main__":
    main()
