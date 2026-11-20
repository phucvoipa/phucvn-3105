# -*- coding: utf-8 -*-
import sys
import os
import time
import json
import urllib.request
import urllib.error
import subprocess
from pathlib import Path

# Force UTF-8 output
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

REPO_OWNER = "phucvoipa"
REPO_NAME = "phucvn-3105"
API_BASE = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}"
RELEASE_URL = f"https://github.com/{REPO_OWNER}/{REPO_NAME}/releases/download/latest/3105-x-nminhios-unsigned.ipa"
HEADERS = {"User-Agent": "BuildIPATool/1.0"}

def print_banner():
    print("=" * 60)
    print("       CÔNG CỤ TỰ ĐỘNG THEO DÕI & TẢI BUILD IPA (3105)")
    print(f"       Kho lưu trữ: https://github.com/{REPO_OWNER}/{REPO_NAME}")
    print("=" * 60)
    print()

def get_latest_run():
    url = f"{API_BASE}/actions/runs?per_page=1"
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            runs = data.get("workflow_runs", [])
            if runs:
                return runs[0]
    except Exception as e:
        print(f"[!] Lỗi khi lấy thông tin build: {e}")
    return None

def download_file(url, target_path):
    print(f"[+] Đang tải file IPA từ: {url}")
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req) as response:
            total_size = int(response.headers.get("Content-Length", 0))
            downloaded = 0
            block_size = 1024 * 64

            with open(target_path, "wb") as f:
                while True:
                    buffer = response.read(block_size)
                    if not buffer:
                        break
                    downloaded += len(buffer)
                    f.write(buffer)
                    if total_size > 0:
                        percent = int((downloaded / total_size) * 100)
                        bar = "#" * (percent // 4) + "-" * (25 - (percent // 4))
                        mb_done = downloaded / (1024 * 1024)
                        mb_total = total_size / (1024 * 1024)
                        print(f"\r    [{bar}] {percent}% ({mb_done:.1f}MB / {mb_total:.1f}MB)", end="", flush=True)
            print("\n[OK] Tải file hoàn tất!")
            return True
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print("\n[!] Chưa tìm thấy file Release trực tiếp. Sẽ mở trang tải trên trình duyệt...")
        else:
            print(f"\n[!] Lỗi khi tải file: {e}")
    except Exception as e:
        print(f"\n[!] Lỗi: {e}")
    return False

def open_folder(path):
    try:
        if sys.platform == "win32":
            subprocess.run(["explorer", "/select,", str(path)])
        else:
            os.system(f"open '{path.parent}'")
    except Exception:
        pass

def main():
    print_banner()

    print("[+] Đang kiểm tra lượt build mới nhất trên GitHub Actions...")
    last_run = get_latest_run()
    if not last_run:
        print("[!] Không tìm thấy lượt build nào. Vui lòng đảm bảo bạn đã push code lên GitHub.")
        input("\nNhấn Enter để thoát...")
        return

    run_id = last_run.get("id")
    run_number = last_run.get("run_number")
    html_url = last_run.get("html_url")
    commit_msg = last_run.get("head_commit", {}).get("message", "N/A").strip().split("\n")[0]

    print(f"[*] Lượt chạy: #{run_number} (ID: {run_id})")
    print(f"[*] Commit: {commit_msg}")
    print(f"[*] Chi tiết: {html_url}")
    print("-" * 60)

    start_time = time.time()
    last_status = None

    while True:
        run = get_latest_run()
        if not run:
            time.sleep(5)
            continue

        status = run.get("status")
        conclusion = run.get("conclusion")
        elapsed = int(time.time() - start_time)
        mins, secs = divmod(elapsed, 60)
        time_str = f"{mins:02d}:{secs:02d}"

        if status != last_status:
            print(f"\n[Trạng thái mới: {status.upper()}] Lúc: {time_str}")
            last_status = status

        if status == "completed":
            print(f"\n" + "=" * 60)
            if conclusion == "success":
                print(">>> CHÚC MỪNG! BUILD IPA THÀNH CÔNG RỒI! <<<")
                print("=" * 60)

                # Determine target download path
                downloads_dir = Path(os.environ.get("USERPROFILE", ".")) / "Downloads"
                target_ipa = downloads_dir / "3105-x-nminhios-unsigned.ipa"

                # Try to download directly from release
                success = download_file(RELEASE_URL, target_ipa)
                if success:
                    print(f"\n[FILE IPA CỦA BẠN]: {target_ipa}")
                    open_folder(target_ipa)
                else:
                    print(f"\n[+] Mở trang tải về trên trình duyệt: {html_url}")
                    import webbrowser
                    webbrowser.open(html_url)
            else:
                print(f"[!] Build kết thúc với trạng thái: {conclusion.upper()}")
                print(f"[!] Bạn có thể xem chi tiết lỗi tại: {html_url}")
                import webbrowser
                webbrowser.open(html_url)
            break
        elif status == "queued":
            print(f"\r[Đang xếp hàng chờ máy ảo...] Thời gian: {time_str}  ", end="", flush=True)
        elif status == "in_progress":
            print(f"\r[ĐANG BUILD TRÊN MACOS...] Thời gian: {time_str}  ", end="", flush=True)
        else:
            print(f"\r[{status}] Thời gian: {time_str}  ", end="", flush=True)

        time.sleep(6)

    print("\n" + "=" * 60)
    input("Nhấn Enter để hoàn tất...")

if __name__ == "__main__":
    main()
