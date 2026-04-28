<?php
/*
S - One class one purpose, it holds the data & methods needed for its job & nothing more.
Open/Closed Principle
O - open for extension, closed for modification 
Liskov Substitution Principle
L - Child classes must be usable in place of their parent classes 
Interface Segregation Principle
I - Don't force classes to implement things they don't need 
Dependency Inversion Principle
D - interfaces used as params instead of specific classes; High-level code rely on interfaces (not concrete classes); low-level code implements those interfaces.
*/


/**
 * Layered keymaps without bulky per-keyboard lists (SOLID).
 * S — Each class has one job: contracts declare capabilities; devices map inputs→actions; Operator orchestrates.
 * O — Extend by supplying only overrides; compose global ▸ layout ▸ overrides (no edits to existing classes).
 * L — Implementations remain substitutable (same inputs/outputs; no stricter preconditions).
 * I — Narrow interfaces (`Keyboard`, `Pointer`); clients depend only on what they use.
 * D — High-level (Operator) depends on interfaces; low-level devices implement and are injected (IoC/DI).
 */

enum KeyboardType: string
{
    case TKL75 = 'TKL75';
    case TKL80 = 'TKL80';
    case FULL = 'FULL';
}

enum MouseButton: string
{
    case LMB = 'LMB';
    case RMB = 'RMB';
    case WHEEL = 'WHEEL';
}

enum KeyboardButton: string
{
    case ESC = 'ESC';
    case SPACE = 'SPACE';
    case ENTER = 'ENTER'; /* …add more… */
}

// I, D: small, policy-owned contracts
interface Keyboard
{
    public function press(KeyboardButton $key): bool;
}

interface Pointer
{
    public function click(MouseButton $btn): bool;
}

/** S: “map keys to actions” only. O: compose defaults + overrides; no class edits to extend. */
final class KeyboardDevice implements Keyboard
{
    /** @var array<string, callable():bool> keyed by KeyboardButton::$value */
    private array $handlers;

    /**
     * @param array<string, callable():bool> $overrides keys must be string values, e.g. KeyboardButton::ESC->value
     */
    public function __construct(
        public readonly KeyboardType $type, // S: device data only
        array                        $overrides = []
    )
    {
        // O: later arrays override earlier ones (global ▸ layout ▸ overrides)
        $this->handlers = array_replace(
            $this->globalDefaults(),
            $this->layoutDefaults($type),
            $overrides
        );
    }

    public function press(KeyboardButton $key): bool
    {
        // L: consistent contract; unknown key → false (no stricter preconditions)
        echo self::class . " the key '{$key->value}' was pressed" . PHP_EOL;
        $h = $this->handlers[$key->value] ?? [$this, 'noop'];  // instance callable ✔
        return (bool)($h)();
    }

    /** @return array<string, callable():bool> */
    private function globalDefaults(): array
    {
        // O: shared bindings for all keyboards; instance closures capture $this
        return [
            KeyboardButton::ESC->value => fn(): bool => $this->cancel(),
            KeyboardButton::SPACE->value => fn(): bool => $this->space(),
            KeyboardButton::ENTER->value => fn(): bool => $this->enter(),
        ];
    }

    /** @return array<string, callable():bool> */
    private function layoutDefaults(KeyboardType $type): array
    {
        // O: layout-specific bindings; add only what differs from globals
        return match ($type) {
            KeyboardType::FULL => [
                // e.g., numpad keys later: 'NUM_0' => fn() => $this->num0(),
            ],
            KeyboardType::TKL80,
            KeyboardType::TKL75 => [
                // e.g., FN-layer for compact boards
            ],
        };
    }

    // S: concrete actions (private; swappable via overrides without editing this class)
    private function cancel(): bool
    { /* cancel op */
        return true;
    }

    private function space(): bool
    { /* insert space */
        return true;
    }

    private function enter(): bool
    { /* submit/confirm */
        return true;
    }

    private function noop(): bool
    {
        return false;
    }
}

/** Parallel mouse with same layering (S/O/L/I/D). */
final class MouseDevice implements Pointer
{
    /** @var array<string, callable():bool> */
    private array $handlers;

    /** @param array<string, callable():bool> $overrides */
    public function __construct(array $overrides = [])
    {
        // O: compose defaults with overrides
        $this->handlers = array_replace($this->globalDefaults(), $overrides);
    }

    public function click(MouseButton $btn): bool
    {
        // L: predictable fallback
        echo self::class . " the btn '{$btn->value}' was pressed" . PHP_EOL;
        $h = $this->handlers[$btn->value] ?? [$this, 'noop'];  // instance callable ✔
        return (bool)($h)();
    }

    /** @return array<string, callable():bool> */
    private function globalDefaults(): array
    {
        return [
            MouseButton::LMB->value => fn(): bool => $this->select(),
            MouseButton::RMB->value => fn(): bool => $this->contextMenu(),
            MouseButton::WHEEL->value => fn(): bool => $this->wheel(),
        ];
    }

    private function select(): bool
    {
        return true;
    }

    private function contextMenu(): bool
    {
        return true;
    }

    private function wheel(): bool
    {
        return true;
    }

    private function noop(): bool
    {
        return false;
    }
}

// D: high-level depends on abstractions; mechanisms injected (IoC)
final readonly class Operator
{
    public function __construct(
        private ?Keyboard $kb = null,  // D: depends on interface
        private ?Pointer  $ptr = null  // D: depends on interface
    )
    {
    }

    public function press(KeyboardButton $k): bool
    {
        return $this->kb?->press($k) ?? false;
    } // I/L

    public function click(MouseButton $b): bool
    {
        return $this->ptr?->click($b) ?? false;
    } // I/L
}

// ── Usage: pass only overrides; common keys come from defaults (OCP, DRY) ───────
$kb = new KeyboardDevice(
    KeyboardType::TKL75,
    [
        KeyboardButton::ESC->value => fn(): bool => true, // override default
        KeyboardButton::ENTER->value => fn(): bool => true, // override default
        // SPACE and other common keys come from global defaults
    ]
);

$mouse = new MouseDevice([
    MouseButton::RMB->value => fn(): bool => true, // custom context menu
]);

$op = new Operator($kb, $mouse);
$op->press(KeyboardButton::ESC);
$op->click(MouseButton::LMB);