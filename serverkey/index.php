<?php
/**
 * PHUCVN STUDIO - Trang Đăng Ký Tài Khoản iOS
 * Hỗ trợ 5 loại thời hạn: 1 Giờ, 1 Ngày, 7 Ngày, 30 Ngày, Vĩnh Viễn
 */
require_once __DIR__ . '/config.php';

$settings = getSettings();
$error = '';
$success = false;
$registeredUser = null;

// Xử lý khi người dùng submit form đăng ký
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'register') {
    $username = strtolower(trim($_POST['username'] ?? ''));
    $password = trim($_POST['password'] ?? '');
    $confirmPassword = trim($_POST['confirm_password'] ?? '');
    $hwid = trim($_POST['hwid'] ?? '');
    $licenseKey = strtoupper(trim($_POST['license_key'] ?? ''));

    if (empty($settings['allow_register'])) {
        $error = 'Hệ thống hiện đang tạm đóng đăng ký mới. Vui lòng liên hệ Admin!';
    } elseif (strlen($username) < 3 || strlen($username) > 32) {
        $error = 'Tên tài khoản phải từ 3 đến 32 ký tự!';
    } elseif (!preg_match('/^[a-z0-9_]+$/', $username)) {
        $error = 'Tên tài khoản chỉ được chứa chữ cái, số và dấu gạch dưới (_)!';
    } elseif (strlen($password) < 4) {
        $error = 'Mật khẩu phải có ít nhất 4 ký tự!';
    } elseif ($password !== $confirmPassword) {
        $error = 'Mật khẩu xác nhận không trùng khớp!';
    } else {
        $existing = findUserByUsername($username);
        if ($existing) {
            $error = 'Tên tài khoản "' . htmlspecialchars($username) . '" đã được sử dụng! Vui lòng chọn tên khác.';
        } else {
            $role = 'member';
            $duration = $settings['default_duration'] ?? '30d';
            $keyUsed = false;

            // Xử lý mã License Key nếu có
            if (!empty($licenseKey)) {
                $keyData = findKey($licenseKey);
                if (!$keyData) {
                    $error = 'Mã kích hoạt (License Key) không hợp lệ!';
                } elseif (!empty($keyData['is_used'])) {
                    $error = 'Mã kích hoạt này đã được người khác sử dụng!';
                } else {
                    $duration = $keyData['duration'] ?? ($keyData['days'] ?? '30d');
                    $role = $keyData['role'] ?? 'vip';
                    $keyUsed = true;
                }
            } elseif (!empty($settings['require_key'])) {
                $error = 'Hệ thống yêu cầu phải có Mã kích hoạt (License Key) để đăng ký!';
            }

            if (empty($error)) {
                $expiryDate = calculateExpiryDate($duration);

                $newUser = [
                    'id' => time() . rand(100, 999),
                    'username' => $username,
                    'password' => hashUserPassword($password),
                    'role' => $role,
                    'hwid' => $hwid,
                    'is_active' => !empty($settings['auto_activate']),
                    'expiry_date' => $expiryDate,
                    'created_at' => date('Y-m-d H:i:s'),
                    'registered_ip' => $_SERVER['REMOTE_ADDR'] ?? 'Unknown',
                    'api_key' => '',
                    'last_login' => null,
                    'is_hwid_blocked' => false
                ];

                upsertUser($newUser);

                if ($keyUsed) {
                    markKeyUsed($licenseKey, $username);
                }

                $durLabel = formatDurationLabel($duration);
                addLog('register', $username, "Đăng ký tài khoản thành công qua web (Gói: {$durLabel})", $newUser['registered_ip'], $hwid);

                $success = true;
                $registeredUser = [
                    'username' => $username,
                    'role' => ($role === 'vip' ? 'VIP Member' : 'Thành Viên'),
                    'duration_label' => $durLabel,
                    'expiry' => ($expiryDate === 'permanent' ? 'Vĩnh Viễn' : date('d/m/Y H:i', strtotime($expiryDate))),
                    'hwid' => $hwid ?: 'Tự động liên kết khi đăng nhập app'
                ];
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= htmlspecialchars($settings['app_name']) ?> - Đăng Ký Tài Khoản Bản Quyền iOS</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
    <style>
        :root {
            --bg-base: #0a0b10;
            --bg-surface: #12141c;
            --bg-card: #181b26;
            --bg-input: #0e1017;
            --border-color: rgba(147, 51, 234, 0.25);
            --border-focus: #a855f7;
            --primary: #9333ea;
            --primary-glow: rgba(147, 51, 234, 0.45);
            --accent-cyan: #06b6d4;
            --accent-green: #10b981;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --radius-md: 14px;
            --radius-lg: 20px;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { background-color: var(--bg-base); color: var(--text-main); min-height: 100vh; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 24px 16px; position: relative; overflow-x: hidden; }
        .glow-sphere { position: fixed; border-radius: 50%; filter: blur(140px); opacity: 0.28; pointer-events: none; z-index: 0; }
        .sphere-1 { width: 450px; height: 450px; background: #9333ea; top: -100px; left: -100px; }
        .sphere-2 { width: 400px; height: 400px; background: #06b6d4; bottom: -100px; right: -100px; }
        .main-container { width: 100%; max-width: 480px; z-index: 1; position: relative; }
        .glass-card { background: rgba(24, 27, 38, 0.85); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 36px 30px; box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6), 0 0 40px var(--primary-glow); }
        .app-header { text-align: center; margin-bottom: 28px; }
        .logo-wrap { position: relative; display: inline-block; margin-bottom: 14px; }
        .logo-img { width: 90px; height: 90px; border-radius: 50%; object-fit: cover; border: 2px solid var(--primary); box-shadow: 0 0 25px var(--primary-glow); }
        .app-title { font-size: 24px; font-weight: 800; letter-spacing: -0.5px; background: linear-gradient(135deg, #f8fafc 30%, #c084fc 70%, #06b6d4 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; margin-bottom: 6px; }
        .app-subtitle { font-size: 13.5px; color: var(--text-muted); line-height: 1.5; }
        .status-badge { display: inline-flex; align-items: center; gap: 8px; background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.3); color: #34d399; font-size: 12px; font-weight: 600; padding: 6px 14px; border-radius: 999px; margin-top: 12px; }
        .status-dot { width: 7px; height: 7px; background: #10b981; border-radius: 50%; box-shadow: 0 0 10px #10b981; }
        .alert { padding: 14px 16px; border-radius: var(--radius-md); font-size: 13.5px; display: flex; align-items: center; gap: 12px; margin-bottom: 22px; line-height: 1.4; }
        .alert-error { background: rgba(239, 68, 68, 0.15); border: 1px solid rgba(239, 68, 68, 0.4); color: #fca5a5; }
        .alert-success { background: rgba(16, 185, 129, 0.15); border: 1px solid rgba(16, 185, 129, 0.4); color: #6ee7b7; }
        .form-group { margin-bottom: 18px; position: relative; }
        .form-label { display: block; font-size: 13px; font-weight: 600; color: #cbd5e1; margin-bottom: 7px; }
        .input-wrapper { position: relative; display: flex; align-items: center; }
        .input-icon { position: absolute; left: 15px; color: #64748b; font-size: 14px; }
        .form-input { width: 100%; background: var(--bg-input); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: var(--radius-md); padding: 13px 44px 13px 42px; color: var(--text-main); font-size: 14px; outline: none; transition: all 0.2s ease; }
        .form-input:focus { border-color: var(--border-focus); box-shadow: 0 0 0 3px rgba(168, 85, 247, 0.2); }
        .toggle-pwd { position: absolute; right: 15px; color: #64748b; cursor: pointer; padding: 4px; }
        .field-tip { font-size: 11.5px; color: var(--text-muted); margin-top: 5px; line-height: 1.4; }
        .btn-submit { width: 100%; background: linear-gradient(135deg, #9333ea 0%, #7c3aed 50%, #06b6d4 100%); border: none; border-radius: var(--radius-md); padding: 15px; color: #ffffff; font-size: 15px; font-weight: 700; cursor: pointer; display: flex; align-items: center; justify-content: center; gap: 10px; box-shadow: 0 10px 25px rgba(147, 51, 234, 0.4); transition: all 0.3s ease; margin-top: 24px; }
        .btn-submit:hover { transform: translateY(-2px); box-shadow: 0 15px 35px rgba(147, 51, 234, 0.6); }
        .success-box { text-align: center; padding: 10px 0; }
        .success-icon { width: 70px; height: 70px; background: rgba(16, 185, 129, 0.15); border: 2px solid #10b981; border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #10b981; font-size: 30px; margin: 0 auto 18px; box-shadow: 0 0 25px rgba(16, 185, 129, 0.4); }
        .success-title { font-size: 22px; font-weight: 800; color: #34d399; margin-bottom: 8px; }
        .success-desc { font-size: 14px; color: var(--text-muted); margin-bottom: 22px; line-height: 1.5; }
        .account-details { background: var(--bg-input); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: var(--radius-md); padding: 16px; text-align: left; margin-bottom: 24px; }
        .detail-row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; font-size: 13.5px; border-bottom: 1px solid rgba(255, 255, 255, 0.05); }
        .detail-row:last-child { border-bottom: none; }
        .detail-label { color: var(--text-muted); }
        .detail-val { font-weight: 700; color: #e2e8f0; }
        .btn-open-app { background: rgba(255, 255, 255, 0.08); border: 1px solid rgba(255, 255, 255, 0.15); border-radius: var(--radius-md); padding: 14px; color: #fff; text-decoration: none; display: block; font-size: 14.5px; font-weight: 600; margin-bottom: 10px; transition: all 0.2s; }
        .btn-open-app:hover { background: rgba(255, 255, 255, 0.15); }
        .info-card { background: rgba(6, 182, 212, 0.06); border: 1px solid rgba(6, 182, 212, 0.2); border-radius: var(--radius-md); padding: 14px 16px; margin-top: 24px; display: flex; gap: 12px; align-items: flex-start; }
        .info-card i { color: var(--accent-cyan); font-size: 16px; margin-top: 3px; }
        .info-card p { font-size: 12.5px; color: #cbd5e1; line-height: 1.5; }
        .footer { margin-top: 24px; text-align: center; font-size: 12px; color: #64748b; }
        .footer a { color: var(--border-focus); text-decoration: none; }
        .footer a:hover { color: #c084fc; text-decoration: underline; }
    </style>
</head>
<body>
    <div class="glow-sphere sphere-1"></div>
    <div class="glow-sphere sphere-2"></div>

    <div class="main-container">
        <div class="glass-card">
            <div class="app-header">
                <div class="logo-wrap">
                    <img src="assets/logo.png" alt="Logo" class="logo-img" onerror="this.src='https://api.iconify.design/fluent-emoji-flat:robot.svg';">
                </div>
                <h1 class="app-title"><?= htmlspecialchars($settings['app_name']) ?></h1>
                <p class="app-subtitle">Cổng Đăng Ký Tài Khoản Kích Hoạt Bản Quyền iOS</p>
                <div>
                    <span class="status-badge">
                        <span class="status-dot"></span>
                        Cổng Máy Chủ : Đang Hoạt Động
                    </span>
                </div>

                <!-- Điều hướng nhanh -->
                <div style="display: flex; justify-content: center; gap: 10px; margin-top: 15px;">
                    <a href="index.php" style="background: rgba(168, 85, 247, 0.25); border: 1px solid rgba(168, 85, 247, 0.5); color: #fff; padding: 7px 16px; border-radius: 20px; font-size: 13px; text-decoration: none; font-weight: 600;">
                        <i class="fa-solid fa-user-plus"></i> Đăng Ký
                    </a>
                    <a href="admin.php" style="background: rgba(255, 255, 255, 0.08); border: 1px solid rgba(255, 255, 255, 0.15); color: #cbd5e1; padding: 7px 16px; border-radius: 20px; font-size: 13px; text-decoration: none; font-weight: 500;">
                        <i class="fa-solid fa-lock"></i> Đăng Nhập Quản Trị (Admin)
                    </a>
                </div>
            </div>

            <?php if ($success && $registeredUser): ?>
                <div class="success-box">
                    <div class="success-icon">
                        <i class="fa-solid fa-check"></i>
                    </div>
                    <h2 class="success-title">Đăng Ký Thành Công!</h2>
                    <p class="success-desc">Tài khoản của bạn đã được kích hoạt. Hãy đăng nhập vào app iOS để bắt đầu sử dụng.</p>

                    <div class="account-details">
                        <div class="detail-row">
                            <span class="detail-label">Tài khoản:</span>
                            <span class="detail-val"><?= htmlspecialchars($registeredUser['username']) ?></span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Gói bản quyền:</span>
                            <span class="detail-val" style="color: #c084fc;"><?= htmlspecialchars($registeredUser['role']) ?></span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Thời hạn:</span>
                            <span class="detail-val" style="color: #38bdf8;"><?= htmlspecialchars($registeredUser['duration_label']) ?></span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Hết hạn vào:</span>
                            <span class="detail-val" style="color: #34d399;"><?= htmlspecialchars($registeredUser['expiry']) ?></span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Ràng buộc HWID:</span>
                            <span class="detail-val" style="font-size: 11.5px;"><?= htmlspecialchars($registeredUser['hwid']) ?></span>
                        </div>
                    </div>

                    <a href="index.php" class="btn-open-app">
                        <i class="fa-solid fa-user-plus"></i> Đăng Ký Thêm Tài Khoản Khác
                    </a>

                    <div class="info-card" style="margin-top: 15px;">
                        <i class="fa-solid fa-mobile-screen-button"></i>
                        <p><strong>Bước tiếp theo:</strong> Mở ứng dụng <strong>phuciosvn</strong> trên iPhone của bạn và đăng nhập. Thời gian sử dụng sẽ hiển thị ngay trong mục <strong>Cài Đặt</strong> của app!</p>
                    </div>
                </div>

            <?php else: ?>
                <?php if (!empty($error)): ?>
                    <div class="alert alert-error">
                        <i class="fa-solid fa-circle-exclamation"></i>
                        <span><?= htmlspecialchars($error) ?></span>
                    </div>
                <?php endif; ?>

                <form action="index.php" method="POST" id="registerForm">
                    <input type="hidden" name="action" value="register">

                    <!-- Username -->
                    <div class="form-group">
                        <label class="form-label" for="username">Tên tài khoản</label>
                        <div class="input-wrapper">
                            <i class="fa-solid fa-user input-icon"></i>
                            <input type="text" id="username" name="username" class="form-input" placeholder="Ví dụ: phucvn99" required autocomplete="username" value="<?= htmlspecialchars($_POST['username'] ?? '') ?>">
                        </div>
                        <div class="field-tip">Tên đăng nhập từ 3 - 32 ký tự, không dấu.</div>
                    </div>

                    <!-- Password -->
                    <div class="form-group">
                        <label class="form-label" for="password">Mật khẩu</label>
                        <div class="input-wrapper">
                            <i class="fa-solid fa-lock input-icon"></i>
                            <input type="password" id="password" name="password" class="form-input" placeholder="Nhập mật khẩu" required autocomplete="new-password">
                            <i class="fa-regular fa-eye toggle-pwd" onclick="togglePassword('password', this)"></i>
                        </div>
                    </div>

                    <!-- Confirm Password -->
                    <div class="form-group">
                        <label class="form-label" for="confirm_password">Xác nhận mật khẩu</label>
                        <div class="input-wrapper">
                            <i class="fa-solid fa-shield-halved input-icon"></i>
                            <input type="password" id="confirm_password" name="confirm_password" class="form-input" placeholder="Nhập lại mật khẩu" required autocomplete="new-password">
                            <i class="fa-regular fa-eye toggle-pwd" onclick="togglePassword('confirm_password', this)"></i>
                        </div>
                    </div>

                    <!-- HWID (Optional) -->
                    <div class="form-group">
                        <label class="form-label" for="hwid">Mã định danh thiết bị (HWID) <span style="color: var(--text-muted); font-weight: normal;">(Tùy chọn)</span></label>
                        <div class="input-wrapper">
                            <i class="fa-solid fa-fingerprint input-icon"></i>
                            <input type="text" id="hwid" name="hwid" class="form-input" placeholder="Dán mã HWID nếu muốn khóa máy trước" value="<?= htmlspecialchars($_POST['hwid'] ?? '') ?>">
                        </div>
                        <div class="field-tip">Nếu để trống, hệ thống sẽ tự động liên kết máy iPhone khi bạn đăng nhập app lần đầu.</div>
                    </div>

                    <!-- License Key -->
                    <div class="form-group">
                        <label class="form-label" for="license_key">Mã kích hoạt / License Key <?= !empty($settings['require_key']) ? '<span style="color: #ef4444;">*</span>' : '<span style="color: var(--text-muted); font-weight: normal;">(1 giờ, 1 ngày, 7 ngày, 30 ngày, vĩnh viễn)</span>' ?></label>
                        <div class="input-wrapper">
                            <i class="fa-solid fa-key input-icon"></i>
                            <input type="text" id="license_key" name="license_key" class="form-input" placeholder="Dán mã Key nếu có để nhận hạn dùng tương ứng" <?= !empty($settings['require_key']) ? 'required' : '' ?> value="<?= htmlspecialchars($_POST['license_key'] ?? '') ?>">
                        </div>
                        <div class="field-tip">Hệ thống hỗ trợ 5 loại Key: <strong>1 Giờ, 1 Ngày, 7 Ngày, 30 Ngày, Vĩnh Viễn</strong>.</div>
                    </div>

                    <button type="submit" class="btn-submit">
                        <i class="fa-solid fa-rocket"></i> TẠO TÀI KHOẢN NGAY
                    </button>
                </form>

                <div class="info-card">
                    <i class="fa-solid fa-circle-info"></i>
                    <p>Sau khi đăng nhập app thành công, thời gian sử dụng bản quyền còn lại sẽ tự động hiển thị trong mục <strong>Cài Đặt</strong> của app.</p>
                </div>
            <?php endif; ?>
        </div>

        <div class="footer">
            <p><?= htmlspecialchars($settings['app_name']) ?> &copy; 2026 &bull; AI Engine Gatekeeper</p>
            <p style="margin-top: 6px;">
                <a href="admin.php"><i class="fa-solid fa-lock"></i> Quản Trị Viên (Admin)</a>
                <?php if (!empty($settings['telegram_support'])): ?>
                    &bull; <a href="<?= htmlspecialchars($settings['telegram_support']) ?>" target="_blank"><i class="fa-brands fa-telegram"></i> Hỗ trợ Telegram</a>
                <?php endif; ?>
            </p>
        </div>
    </div>

    <script>
        function togglePassword(inputId, icon) {
            const input = document.getElementById(inputId);
            if (input.type === 'password') {
                input.type = 'text';
                icon.classList.remove('fa-eye');
                icon.classList.add('fa-eye-slash');
            } else {
                input.type = 'password';
                icon.classList.remove('fa-eye-slash');
                icon.classList.add('fa-eye');
            }
        }
    </script>
</body>
</html>
