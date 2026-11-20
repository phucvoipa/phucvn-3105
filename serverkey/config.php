<?php
/**
 * PHUCVN STUDIO - Core Configuration & Database Layer
 * Hệ thống Quản lý Tài khoản & API Kích hoạt Bản quyền iOS
 */

if (session_status() === PHP_SESSION_NONE) {
    @session_start();
}

// Thiết lập múi giờ Việt Nam
date_default_timezone_set('Asia/Ho_Chi_Minh');

// Đường dẫn lưu trữ dữ liệu JSON
define('DATA_DIR', __DIR__ . '/data');
define('USERS_FILE', DATA_DIR . '/users.json');
define('KEYS_FILE', DATA_DIR . '/keys.json');
define('SETTINGS_FILE', DATA_DIR . '/settings.json');
define('LOGS_FILE', DATA_DIR . '/logs.json');

// Mật khẩu quản trị viên mặc định
define('DEFAULT_ADMIN_USER', 'phucvn');
define('DEFAULT_ADMIN_PASS', '1231234aZ@1');

// Khởi tạo thư mục nếu chưa tồn tại
if (!file_exists(DATA_DIR)) {
    @mkdir(DATA_DIR, 0777, true);
}

// Đọc file JSON an toàn
function readJsonFile($path, $default = []) {
    if (!file_exists($path)) {
        return $default;
    }
    $content = @file_get_contents($path);
    if ($content === false || trim($content) === '') {
        return $default;
    }
    $data = json_decode($content, true);
    return is_array($data) ? $data : $default;
}

// Ghi file JSON có khóa an toàn (File Locking)
function writeJsonFile($path, $data) {
    $dir = dirname($path);
    if (!file_exists($dir)) {
        @mkdir($dir, 0777, true);
    }
    $json = json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $fp = @fopen($path, 'c');
    if ($fp) {
        if (@flock($fp, LOCK_EX)) {
            @ftruncate($fp, 0);
            @fwrite($fp, $json);
            @fflush($fp);
            @flock($fp, LOCK_UN);
        }
        @fclose($fp);
        return true;
    }
    return @file_put_contents($path, $json) !== false;
}

// Lấy cài đặt hệ thống
function getSettings() {
    $defaults = [
        'app_name' => 'PHUCVN STUDIO',
        'admin_user' => DEFAULT_ADMIN_USER,
        'admin_pass' => DEFAULT_ADMIN_PASS,
        'allow_register' => true,
        'require_key' => false,
        'auto_activate' => true,
        'default_duration' => '30d', // 1h, 1d, 7d, 30d, permanent
        'bind_hwid' => true,
        'telegram_support' => 'https://t.me/phuciosvn'
    ];
    $current = readJsonFile(SETTINGS_FILE, []);
    return array_merge($defaults, $current);
}

// Lưu cài đặt hệ thống
function saveSettings($settings) {
    return writeJsonFile(SETTINGS_FILE, $settings);
}

// Tính toán ngày hết hạn dựa trên 5 loại thời hạn (1h, 1d, 7d, 30d, permanent)
function calculateExpiryDate($duration, $baseDate = null) {
    $d = strtolower(trim((string)$duration));
    if ($d === 'permanent' || $d === '0' || $d === '') {
        return 'permanent';
    }

    $now = new DateTime();
    $dt = clone $now;
    if (!empty($baseDate) && $baseDate !== 'permanent') {
        try {
            $parsed = new DateTime($baseDate);
            if ($parsed > $now) {
                $dt = $parsed;
            }
        } catch (Exception $e) {}
    }

    switch ($d) {
        case '1h':
        case '1_hour':
            $dt->modify('+1 hour');
            break;
        case '1d':
        case '1':
        case '1_day':
            $dt->modify('+1 day');
            break;
        case '7d':
        case '7':
        case '7_days':
            $dt->modify('+7 days');
            break;
        case '30d':
        case '30':
        case '30_days':
            $dt->modify('+30 days');
            break;
        default:
            if (is_numeric($d)) {
                $dt->modify("+{$d} days");
            } else {
                $dt->modify('+30 days');
            }
            break;
    }
    return $dt->format('Y-m-d H:i:s');
}

// Hiển thị nhãn thời hạn
function formatDurationLabel($duration) {
    $d = strtolower(trim((string)$duration));
    switch ($d) {
        case '1h': return '1 Giờ';
        case '1d': return '1 Ngày';
        case '7d': return '7 Ngày';
        case '30d': return '30 Ngày';
        case 'permanent':
        case '0': return 'Vĩnh Viễn';
        default: return $d . ' Ngày';
    }
}

