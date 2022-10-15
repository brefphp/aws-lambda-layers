This directory lets you run Lambda layers you have built locally.

**First, build the layers.**

Then, to test them, start the Lambda containers:

```bash
make run
```

In another terminal, send test requests:

```bash
make test-function
make test-fpm
```
