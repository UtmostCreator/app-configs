# Good / Bad: File Viewing

## Good

```bash
bat -n app/Services/Checkout/CheckoutService.php
bat --line-range 100:160 app/Services/Checkout/CheckoutService.php
tail -100 storage/logs/laravel.log
```

## Bad

```bash
cat app/Services/Checkout/CheckoutService.php
cat storage/logs/laravel.log
tail -f storage/logs/*.log
```

Why bad:

- huge output hides relevant evidence
- no line numbers
- harder for agents to cite/reason