// Định dạng thời gian sử dụng còn lại (Hiển thị trong Cài Đặt của app)
function formatRemainingTime($expiryDate) {
    if (empty($expiryDate) || $expiryDate === 'permanent') {
        return 'Vĩnh Viễn';
    }
    try {
        $now = new DateTime();
        $exp = new DateTime($expiryDate);
        if ($now >= $exp) {
            return 'Hết hạn';
        }

        $diff = $now->diff($exp);
        $totalMinutes = ($diff->days * 24 * 60) + ($diff->h * 60) + $diff->i;

        if ($totalMinutes < 60) {
            return "Còn {$totalMinutes} phút";
        } elseif ($diff->days < 1) {
            return "Còn {$diff->h}h {$diff->i}p";
        } elseif ($diff->days == 1) {
            return "Còn 1 ngày ({$exp->format('d/m H:i')})";
        } elseif ($diff->days <= 7) {
            return "Còn {$diff->days} ngày ({$exp->format('d/m')})";
        } else {
            return "HSD: {$exp->format('d/m/Y')}";
        }
    } catch (Exception $e) {
        return 'Vĩnh Viễn';
    }
}

// Lấy danh sách tài khoản
function getUsers() {
    return readJsonFile(USERS_FILE, []);
}

// Lưu danh sách tài khoản
function saveUsers($users) {
    return writeJsonFile(USERS_FILE, $users);
}

// Tìm tài khoản theo username
function findUserByUsername($username) {
    $users = getUsers();
    $target = strtolower(trim($username));
    foreach ($users as $u) {
        if (strtolower(trim($u['username'])) === $target) {
            return $u;
        }
    }
    return null;
}

// Cập nhật hoặc thêm tài khoản
function upsertUser($userData) {
    $users = getUsers();
    $target = strtolower(trim($userData['username']));
    $found = false;
    foreach ($users as $i => $u) {
        if (strtolower(trim($u['username'])) === $target) {
            $users[$i] = array_merge($u, $userData);
            $found = true;
            break;
        }
    }
    if (!$found) {
        if (empty($userData['id'])) {
            $userData['id'] = time() . rand(100, 999);
        }
        $users[] = $userData;
    }
    saveUsers($users);
    return true;
}

// Kiểm tra mật khẩu
function verifyUserPassword($inputPassword, $storedPassword) {
    if (password_verify($inputPassword, $storedPassword)) {
        return true;
    }
    return ($inputPassword === $storedPassword);
}

// Mã hóa mật khẩu
function hashUserPassword($password) {
    return password_hash($password, PASSWORD_BCRYPT);
}

// Tạo API Key ngẫu nhiên cho phiên đăng nhập
function generateApiKey($length = 32) {
    return bin2hex(random_bytes($length / 2));
}

// Lấy danh sách Key bản quyền
function getKeys() {
    return readJsonFile(KEYS_FILE, []);
}

// Lưu danh sách Key bản quyền
function saveKeys($keys) {
    return writeJsonFile(KEYS_FILE, $keys);
}

// Tìm Key bản quyền
function findKey($keyCode) {
    $keys = getKeys();
    $code = strtoupper(trim($keyCode));
    foreach ($keys as $k) {
        if (strtoupper(trim($k['key'])) === $code) {
            return $k;
        }
    }
    return null;
}

// Đánh dấu Key đã sử dụng
function markKeyUsed($keyCode, $username) {
    $keys = getKeys();
    $code = strtoupper(trim($keyCode));
    foreach ($keys as $i => $k) {
        if (strtoupper(trim($k['key'])) === $code) {
            $keys[$i]['is_used'] = true;
            $keys[$i]['used_by'] = $username;
            $keys[$i]['used_at'] = date('Y-m-d H:i:s');
            saveKeys($keys);
            return true;
        }
    }
    return false;
}

// Ghi nhật ký
function addLog($type, $username, $message, $ip = null, $hwid = null) {
    $logs = readJsonFile(LOGS_FILE, []);
    $ip = $ip ?: ($_SERVER['REMOTE_ADDR'] ?? 'Unknown');
    $entry = [
        'id' => uniqid(),
        'time' => date('Y-m-d H:i:s'),
        'type' => $type,
        'username' => $username,
        'message' => $message,
        'ip' => $ip,
        'hwid' => $hwid
    ];
    array_unshift($logs, $entry);
    if (count($logs) > 500) {
        $logs = array_slice($logs, 0, 500);
    }
    writeJsonFile(LOGS_FILE, $logs);
}
