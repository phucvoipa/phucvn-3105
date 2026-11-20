<?php
/**
 * PHUCVN STUDIO - Admin Control Panel
 * Quản lý 5 loại key bản quyền: 1 giờ, 1 ngày, 7 ngày, 30 ngày, vĩnh viễn
 */
require_once __DIR__ . '/config.php';

$settings = getSettings();
$msg = '';
$error = '';

// Đăng xuất
if (isset($_GET['action']) && $_GET['action'] === 'logout') {
    unset($_SESSION['admin_logged_in']);
    header('Location: admin.php');
    exit;
}

// Đăng nhập Admin
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'admin_login') {
    $adminUser = trim($_POST['username'] ?? '');
    $adminPass = trim($_POST['password'] ?? '');

    if ($adminUser === $settings['admin_user'] && $adminPass === $settings['admin_pass']) {
        $_SESSION['admin_logged_in'] = true;
        header('Location: admin.php');
        exit;
    } else {
        $error = 'Sai tài khoản hoặc mật khẩu quản trị!';
    }
}

$isLoggedIn = !empty($_SESSION['admin_logged_in']);

// Xử lý các thao tác quản trị khi đã đăng nhập
if ($isLoggedIn && $_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $act = $_POST['action'];

    // 1. Thêm tài khoản thủ công (5 loại thời hạn: 1h, 1d, 7d, 30d, permanent)
    if ($act === 'add_user') {
        $uName = strtolower(trim($_POST['username'] ?? ''));
        $uPass = trim($_POST['password'] ?? '');
        $uRole = trim($_POST['role'] ?? 'member');
        $uHwid = trim($_POST['hwid'] ?? '');
        $uDuration = trim($_POST['duration'] ?? '30d');

        if (empty($uName) || empty($uPass)) {
            $error = 'Vui lòng nhập đầy đủ tên tài khoản và mật khẩu!';
        } elseif (findUserByUsername($uName)) {
            $error = 'Tài khoản "' . htmlspecialchars($uName) . '" đã tồn tại!';
        } else {
            $expiry = calculateExpiryDate($uDuration);

            upsertUser([
                'id' => time() . rand(100, 999),
                'username' => $uName,
                'password' => hashUserPassword($uPass),
                'role' => $uRole,
                'hwid' => $uHwid,
                'is_active' => true,
                'expiry_date' => $expiry,
                'created_at' => date('Y-m-d H:i:s'),
                'api_key' => '',
                'last_login' => null,
                'is_hwid_blocked' => false
            ]);
            $durLabel = formatDurationLabel($uDuration);
            addLog('admin', 'admin', "Thêm tài khoản mới: {$uName} ({$uRole}, Hạn: {$durLabel})");
            $msg = "Đã thêm thành công tài khoản: {$uName} (Hạn: {$durLabel})";
        }
    }

    // 2. Xóa tài khoản
    elseif ($act === 'delete_user') {
        $uName = strtolower(trim($_POST['username'] ?? ''));
        $users = getUsers();
        $newUsers = [];
        foreach ($users as $u) {
            if (strtolower($u['username']) !== $uName) {
                $newUsers[] = $u;
            }
        }
        saveUsers($newUsers);
        addLog('admin', 'admin', "Đã xóa tài khoản: {$uName}");
        $msg = "Đã xóa tài khoản: {$uName}";
    }

    // 3. Khóa / Mở khóa tài khoản
    elseif ($act === 'toggle_status') {
        $uName = strtolower(trim($_POST['username'] ?? ''));
        $users = getUsers();
        foreach ($users as $i => $u) {
            if (strtolower($u['username']) === $uName) {
                $users[$i]['is_active'] = empty($u['is_active']);
                saveUsers($users);
                $stText = $users[$i]['is_active'] ? 'Kích hoạt' : 'Khóa';
                addLog('admin', 'admin', "Thay đổi trạng thái tài khoản {$uName}: {$stText}");
                $msg = "Đã {$stText} tài khoản: {$uName}";
                break;
            }
        }
    }

    // 4. Đặt lại HWID
    elseif ($act === 'reset_hwid') {
        $uName = strtolower(trim($_POST['username'] ?? ''));
        $users = getUsers();
        foreach ($users as $i => $u) {
            if (strtolower($u['username']) === $uName) {
                $users[$i]['hwid'] = '';
                saveUsers($users);
                addLog('admin', 'admin', "Reset HWID tài khoản: {$uName}");
                $msg = "Đã reset HWID cho tài khoản: {$uName}. Thiết bị mới sẽ tự động liên kết khi đăng nhập.";
                break;
            }
        }
    }

    // 5. Gia hạn thời gian sử dụng
    elseif ($act === 'extend_user') {
        $uName = strtolower(trim($_POST['username'] ?? ''));
        $addDuration = trim($_POST['add_duration'] ?? '30d');
        $users = getUsers();
        foreach ($users as $i => $u) {
            if (strtolower($u['username']) === $uName) {
                $currentExp = $users[$i]['expiry_date'] ?? 'permanent';
                $users[$i]['expiry_date'] = calculateExpiryDate($addDuration, $currentExp);
                saveUsers($users);
                $label = formatDurationLabel($addDuration);
                addLog('admin', 'admin', "Gia hạn tài khoản {$uName}: {$label}");
                $msg = "Đã gia hạn tài khoản {$uName}: {$label}";
                break;
            }
        }
    }

    // 6. Tạo 5 loại mã Key bản quyền: 1h, 1d, 7d, 30d, permanent
    elseif ($act === 'create_key') {
        $duration = trim($_POST['key_duration'] ?? '30d');
        $role = trim($_POST['key_role'] ?? 'vip');
        $qty = max(1, min(50, intval($_POST['quantity'] ?? 1)));

        // Định dạng prefix theo thời hạn
        $prefix = 'VIP-';
        if ($duration === '1h') $prefix = '1H-';
        elseif ($duration === '1d') $prefix = '1D-';
        elseif ($duration === '7d') $prefix = '7D-';
        elseif ($duration === '30d') $prefix = '30D-';
        elseif ($duration === 'permanent') $prefix = 'LIFE-';

        $keys = getKeys();
        for ($k = 0; $k < $qty; $k++) {
            $keyCode = 'PHUCVN-' . $prefix . strtoupper(substr(bin2hex(random_bytes(3)), 0, 4) . '-' . substr(bin2hex(random_bytes(3)), 0, 4));
            $keys[] = [
                'key' => $keyCode,
                'duration' => $duration, // 1h, 1d, 7d, 30d, permanent
                'role' => $role,
                'is_used' => false,
                'used_by' => null,
                'used_at' => null,
                'created_at' => date('Y-m-d H:i:s')
            ];
        }
        saveKeys($keys);
        $durName = formatDurationLabel($duration);
        addLog('admin', 'admin', "Tạo {$qty} Key bản quyền mới loại {$durName}");
        $msg = "Đã tạo thành công {$qty} Key bản quyền loại: {$durName}!";
    }

    // 7. Xóa Key bản quyền
    elseif ($act === 'delete_key') {
        $keyCode = strtoupper(trim($_POST['key'] ?? ''));
        $keys = getKeys();
        $newKeys = [];
        foreach ($keys as $k) {
            if (strtoupper($k['key']) !== $keyCode) {
                $newKeys[] = $k;
            }
        }
        saveKeys($newKeys);
        $msg = "Đã xóa Key: {$keyCode}";
    }

    // 7b. Reset HWID cho Key (cho phép đổi máy)
    elseif ($act === 'reset_key_hwid') {
        $keyCode = strtoupper(trim($_POST['key'] ?? ''));
        $keys = getKeys();
        foreach ($keys as &$k) {
            if (strtoupper($k['key']) === $keyCode) {
                $oldHwid = $k['used_by'] ?? '';
                $k['used_by'] = null;
                addLog('admin', 'admin', "Đặt lại HWID cho Key {$keyCode} (cũ: {$oldHwid})");
                $msg = "Đã đặt lại HWID cho Key: {$keyCode}! Thiết bị mới có thể kích hoạt.";
                break;
            }
        }
        unset($k);
        saveKeys($keys);
    }

    // 8. Cập nhật Cài đặt hệ thống
    elseif ($act === 'update_settings') {
        $settings['app_name'] = trim($_POST['app_name'] ?? 'PHUCVN STUDIO');
        $settings['admin_user'] = trim($_POST['admin_user'] ?? 'admin');
        if (!empty($_POST['admin_pass'])) {
            $settings['admin_pass'] = trim($_POST['admin_pass']);
        }
        $settings['allow_register'] = !empty($_POST['allow_register']);
        $settings['require_key'] = !empty($_POST['require_key']);
        $settings['auto_activate'] = !empty($_POST['auto_activate']);
        $settings['default_duration'] = trim($_POST['default_duration'] ?? '30d');
        $settings['bind_hwid'] = !empty($_POST['bind_hwid']);
        $settings['telegram_support'] = trim($_POST['telegram_support'] ?? '');

        saveSettings($settings);
        addLog('admin', 'admin', "Cập nhật cấu hình hệ thống");
        $msg = "Đã lưu cài đặt hệ thống thành công!";
    }
}

