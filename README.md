# 3105 x nminhios

Phiên bản tùy biến của **ThreeOneOSFive (3105)** dành cho iOS.

## Tự động Build IPA trên GitHub Actions

Dự án đã được tích hợp sẵn GitHub Actions workflow tại `.github/workflows/build.yml`.

### Cách kích hoạt build:
1. Khi push mã nguồn lên nhánh `main` hoặc `master`, GitHub Actions sẽ tự động kích hoạt tiến trình build.
2. Hoặc bạn có thể kích hoạt thủ công trong mục **Actions** -> Chọn workflow **Build 3105 IPA** -> Nhấn **Run workflow**.

### Tải file IPA sau khi build:
1. Vào tab **Actions** trên GitHub repository.
2. Bấm vào lượt chạy workflow mới nhất.
3. Cuộn xuống phần **Artifacts** ở cuối trang.
4. Tải về file `3105-unsigned-ipa.zip`, giải nén ra sẽ có file `3105-x-nminhios-unsigned.ipa`.
5. Cài đặt file IPA này vào iPhone/iPad thông qua TrollStore, AltStore, Sideloadly hoặc Scarlet.
