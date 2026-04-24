<?php

/** Strategy interface (family of algorithms) */
interface ValidationRule
{
    public function validate(string $value): bool;
}

/** Concrete strategies */
final class EmailRule implements ValidationRule
{
    public function validate(string $v): bool
    {
        return filter_var($v, FILTER_VALIDATE_EMAIL) !== false;
    }
}

final class PasswordRule implements ValidationRule
{
    public function validate(string $v): bool
    {
        return strlen($v) >= 8 && preg_match('/[A-Z]/', $v) && preg_match('/\d/', $v);
    }
}

final class PhoneRule implements ValidationRule
{
    public function validate(string $v): bool
    {
        return preg_match('/^\+\d{10,15}$/', $v) === 1;
    }
}

final class UrlRule implements ValidationRule
{
    public function validate(string $v): bool
    {
        return filter_var($v, FILTER_VALIDATE_URL) !== false;
    }
}

/** Context */
final class Validator
{
    public function __construct(private ValidationRule $rule)
    {
    }

    public function setRule(ValidationRule $r): void
    {
        $this->rule = $r;
    }

    public function isValid(string $value): bool
    {
        return $this->rule->validate($value);
    }
}

/** Demo (runtime swapping) */
$v = new Validator(new EmailRule());
var_dump($v->isValid('user@mail.com')); // true

$v->setRule(new PasswordRule());
var_dump($v->isValid('Strong123')); // true

$v->setRule(new PhoneRule());
var_dump($v->isValid('+447911123456')); // true

$v->setRule(new UrlRule());
var_dump($v->isValid('https://example.com')); // true