$allUsers = getUsers();
$allKeys = getKeys();
$allLogs = readJsonFile(LOGS_FILE, []);

$search = strtolower(trim($_GET['q'] ?? ''));
if (!empty($search)) {
    $filteredUsers = [];
    foreach ($allUsers as $u) {
        if (strpos(strtolower($u['username']), $search) !== false || strpos(strtolower($u['hwid'] ?? ''), $search) !== false) {
            $filteredUsers[] = $u;
        }
    }
} else {
    $filteredUsers = $allUsers;
}

$totalUsers = count($allUsers);
$activeUsers = count(array_filter($allUsers, function($u) { return !empty($u['is_active']); }));
$totalKeys = count($allKeys);
$unusedKeys = count(array_filter($allKeys, function($k) { return empty($k['is_used']); }));
?>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quản Trị Hệ Thống - <?= htmlspecialchars($settings['app_name']) ?></title>
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
            --border-color: rgba(147, 51, 234, 0.2);
            --border-focus: #a855f7;
            --primary: #9333ea;
            --accent-cyan: #06b6d4;
            --accent-green: #10b981;
            --accent-red: #ef4444;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --radius-md: 10px;
            --radius-lg: 16px;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Plus Jakarta Sans', sans-serif; }
        body { background: var(--bg-base); color: var(--text-main); min-height: 100vh; font-size: 14px; }
        .login-wrap { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
        .login-box { width: 100%; max-width: 400px; background: var(--bg-surface); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 32px; box-shadow: 0 20px 40px rgba(0,0,0,0.6); }
        .admin-nav { background: var(--bg-surface); border-bottom: 1px solid var(--border-color); padding: 14px 24px; display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 100; }
        .nav-brand { font-size: 18px; font-weight: 800; display: flex; align-items: center; gap: 10px; color: #fff; }
        .nav-links { display: flex; gap: 12px; align-items: center; }
        .nav-btn { background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.1); color: #cbd5e1; padding: 7px 14px; border-radius: var(--radius-md); text-decoration: none; font-size: 13px; font-weight: 600; transition: all 0.2s; }
        .nav-btn:hover { background: rgba(255,255,255,0.12); color: #fff; }
        .nav-btn.logout { color: #fca5a5; border-color: rgba(239,68,68,0.3); }
        .container { max-width: 1240px; margin: 0 auto; padding: 24px; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; margin-bottom: 24px; }
        .stat-card { background: var(--bg-surface); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 18px 20px; display: flex; align-items: center; justify-content: space-between; }
        .stat-val { font-size: 26px; font-weight: 800; color: #fff; margin-top: 4px; }
        .stat-lbl { font-size: 12.5px; color: var(--text-muted); font-weight: 500; }
        .stat-icon { width: 44px; height: 44px; border-radius: 10px; display: flex; align-items: center; justify-content: center; font-size: 18px; }
        .icon-purple { background: rgba(147, 51, 234, 0.15); color: #c084fc; }
        .icon-green { background: rgba(16, 185, 129, 0.15); color: #34d399; }
        .icon-cyan { background: rgba(6, 182, 212, 0.15); color: #22d3ee; }
        .tabs { display: flex; gap: 8px; margin-bottom: 20px; border-bottom: 1px solid rgba(255,255,255,0.08); padding-bottom: 12px; overflow-x: auto; }
        .tab-btn { background: none; border: none; color: var(--text-muted); font-size: 14px; font-weight: 600; padding: 8px 16px; border-radius: var(--radius-md); cursor: pointer; transition: all 0.2s; white-space: nowrap; }
        .tab-btn.active { background: var(--primary); color: #fff; }
        .content-card { background: var(--bg-surface); border: 1px solid var(--border-color); border-radius: var(--radius-lg); padding: 22px; margin-bottom: 24px; }
        .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 18px; flex-wrap: wrap; gap: 12px; }
        .card-title { font-size: 16px; font-weight: 700; color: #f1f5f9; display: flex; align-items: center; gap: 8px; }
        .table-responsive { width: 100%; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; text-align: left; }
        th { background: rgba(255,255,255,0.03); color: var(--text-muted); font-weight: 600; font-size: 12.5px; padding: 12px 14px; border-bottom: 1px solid rgba(255,255,255,0.08); }
        td { padding: 13px 14px; border-bottom: 1px solid rgba(255,255,255,0.04); font-size: 13px; color: #cbd5e1; vertical-align: middle; }
        tr:hover td { background: rgba(255,255,255,0.02); }
        .badge { display: inline-block; padding: 4px 10px; border-radius: 999px; font-size: 11px; font-weight: 700; }
        .badge-active { background: rgba(16, 185, 129, 0.15); color: #34d399; }
        .badge-blocked { background: rgba(239, 68, 68, 0.15); color: #f87171; }
        .badge-vip { background: rgba(147, 51, 234, 0.2); color: #c084fc; }
        .badge-member { background: rgba(148, 163, 184, 0.15); color: #cbd5e1; }
        .form-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 14px; margin-bottom: 16px; }
        .form-group { margin-bottom: 14px; }
        .form-label { display: block; font-size: 12.5px; font-weight: 600; color: #cbd5e1; margin-bottom: 6px; }
        .form-input, .form-select { width: 100%; background: var(--bg-input); border: 1px solid rgba(255,255,255,0.1); border-radius: var(--radius-md); padding: 10px 14px; color: #fff; font-size: 13.5px; outline: none; }
        .form-input:focus, .form-select:focus { border-color: var(--border-focus); }
        .btn { padding: 8px 14px; border-radius: var(--radius-md); font-size: 12.5px; font-weight: 600; cursor: pointer; border: none; display: inline-flex; align-items: center; gap: 6px; transition: all 0.2s; text-decoration: none; }
        .btn-primary { background: var(--primary); color: #fff; }
        .btn-primary:hover { background: #a855f7; }
        .btn-danger { background: rgba(239,68,68,0.2); color: #f87171; }
        .btn-danger:hover { background: #ef4444; color: #fff; }
        .btn-sm { padding: 5px 10px; font-size: 11.5px; }
        .alert { padding: 12px 16px; border-radius: var(--radius-md); margin-bottom: 20px; font-size: 13.5px; }
        .alert-success { background: rgba(16,185,129,0.15); border: 1px solid #10b981; color: #6ee7b7; }
        .alert-error { background: rgba(239,68,68,0.15); border: 1px solid #ef4444; color: #fca5a5; }
        .code-box { font-family: monospace; background: var(--bg-input); padding: 4px 8px; border-radius: 6px; font-size: 11.5px; color: #22d3ee; }
    </style>
</head>
<body>

<?php if (!$isLoggedIn): ?>
    <div class="login-wrap">
        <div class="login-box" style="text-align: center;">
            <div style="margin-bottom: 16px;">
                <img src="assets/logo.png" alt="PHUCVN" style="width: 72px; height: 72px; border-radius: 50%; box-shadow: 0 0 25px rgba(168, 85, 247, 0.45); border: 2px solid rgba(168, 85, 247, 0.5);">
            </div>
            <h2 style="font-size: 22px; font-weight: 800; margin-bottom: 4px; color: #fff; letter-spacing: 0.5px;">PHUCVN STUDIO</h2>
            <p style="font-size: 11px; font-weight: 700; color: #22d3ee; letter-spacing: 1.5px; text-transform: uppercase; margin-bottom: 22px;">Cổng Quản Trị Server Key iOS</p>

            <?php if (!empty($error)): ?>
                <div class="alert alert-error" style="text-align: left;"><?= htmlspecialchars($error) ?></div>
            <?php endif; ?>

            <form method="POST" style="text-align: left;">
                <input type="hidden" name="action" value="admin_login">
                <div class="form-group">
                    <label class="form-label"><i class="fa-solid fa-user-shield"></i> Tài khoản Quản Trị</label>
                    <input type="text" name="username" class="form-input" required autocomplete="username" placeholder="Nhập tài khoản admin">
                </div>
                <div class="form-group">
                    <label class="form-label"><i class="fa-solid fa-lock"></i> Mật khẩu Quản Trị</label>
                    <input type="password" name="password" class="form-input" required autocomplete="current-password" placeholder="Nhập mật khẩu admin">
                </div>
                <button type="submit" class="btn btn-primary" style="width: 100%; padding: 12px; justify-content: center; font-size: 14px; font-weight: 700; margin-top: 10px;">
                    <i class="fa-solid fa-right-to-bracket"></i> ĐĂNG NHẬP HỆ THỐNG
                </button>
            </form>
            <div style="text-align: center; margin-top: 24px; border-top: 1px solid rgba(255,255,255,0.06); padding-top: 16px;">
                <a href="https://phuciosvn.com/" target="_blank" style="color: #22d3ee; text-decoration: none; font-size: 12.5px; font-weight: 600;">
                    <i class="fa-solid fa-cart-shopping"></i> Truy cập Shop: phuciosvn.com
                </a>
            </div>
        </div>
    </div>

<?php else: ?>
    <nav class="admin-nav">
        <div class="nav-brand">
            <i class="fa-solid fa-server" style="color: var(--primary);"></i>
            <span><?= htmlspecialchars($settings['app_name']) ?> <span style="font-size: 11px; color: var(--accent-cyan); font-weight: normal;">Control Center</span></span>
        </div>
        <div class="nav-links">
            <a href="https://phuciosvn.com/" target="_blank" class="nav-btn"><i class="fa-solid fa-cart-shopping"></i> Xem Shop phuciosvn.com</a>
            <a href="admin.php?action=logout" class="nav-btn logout"><i class="fa-solid fa-power-off"></i> Đăng Xuất</a>
        </div>
    </nav>

    <div class="container">
        <?php if (!empty($msg)): ?>
            <div class="alert alert-success"><i class="fa-solid fa-check"></i> <?= htmlspecialchars($msg) ?></div>
        <?php endif; ?>
        <?php if (!empty($error)): ?>
            <div class="alert alert-error"><i class="fa-solid fa-exclamation-triangle"></i> <?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <!-- Stats Grid -->
        <div class="stats-grid">
            <div class="stat-card">
                <div>
                    <div class="stat-lbl">Tổng Tài Khoản</div>
                    <div class="stat-val"><?= $totalUsers ?></div>
                </div>
                <div class="stat-icon icon-purple"><i class="fa-solid fa-users"></i></div>
            </div>
            <div class="stat-card">
                <div>
                    <div class="stat-lbl">Đang Hoạt Động</div>
                    <div class="stat-val"><?= $activeUsers ?></div>
                </div>
                <div class="stat-icon icon-green"><i class="fa-solid fa-user-check"></i></div>
            </div>
            <div class="stat-card">
                <div>
                    <div class="stat-lbl">Kho Key Khả Dụng</div>
                    <div class="stat-val"><?= $unusedKeys ?> <span style="font-size: 13px; color: var(--text-muted); font-weight: normal;">/ <?= $totalKeys ?></span></div>
                </div>
                <div class="stat-icon icon-cyan"><i class="fa-solid fa-key"></i></div>
            </div>
        </div>

        <!-- Navigation Tabs -->
        <div class="tabs">
            <button class="tab-btn active" onclick="switchTab('keysTab', this)"><i class="fa-solid fa-key"></i> Tạo & Quản Lý 5 Loại Key</button>
            <button class="tab-btn" onclick="switchTab('usersTab', this)"><i class="fa-solid fa-users-gear"></i> Quản Lý Tài Khoản</button>
            <button class="tab-btn" onclick="switchTab('settingsTab', this)"><i class="fa-solid fa-sliders"></i> Cài Đặt Hệ Thống</button>
            <button class="tab-btn" onclick="switchTab('logsTab', this)"><i class="fa-solid fa-clock-rotate-left"></i> Nhật Ký Hoạt Động</button>
        </div>

        <!-- TAB 1: 5 LOẠI KEY -->
        <div id="keysTab" class="tab-pane">
            <div class="content-card">
                <div class="card-header">
                    <span class="card-title"><i class="fa-solid fa-plus-circle"></i> Tạo Mã Key Bản Quyền (5 Loại Thời Hạn)</span>
                </div>
                <form method="POST">
                    <input type="hidden" name="action" value="create_key">
                    <div class="form-row">
                        <div>
                            <label class="form-label">Chọn Loại Key</label>
                            <select name="key_duration" class="form-select" style="font-weight: 700; color: #22d3ee;">
                                <option value="1h">⚡ 1 Giờ (Dùng thử ngắn hạn)</option>
                                <option value="1d">⭐ 1 Ngày (24 Giờ)</option>
                                <option value="7d">🔥 7 Ngày (1 Tuần)</option>
                                <option value="30d" selected>💎 30 Ngày (1 Tháng)</option>
                                <option value="permanent">👑 Vĩnh Viễn (Lifetime Trọn Đời)</option>
                            </select>
                        </div>
                        <div>
                            <label class="form-label">Gói bản quyền</label>
                            <select name="key_role" class="form-select">
                                <option value="vip">VIP Member (Toàn bộ tính năng)</option>
                                <option value="member">Thành Viên Thường</option>
                            </select>
                        </div>
                        <div>
                            <label class="form-label">Số lượng Key cần tạo</label>
                            <input type="number" name="quantity" class="form-input" value="1" min="1" max="50">
                        </div>
                    </div>
                    <button type="submit" class="btn btn-primary"><i class="fa-solid fa-key"></i> Sinh Mã Key Ngay</button>
                </form>
            </div>

            <div class="content-card">
                <div class="card-header">
                    <span class="card-title"><i class="fa-solid fa-list-check"></i> Kho Mã Key Đã Tạo (<?= count($allKeys) ?>)</span>
                </div>
                <div class="table-responsive">
                    <table>
                        <thead>
                            <tr>
                                <th>MÃ KEY</th>
                                <th>LOẠI THỜI HẠN</th>
                                <th>GÓI</th>
                                <th>TRẠNG THÁI</th>
                                <th>NGƯỜI KÍCH HOẠT</th>
                                <th>NGÀY TẠO</th>
                                <th>THAO TÁC</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($allKeys)): ?>
                                <tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 30px;">Chưa có mã key nào. Hãy chọn loại key ở trên để tạo.</td></tr>
                            <?php else: foreach (array_reverse($allKeys) as $k): ?>
                                <tr>
                                    <td><strong class="code-box"><?= htmlspecialchars($k['key']) ?></strong></td>
                                    <td>
                                        <strong style="color: #38bdf8;">
                                            <?= formatDurationLabel($k['duration'] ?? ($k['days'] ?? 30)) ?>
                                        </strong>
                                    </td>
                                    <td><span class="badge badge-vip"><?= strtoupper($k['role'] ?? 'VIP') ?></span></td>
                                    <td>
                                        <?php if (!empty($k['is_used'])): ?>
                                            <span class="badge" style="background: rgba(148,163,184,0.15); color: #94a3b8;">Đã dùng</span>
                                        <?php else: ?>
                                            <span class="badge badge-active"><i class="fa-solid fa-sparkles"></i> Chưa dùng</span>
                                        <?php endif; ?>
                                    </td>
                                    <td><?= !empty($k['used_by']) ? ('<strong style="color:#fff;">' . htmlspecialchars($k['used_by']) . '</strong>') : '<span style="color:#64748b;">-</span>' ?></td>
                                    <td style="font-size: 11.5px; color: var(--text-muted);"><?= htmlspecialchars($k['created_at'] ?? 'N/A') ?></td>
                                    <td>
                                        <?php if (!empty($k['used_by'])): ?>
                                        <form method="POST" style="display:inline; margin-right: 4px;" onsubmit="return confirm('Đặt lại thiết bị HWID cho key này? Thiết bị mới sẽ có thể kích hoạt.');">
                                            <input type="hidden" name="action" value="reset_key_hwid">
                                            <input type="hidden" name="key" value="<?= htmlspecialchars($k['key']) ?>">
                                            <button type="submit" class="btn btn-warning btn-sm" title="Đặt lại HWID thiết bị"><i class="fa-solid fa-arrows-rotate"></i> Đổi máy</button>
                                        </form>
                                        <?php endif; ?>
                                        <form method="POST" style="display:inline;" onsubmit="return confirm('Xóa key này?');">
                                            <input type="hidden" name="action" value="delete_key">
                                            <input type="hidden" name="key" value="<?= htmlspecialchars($k['key']) ?>">
                                            <button type="submit" class="btn btn-danger btn-sm" title="Xóa key"><i class="fa-solid fa-trash"></i></button>
                                        </form>
                                    </td>
                                </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- TAB 2: USERS -->
        <div id="usersTab" class="tab-pane" style="display: none;">
            <div class="content-card">
                <div class="card-header">
                    <span class="card-title"><i class="fa-solid fa-user-plus"></i> Thêm Tài Khoản Mới Trực Tiếp</span>
                </div>
                <form method="POST">
                    <input type="hidden" name="action" value="add_user">
                    <div class="form-row">
                        <div>
                            <label class="form-label">Tên tài khoản</label>
                            <input type="text" name="username" class="form-input" required placeholder="Tên đăng nhập">
                        </div>
                        <div>
                            <label class="form-label">Mật khẩu</label>
                            <input type="text" name="password" class="form-input" required placeholder="Mật khẩu">
                        </div>
                        <div>
                            <label class="form-label">Hạng thành viên</label>
                            <select name="role" class="form-select">
                                <option value="vip">VIP Member</option>
                                <option value="member">Thành Viên Thường</option>
                                <option value="admin">Quản Trị Viên (Admin)</option>
                            </select>
                        </div>
                        <div>
                            <label class="form-label">Thời hạn sử dụng</label>
                            <select name="duration" class="form-select" style="color: #22d3ee; font-weight: 700;">
                                <option value="1h">1 Giờ</option>
                                <option value="1d">1 Ngày</option>
                                <option value="7d">7 Ngày</option>
                                <option value="30d" selected>30 Ngày</option>
                                <option value="permanent">Vĩnh Viễn</option>
                            </select>
                        </div>
                    </div>
                    <button type="submit" class="btn btn-primary"><i class="fa-solid fa-plus"></i> Tạo Tài Khoản</button>
                </form>
            </div>

            <div class="content-card">
                <div class="card-header">
                    <span class="card-title"><i class="fa-solid fa-table-list"></i> Danh Sách Tài Khoản (<?= count($filteredUsers) ?>)</span>
                    <form method="GET" style="display: flex; gap: 8px;">
                        <input type="text" name="q" class="form-input" style="width: 250px; padding: 7px 12px; font-size: 12.5px;" placeholder="Tìm username hoặc HWID..." value="<?= htmlspecialchars($_GET['q'] ?? '') ?>">
                        <button type="submit" class="btn btn-primary btn-sm"><i class="fa-solid fa-search"></i> Tìm</button>
                    </form>
                </div>

                <div class="table-responsive">
                    <table>
                        <thead>
                            <tr>
                                <th>TÀI KHOẢN</th>
                                <th>VAI TRÒ</th>
                                <th>TRẠNG THÁI</th>
                                <th>THỜI GIAN CÒN LẠI (HIỆN TRONG APP)</th>
                                <th>THIẾT BỊ (HWID)</th>
                                <th>ĐĂNG NHẬP CUỐI</th>
                                <th>THAO TÁC</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($filteredUsers)): ?>
                                <tr><td colspan="7" style="text-align: center; color: var(--text-muted); padding: 30px;">Chưa có tài khoản nào trong hệ thống.</td></tr>
                            <?php else: foreach ($filteredUsers as $u): ?>
                                <tr>
                                    <td>
                                        <strong style="color: #fff; font-size: 14px;"><?= htmlspecialchars($u['username']) ?></strong>
                                        <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">Tạo: <?= htmlspecialchars($u['created_at'] ?? 'N/A') ?></div>
                                    </td>
                                    <td>
                                        <?php if (($u['role'] ?? '') === 'admin'): ?>
                                            <span class="badge" style="background: rgba(239,68,68,0.2); color: #f87171;">ADMIN</span>
                                        <?php elseif (($u['role'] ?? '') === 'vip'): ?>
                                            <span class="badge badge-vip">VIP</span>
                                        <?php else: ?>
                                            <span class="badge badge-member">MEMBER</span>
                                        <?php endif; ?>
                                    </td>
                                    <td>
                                        <?php if (!empty($u['is_active'])): ?>
                                            <span class="badge badge-active"><i class="fa-solid fa-check"></i> Hoạt động</span>
                                        <?php else: ?>
                                            <span class="badge badge-blocked"><i class="fa-solid fa-ban"></i> Đã khóa</span>
                                        <?php endif; ?>
                                    </td>
                                    <td>
                                        <div style="font-weight: 700; color: #34d399; font-size: 13.5px;">
                                            <i class="fa-solid fa-clock"></i> <?= formatRemainingTime($u['expiry_date'] ?? 'permanent') ?>
                                        </div>
                                        <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">
                                            <?= empty($u['expiry_date']) || $u['expiry_date'] === 'permanent' ? 'Vĩnh viễn' : date('d/m/Y H:i', strtotime($u['expiry_date'])) ?>
                                        </div>
                                    </td>
                                    <td>
                                        <?php if (!empty($u['hwid'])): ?>
                                            <span class="code-box" title="<?= htmlspecialchars($u['hwid']) ?>"><?= htmlspecialchars(substr($u['hwid'], 0, 16)) ?>...</span>
                                        <?php else: ?>
                                            <span style="color: #64748b; font-size: 11.5px;">(Chưa liên kết)</span>
                                        <?php endif; ?>
                                    </td>
                                    <td style="font-size: 11.5px; color: var(--text-muted);">
                                        <?= htmlspecialchars($u['last_login'] ?? 'Chưa đăng nhập') ?>
                                    </td>
                                    <td>
                                        <div style="display: flex; gap: 5px;">
                                            <!-- Khóa / Mở -->
                                            <form method="POST" style="display:inline;">
                                                <input type="hidden" name="action" value="toggle_status">
                                                <input type="hidden" name="username" value="<?= htmlspecialchars($u['username']) ?>">
                                                <button type="submit" class="btn btn-sm <?= empty($u['is_active']) ? 'btn-primary' : 'btn-danger' ?>" title="Đổi trạng thái Khóa/Mở">
                                                    <?= empty($u['is_active']) ? '<i class="fa-solid fa-unlock"></i>' : '<i class="fa-solid fa-lock"></i>' ?>
                                                </button>
                                            </form>

                                            <!-- Reset HWID -->
                                            <form method="POST" style="display:inline;" onsubmit="return confirm('Reset HWID tài khoản <?= htmlspecialchars($u['username']) ?> để liên kết máy mới?');">
                                                <input type="hidden" name="action" value="reset_hwid">
                                                <input type="hidden" name="username" value="<?= htmlspecialchars($u['username']) ?>">
                                                <button type="submit" class="btn btn-sm" style="background: rgba(6,182,212,0.15); color: #22d3ee;" title="Reset HWID máy">
                                                    <i class="fa-solid fa-arrows-rotate"></i>
                                                </button>
                                            </form>

                                            <!-- Xóa User -->
                                            <form method="POST" style="display:inline;" onsubmit="return confirm('Xóa vĩnh viễn tài khoản <?= htmlspecialchars($u['username']) ?>?');">
                                                <input type="hidden" name="action" value="delete_user">
                                                <input type="hidden" name="username" value="<?= htmlspecialchars($u['username']) ?>">
                                                <button type="submit" class="btn btn-sm btn-danger" title="Xóa tài khoản">
                                                    <i class="fa-solid fa-trash"></i>
                                                </button>
                                            </form>
                                        </div>
                                    </td>
                                </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <!-- TAB 3: SETTINGS -->
        <div id="settingsTab" class="tab-pane" style="display: none;">
            <div class="content-card">
                <div class="card-header">
                    <span class="card-title"><i class="fa-solid fa-gears"></i> Cấu Hình Cổng Đăng Ký & Bảo Mật</span>
                </div>
                <form method="POST">
                    <input type="hidden" name="action" value="update_settings">
                    <div class="form-row">
                        <div>
                            <label class="form-label">Tên Ứng Dụng</label>
                            <input type="text" name="app_name" class="form-input" value="<?= htmlspecialchars($settings['app_name']) ?>" required>
                        </div>
                        <div>
                            <label class="form-label">Tài Khoản Admin</label>
                            <input type="text" name="admin_user" class="form-input" value="<?= htmlspecialchars($settings['admin_user']) ?>" required>
                        </div>
                        <div>
                            <label class="form-label">Mật Khẩu Admin Mới <span style="font-weight:normal; color:var(--text-muted);">(Để trống nếu không đổi)</span></label>
                            <input type="password" name="admin_pass" class="form-input" placeholder="Nhập nếu muốn đổi">
                        </div>
                    </div>

                    <div class="form-row">
                        <div>
                            <label class="form-label">Thời hạn mặc định khi đăng ký tự do</label>
                            <select name="default_duration" class="form-select">
                                <option value="1h" <?= ($settings['default_duration'] ?? '') === '1h' ? 'selected' : '' ?>>1 Giờ</option>
                                <option value="1d" <?= ($settings['default_duration'] ?? '') === '1d' ? 'selected' : '' ?>>1 Ngày</option>
                                <option value="7d" <?= ($settings['default_duration'] ?? '') === '7d' ? 'selected' : '' ?>>7 Ngày</option>
                                <option value="30d" <?= ($settings['default_duration'] ?? '') === '30d' || empty($settings['default_duration']) ? 'selected' : '' ?>>30 Ngày</option>
                                <option value="permanent" <?= ($settings['default_duration'] ?? '') === 'permanent' ? 'selected' : '' ?>>Vĩnh Viễn</option>
                            </select>
                        </div>
                        <div>
                            <label class="form-label">Link Hỗ Trợ Telegram</label>
                            <input type="text" name="telegram_support" class="form-input" value="<?= htmlspecialchars($settings['telegram_support'] ?? '') ?>" placeholder="https://t.me/...">
                        </div>
                    </div>

                    <div style="margin: 20px 0; border-top: 1px solid rgba(255,255,255,0.06); padding-top: 16px;">
                        <label style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px; cursor: pointer;">
                            <input type="checkbox" name="allow_register" value="1" <?= !empty($settings['allow_register']) ? 'checked' : '' ?>>
                            <span><strong>Mở cổng đăng ký tài khoản tự do:</strong> Cho phép thành viên tự đăng ký trên website</span>
                        </label>

                        <label style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px; cursor: pointer;">
                            <input type="checkbox" name="require_key" value="1" <?= !empty($settings['require_key']) ? 'checked' : '' ?>>
                            <span><strong>Bắt buộc có License Key khi đăng ký:</strong> Chỉ người có mã Key bạn cấp mới đăng ký được</span>
                        </label>

                        <label style="display: flex; align-items: center; gap: 10px; margin-bottom: 12px; cursor: pointer;">
                            <input type="checkbox" name="bind_hwid" value="1" <?= !empty($settings['bind_hwid']) ? 'checked' : '' ?>>
                            <span><strong>Tự động khóa thiết bị (HWID) ở lần đăng nhập app đầu tiên:</strong> Chống chia sẻ tài khoản</span>
                        </label>
                    </div>

                    <button type="submit" class="btn btn-primary"><i class="fa-solid fa-save"></i> Lưu Cài Đặt</button>
                </form>
            </div>
        </div>

        <!-- TAB 4: LOGS -->
        <div id="logsTab" class="tab-pane" style="display: none;">
            <div class="content-card">
                <div class="card-header">
                    <span class="card-title"><i class="fa-solid fa-history"></i> Nhật Ký Hoạt Động Gần Đây</span>
                </div>
                <div class="table-responsive">
                    <table>
                        <thead>
                            <tr>
                                <th>THỜI GIAN</th>
                                <th>LOẠI</th>
                                <th>TÀI KHOẢN</th>
                                <th>NỘI DUNG</th>
                                <th>IP TRUY CẬP</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($allLogs)): ?>
                                <tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 30px;">Chưa có nhật ký nào.</td></tr>
                            <?php else: foreach (array_slice($allLogs, 0, 50) as $l): ?>
                                <tr>
                                    <td style="font-size: 11.5px; color: var(--text-muted);"><?= htmlspecialchars($l['time']) ?></td>
                                    <td>
                                        <?php if ($l['type'] === 'login_success'): ?>
                                            <span class="badge badge-active">Login OK</span>
                                        <?php elseif ($l['type'] === 'login_fail'): ?>
                                            <span class="badge badge-blocked">Login Fail</span>
                                        <?php elseif ($l['type'] === 'register'): ?>
                                            <span class="badge badge-vip">Register</span>
                                        <?php else: ?>
                                            <span class="badge badge-member"><?= htmlspecialchars($l['type']) ?></span>
                                        <?php endif; ?>
                                    </td>
                                    <td><strong><?= htmlspecialchars($l['username']) ?></strong></td>
                                    <td><?= htmlspecialchars($l['message']) ?></td>
                                    <td><span class="code-box"><?= htmlspecialchars($l['ip'] ?? 'Unknown') ?></span></td>
                                </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <script>
        function switchTab(tabId, btn) {
            document.querySelectorAll('.tab-pane').forEach(el => el.style.display = 'none');
            document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
            document.getElementById(tabId).style.display = 'block';
            btn.classList.add('active');
        }
    </script>
<?php endif; ?>

</body>
</html>
