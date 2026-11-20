# -*- coding: utf-8 -*-
import sys
import os
import time
import subprocess
from pathlib import Path

# Setup colorama for Windows terminal
try:
    import colorama
    from colorama import Fore, Style
    colorama.init(autoreset=True)
    GREEN = Fore.GREEN
    YELLOW = Fore.YELLOW
    CYAN = Fore.CYAN
    RED = Fore.RED
    RESET = Style.RESET_ALL
    BOLD = Style.BRIGHT
except Exception:
    GREEN = YELLOW = CYAN = RED = RESET = BOLD = ""

try:
    import requests
    USE_REQUESTS = True
except Exception:
    import urllib.request
    import json
    USE_REQUESTS = False

REPO_OWNER = "phucvoipa"
REPO_NAME = "phucvn-3105"
API_BASE = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}"
RELEASE_URL = f"https://github.com/{REPO_OWNER}/{REPO_NAME}/releases/download/latest/3105-x-phucvn-unsigned.ipa"
HEADERS = {"User-Agent": "BuildIPATool/1.0"}

def print_banner():
    print(f"{CYAN}{BOLD}=" * 60)
    print(f"{GREEN}{BOLD}       3105 x PHUCVN - TỰ ĐỘNG THEO DÕI & TẢI BUILD IPA")
    print(f"{CYAN}       Kho lưu trữ: https://github.com/{REPO_OWNER}/{REPO_NAME}")
    print(f"{CYAN}{BOLD}=" * 60 + f"{RESET}\n")

def get_latest_run():
    url = f"{API_BASE}/actions/runs?per_page=1"
    try:
        if USE_REQUESTS:
            res = requests.get(url, headers=HEADERS, timeout=10)
            if res.status_code == 200:
                runs = res.json().get("workflow_runs", [])
                if runs:
                    return runs[0]
            elif res.status_code == 403:
                # Rate limit exceeded for unauthenticated IP
                return {"rate_limited": True}
        else:
            req = urllib.request.Request(url, headers=HEADERS)
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                    runs = data.get("workflow_runs", [])
                    if runs:
                        return runs[0]
            except urllib.error.HTTPError as e:
                if e.code == 403:
                    return {"rate_limited": True}
    except Exception as e:
        print(f"{RED}[!] Lỗi khi lấy thông tin build: {e}{RESET}")
    return None

def download_file(url, target_path):
    print(f"{CYAN}[+] Đang tải file IPA từ Release...{RESET}")
    try:
        if USE_REQUESTS:
            res = requests.get(url, headers=HEADERS, stream=True, timeout=30)
            if res.status_code == 200:
                total_size = int(res.headers.get("content-length", 0))
                downloaded = 0
                with open(target_path, "wb") as f:
                    for chunk in res.iter_content(chunk_size=1024 * 64):
                        if chunk:
                            f.write(chunk)
                            downloaded += len(chunk)
                            if total_size > 0:
                                percent = int((downloaded / total_size) * 100)
                                bar = "#" * (percent // 4) + "-" * (25 - (percent // 4))
                                mb_done = downloaded / (1024 * 1024)
                                mb_total = total_size / (1024 * 1024)
                                print(f"\r    [{bar}] {percent}% ({mb_done:.1f}MB / {mb_total:.1f}MB)", end="", flush=True)
                print(f"\n{GREEN}[OK] Tải file IPA thành công!{RESET}")
                return True
            elif res.status_code == 404:
                print(f"\n{YELLOW}[!] Bản Release chưa sẵn sàng, đang chuyển sang link Actions...{RESET}")
                return False
    except Exception as e:
        print(f"\n{RED}[!] Lỗi tải file: {e}{RESET}")
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

    print(f"{YELLOW}[+] Đang kiểm tra tiến trình build trên GitHub Actions...{RESET}")
    last_run = get_latest_run()
    if last_run and last_run.get("rate_limited"):
        print(f"{YELLOW}[!] GitHub API tạm giới hạn lượt truy vấn ẩn danh.{RESET}")
        print(f"{CYAN}[*] Bạn có thể theo dõi trực tiếp trên web: https://github.com/{REPO_OWNER}/{REPO_NAME}/actions{RESET}")
        print(f"{GREEN}[*] Đang thử kiểm tra xem bản Release IPA đã có chưa...{RESET}")
        downloads_dir = Path(os.environ.get("USERPROFILE", ".")) / "Downloads"
        target_ipa = downloads_dir / "3105-x-phucvn-unsigned.ipa"
        if download_file(RELEASE_URL, target_ipa):
            print(f"\n{GREEN}{BOLD}[VỊ TRÍ FILE IPA]: {target_ipa}{RESET}")
            open_folder(target_ipa)
        else:
            import webbrowser
            webbrowser.open(f"https://github.com/{REPO_OWNER}/{REPO_NAME}/actions")
        input("\nNhấn Enter để thoát...")
        return

    if not last_run:
        print(f"{RED}[!] Không tìm thấy lượt build nào. Vui lòng đảm bảo bạn đã push code lên GitHub.{RESET}")
        input("\nNhấn Enter để thoát...")
        return

    run_id = last_run.get("id")
    run_number = last_run.get("run_number")
    html_url = last_run.get("html_url")
    commit_msg = last_run.get("head_commit", {}).get("message", "N/A").strip().split("\n")[0]

    print(f"{BOLD}[*] Lượt chạy: #{run_number} (ID: {run_id})")
    print(f"[*] Commit: {commit_msg}")
    print(f"[*] Đường dẫn: {html_url}{RESET}")
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
            print(f"\n{CYAN}[Trạng thái: {status.upper()}]{RESET} (Thời gian theo dõi: {time_str})")
            last_status = status

        if status == "completed":
            print(f"\n" + "=" * 60)
            if conclusion == "success":
                print(f"{GREEN}{BOLD}>>> CHÚC MỪNG! ĐÃ BUILD THÀNH CÔNG FILE IPA! <<< {RESET}")
                print("=" * 60)

                downloads_dir = Path(os.environ.get("USERPROFILE", ".")) / "Downloads"
                target_ipa = downloads_dir / "3105-x-phucvn-unsigned.ipa"

                success = download_file(RELEASE_URL, target_ipa)
                if success:
                    print(f"\n{GREEN}{BOLD}[VỊ TRÍ FILE IPA]: {target_ipa}{RESET}")
                    open_folder(target_ipa)
                else:
                    print(f"\n{CYAN}[+] Đang mở trang tải về trên trình duyệt: {html_url}{RESET}")
                    import webbrowser
                    webbrowser.open(html_url)
            else:
                print(f"{RED}{BOLD}[!] Quá trình build kết thúc với trạng thái: {conclusion.upper()}{RESET}")
                print(f"{YELLOW}[!] Bạn có thể xem log chi tiết tại: {html_url}{RESET}")
                import webbrowser
                webbrowser.open(html_url)
            break
        elif status == "queued":
            print(f"\r{YELLOW}[Đang xếp hàng chờ máy Mac khả dụng...] Thời gian: {time_str}  {RESET}", end="", flush=True)
        elif status == "in_progress":
            print(f"\r{GREEN}[ĐANG BIÊN DỊCH VÀ ĐÓNG GÓI IPA TRÊN MACOS...] Thời gian: {time_str}  {RESET}", end="", flush=True)
        else:
            print(f"\r[{status}] Thời gian: {time_str}  ", end="", flush=True)

        time.sleep(6)

    print("\n" + "=" * 60)
    input("Nhấn Enter để thoát...")

if __name__ == "__main__":
    main()
