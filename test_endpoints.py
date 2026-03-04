#!/usr/bin/env python3
"""
test_endpoints.py — smoke test de lectura de todos los endpoints del skill.

INSTRUCCIONES PARA RELLENAR ESTE FICHERO
=========================================

1. ENV FILE
   Lee las credenciales del fichero ../<skill-name>.env (un nivel arriba del skill).
   Usa la misma función load_env() que el cliente del skill.
   Ejemplo:
       SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
       ENV_FILE   = os.path.join(os.path.dirname(SCRIPT_DIR), "<skill-name>.env")

2. CLIENTE
   Instancia el cliente principal del skill (el equivalente a HoldedClient, etc.):
       sys.path.insert(0, os.path.join(SCRIPT_DIR, "scripts"))
       from <skill>_client import <Skill>Client
       client = <Skill>Client(...)

3. SOLO LECTURA — BLOQUEA ESCRITURAS
   Sustituye los métodos de escritura del cliente por un guard que lance RuntimeError,
   para garantizar que este script nunca modifica datos:
       def _no_write(*args, **kwargs):
           raise RuntimeError("BLOCKED: test_endpoints.py es read-only")
       client.post   = _no_write
       client.put    = _no_write
       client.patch  = _no_write
       client.delete = _no_write

4. SECCIONES DE TEST
   Por cada módulo/recurso del skill, añade una sección con section() + run():
       section("NOMBRE DEL RECURSO — /ruta/del/endpoint")
       run("recurso.list()",   lambda: list_items(client))
       run("recurso.search()", lambda: search_items(client, "a", limit=3))
       run("recurso.get(id)",  lambda: get_item(client, first_id))

5. HELPER: PRIMERO busca el primer ID
   Para probar get(), haz primero un list() y extrae el ID del primer elemento:
       try:
           items = list_items(client)
           if items:
               first_id = items[0]["id"]
               run(f"item.get({first_id[:8]}...)", lambda: get_item(client, first_id))
       except Exception:
           pass

6. SALIDA SIN DATOS PERSONALES
   Usa la función _mask() (incluida abajo) para que el output muestre estructura
   de campos sin exponer valores reales (nombres, emails, importes, etc.).

EJECUCIÓN
=========
    python test_endpoints.py              # usa el primer alias/credencial del .env
    python test_endpoints.py ALIAS        # alias concreto (si el skill es multi-instancia)

DEPENDENCIAS
============
Solo stdlib + los propios scripts del skill. No requiere pytest ni librerías externas.
"""

import sys
import os
import json


# ── locate env file ────────────────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE   = os.path.join(os.path.dirname(SCRIPT_DIR), "<skill-name>.env")   # AJUSTA


# ── load env ───────────────────────────────────────────────────────────────────
def load_env(path):
    env = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    return env


# ── output helpers ─────────────────────────────────────────────────────────────
GREEN  = "\033[92m"
RED    = "\033[91m"
YELLOW = "\033[93m"
RESET  = "\033[0m"
BOLD   = "\033[1m"


def _mask(value):
    """Reemplaza valores reales por placeholders de tipo — sin datos personales en el output."""
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return "<num>"
    if isinstance(value, str):
        return "<str>" if value else ""
    if isinstance(value, list):
        return f"[{len(value)} items]"
    if isinstance(value, dict):
        return f"{{...{len(value)} keys}}"
    return "<value>"


def ok(label, data):
    if isinstance(data, list):
        count  = len(data)
        sample = data[0] if data else {}
        print(f"  {GREEN}OK{RESET} {label}: {count} item(s)")
        if sample:
            keys   = list(sample.keys())
            masked = {k: _mask(sample[k]) for k in keys[:8]}
            print(f"    fields: {json.dumps(masked, ensure_ascii=False)}")
    elif isinstance(data, dict):
        if "error" in data:
            fail(label, data.get("error", "unknown error"))
            return
        keys   = list(data.keys())
        masked = {k: _mask(data[k]) for k in keys[:8]}
        print(f"  {GREEN}OK{RESET} {label}: dict con {len(data)} keys")
        print(f"    fields: {json.dumps(masked, ensure_ascii=False)}")
    else:
        print(f"  {YELLOW}??{RESET} {label}: tipo inesperado {type(data).__name__}")


def fail(label, err):
    print(f"  {RED}FAIL{RESET} {label}: {err}")


def section(title):
    print(f"\n{BOLD}{'-'*60}{RESET}")
    print(f"{BOLD}  {title}{RESET}")
    print(f"{BOLD}{'-'*60}{RESET}")


def run(label, fn):
    try:
        result = fn()
        ok(label, result)
    except Exception as e:
        fail(label, str(e)[:200])


# ── main ───────────────────────────────────────────────────────────────────────
def main():
    if not os.path.exists(ENV_FILE):
        print(f"ERROR: env file not found: {ENV_FILE}")
        sys.exit(1)

    env = load_env(ENV_FILE)
    for k, v in env.items():
        os.environ.setdefault(k, v)

    print(f"\n{BOLD}<skill-name> endpoint smoke test{RESET}")   # AJUSTA
    print(f"Env file : {ENV_FILE}")

    sys.path.insert(0, os.path.join(SCRIPT_DIR, "scripts"))

    # ── instancia el cliente ────────────────────────────────────────────────
    # from <skill>_client import <Skill>Client
    # client = <Skill>Client(...)

    # ── bloquea escrituras ──────────────────────────────────────────────────
    # def _no_write(*args, **kwargs):
    #     raise RuntimeError("BLOCKED: test_endpoints.py es read-only")
    # client.post   = _no_write
    # client.put    = _no_write
    # client.patch  = _no_write
    # client.delete = _no_write

    # ── secciones de test ───────────────────────────────────────────────────
    # section("RECURSO A  /ruta/endpoint")
    # from modulo import list_items
    # run("items.list()", lambda: list_items(client))

    print(f"\n{BOLD}Done.{RESET}\n")


if __name__ == "__main__":
    main()
