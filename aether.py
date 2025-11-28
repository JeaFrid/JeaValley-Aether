"""
JeaTunnel istemcisi.
- Kaydol / giriş yap
- Port tünellemesini başlat / durdur
- Durumu görüntüle

Varsayılan sunucu: http://127.0.0.1:8000
"""
import argparse
import json
import os
import sys
from dataclasses import dataclass
from getpass import getpass
from pathlib import Path
from typing import Any, Dict, Optional

import requests

DEFAULT_SERVER = os.getenv("JEATUNNEL_SERVER", "http://127.0.0.1:8000")
CONFIG_PATH = Path(os.getenv("JEATUNNEL_CONFIG", Path.home() / ".jeatunnel.json"))


@dataclass
class Session:
    base_url: str = DEFAULT_SERVER
    token: Optional[str] = None
    user_id: Optional[str] = None
    username: Optional[str] = None
    share_url: Optional[str] = None
    plan: Optional[str] = None


def load_session() -> Session:
    if CONFIG_PATH.exists():
        try:
            data = json.loads(CONFIG_PATH.read_text())
            return Session(**data)
        except Exception:
            pass
    return Session()


def save_session(session: Session):
    CONFIG_PATH.write_text(json.dumps(session.__dict__, indent=2))


def api_request(
    session: Session,
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    url = session.base_url.rstrip("/") + path
    headers = {}
    if session.token:
        headers["Authorization"] = f"Bearer {session.token}"
    resp = requests.request(method, url, json=payload, headers=headers, timeout=20)
    if resp.status_code >= 400:
        try:
            detail = resp.json().get("detail") or resp.json().get("error")
        except Exception:
            detail = resp.text
        raise SystemExit(f"[{resp.status_code}] {detail}")
    return resp.json()


def do_register(session: Session, args):
    username = args.username or input("Kullanıcı adı: ").strip()
    password = args.password or getpass("Şifre: ")
    plan = (args.plan or input("Plan (premium/elite/premium_plus/founder): ") or "premium").strip()
    data = api_request(
        session, "POST", "/register", {"username": username, "password": password, "plan": plan}
    )
    session.token = data["token"]
    session.user_id = data["user_id"]
    session.username = data["username"]
    session.share_url = data["share_url"]
    session.plan = data["plan"]
    save_session(session)
    print(f"Giriş yapıldı. UID: {session.user_id} | Plan: {session.plan}")
    print(f"Paylaşılacak VPS linki: {session.share_url}")


def do_login(session: Session, args):
    username = args.username or input("Kullanıcı adı: ").strip()
    password = args.password or getpass("Şifre: ")
    data = api_request(session, "POST", "/login", {"username": username, "password": password})
    session.token = data["token"]
    session.user_id = data["user_id"]
    session.username = data["username"]
    session.share_url = data["share_url"]
    session.plan = data["plan"]
    save_session(session)
    print(f"Giriş başarılı. UID: {session.user_id}")
    print(f"Paylaşılacak VPS linki: {session.share_url}")


def do_run(session: Session, args):
    if not session.token:
        raise SystemExit("Önce giriş yapmalısın.")
    port = args.port or int(input("Tünellenecek port: ").strip())
    data = api_request(session, "POST", "/tunnel/start", {"port": port})
    print(f"Tünel durum: {data['status']} | Port: {data['port']}")
    print(f"Paylaşılacak VPS linki: {data['share_url']}")


def do_stop(session: Session, _args):
    if not session.token:
        raise SystemExit("Önce giriş yapmalısın.")
    data = api_request(session, "POST", "/tunnel/stop")
    print(f"Tünel durduruldu. Toplam istek: {data['request_count']}")


def do_status(session: Session, _args):
    if not session.token:
        raise SystemExit("Önce giriş yapmalısın.")
    data = api_request(session, "GET", "/tunnel/status")
    print(f"Durum: {data['status']} | Port: {data.get('port')}")
    print(f"İstek sayısı: {data['request_count']} | Plan: {data.get('plan')}")
    if data.get("last_error"):
        print(f"Son hata: {data['last_error']}")
    if data.get("share_url"):
        print(f"Paylaşılacak VPS linki: {data['share_url']}")


def do_show(session: Session, _args):
    if not session.user_id:
        print("Kayıtlı oturum yok.")
        return
    print(f"Kullanıcı: {session.username} | UID: {session.user_id} | Plan: {session.plan}")
    if session.share_url:
        print(f"Paylaşılacak VPS linki: {session.share_url}")
    print(f"Sunucu: {session.base_url}")


def do_config(session: Session, args):
    if args.server:
        session.base_url = args.server.rstrip("/")
        save_session(session)
        print(f"Sunucu adresi kaydedildi: {session.base_url}")
    else:
        print(f"Şu anki sunucu: {session.base_url}")


def interactive_menu(session: Session):
    actions = {
        "1": ("Kayıt ol", lambda: do_register(session, argparse.Namespace(username=None, password=None, plan=None))),
        "2": ("Giriş yap", lambda: do_login(session, argparse.Namespace(username=None, password=None))),
        "3": ("Tünel başlat", lambda: do_run(session, argparse.Namespace(port=None))),
        "4": ("Tünel durdur", lambda: do_stop(session, None)),
        "5": ("Durumu göster", lambda: do_status(session, None)),
        "6": ("Oturum bilgisi", lambda: do_show(session, None)),
        "0": ("Çık", lambda: sys.exit(0)),
    }
    while True:
        print("\nJeaTunnel Menü")
        for key, (label, _) in actions.items():
            print(f" {key}) {label}")
        choice = input("Seçim: ").strip()
        action = actions.get(choice)
        if not action:
            print("Geçersiz seçim.")
            continue
        try:
            action[1]()
        except SystemExit as exc:
            raise exc
        except Exception as exc:  # pragma: no cover - etkileşimsel hata
            print(f"Hata: {exc}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="JeaTunnel istemcisi")
    sub = parser.add_subparsers(dest="command")

    reg = sub.add_parser("register", help="Yeni hesap oluştur")
    reg.add_argument("--username")
    reg.add_argument("--password")
    reg.add_argument("--plan")

    log = sub.add_parser("login", help="Giriş yap")
    log.add_argument("--username")
    log.add_argument("--password")

    run = sub.add_parser("run", help="Tünel başlat")
    run.add_argument("port", type=int, nargs="?")

    sub.add_parser("stop", help="Tüneli durdur")
    sub.add_parser("status", help="Tünel durumunu göster")
    sub.add_parser("whoami", help="Kayıtlı oturumu göster")

    cfg = sub.add_parser("config", help="Sunucu adresi ayarla")
    cfg.add_argument("--server", help="Örn: http://127.0.0.1:8000")

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    session = load_session()

    commands = {
        "register": do_register,
        "login": do_login,
        "run": do_run,
        "stop": do_stop,
        "status": do_status,
        "whoami": do_show,
        "config": do_config,
    }

    if not args.command:
        interactive_menu(session)
        return

    handler = commands.get(args.command)
    if not handler:
        parser.print_help()
        return

    handler(session, args)


if __name__ == "__main__":
    main()
