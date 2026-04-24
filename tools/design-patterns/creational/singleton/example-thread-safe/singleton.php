<?php

final class DB
{
    private static ?self $instance = null;
    private \PDO $pdo;

    private function __construct()
    {
        $host = $_ENV['DB_HOST'] ?? '127.0.0.1';
        $db   = $_ENV['DB_NAME'] ?? 'test';
        $user = $_ENV['DB_USER'] ?? 'root';
        $pass = $_ENV['DB_PASS'] ?? '';
        $port = (int)($_ENV['DB_PORT'] ?? 3306);
        $dsn  = "mysql:host={$host};port={$port};dbname={$db};charset=utf8mb4";

        $options = [
            \PDO::ATTR_ERRMODE            => \PDO::ERRMODE_EXCEPTION,
            \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
            \PDO::ATTR_EMULATE_PREPARES   => false,
        ];

        $this->pdo = new \PDO($dsn, $user, $pass, $options);
    }

    public static function instance(): self
    {
        return self::$instance ??= new self();
    }

    public function pdo(): \PDO
    {
        return $this->pdo;
    }

    public function query(string $sql, array $params = []): \PDOStatement
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt;
    }

    /** Fetch all rows */
    public function fetchAll(string $sql, array $params = []): array
    {
        return $this->query($sql, $params)->fetchAll();
    }

    /** Fetch single row */
    public function fetch(string $sql, array $params = []): ?array
    {
        $row = $this->query($sql, $params)->fetch();
        return $row ?: null;
    }

    /** Insert row and return last insert ID */
    public function insert(string $table, array $data): int
    {
        $cols = array_keys($data);
        $placeholders = implode(', ', array_fill(0, count($cols), '?'));
        $sql = sprintf(
            "INSERT INTO `%s` (%s) VALUES (%s)",
            $table,
            implode(', ', $cols),
            $placeholders
        );
        $this->query($sql, array_values($data));
        return (int)$this->pdo->lastInsertId();
    }

    /** Update rows by condition */
    public function update(string $table, array $data, string $where, array $whereParams = []): int
    {
        $set = implode(', ', array_map(fn($col) => "`$col` = ?", array_keys($data)));
        $sql = sprintf("UPDATE `%s` SET %s WHERE %s", $table, $set, $where);
        $stmt = $this->query($sql, array_merge(array_values($data), $whereParams));
        return $stmt->rowCount();
    }

    /** Delete rows by condition */
    public function delete(string $table, string $where, array $params = []): int
    {
        $sql = sprintf("DELETE FROM `%s` WHERE %s", $table, $where);
        $stmt = $this->query($sql, $params);
        return $stmt->rowCount();
    }

    /** Count rows */
    public function count(string $table, string $where = '1', array $params = []): int
    {
        $sql = sprintf("SELECT COUNT(*) AS c FROM `%s` WHERE %s", $table, $where);
        return (int)$this->query($sql, $params)->fetchColumn();
    }

    /** Check if a record exists */
    public function exists(string $table, string $where, array $params = []): bool
    {
        $sql = sprintf("SELECT 1 FROM `%s` WHERE %s LIMIT 1", $table, $where);
        return (bool)$this->query($sql, $params)->fetchColumn();
    }

    private function __clone() {}
    public function __wakeup(): void
    {
        throw new \LogicException('Cannot unserialize singleton');
    }
}

$db = DB::instance();

// 1. Select all users
$users = $db->fetchAll("SELECT * FROM user");

// 2. Select one user
$user = $db->fetch("SELECT * FROM user WHERE id = ?", [1]);

// 3. Insert new user
$newId = $db->insert('user', ['first_name' => 'Roman', 'email' => 'r@example.com']);

// 4. Update existing user
$updated = $db->update('user', ['email' => 'new@example.com'], 'id = ?', [1]);

// 5. Count users
$count = $db->count('user');

// 6. Check existence
$exists = $db->exists('user', 'email = ?', ['new@example.com']);

// 7. Delete user
$deleted = $db->delete('user', 'id = ?', [1]);

var_dump($user, $newId, $updated, $deleted, $count); // NULL int(1) int(1) int(1) int(1)