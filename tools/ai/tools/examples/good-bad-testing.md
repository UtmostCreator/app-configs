# Good / Bad: Testing

## Good

```bash
php artisan test --filter=CheckoutServiceTest
php artisan test tests/Feature/CheckoutServiceTest.php
php artisan test 2>&1 | tail -80
```

## Bad

```bash
php artisan test
php artisan test
php artisan test
```

before isolating the failing test.

Why bad:

- slow
- repetitive
- less diagnostic
