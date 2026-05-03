# Good / Bad: Code Structure Search

## Good

```bash
sg -p 'new CheckoutService($A, $B)' -l php tests
sg -p 'console.log($A)' -l ts src
semgrep -e 'eval($X)' --lang php app
```

## Bad

```bash
rg "new CheckoutService\("
rg "console\.log\("
sed -i 's/oldFunction/newFunction/g' src/**/*.ts
```

Why bad:

- regex can match comments/strings
- bulk text replacement can corrupt code
- AST search reduces false positives
